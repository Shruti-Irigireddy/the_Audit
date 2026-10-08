import 'package:bloc/bloc.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/post_flight/domain/dtos/post_flight_dtos.dart';
import 'package:the_audit/features/post_flight/domain/repositories/post_flight_repository.dart';
import 'post_flight_state.dart';

class PostFlightCubit extends Cubit<PostFlightState> {
  static const _log = AppLogger('PostFlightCubit');

  final PostFlightRepository _repository;

  PostFlightCubit(this._repository) : super(PostFlightState.initial());

  Future<void> loadPendingSorties({String? sessionId, int limit = 50}) async {
    _log.t('loadPendingSorties(session: $sessionId, limit: $limit)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final sorties = await _repository.getPostFlightPendingSorties(
        sessionId: sessionId,
        limit: limit,
      );
      _log.d('${sorties.length} pending sorties loaded');
      emit(
        state.copyWith(
          viewStatus: PostFlightViewStatus.loaded,
          pendingSorties: sorties,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadPendingSorties failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadClosedSorties({String? sessionId, int limit = 50}) async {
    _log.t('loadClosedSorties(session: $sessionId, limit: $limit)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final sorties = await _repository.getClosedSorties(
        sessionId: sessionId,
        limit: limit,
      );
      _log.d('${sorties.length} closed sorties loaded');
      emit(
        state.copyWith(
          viewStatus: PostFlightViewStatus.loaded,
          closedSorties: sorties,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadClosedSorties failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadSetup(String flightId) async {
    _log.t('loadSetup($flightId)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final setup = await _repository.getPostFlightSetup(flightId);
      final note = await _repository.getPostFlightNoteForFlight(flightId);
      final batteries = await _repository.getSortieBatteries(flightId);
      final payloads = await _repository.getSortiePayloads(flightId);
      final missingEndStates = await _repository.countBatteriesWithoutEndState(
        flightId,
      );
      final allBatteriesHaveEndState = await _repository
          .allBatteriesHaveEndState(flightId);
      _log.d(
        'setup $flightId: ${batteries.length} batteries, '
        '${payloads.length} payloads, $missingEndStates missing end states',
      );

      emit(
        state.copyWith(
          viewStatus: PostFlightViewStatus.loaded,
          setup: setup,
          note: note,
          batteries: batteries,
          payloads: payloads,
          batteriesWithoutEndStateCount: missingEndStates,
          allBatteriesHaveEndState: allBatteriesHaveEndState,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSetup failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  /// Saves the notes and closes the sortie (FR-POST-08). A sortie that is
  /// already closed is just saved again; the database logs that edit as an
  /// amendment. Returns whether it worked.
  Future<bool> saveAndClose({
    required String flightId,
    required String objectiveResult,
    String? objectiveNotes,
    String? missionRating,
    String? issuesEncountered,
    String? logStoredAt,
    String? logLocation,
    String? logNotes,
    int? flightDurationSeconds,
    double? landedBatteryVoltage,
    int? landedBatteryPercent,
    bool followUpRequired = false,
    String? followUpNotes,
    String? followUpAssignedTo,
    String? followUpStatus,
    String? notes,
    required String performedBy,
  }) async {
    _log.i(
      'saveAndClose($flightId, objective: $objectiveResult, '
      'followUp: $followUpRequired)',
    );
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.savePostFlightNote(
        flightId: flightId,
        objectiveResult: objectiveResult,
        objectiveNotes: objectiveNotes,
        missionRating: missionRating,
        issuesEncountered: issuesEncountered,
        logStoredAt: logStoredAt,
        logLocation: logLocation,
        logNotes: logNotes,
        flightDurationSeconds: flightDurationSeconds,
        landedBatteryVoltage: landedBatteryVoltage,
        landedBatteryPercent: landedBatteryPercent,
        followUpRequired: followUpRequired,
        followUpNotes: followUpNotes,
        followUpAssignedTo: followUpAssignedTo,
        followUpStatus: followUpStatus,
        notes: notes,
        createdBy: performedBy,
      );
      final sortie = state.setup?.sortie;
      if (sortie?.flightStatus != 'CLOSED') {
        await _repository.closeSortie(flightId: flightId, closedBy: performedBy);
        _log.i('sortie closed: $flightId');
      }
      await loadSetup(flightId);
      return !state.hasError;
    } catch (error, stackTrace) {
      _log.e('saveAndClose failed', error, stackTrace);
      _emitFailure(error);
      return false;
    }
  }

  Future<void> saveBatteryEndStates({
    required String flightId,
    required List<BatteryEndStateDraft> batteries,
    required String performedBy,
  }) async {
    _log.i('saveBatteryEndStates($flightId, ${batteries.length} batteries)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.saveBatteryEndStates(
        flightId: flightId,
        batteries: batteries,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('saveBatteryEndStates failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updateObjectiveResult({
    required String flightId,
    required String objectiveResult,
    String? objectiveNotes,
    required String performedBy,
  }) async {
    _log.i('updateObjectiveResult($flightId, $objectiveResult)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.updateObjectiveResult(
        flightId: flightId,
        objectiveResult: objectiveResult,
        objectiveNotes: objectiveNotes,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('updateObjectiveResult failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updateMissionRating({
    required String flightId,
    String? missionRating,
    required String performedBy,
  }) async {
    _log.i('updateMissionRating($flightId, $missionRating)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.updateMissionRating(
        flightId: flightId,
        missionRating: missionRating,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('updateMissionRating failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updateLogDetails({
    required String flightId,
    String? logStoredAt,
    String? logLocation,
    String? logNotes,
    required String performedBy,
  }) async {
    _log.i('updateLogDetails($flightId)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.updateLogDetails(
        flightId: flightId,
        logStoredAt: logStoredAt,
        logLocation: logLocation,
        logNotes: logNotes,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('updateLogDetails failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updateIssuesEncountered({
    required String flightId,
    String? issuesEncountered,
    String? notes,
    required String performedBy,
  }) async {
    _log.i('updateIssuesEncountered($flightId)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.updateIssuesEncountered(
        flightId: flightId,
        issuesEncountered: issuesEncountered,
        notes: notes,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('updateIssuesEncountered failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updateFollowUpStatus({
    required String flightId,
    required String followUpStatus,
    bool? followUpRequired,
    String? followUpNotes,
    String? followUpAssignedTo,
    DateTime? followUpDueDate,
    required String performedBy,
  }) async {
    _log.i('updateFollowUpStatus($flightId, $followUpStatus)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.updateFollowUpStatus(
        flightId: flightId,
        followUpStatus: followUpStatus,
        followUpRequired: followUpRequired,
        followUpNotes: followUpNotes,
        followUpAssignedTo: followUpAssignedTo,
        followUpDueDate: followUpDueDate,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('updateFollowUpStatus failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> addPostFlightAmendment({
    String? id,
    required String flightId,
    required String amendmentText,
    required String createdBy,
  }) async {
    _log.i('addPostFlightAmendment($flightId)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.addPostFlightAmendment(
        id: id,
        flightId: flightId,
        amendmentText: amendmentText,
        createdBy: createdBy,
      );
      emit(
        state.copyWith(
          viewStatus: PostFlightViewStatus.loaded,
          successMessage: 'Amendment added.',
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('addPostFlightAmendment failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> saveBatteryEndState({
    required String flightId,
    required String batteryId,
    double? voltageEnd,
    int? percentEnd,
    required String performedBy,
  }) async {
    _log.i('saveBatteryEndState($flightId, battery: $batteryId)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.saveBatteryEndState(
        flightId: flightId,
        batteryId: batteryId,
        voltageEnd: voltageEnd,
        percentEnd: percentEnd,
        performedBy: performedBy,
      );
      await loadSetup(flightId);
    } catch (error, stackTrace) {
      _log.e('saveBatteryEndState failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> validateCompletion(String flightId) async {
    _log.t('validateCompletion($flightId)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.validating,
        errorMessage: null,
      ),
    );

    try {
      final issues = await _repository.validatePostFlightCompletion(flightId);
      _log.d('validateCompletion($flightId): ${issues.length} issues');
      emit(
        state.copyWith(
          viewStatus: PostFlightViewStatus.loaded,
          completionIssues: issues,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('validateCompletion failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> closeSortie({
    required String flightId,
    required String closedBy,
  }) async {
    _log.i('closeSortie($flightId)');
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.saving,
        errorMessage: null,
      ),
    );

    try {
      await _repository.closeSortie(flightId: flightId, closedBy: closedBy);
      _log.i('sortie closed: $flightId');
      emit(
        state.copyWith(
          viewStatus: PostFlightViewStatus.loaded,
          successMessage: 'Sortie closed.',
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('closeSortie failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  void _emitFailure(Object error) {
    emit(
      state.copyWith(
        viewStatus: PostFlightViewStatus.failure,
        errorMessage: friendlyError(error),
      ),
    );
  }
}
