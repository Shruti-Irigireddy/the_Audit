import 'package:bloc/bloc.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/pre_field/domain/dtos/pre_field_dtos.dart';
import 'package:the_audit/features/pre_field/domain/repositories/pre_field_repository.dart';
import 'pre_field_state.dart';

class PreFieldCubit extends Cubit<PreFieldState> {
  static const _log = AppLogger('PreFieldCubit');

  final PreFieldRepository _repository;

  PreFieldCubit(this._repository) : super(PreFieldState.initial());

  Future<void> loadInProgressSessions() async {
    _log.t('loadInProgressSessions()');
    emit(
      state.copyWith(
        viewStatus: PreFieldViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final sessions = await _repository.getInProgressFieldSessions();
      _log.d('${sessions.length} in-progress sessions loaded');
      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          sessions: sessions,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadInProgressSessions failed', error, stackTrace);
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
    required String sessionStatus,
    required String createdBy,
  }) async {
    _log.i(
      'createFieldSession(id: $sessionId, mission: $missionType, status: $sessionStatus)',
    );
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
        sessionStatus: sessionStatus,
        createdBy: createdBy,
      );
      _log.i('session created: $id');
      await loadSession(id);
    } catch (error, stackTrace) {
      _log.e('createFieldSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadSession(String sessionId) async {
    _log.t('loadSession($sessionId)');
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
      _log.d(
        'session $sessionId: ${users.length} users, ${vehicles.length} vehicles, '
        '${batteries.length} batteries, ${equipmentChecks.length} checks, '
        '${compatibilityIssues.length} compatibility issues',
      );

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
    } catch (error, stackTrace) {
      _log.e('loadSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadSummary(String sessionId) async {
    _log.t('loadSummary($sessionId)');
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
    } catch (error, stackTrace) {
      _log.e('loadSummary failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadEquipmentList() async {
    _log.t('loadEquipmentList()');
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
    } catch (error, stackTrace) {
      _log.e('loadEquipmentList failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> closeFieldSession({
    required String sessionId,
    required String closedBy,
  }) async {
    _log.i('closeFieldSession($sessionId)');
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.closeFieldSession(
        sessionId: sessionId,
        closedBy: closedBy,
      );
      _log.i('session closed: $sessionId');
      emit(
        state.copyWith(
          viewStatus: PreFieldViewStatus.loaded,
          successMessage: 'Field session closed.',
          errorMessage: null,
        ),
      );
      await loadInProgressSessions();
    } catch (error, stackTrace) {
      _log.e('closeFieldSession failed', error, stackTrace);
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
    _log.i('updateFieldSessionBasicInfo($sessionId)');
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
    } catch (error, stackTrace) {
      _log.e('updateFieldSessionBasicInfo failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> addUserToSession({
    required String sessionId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    _log.i('addUserToSession($sessionId, role: $role)');
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
    } catch (error, stackTrace) {
      _log.e('addUserToSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removeUserFromSession({
    required String sessionId,
    required String sessionUserId,
    required String performedBy,
  }) async {
    _log.i('removeUserFromSession($sessionId, $sessionUserId)');
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removeUserFromSession(
        sessionUserId: sessionUserId,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error, stackTrace) {
      _log.e('removeUserFromSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replaceSessionUsers({
    required String sessionId,
    required List<SessionUserDraft> users,
    required String performedBy,
  }) async {
    _log.i('replaceSessionUsers($sessionId, ${users.length} users)');
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
    } catch (error, stackTrace) {
      _log.e('replaceSessionUsers failed', error, stackTrace);
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
    _log.i('addVehicleToSession($sessionId, vehicle: $vehicleId)');
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
    } catch (error, stackTrace) {
      _log.e('addVehicleToSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removeVehicleFromSession({
    required String sessionId,
    required String sessionVehicleId,
    required String performedBy,
  }) async {
    _log.i('removeVehicleFromSession($sessionId, $sessionVehicleId)');
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removeVehicleFromSession(
        sessionVehicleId: sessionVehicleId,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error, stackTrace) {
      _log.e('removeVehicleFromSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updateSessionVehicleObjective({
    required String sessionId,
    required String sessionVehicleId,
    String? objective,
    required String performedBy,
  }) async {
    _log.i('updateSessionVehicleObjective($sessionId, $sessionVehicleId)');
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
    } catch (error, stackTrace) {
      _log.e('updateSessionVehicleObjective failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replaceSessionVehicles({
    required String sessionId,
    required List<SessionVehicleDraft> vehicles,
    required String performedBy,
  }) async {
    _log.i('replaceSessionVehicles($sessionId, ${vehicles.length} vehicles)');
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
    } catch (error, stackTrace) {
      _log.e('replaceSessionVehicles failed', error, stackTrace);
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
    _log.t('loadPayloadsForSessionVehicle($sessionVehicleId)');
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
    } catch (error, stackTrace) {
      _log.e('loadPayloadsForSessionVehicle failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> addPayloadToSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    _log.i(
      'addPayloadToSessionVehicle($sessionVehicleId, payload: $payloadId)',
    );
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
    } catch (error, stackTrace) {
      _log.e('addPayloadToSessionVehicle failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removePayloadFromSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    _log.i(
      'removePayloadFromSessionVehicle($sessionVehicleId, payload: $payloadId)',
    );
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
    } catch (error, stackTrace) {
      _log.e('removePayloadFromSessionVehicle failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replacePayloadsForSessionVehicle({
    required String sessionVehicleId,
    required List<String> payloadIds,
    required String performedBy,
  }) async {
    _log.i(
      'replacePayloadsForSessionVehicle($sessionVehicleId, ${payloadIds.length} payloads)',
    );
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
    } catch (error, stackTrace) {
      _log.e('replacePayloadsForSessionVehicle failed', error, stackTrace);
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
    _log.i('addBatteryToSession($sessionId, battery: $batteryId)');
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
    } catch (error, stackTrace) {
      _log.e('addBatteryToSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removeBatteryFromSession({
    required String sessionId,
    required String sessionBatteryId,
    required String performedBy,
  }) async {
    _log.i('removeBatteryFromSession($sessionId, $sessionBatteryId)');
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removeBatteryFromSession(
        sessionBatteryId: sessionBatteryId,
        performedBy: performedBy,
      );
      await loadSession(sessionId);
    } catch (error, stackTrace) {
      _log.e('removeBatteryFromSession failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replaceSessionBatteries({
    required String sessionId,
    required List<SessionBatteryDraft> batteries,
    required String performedBy,
  }) async {
    _log.i(
      'replaceSessionBatteries($sessionId, ${batteries.length} batteries)',
    );
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
    } catch (error, stackTrace) {
      _log.e('replaceSessionBatteries failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> createEquipmentChecksForSession({
    required String sessionId,
    required String checkedBy,
  }) async {
    _log.i('createEquipmentChecksForSession($sessionId)');
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.createEquipmentChecksForSession(
        sessionId: sessionId,
        checkedBy: checkedBy,
      );
      await loadSession(sessionId);
    } catch (error, stackTrace) {
      _log.e('createEquipmentChecksForSession failed', error, stackTrace);
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
    _log.i(
      'updateEquipmentCheck($sessionId, $equipmentCheckId, packed: $isPacked)',
    );
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
    } catch (error, stackTrace) {
      _log.e('updateEquipmentCheck failed', error, stackTrace);
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
    _log.i(
      'addCustomEquipmentCheckToSession($sessionId, $equipmentId, packed: $isPacked)',
    );
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
    } catch (error, stackTrace) {
      _log.e('addCustomEquipmentCheckToSession failed', error, stackTrace);
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
    _log.i('createEquipmentItem(id: $id, category: $category)');
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
    } catch (error, stackTrace) {
      _log.e('createEquipmentItem failed', error, stackTrace);
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
    _log.i('updateEquipmentItem($equipmentId, active: $isActive)');
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
    } catch (error, stackTrace) {
      _log.e('updateEquipmentItem failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> deactivateEquipmentItem({
    required String equipmentId,
    required String performedBy,
  }) async {
    _log.i('deactivateEquipmentItem($equipmentId)');
    emit(
      state.copyWith(viewStatus: PreFieldViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.deactivateEquipmentItem(
        equipmentId: equipmentId,
        performedBy: performedBy,
      );
      await loadEquipmentList();
    } catch (error, stackTrace) {
      _log.e('deactivateEquipmentItem failed', error, stackTrace);
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
