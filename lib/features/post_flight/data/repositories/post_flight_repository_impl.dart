import 'package:the_audit/core/database/daos/post_flight/post_flight_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/database/dtos/post_flight_dtos.dart'
    as db_post_flight;

import 'package:the_audit/features/post_flight/data/mappers/post_flight_mapper.dart';
import 'package:the_audit/features/post_flight/domain/dtos/post_flight_dtos.dart';
import 'package:the_audit/features/post_flight/domain/entities/post_flight_note_entity.dart';
import 'package:the_audit/features/post_flight/domain/entities/post_flight_setup_entity.dart';
import 'package:the_audit/features/post_flight/domain/repositories/post_flight_repository.dart';

import 'package:the_audit/features/pre_flight/data/mappers/pre_flight_mapper.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';

class PostFlightRepositoryImpl implements PostFlightRepository {
  static const _log = AppLogger('PostFlightRepositoryImpl');

  final PostFlightDao _postFlightDao;

  const PostFlightRepositoryImpl(this._postFlightDao);

  @override
  Future<PostFlightSetupEntity> getPostFlightSetup(String flightId) {
    _log.t('getPostFlightSetup(flightId: $flightId)');
    return _postFlightDao
        .getPostFlightSetup(flightId)
        .then((setup) => setup.toEntity());
  }

  @override
  Future<PostFlightNoteEntity?> getPostFlightNoteForFlight(String flightId) {
    _log.t('getPostFlightNoteForFlight(flightId: $flightId)');
    return _postFlightDao
        .getPostFlightNoteForFlight(flightId)
        .then((note) => note?.toEntity());
  }

  @override
  Future<List<SortieEntity>> getPostFlightPendingSorties({
    String? sessionId,
    int limit = 100,
  }) {
    _log.t('getPostFlightPendingSorties(sessionId: $sessionId, limit: $limit)');
    return _postFlightDao
        .getPostFlightPendingSorties(sessionId: sessionId, limit: limit)
        .then((sorties) => sorties.map((s) => s.toEntity()).toList());
  }

  @override
  Future<List<SortieEntity>> getClosedSorties({
    String? sessionId,
    int limit = 100,
  }) {
    _log.t('getClosedSorties(sessionId: $sessionId, limit: $limit)');
    return _postFlightDao
        .getClosedSorties(sessionId: sessionId, limit: limit)
        .then((sorties) => sorties.map((s) => s.toEntity()).toList());
  }

  @override
  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  ) {
    _log.t('getSortieBatteries(flightId: $flightId)');
    return _postFlightDao
        .getSortieBatteries(flightId)
        .then((batteries) => batteries.map((b) => b.toEntity()).toList());
  }

  @override
  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  ) {
    _log.t('getSortiePayloads(flightId: $flightId)');
    return _postFlightDao
        .getSortiePayloads(flightId)
        .then((payloads) => payloads.map((p) => p.toEntity()).toList());
  }

  @override
  Future<void> savePostFlightNote({
    String? id,
    required String flightId,
    required String objectiveResult,
    String? objectiveNotes,
    String? missionRating,
    String? issuesEncountered,
    String? logStoredAt,
    String? logLocation,
    String? logNotes,
    bool followUpRequired = false,
    String? followUpNotes,
    String? followUpAssignedTo,
    DateTime? followUpDueDate,
    String? followUpStatus,
    String? notes,
    required String createdBy,
  }) {
    _log.t(
      'savePostFlightNote(id: $id, flightId: $flightId, objectiveResult: $objectiveResult, followUpStatus: $followUpStatus)',
    );
    return _postFlightDao.savePostFlightNote(
      id: id,
      flightId: flightId,
      objectiveResult: objectiveResult,
      objectiveNotes: objectiveNotes,
      missionRating: missionRating,
      issuesEncountered: issuesEncountered,
      logStoredAt: logStoredAt,
      logLocation: logLocation,
      logNotes: logNotes,
      followUpRequired: followUpRequired,
      followUpNotes: followUpNotes,
      followUpAssignedTo: followUpAssignedTo,
      followUpDueDate: followUpDueDate,
      followUpStatus: followUpStatus,
      notes: notes,
      createdBy: createdBy,
    );
  }

  @override
  Future<void> updateObjectiveResult({
    required String flightId,
    required String objectiveResult,
    String? objectiveNotes,
    required String performedBy,
  }) {
    _log.t(
      'updateObjectiveResult(flightId: $flightId, objectiveResult: $objectiveResult)',
    );
    return _postFlightDao.updateObjectiveResult(
      flightId: flightId,
      objectiveResult: objectiveResult,
      objectiveNotes: objectiveNotes,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateMissionRating({
    required String flightId,
    String? missionRating,
    required String performedBy,
  }) {
    _log.t('updateMissionRating(flightId: $flightId)');
    return _postFlightDao.updateMissionRating(
      flightId: flightId,
      missionRating: missionRating,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateLogDetails({
    required String flightId,
    String? logStoredAt,
    String? logLocation,
    String? logNotes,
    required String performedBy,
  }) {
    _log.t('updateLogDetails(flightId: $flightId)');
    return _postFlightDao.updateLogDetails(
      flightId: flightId,
      logStoredAt: logStoredAt,
      logLocation: logLocation,
      logNotes: logNotes,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateIssuesEncountered({
    required String flightId,
    String? issuesEncountered,
    String? notes,
    required String performedBy,
  }) {
    _log.t('updateIssuesEncountered(flightId: $flightId)');
    return _postFlightDao.updateIssuesEncountered(
      flightId: flightId,
      issuesEncountered: issuesEncountered,
      notes: notes,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateFollowUpStatus({
    required String flightId,
    required String followUpStatus,
    bool? followUpRequired,
    String? followUpNotes,
    String? followUpAssignedTo,
    DateTime? followUpDueDate,
    required String performedBy,
  }) {
    _log.t(
      'updateFollowUpStatus(flightId: $flightId, followUpStatus: $followUpStatus)',
    );
    return _postFlightDao.updateFollowUpStatus(
      flightId: flightId,
      followUpStatus: followUpStatus,
      followUpRequired: followUpRequired,
      followUpNotes: followUpNotes,
      followUpAssignedTo: followUpAssignedTo,
      followUpDueDate: followUpDueDate,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> addPostFlightAmendment({
    String? id,
    required String flightId,
    required String amendmentText,
    required String createdBy,
  }) {
    _log.t('addPostFlightAmendment(id: $id, flightId: $flightId)');
    return _postFlightDao.addPostFlightAmendment(
      id: id,
      flightId: flightId,
      amendmentText: amendmentText,
      createdBy: createdBy,
    );
  }

  @override
  Future<void> saveBatteryEndState({
    required String flightId,
    required String batteryId,
    double? voltageEnd,
    int? percentEnd,
    required String performedBy,
  }) {
    _log.t('saveBatteryEndState(flightId: $flightId, batteryId: $batteryId)');
    return _postFlightDao.saveBatteryEndState(
      flightId: flightId,
      batteryId: batteryId,
      voltageEnd: voltageEnd,
      percentEnd: percentEnd,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> saveBatteryEndStates({
    required String flightId,
    required List<BatteryEndStateDraft> batteries,
    required String performedBy,
  }) {
    _log.t('saveBatteryEndStates(flightId: $flightId)');
    final batteryDtos = batteries.map((battery) {
      return db_post_flight.BatteryEndStateDraft(
        batteryId: battery.batteryId,
        voltageEnd: battery.voltageEnd,
        percentEnd: battery.percentEnd,
      );
    }).toList();

    return _postFlightDao.saveBatteryEndStates(
      flightId: flightId,
      batteries: batteryDtos,
      performedBy: performedBy,
    );
  }

  @override
  Future<int> countBatteriesWithoutEndState(String flightId) {
    _log.t('countBatteriesWithoutEndState(flightId: $flightId)');
    return _postFlightDao.countBatteriesWithoutEndState(flightId);
  }

  @override
  Future<bool> allBatteriesHaveEndState(String flightId) {
    _log.t('allBatteriesHaveEndState(flightId: $flightId)');
    return _postFlightDao.allBatteriesHaveEndState(flightId);
  }

  @override
  Future<List<String>> validatePostFlightCompletion(String flightId) {
    _log.t('validatePostFlightCompletion(flightId: $flightId)');
    return _postFlightDao.validatePostFlightCompletion(flightId);
  }

  @override
  Future<void> closeSortie({
    required String flightId,
    required String closedBy,
  }) {
    _log.t('closeSortie(flightId: $flightId)');
    return _postFlightDao.closeSortie(flightId: flightId, closedBy: closedBy);
  }
}
