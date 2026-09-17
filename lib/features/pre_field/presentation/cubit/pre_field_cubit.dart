import 'package:bloc/bloc.dart';

import 'package:the_audit/features/pre_field/domain/dtos/pre_field_dtos.dart';
import 'package:the_audit/features/pre_field/domain/repositories/pre_field_repository.dart';
import 'pre_field_state.dart';

class PreFieldCubit extends Cubit<PreFieldState> {
  final PreFieldRepository _repository;

  PreFieldCubit(this._repository) : super(PreFieldState.initial());

  Future<void> loadInProgressSessions() async {
    emit(
      state.copyWith(
        viewStatus: PreFieldViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final sessions = await _repository.getInProgressFieldSessions();
      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          sessions: sessions,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> createFieldSession({
    String? sessionId,
    required DateTime date,
    required String locationName,
    required double latitude,
    required double longitude,
    required String missionType,
    required String createdBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      final id = await _repository.createFieldSession(
        sessionId: sessionId,
        date: date,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        missionType: missionType,
        createdBy: createdBy,
      );
      await loadSession(id);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> loadSession(String sessionId) async {
    emit(
      state.copyWith(
        viewStatus: PreFieldViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final session = await _repository.getFieldSessionById(sessionId);
      final users = await _repository.getSessionUsers(sessionId);
      final vehicles = await _repository.getSessionVehicles(sessionId);
      final batteries = await _repository.getSessionBatteries(sessionId);
      final equipmentChecks = await _repository.getSessionEquipmentChecks(
        sessionId,
      );
      final compatibilityIssues = await _repository
          .getPayloadCompatibilityIssues(sessionId);

      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          selectedSession: session,
          sessionUsers: users,
          sessionVehicles: vehicles,
          sessionBatteries: batteries,
          equipmentChecks: equipmentChecks,
          compatibilityIssues: compatibilityIssues,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> loadSummary(String sessionId) async {
    emit(
      state.copyWith(
        viewStatus: PreFieldViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final summary = await _repository.getPreFieldSummary(sessionId);
      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          summary: summary,
          selectedSession: summary.session,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> loadEquipmentList() async {
    emit(
      state.copyWith(
        viewStatus: PreFieldViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final equipmentList = await _repository.getActiveEquipmentList();
      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          equipmentList: equipmentList,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> closeFieldSession({
    required String sessionId,
    required String closedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.closeFieldSession(
        sessionId: sessionId,
        closedBy: closedBy,
      );
      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          successMessage: 'Field session closed.',
          errorMessage: null,
        ),
      );
      await loadInProgressSessions();
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> updateFieldSessionBasicInfo({
    required String sessionId,
    DateTime? date,
    String? locationName,
    double? latitude,
    double? longitude,
    String? missionType,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.updateFieldSessionBasicInfo(
        sessionId: sessionId,
        date: date,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        missionType: missionType,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> addUserToSession({
    required String sessionId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.addUserToSession(
        sessionId: sessionId,
        userId: userId,
        role: role,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> removeUserFromSession({
    required String sessionId,
    required String sessionUserId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removeUserFromSession(
        sessionUserId: sessionUserId,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replaceSessionUsers({
    required String sessionId,
    required List<SessionUserDraft> users,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.replaceSessionUsers(
        sessionId: sessionId,
        users: users,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<int> countSessionUsersByRole({
    required String sessionId,
    required String role,
  }) {
    return _repository.countSessionUsersByRole(
      sessionId: sessionId,
      role: role,
    );
  }

  Future<void> addVehicleToSession({
    required String sessionId,
    required String vehicleId,
    String? objective,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.addVehicleToSession(
        sessionId: sessionId,
        vehicleId: vehicleId,
        objective: objective,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> removeVehicleFromSession({
    required String sessionId,
    required String sessionVehicleId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removeVehicleFromSession(
        sessionVehicleId: sessionVehicleId,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> updateSessionVehicleObjective({
    required String sessionId,
    required String sessionVehicleId,
    String? objective,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.updateSessionVehicleObjective(
        sessionVehicleId: sessionVehicleId,
        objective: objective,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replaceSessionVehicles({
    required String sessionId,
    required List<SessionVehicleDraft> vehicles,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.replaceSessionVehicles(
        sessionId: sessionId,
        vehicles: vehicles,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<int> countSessionVehicles(String sessionId) {
    return _repository.countSessionVehicles(sessionId);
  }

  Future<int> countSortiesForSessionVehicle(String sessionVehicleId) {
    return _repository.countSortiesForSessionVehicle(sessionVehicleId);
  }

  Future<void> loadPayloadsForSessionVehicle(String sessionVehicleId) async {
    emit(
      state.copyWith(
        viewStatus: PreFieldViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final payloads = await _repository.getPayloadsForSessionVehicle(
        sessionVehicleId,
      );
      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          sessionVehiclePayloads: payloads,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> addPayloadToSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.addPayloadToSessionVehicle(
        sessionVehicleId: sessionVehicleId,
        payloadId: payloadId,
        performedBy: performedBy,
      );
      await loadPayloadsForSessionVehicle(sessionVehicleId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> removePayloadFromSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removePayloadFromSessionVehicle(
        sessionVehicleId: sessionVehicleId,
        payloadId: payloadId,
        performedBy: performedBy,
      );
      await loadPayloadsForSessionVehicle(sessionVehicleId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replacePayloadsForSessionVehicle({
    required String sessionVehicleId,
    required List<String> payloadIds,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.replacePayloadsForSessionVehicle(
        sessionVehicleId: sessionVehicleId,
        payloadIds: payloadIds,
        performedBy: performedBy,
      );
      await loadPayloadsForSessionVehicle(sessionVehicleId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<int> countPayloadsForSessionVehicle(String sessionVehicleId) {
    return _repository.countPayloadsForSessionVehicle(sessionVehicleId);
  }

  Future<void> addBatteryToSession({
    required String sessionId,
    required String batteryId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.addBatteryToSession(
        sessionId: sessionId,
        batteryId: batteryId,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> removeBatteryFromSession({
    required String sessionId,
    required String sessionBatteryId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removeBatteryFromSession(
        sessionBatteryId: sessionBatteryId,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replaceSessionBatteries({
    required String sessionId,
    required List<SessionBatteryDraft> batteries,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.replaceSessionBatteries(
        sessionId: sessionId,
        batteries: batteries,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> createEquipmentChecksForSession({
    required String sessionId,
    required String checkedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.createEquipmentChecksForSession(
        sessionId: sessionId,
        checkedBy: checkedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> updateEquipmentCheck({
    required String sessionId,
    required String equipmentCheckId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.updateEquipmentCheck(
        equipmentCheckId: equipmentCheckId,
        isPacked: isPacked,
        notes: notes,
        checkedBy: checkedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> addCustomEquipmentCheckToSession({
    required String sessionId,
    required String equipmentId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.addCustomEquipmentCheckToSession(
        sessionId: sessionId,
        equipmentId: equipmentId,
        isPacked: isPacked,
        notes: notes,
        checkedBy: checkedBy,
      );
      await loadSession(sessionId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<int> countUnpackedEquipmentChecks(String sessionId) {
    return _repository.countUnpackedEquipmentChecks(sessionId);
  }

  Future<void> createEquipmentItem({
    String? id,
    required String name,
    required String category,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.createEquipmentItem(
        id: id,
        name: name,
        category: category,
        performedBy: performedBy,
      );
      await loadEquipmentList();
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> updateEquipmentItem({
    required String equipmentId,
    String? name,
    String? category,
    bool? isActive,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.updateEquipmentItem(
        equipmentId: equipmentId,
        name: name,
        category: category,
        isActive: isActive,
        performedBy: performedBy,
      );
      await loadEquipmentList();
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> deactivateEquipmentItem({
    required String equipmentId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.deactivateEquipmentItem(
        equipmentId: equipmentId,
        performedBy: performedBy,
      );
      await loadEquipmentList();
    } catch (error) {
      _emitFailure(error);
    }
  }

  void _emitFailure(Object error) {
    emit(
      state.copyWith(
        viewStatus: PreFieldViewStatus.failure,
        errorMessage: error.toString(),
      ),
    );
  }
}
