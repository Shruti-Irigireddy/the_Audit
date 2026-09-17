import 'package:bloc/bloc.dart';

import 'package:the_audit/features/pre_flight/domain/dtos/pre_flight_dtos.dart';
import 'package:the_audit/features/pre_flight/domain/repositories/pre_flight_repository.dart';
import 'pre_flight_state.dart';

class PreFlightCubit extends Cubit<PreFlightState> {
  final PreFlightRepository _repository;

  PreFlightCubit(this._repository) : super(PreFlightState.initial());

  Future<void> loadSortiesForSession(String sessionId) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final sorties = await _repository.getSortiesForSession(sessionId);
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          sorties: sorties,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> createSortie({
    String? flightId,
    required String sessionId,
    required String sessionVehicleId,
    required String picUserId,
    String? objective,
    required String performedBy,
    List<String> selectedPayloadIds = const [],
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      final id = await _repository.createSortie(
        flightId: flightId,
        sessionId: sessionId,
        sessionVehicleId: sessionVehicleId,
        picUserId: picUserId,
        objective: objective,
        performedBy: performedBy,
        selectedPayloadIds: selectedPayloadIds,
      );
      await loadSetup(id);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> loadSetup(String flightId) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final sortie = await _repository.getSortieById(flightId);
      final setup = await _repository.getPreFlightSetup(flightId);
      final users = await _repository.getSortieUsers(flightId);
      final payloads = await _repository.getSortiePayloads(flightId);
      final batteries = await _repository.getSortieBatteries(flightId);
      final checklistItems = await _repository.loadChecklistForSortie(flightId);
      final checklistResponses = await _repository
          .getChecklistResponsesForFlight(flightId);
      final overrides = await _repository.getOverridesForFlight(flightId);

      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          selectedSortie: sortie,
          setup: setup,
          users: users,
          payloads: payloads,
          batteries: batteries,
          checklistItems: checklistItems,
          checklistResponses: checklistResponses,
          overrides: overrides,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> updateSortieBasicInfo({
    required String flightId,
    String? picUserId,
    String? objective,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.updateSortieBasicInfo(
        flightId: flightId,
        picUserId: picUserId,
        objective: objective,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> addUserToSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.addUserToSortie(
        flightId: flightId,
        userId: userId,
        role: role,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> removeUserFromSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.removeUserFromSortie(
        flightId: flightId,
        userId: userId,
        role: role,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replaceSortieUsers({
    required String flightId,
    required List<SortieUserDraft> users,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.replaceSortieUsers(
        flightId: flightId,
        users: users,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> loadSelectablePayloadsForSortie(String flightId) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final payloads = await _repository.getSelectablePayloadsForSortie(
        flightId,
      );
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          selectablePayloads: payloads,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> addPayloadToSortie({
    required String flightId,
    required String payloadId,
    required String createdBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.addPayloadToSortie(
        flightId: flightId,
        payloadId: payloadId,
        createdBy: createdBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> removePayloadFromSortie({
    required String flightId,
    required String payloadId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.removePayloadFromSortie(
        flightId: flightId,
        payloadId: payloadId,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replaceSortiePayloads({
    required String flightId,
    required List<String> payloadIds,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.replaceSortiePayloads(
        flightId: flightId,
        payloadIds: payloadIds,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> loadSelectableBatteriesForSortie(String flightId) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final batteries = await _repository.getSelectableBatteriesForSortie(
        flightId,
      );
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          selectableBatteries: batteries,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> addBatteryToSortie({
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String createdBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.addBatteryToSortie(
        flightId: flightId,
        batteryId: batteryId,
        voltageStart: voltageStart,
        percentStart: percentStart,
        createdBy: createdBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replaceAllSortieBatteries({
    required String flightId,
    required List<SortieBatteryDraft> batteries,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.replaceAllSortieBatteries(
        flightId: flightId,
        batteries: batteries,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> replaceSortieBattery({
    required String flightId,
    required String oldBatteryId,
    required String newBatteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.replaceSortieBattery(
        flightId: flightId,
        oldBatteryId: oldBatteryId,
        newBatteryId: newBatteryId,
        voltageStart: voltageStart,
        percentStart: percentStart,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> updateSortieBatteryStartState({
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.updateSortieBatteryStartState(
        flightId: flightId,
        batteryId: batteryId,
        voltageStart: voltageStart,
        percentStart: percentStart,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> removeBatteryFromSortie({
    required String flightId,
    required String batteryId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.removeBatteryFromSortie(
        flightId: flightId,
        batteryId: batteryId,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<BatteryStartDefaults?> getLatestBatteryEndStateAsStartDefault({
    required String batteryId,
    String? excludeFlightId,
  }) {
    return _repository.getLatestBatteryEndStateAsStartDefault(
      batteryId: batteryId,
      excludeFlightId: excludeFlightId,
    );
  }

  Future<void> loadBlockingChecklistItemsForSortie(String flightId) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final checklistItems = await _repository
          .loadBlockingChecklistItemsForSortie(flightId);
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          checklistItems: checklistItems,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> saveChecklistResponse({
    required String flightId,
    required String itemId,
    required String response,
    String? valueText,
    double? valueNumber,
    String? notes,
    required String createdBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.saveChecklistResponse(
        flightId: flightId,
        itemId: itemId,
        response: response,
        valueText: valueText,
        valueNumber: valueNumber,
        notes: notes,
        createdBy: createdBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> saveChecklistResponses({
    required String flightId,
    required List<ChecklistResponseDraft> responses,
    required String createdBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.saveChecklistResponses(
        flightId: flightId,
        responses: responses,
        createdBy: createdBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> validateReadyToArm(String flightId) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.validating,
        errorMessage: null,
      ),
    );

    try {
      final readyToArmValidation = await _repository.validateReadyToArm(
        flightId,
      );
      final completionIssues = await _repository.validatePreflightCompletion(
        flightId,
      );
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          readyToArmValidation: readyToArmValidation,
          completionIssues: completionIssues,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> submitGoNoGoDecision({
    required String flightId,
    required String finalDecision,
    String? decisionReason,
    required String decisionBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.submitGoNoGoDecision(
        flightId: flightId,
        finalDecision: finalDecision,
        decisionReason: decisionReason,
        decisionBy: decisionBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> createChecklistOverride({
    required String flightId,
    required String itemId,
    required String overriddenReason,
    required String overriddenBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.createChecklistOverride(
        flightId: flightId,
        itemId: itemId,
        overriddenReason: overriddenReason,
        overriddenBy: overriddenBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> markFlightInProgress({
    required String flightId,
    String flightStatus = 'IN_PROGRESS',
    DateTime? takeoffAt,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.markFlightInProgress(
        flightId: flightId,
        flightStatus: flightStatus,
        takeoffAt: takeoffAt,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> recordLanding({
    required String flightId,
    String flightStatus = 'LANDED',
    DateTime? landingAt,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.recordLanding(
        flightId: flightId,
        flightStatus: flightStatus,
        landingAt: landingAt,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> abortSortie({
    required String flightId,
    required String reason,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.abortSortie(
        flightId: flightId,
        reason: reason,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error) {
      _emitFailure(error);
    }
  }

  void _emitFailure(Object error) {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.failure,
        errorMessage: error.toString(),
      ),
    );
  }
}
