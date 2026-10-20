import 'dart:async';

import 'package:bloc/bloc.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/pre_flight/domain/dtos/pre_flight_dtos.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/repositories/pre_flight_repository.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';
import 'pre_flight_state.dart';

class PreFlightCubit extends Cubit<PreFlightState> {
  static const _log = AppLogger('PreFlightCubit');

  final PreFlightRepository _repository;

  PreFlightCubit(this._repository) : super(PreFlightState.initial());

  StreamSubscription<List<SortieEntity>>? _sortiesWatch;

  /// Keeps [PreFlightState.sorties] in step with the database: the list
  /// updates itself after a sortie is created, decided or closed.
  void watchSortiesForSession(String sessionId) {
    _log.t('watchSortiesForSession($sessionId)');
    _sortiesWatch?.cancel();
    _sortiesWatch = _repository
        .watchSortiesForSession(sessionId)
        .listen(
          (sorties) => emit(
            state.copyWith(
              viewStatus: PreFlightViewStatus.loaded,
              sorties: sorties,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            _log.e('watchSortiesForSession failed', error, stackTrace);
            _emitFailure(error);
          },
        );
  }

  @override
  Future<void> close() async {
    await _sortiesWatch?.cancel();
    return super.close();
  }

  Future<void> loadSortiesForSession(String sessionId) async {
    _log.t('loadSortiesForSession($sessionId)');
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final sorties = await _repository.getSortiesForSession(sessionId);
      _log.d('${sorties.length} sorties loaded for $sessionId');
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          sorties: sorties,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSortiesForSession failed', error, stackTrace);
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
    _log.i(
      'createSortie(id: $flightId, session: $sessionId, vehicle: $sessionVehicleId, ${selectedPayloadIds.length} payloads)',
    );
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
      _log.i('sortie created: $id');
      await loadSetup(id);
    } catch (error, stackTrace) {
      _log.e('createSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadSetup(String flightId) async {
    _log.t('loadSetup($flightId)');
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
      _log.d(
        'setup $flightId: ${checklistItems.length} checklist items, '
        '${checklistResponses.length} responses, ${overrides.length} overrides',
      );

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
    } catch (error, stackTrace) {
      _log.e('loadSetup failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  /// Saves the take-off coordinates and refreshes just the sortie (no full
  /// reload, so the checklist below doesn't redraw). Returns whether it
  /// worked.
  Future<bool> updateSortieLocation({
    required String flightId,
    required double latitude,
    required double longitude,
    required String performedBy,
  }) async {
    _log.i('updateSortieLocation($flightId)');
    try {
      await _repository.updateSortieLocation(
        flightId: flightId,
        latitude: latitude,
        longitude: longitude,
        performedBy: performedBy,
      );
      final sortie = await _repository.getSortieById(flightId);
      emit(state.copyWith(selectedSortie: sortie, errorMessage: null));
      return true;
    } catch (error, stackTrace) {
      _log.e('updateSortieLocation failed', error, stackTrace);
      _emitFailure(error);
      return false;
    }
  }

  Future<void> updateSortieBasicInfo({
    required String flightId,
    String? picUserId,
    String? objective,
    required String performedBy,
  }) async {
    _log.i('updateSortieBasicInfo($flightId)');
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
    } catch (error, stackTrace) {
      _log.e('updateSortieBasicInfo failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> addUserToSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    _log.i('addUserToSortie($flightId, role: $role)');
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
    } catch (error, stackTrace) {
      _log.e('addUserToSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removeUserFromSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    _log.i('removeUserFromSortie($flightId, role: $role)');
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
    } catch (error, stackTrace) {
      _log.e('removeUserFromSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replaceSortieUsers({
    required String flightId,
    required List<SortieUserDraft> users,
    required String performedBy,
  }) async {
    _log.i('replaceSortieUsers($flightId, ${users.length} users)');
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
    } catch (error, stackTrace) {
      _log.e('replaceSortieUsers failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadSelectablePayloadsForSortie(String flightId) async {
    _log.t('loadSelectablePayloadsForSortie($flightId)');
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
    } catch (error, stackTrace) {
      _log.e('loadSelectablePayloadsForSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> addPayloadToSortie({
    required String flightId,
    required String payloadId,
    required String createdBy,
  }) async {
    _log.i('addPayloadToSortie($flightId, payload: $payloadId)');
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
    } catch (error, stackTrace) {
      _log.e('addPayloadToSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removePayloadFromSortie({
    required String flightId,
    required String payloadId,
    required String performedBy,
  }) async {
    _log.i('removePayloadFromSortie($flightId, payload: $payloadId)');
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
    } catch (error, stackTrace) {
      _log.e('removePayloadFromSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replaceSortiePayloads({
    required String flightId,
    required List<String> payloadIds,
    required String performedBy,
  }) async {
    _log.i('replaceSortiePayloads($flightId, ${payloadIds.length} payloads)');
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
    } catch (error, stackTrace) {
      _log.e('replaceSortiePayloads failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadSelectableBatteriesForSortie(String flightId) async {
    _log.t('loadSelectableBatteriesForSortie($flightId)');
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
    } catch (error, stackTrace) {
      _log.e('loadSelectableBatteriesForSortie failed', error, stackTrace);
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
    _log.i('addBatteryToSortie($flightId, battery: $batteryId)');
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
    } catch (error, stackTrace) {
      _log.e('addBatteryToSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replaceAllSortieBatteries({
    required String flightId,
    required List<SortieBatteryDraft> batteries,
    required String performedBy,
  }) async {
    _log.i(
      'replaceAllSortieBatteries($flightId, ${batteries.length} batteries)',
    );
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
    } catch (error, stackTrace) {
      _log.e('replaceAllSortieBatteries failed', error, stackTrace);
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
    _log.i('replaceSortieBattery($flightId, $oldBatteryId -> $newBatteryId)');
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
    } catch (error, stackTrace) {
      _log.e('replaceSortieBattery failed', error, stackTrace);
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
    _log.i('updateSortieBatteryStartState($flightId, battery: $batteryId)');
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
    } catch (error, stackTrace) {
      _log.e('updateSortieBatteryStartState failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removeBatteryFromSortie({
    required String flightId,
    required String batteryId,
    required String performedBy,
  }) async {
    _log.i('removeBatteryFromSortie($flightId, battery: $batteryId)');
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
    } catch (error, stackTrace) {
      _log.e('removeBatteryFromSortie failed', error, stackTrace);
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
    _log.t('loadBlockingChecklistItemsForSortie($flightId)');
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
    } catch (error, stackTrace) {
      _log.e('loadBlockingChecklistItemsForSortie failed', error, stackTrace);
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
    _log.i(
      'saveChecklistResponse($flightId, item: $itemId, response: $response)',
    );
    // Updated in place: the answer shows (and the arming count changes) at
    // once, with no loading/saving status, so the checklist doesn't redraw
    // around a focused field or jump while it's being filled in.
    final previousResponses = state.checklistResponses;
    final optimistic = _withLocalResponse(
      previousResponses,
      flightId: flightId,
      itemId: itemId,
      response: response,
      valueText: valueText,
      valueNumber: valueNumber,
      notes: notes,
      createdBy: createdBy,
    );
    if (optimistic != null) {
      emit(state.copyWith(checklistResponses: optimistic, errorMessage: null));
    }

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
      // Only the answers and the arming check are re-read, in one emit.
      final checklistResponses = await _repository
          .getChecklistResponsesForFlight(flightId);
      final readyToArmValidation = await _repository.validateReadyToArm(
        flightId,
      );
      final completionIssues = await _repository.validatePreflightCompletion(
        flightId,
      );
      _log.d(
        'response saved; readyToArm=${readyToArmValidation.canProceed}, '
        'missing=${readyToArmValidation.missingItems.length}, '
        'failed=${readyToArmValidation.failedItems.length}',
      );
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          checklistResponses: checklistResponses,
          readyToArmValidation: readyToArmValidation,
          completionIssues: completionIssues,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('saveChecklistResponse failed', error, stackTrace);
      // Put the answer back the way it was; the error shows as a snackbar.
      emit(state.copyWith(checklistResponses: previousResponses));
      _emitFailure(error);
    }
  }

  /// [responses] with [itemId]'s answer replaced (or added), or null when the
  /// item isn't in the loaded checklist.
  List<ChecklistResponseWithItemEntity>? _withLocalResponse(
    List<ChecklistResponseWithItemEntity> responses, {
    required String flightId,
    required String itemId,
    required String response,
    String? valueText,
    double? valueNumber,
    String? notes,
    required String createdBy,
  }) {
    ChecklistItemEntity? item;
    for (final candidate in state.checklistItems) {
      if (candidate.id == itemId) item = candidate;
    }
    if (item == null) return null;

    ChecklistResponseEntity? existing;
    for (final saved in responses) {
      if (saved.checklistItem.id == itemId) existing = saved.checklistResponse;
    }
    final now = DateTime.now();
    final updated = ChecklistResponseWithItemEntity(
      checklistItem: item,
      checklistResponse: ChecklistResponseEntity(
        id: existing?.id ?? 'pending-$itemId',
        flightId: flightId,
        itemId: itemId,
        response: response,
        valueText: valueText,
        valueNumber: valueNumber,
        notes: notes,
        createdBy: existing?.createdBy ?? createdBy,
        responseAt: now,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );

    return [
      for (final saved in responses)
        if (saved.checklistItem.id != itemId) saved,
      updated,
    ];
  }

  Future<void> saveChecklistResponses({
    required String flightId,
    required List<ChecklistResponseDraft> responses,
    required String createdBy,
  }) async {
    _log.i('saveChecklistResponses($flightId, ${responses.length} responses)');
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
    } catch (error, stackTrace) {
      _log.e('saveChecklistResponses failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> validateReadyToArm(String flightId) async {
    _log.t('validateReadyToArm($flightId)');
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
      _log.d(
        'readyToArm($flightId): canProceed=${readyToArmValidation.canProceed}, '
        'missing=${readyToArmValidation.missingItems.length}, '
        'failed=${readyToArmValidation.failedItems.length}, '
        'completionIssues=${completionIssues.length}',
      );
      emit(
        state.copyWith(
          viewStatus: PreFlightViewStatus.loaded,
          readyToArmValidation: readyToArmValidation,
          completionIssues: completionIssues,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('validateReadyToArm failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> submitGoNoGoDecision({
    required String flightId,
    required String finalDecision,
    String? decisionReason,
    required String decisionBy,
  }) async {
    _log.i('submitGoNoGoDecision($flightId, decision: $finalDecision)');
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
      _log.i('decision recorded: $flightId -> $finalDecision');
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('submitGoNoGoDecision failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> createChecklistOverride({
    required String flightId,
    required String itemId,
    required String overriddenReason,
    required String overriddenBy,
  }) async {
    _log.i('createChecklistOverride($flightId, item: $itemId)');
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
      _log.i('manual override recorded: $flightId, item $itemId');
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('createChecklistOverride failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> markFlightInProgress({
    required String flightId,
    DateTime? takeoffAt,
    required String performedBy,
  }) async {
    _log.i('markFlightInProgress($flightId)');
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.markFlightInProgress(
        flightId: flightId,
        takeoffAt: takeoffAt,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('markFlightInProgress failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> recordLanding({
    required String flightId,
    DateTime? landingAt,
    required String performedBy,
  }) async {
    _log.i('recordLanding($flightId)');
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.recordLanding(
        flightId: flightId,
        landingAt: landingAt,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('recordLanding failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> abortSortie({
    required String flightId,
    required String reason,
    required String performedBy,
  }) async {
    _log.i('abortSortie($flightId)');
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
      _log.i('sortie aborted: $flightId');
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('abortSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  void _emitFailure(Object error) {
    emit(
      state.copyWith(
        viewStatus: PreFlightViewStatus.failure,
        errorMessage: friendlyError(error),
      ),
    );
  }
}
