import 'package:the_audit/core/database/daos/post_flight/post_flight_dao.dart';
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
  final PostFlightDao _postFlightDao;

  const PostFlightRepositoryImpl(this._postFlightDao);

  @override
  Future<PostFlightSetupEntity> getPostFlightSetup(String flightId) {
    return _postFlightDao
        .getPostFlightSetup(flightId)
        .then((setup) => setup.toEntity());
  }

  @override
  Future<PostFlightNoteEntity?> getPostFlightNoteForFlight(String flightId) {
    return _postFlightDao
        .getPostFlightNoteForFlight(flightId)
        .then((note) => note?.toEntity());
  }

  @override
  Future<List<SortieEntity>> getPostFlightPendingSorties({
    String? sessionId,
    int limit = 100,
  }) {
    return _postFlightDao
        .getPostFlightPendingSorties(
          sessionId: sessionId,
          limit: limit,
        )
        .then((sorties) => sorties.map((s) => s.toEntity()).toList());
  }

  @override
  Future<List<SortieEntity>> getClosedSorties({
    String? sessionId,
    int limit = 100,
  }) {
    return _postFlightDao
        .getClosedSorties(
          sessionId: sessionId,
          limit: limit,
        )
        .then((sorties) => sorties.map((s) => s.toEntity()).toList());
  }

  @override
  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  ) {
    return _postFlightDao
        .getSortieBatteries(flightId)
        .then((batteries) => batteries.map((b) => b.toEntity()).toList());
  }

  @override
  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  ) {
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
    return _postFlightDao.countBatteriesWithoutEndState(flightId);
  }

  @override
  Future<bool> allBatteriesHaveEndState(String flightId) {
    return _postFlightDao.allBatteriesHaveEndState(flightId);
  }

  @override
  Future<List<String>> validatePostFlightCompletion(String flightId) {
    return _postFlightDao.validatePostFlightCompletion(flightId);
  }

  @override
  Future<void> closeSortie({
    required String flightId,
    required String closedBy,
  }) {
    return _postFlightDao.closeSortie(
      flightId: flightId,
      closedBy: closedBy,
    );
  }
}
