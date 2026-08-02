import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';
import 'package:the_audit/core/database/dtos/post_flight_dtos.dart';

part 'post_flight_dao.g.dart';

final _uuid = Uuid();

@DriftAccessor(
  tables: [
    Users,
    FieldSessions,
    Sorties,
    SortieBatteries,
    Batteries,
    SortiePayloads,
    Payloads,
    PostFlightNotes,
    RecordAmendments,
    AuditEvents,
    SyncQueue,
  ],
)
class PostFlightDao extends DatabaseAccessor<AppDatabase>
    with _$PostFlightDaoMixin {
  PostFlightDao(super.db);

  Future<PostFlightSetupData> getPostFlightSetup(String flightId) async {
    final sortie = await _requireSortie(flightId);
    final postFlightNote = await getPostFlightNoteForFlight(flightId);
    final batteries = await getSortieBatteries(flightId);
    final payloads = await getSortiePayloads(flightId);

    return PostFlightSetupData(
      sortie: sortie,
      postFlightNote: postFlightNote,
      batteries: batteries,
      payloads: payloads,
    );
  }

  Future<PostFlightNote?> getPostFlightNoteForFlight(String flightId) {
    return (select(db.postFlightNotes)
          ..where((v) => v.flightId.equals(flightId)))
        .getSingleOrNull();
  }

  Future<List<Sorty>> getPostFlightPendingSorties({
    String? sessionId,
    int limit = 50,
  }) {
    final selector = select(db.sorties)
      ..where(
        (v) =>
            v.flightStatus.equals(_statusFlown) |
            v.flightStatus.equals(_statusAborted),
      );

    if (sessionId != null && sessionId.trim().isNotEmpty) {
      selector.where((v) => v.sessionId.equals(sessionId));
    }

    selector
      ..orderBy([
        (v) => OrderingTerm.desc(v.landingAt),
        (v) => OrderingTerm.desc(v.updatedAt),
      ])
      ..limit(limit);

    return selector.get();
  }

  Future<List<Sorty>> getClosedSorties({
    String? sessionId,
    int limit = 50,
  }) {
    final selector = select(db.sorties)
      ..where((v) => v.flightStatus.equals(_statusClosed));

    if (sessionId != null && sessionId.trim().isNotEmpty) {
      selector.where((v) => v.sessionId.equals(sessionId));
    }

    selector
      ..orderBy([
        (v) => OrderingTerm.desc(v.closedAt),
        (v) => OrderingTerm.desc(v.updatedAt),
      ])
      ..limit(limit);

    return selector.get();
  }

  Future<List<SortieBatteryWithBattery>> getSortieBatteries(
    String flightId,
  ) async {
    final query = select(db.sortieBatteries).join([
      innerJoin(
        db.batteries,
        db.batteries.batteryId.equalsExp(db.sortieBatteries.batteryId),
      ),
    ])
      ..where(db.sortieBatteries.flightId.equals(flightId))
      ..orderBy([
        OrderingTerm.asc(db.batteries.batteryId),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SortieBatteryWithBattery(
        sortieBattery: row.readTable(db.sortieBatteries),
        battery: row.readTable(db.batteries),
      );
    }).toList();
  }

  Future<List<SortiePayloadWithPayload>> getSortiePayloads(
    String flightId,
  ) async {
    final query = select(db.sortiePayloads).join([
      innerJoin(
        db.payloads,
        db.payloads.payloadId.equalsExp(db.sortiePayloads.payloadId),
      ),
    ])
      ..where(db.sortiePayloads.flightId.equals(flightId))
      ..orderBy([
        OrderingTerm.asc(db.payloads.name),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SortiePayloadWithPayload(
        sortiePayload: row.readTable(db.sortiePayloads),
        payload: row.readTable(db.payloads),
      );
    }).toList();
  }

  Future<String> savePostFlightNote({
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
  }) async {
    await _ensurePostFlightEditable(flightId);

    final sortie = await _requireSortie(flightId);
    final existingNote = await getPostFlightNoteForFlight(flightId);

    final noteId = existingNote?.id ?? id ?? _uuid.v4();

    final normalizedObjectiveResult = _upper(objectiveResult);
    final normalizedMissionRating = _nullableUpper(missionRating);
    final normalizedLogStoredAt = _nullableUpper(logStoredAt);
    final resolvedFollowUpRequired =
        followUpRequired ||
        _requiresFollowUp(
          objectiveResult: normalizedObjectiveResult,
          issuesEncountered: issuesEncountered,
        );
    final normalizedFollowUpStatus =
        _nullableUpper(followUpStatus) ?? _followUpPending;

    _validatePostFlightInputs(
      objectiveResult: normalizedObjectiveResult,
      missionRating: normalizedMissionRating,
      logStoredAt: normalizedLogStoredAt,
      followUpStatus: normalizedFollowUpStatus,
      followUpRequired: resolvedFollowUpRequired,
      followUpNotes: followUpNotes,
      followUpAssignedTo: followUpAssignedTo,
      followUpDueDate: followUpDueDate,
    );

    final durationSeconds = _calculateFlightDurationSeconds(sortie);
    final now = DateTime.now();

    await transaction(() async {
      if (existingNote == null) {
        await into(db.postFlightNotes).insert(
          PostFlightNotesCompanion.insert(
            id: noteId,
            flightId: flightId,
            objectiveResult: normalizedObjectiveResult,
            objectiveNotes: Value(objectiveNotes),
            missionRating: Value(normalizedMissionRating),
            issuesEncountered: Value(issuesEncountered),
            logStoredAt: Value(normalizedLogStoredAt),
            logLocation: Value(logLocation),
            logNotes: Value(logNotes),
            flightDurationSeconds: Value(durationSeconds),
            followUpRequired: Value(resolvedFollowUpRequired),
            followUpNotes: Value(followUpNotes),
            followUpAssignedTo: Value(followUpAssignedTo),
            followUpDueDate: Value(followUpDueDate),
            followUpStatus: Value(normalizedFollowUpStatus),
            notes: Value(notes),
            createdBy: createdBy,
          ),
        );
      } else {
        await (update(db.postFlightNotes)
              ..where((v) => v.flightId.equals(flightId)))
            .write(
          PostFlightNotesCompanion(
            objectiveResult: Value(normalizedObjectiveResult),
            objectiveNotes: Value(objectiveNotes),
            missionRating: Value(normalizedMissionRating),
            issuesEncountered: Value(issuesEncountered),
            logStoredAt: Value(normalizedLogStoredAt),
            logLocation: Value(logLocation),
            logNotes: Value(logNotes),
            flightDurationSeconds: Value(durationSeconds),
            followUpRequired: Value(resolvedFollowUpRequired),
            followUpNotes: Value(followUpNotes),
            followUpAssignedTo: Value(followUpAssignedTo),
            followUpDueDate: Value(followUpDueDate),
            followUpStatus: Value(normalizedFollowUpStatus),
            notes: Value(notes),
            updatedAt: Value(now),
          ),
        );
      }

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: noteId,
        action: existingNote == null ? 'CREATE' : 'UPDATE',
        description: 'Post-flight note saved',
        performedBy: createdBy,
      );

      await _enqueueSync(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: noteId,
        operation: existingNote == null ? 'INSERT' : 'UPDATE',
      );
    });

    return noteId;
  }

  Future<void> updateObjectiveResult({
    required String flightId,
    required String objectiveResult,
    String? objectiveNotes,
    required String performedBy,
  }) async {
    await _ensurePostFlightEditable(flightId);

    final note = await _requirePostFlightNote(flightId);
    final sortie = await _requireSortie(flightId);
    final normalizedObjectiveResult = _upper(objectiveResult);

    if (!_allowedObjectiveResults.contains(normalizedObjectiveResult)) {
      throw Exception('Invalid objective result: $objectiveResult');
    }

    final now = DateTime.now();
    final shouldRequireFollowUp =
        note.followUpRequired ||
        _requiresFollowUp(objectiveResult: normalizedObjectiveResult);

    await transaction(() async {
      await (update(db.postFlightNotes)
            ..where((v) => v.flightId.equals(flightId)))
          .write(
        PostFlightNotesCompanion(
          objectiveResult: Value(normalizedObjectiveResult),
          objectiveNotes: Value(objectiveNotes),
          followUpRequired: Value(shouldRequireFollowUp),
          updatedAt: Value(now),
        ),
      );

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        action: 'UPDATE_OBJECTIVE_RESULT',
        description: 'Objective result updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> updateMissionRating({
    required String flightId,
    String? missionRating,
    required String performedBy,
  }) async {
    await _ensurePostFlightEditable(flightId);

    final note = await _requirePostFlightNote(flightId);
    final sortie = await _requireSortie(flightId);
    final normalizedMissionRating = _nullableUpper(missionRating);

    if (normalizedMissionRating != null &&
        !_allowedMissionRatings.contains(normalizedMissionRating)) {
      throw Exception('Invalid mission rating: $missionRating');
    }

    final now = DateTime.now();

    await transaction(() async {
      await (update(db.postFlightNotes)
            ..where((v) => v.flightId.equals(flightId)))
          .write(
        PostFlightNotesCompanion(
          missionRating: Value(normalizedMissionRating),
          updatedAt: Value(now),
        ),
      );

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        action: 'UPDATE_MISSION_RATING',
        description: 'Mission rating updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> updateLogDetails({
    required String flightId,
    String? logStoredAt,
    String? logLocation,
    String? logNotes,
    required String performedBy,
  }) async {
    await _ensurePostFlightEditable(flightId);

    final note = await _requirePostFlightNote(flightId);
    final sortie = await _requireSortie(flightId);
    final normalizedLogStoredAt = _nullableUpper(logStoredAt);

    if (normalizedLogStoredAt != null &&
        !_allowedLogStoredAt.contains(normalizedLogStoredAt)) {
      throw Exception('Invalid log storage value: $logStoredAt');
    }

    final now = DateTime.now();

    await transaction(() async {
      await (update(db.postFlightNotes)
            ..where((v) => v.flightId.equals(flightId)))
          .write(
        PostFlightNotesCompanion(
          logStoredAt: Value(normalizedLogStoredAt),
          logLocation: Value(logLocation),
          logNotes: Value(logNotes),
          updatedAt: Value(now),
        ),
      );

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        action: 'UPDATE_LOG_DETAILS',
        description: 'Log details updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> updateIssuesEncountered({
    required String flightId,
    String? issuesEncountered,
    String? notes,
    required String performedBy,
  }) async {
    await _ensurePostFlightEditable(flightId);

    final note = await _requirePostFlightNote(flightId);
    final sortie = await _requireSortie(flightId);
    final now = DateTime.now();
    final shouldRequireFollowUp =
        note.followUpRequired ||
        _requiresFollowUp(issuesEncountered: issuesEncountered);

    await transaction(() async {
      await (update(db.postFlightNotes)
            ..where((v) => v.flightId.equals(flightId)))
          .write(
        PostFlightNotesCompanion(
          issuesEncountered: Value(issuesEncountered),
          notes: Value(notes),
          followUpRequired: Value(shouldRequireFollowUp),
          updatedAt: Value(now),
        ),
      );

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        action: 'UPDATE_ISSUES',
        description: 'Post-flight issues updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> updateFollowUpStatus({
    required String flightId,
    required String followUpStatus,
    String? followUpNotes,
    String? followUpAssignedTo,
    DateTime? followUpDueDate,
    bool? followUpRequired,
    required String performedBy,
  }) async {
    await _ensurePostFlightEditable(flightId);

    final note = await _requirePostFlightNote(flightId);
    final sortie = await _requireSortie(flightId);
    final normalizedStatus = _upper(followUpStatus);

    if (!_allowedFollowUpStatuses.contains(normalizedStatus)) {
      throw Exception('Invalid follow-up status: $followUpStatus');
    }

    final now = DateTime.now();

    await transaction(() async {
      await (update(db.postFlightNotes)
            ..where((v) => v.flightId.equals(flightId)))
          .write(
        PostFlightNotesCompanion(
          followUpRequired: followUpRequired == null
              ? const Value.absent()
              : Value(followUpRequired),
          followUpStatus: Value(normalizedStatus),
          followUpNotes: Value(followUpNotes),
          followUpAssignedTo: Value(followUpAssignedTo),
          followUpDueDate: Value(followUpDueDate),
          updatedAt: Value(now),
        ),
      );

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        action: 'UPDATE_FOLLOW_UP_STATUS',
        description: 'Follow-up status updated to $normalizedStatus',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> saveBatteryEndState({
    required String flightId,
    required String batteryId,
    double? voltageEnd,
    int? percentEnd,
    required String performedBy,
  }) async {
    await _ensurePostFlightEditable(flightId);

    _validateBatteryEndState(
      voltageEnd: voltageEnd,
      percentEnd: percentEnd,
    );

    final sortie = await _requireSortie(flightId);

    final sortieBattery = await (select(db.sortieBatteries)
          ..where(
            (v) =>
                v.flightId.equals(flightId) &
                v.batteryId.equals(batteryId),
          ))
        .getSingleOrNull();

    if (sortieBattery == null) {
      throw Exception('Battery $batteryId was not selected for this sortie.');
    }

    final now = DateTime.now();

    await transaction(() async {
      await (update(db.sortieBatteries)
            ..where((v) => v.id.equals(sortieBattery.id)))
          .write(
        SortieBatteriesCompanion(
          voltageEnd: Value(voltageEnd),
          percentEnd: Value(percentEnd),
          updatedAt: Value(now),
        ),
      );

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'SORTIE_BATTERY',
        entityId: sortieBattery.id,
        action: 'UPDATE_END_STATE',
        description: 'Battery end state saved',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SORTIE_BATTERY',
        entityId: sortieBattery.id,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> addPostFlightAmendment({
    String? id,
    required String flightId,
    required String amendmentText,
    required String createdBy,
  }) async {
    final note = await _requirePostFlightNote(flightId);

    if (amendmentText.trim().isEmpty) {
      throw Exception('Amendment text cannot be empty.');
    }

    final amendmentId = id ?? _uuid.v4();

    await transaction(() async {
      await into(db.recordAmendments).insert(
        RecordAmendmentsCompanion.insert(
          id: amendmentId,
          entityType: 'POST_FLIGHT_NOTE',
          entityId: note.id,
          amendmentText: amendmentText,
          createdBy: createdBy,
        ),
      );

      await _insertAuditEvent(
        entityType: 'POST_FLIGHT_NOTE',
        entityId: note.id,
        action: 'AMEND',
        description: amendmentText,
        performedBy: createdBy,
      );

      await _enqueueSync(
        entityType: 'RECORD_AMENDMENT',
        entityId: amendmentId,
        operation: 'INSERT',
      );
    });
  }

  Future<void> saveBatteryEndStates({
    required String flightId,
    required List<BatteryEndStateDraft> batteries,
    required String performedBy,
  }) async {
    await _ensurePostFlightEditable(flightId);

    for (final battery in batteries) {
      _validateBatteryEndState(
        voltageEnd: battery.voltageEnd,
        percentEnd: battery.percentEnd,
      );
    }

    final sortie = await _requireSortie(flightId);

    final existingBatteries = await (select(db.sortieBatteries)
          ..where((v) => v.flightId.equals(flightId)))
        .get();

    final existingByBatteryId = {
      for (final battery in existingBatteries) battery.batteryId: battery,
    };

    for (final battery in batteries) {
      if (!existingByBatteryId.containsKey(battery.batteryId)) {
        throw Exception(
          'Battery ${battery.batteryId} was not selected for this sortie.',
        );
      }
    }

    final now = DateTime.now();

    await transaction(() async {
      for (final battery in batteries) {
        final existingBattery = existingByBatteryId[battery.batteryId]!;

        await (update(db.sortieBatteries)
              ..where((v) => v.id.equals(existingBattery.id)))
            .write(
          SortieBatteriesCompanion(
            voltageEnd: Value(battery.voltageEnd),
            percentEnd: Value(battery.percentEnd),
            updatedAt: Value(now),
          ),
        );

        await _insertAuditEvent(
          entityType: 'SORTIE_BATTERY',
          entityId: existingBattery.id,
          action: 'UPDATE_END_STATE',
          description: 'Battery end state saved',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE_BATTERY',
          entityId: existingBattery.id,
          operation: 'UPDATE',
        );
      }

      await _touchSortie(flightId, now: now);
      await _touchSession(sortie.sessionId, now: now);
    });
  }

  Future<int> countBatteriesWithoutEndState(String flightId) async {
    final countExp = db.sortieBatteries.id.count();

    final query = selectOnly(db.sortieBatteries)
      ..addColumns([countExp])
      ..where(db.sortieBatteries.flightId.equals(flightId))
      ..where(
        db.sortieBatteries.voltageEnd.isNull() &
            db.sortieBatteries.percentEnd.isNull(),
      );

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<bool> allBatteriesHaveEndState(String flightId) async {
    final missingCount = await countBatteriesWithoutEndState(flightId);
    return missingCount == 0;
  }

  Future<List<String>> validatePostFlightCompletion(String flightId) async {
    final check = await _buildPostFlightClosureCheck(flightId);
    return check.issues;
  }

  Future<({
    Sorty sortie,
    PostFlightNote? postFlightNote,
    List<String> issues,
  })> _buildPostFlightClosureCheck(String flightId) async {
    final sortie = await _requireSortie(flightId);

    final issues = <String>[
      ..._validateSortieStateForPostFlightClosure(sortie),
    ];

    if (!_canContinueClosureValidation(sortie, issues)) {
      return (
        sortie: sortie,
        postFlightNote: null,
        issues: issues,
      );
    }

    final postFlightNote = await getPostFlightNoteForFlight(flightId);

    if (postFlightNote != null) {
      issues.addAll(_validateExistingPostFlightNoteForClosure(postFlightNote));
    }

    if (_isStatus(sortie, _statusAborted)) {
      return (
        sortie: sortie,
        postFlightNote: postFlightNote,
        issues: issues,
      );
    }

    if (postFlightNote == null) {
      issues.add('Post-flight note is required.');
    }

    final missingEndStateCount = await countBatteriesWithoutEndState(flightId);

    if (missingEndStateCount > 0) {
      issues.add('$missingEndStateCount battery end state(s) missing.');
    }

    return (
      sortie: sortie,
      postFlightNote: postFlightNote,
      issues: issues,
    );
  }

  List<String> _validateSortieStateForPostFlightClosure(Sorty sortie) {
    final status = _normalizeStatus(sortie.flightStatus);

    switch (status) {
      case _statusPreflight:
        return ['Flight has not started.'];

      case _statusInProgress:
        return ['Landing must be recorded before post-flight closure.'];

      case _statusClosed:
        return ['Sortie is already closed.'];

      case _statusAborted:
        return _validateAbortedSortieForClosure(sortie);

      case _statusFlown:
        return _validateFlownSortieTimesForClosure(sortie);

      default:
        return ['Invalid sortie status: ${sortie.flightStatus}.'];
    }
  }

  List<String> _validateAbortedSortieForClosure(Sorty sortie) {
    final reason = sortie.decisionReason?.trim();

    if (reason == null || reason.isEmpty) {
      return ['Aborted sortie requires a reason.'];
    }

    return [];
  }

  List<String> _validateFlownSortieTimesForClosure(Sorty sortie) {
    final issues = <String>[];

    final takeoffAt = sortie.takeoffAt;
    final landingAt = sortie.landingAt;

    if (takeoffAt == null) {
      issues.add('Takeoff time is missing.');
    }

    if (landingAt == null) {
      issues.add('Landing time is missing.');
    }

    if (takeoffAt != null && landingAt != null && landingAt.isBefore(takeoffAt)) {
      issues.add('Landing time cannot be before takeoff time.');
    }

    return issues;
  }

  bool _canContinueClosureValidation(
    Sorty sortie,
    List<String> currentIssues,
  ) {
    final status = _normalizeStatus(sortie.flightStatus);

    if (status != _statusFlown && status != _statusAborted) {
      return false;
    }

    if (currentIssues.isNotEmpty) {
      return false;
    }

    return true;
  }

  Future<void> closeSortie({
    required String flightId,
    required String closedBy,
  }) async {
    final check = await _buildPostFlightClosureCheck(flightId);

    if (check.issues.isNotEmpty) {
      throw Exception(check.issues.join('\n'));
    }

    final sortie = check.sortie;
    final postFlightNote = check.postFlightNote;
    final durationSeconds = _calculateFlightDurationSeconds(sortie);
    final now = DateTime.now();

    await transaction(() async {
      await (update(db.sorties)..where((v) => v.flightId.equals(flightId)))
          .write(
        SortiesCompanion(
          flightStatus: const Value(_statusClosed),
          closedAt: Value(now),
          closedBy: Value(closedBy),
          updatedAt: Value(now),
        ),
      );

      if (postFlightNote != null) {
        await (update(db.postFlightNotes)
              ..where((v) => v.flightId.equals(flightId)))
            .write(
          PostFlightNotesCompanion(
            flightDurationSeconds: Value(durationSeconds),
            updatedAt: Value(now),
          ),
        );

        await _enqueueSync(
          entityType: 'POST_FLIGHT_NOTE',
          entityId: postFlightNote.id,
          operation: 'UPDATE',
        );
      }

      if (sortie.takeoffAt != null) {
        await _incrementBatteryCyclesForFlight(
          flightId,
          performedBy: closedBy,
          now: now,
        );
      }

      await _touchSession(sortie.sessionId, now: now);

      await _insertAuditEvent(
        entityType: 'SORTIE',
        entityId: flightId,
        action: 'CLOSE',
        description: 'Sortie closed after post-flight completion',
        performedBy: closedBy,
      );

      await _enqueueSync(
        entityType: 'SORTIE',
        entityId: flightId,
        operation: 'UPDATE',
      );
    });
  }

  Future<Sorty> _requireSortie(String flightId) async {
    final sortie = await (select(db.sorties)
          ..where((v) => v.flightId.equals(flightId)))
        .getSingleOrNull();

    if (sortie == null) {
      throw Exception('Sortie not found: $flightId');
    }

    return sortie;
  }

  Future<PostFlightNote> _requirePostFlightNote(String flightId) async {
    final note = await getPostFlightNoteForFlight(flightId);

    if (note == null) {
      throw Exception('Post-flight note not found for flight: $flightId');
    }

    return note;
  }

  Future<void> _ensurePostFlightEditable(String flightId) async {
    final sortie = await _requireSortie(flightId);
    final status = _normalizeStatus(sortie.flightStatus);

    switch (status) {
      case _statusFlown:
      case _statusAborted:
        return;

      case _statusClosed:
        throw Exception(
          'Sortie is closed. Add an amendment instead of editing directly.',
        );

      case _statusPreflight:
        throw Exception('Cannot add post-flight data before flight starts.');

      case _statusInProgress:
        throw Exception('Record landing or abort the sortie before post-flight.');

      default:
        throw Exception('Invalid sortie status: ${sortie.flightStatus}.');
    }
  }

  int? _calculateFlightDurationSeconds(Sorty sortie) {
    final takeoffAt = sortie.takeoffAt;
    final landingAt = sortie.landingAt;

    if (takeoffAt == null || landingAt == null) {
      return null;
    }

    final seconds = landingAt.difference(takeoffAt).inSeconds;

    if (seconds < 0) {
      throw Exception('Landing time cannot be before takeoff time.');
    }

    return seconds;
  }

  Future<void> _incrementBatteryCyclesForFlight(
    String flightId, {
    required String performedBy,
    required DateTime now,
  }) async {
    final sortieBatteries = await (select(db.sortieBatteries)
          ..where((v) => v.flightId.equals(flightId)))
        .get();

    if (sortieBatteries.isEmpty) {
      return;
    }

    final batteryIds = sortieBatteries.map((v) => v.batteryId).toSet().toList();

    await customUpdate(
      '''
      UPDATE batteries
      SET cycle_count = cycle_count + 1,
          updated_at = ?
      WHERE battery_id IN (
        SELECT battery_id
        FROM sortie_batteries
        WHERE flight_id = ?
      )
      ''',
      variables: [
        Variable<DateTime>(now),
        Variable<String>(flightId),
      ],
      updates: {
        db.batteries,
      },
    );

    for (final batteryId in batteryIds) {
      await _insertAuditEvent(
        entityType: 'BATTERY',
        entityId: batteryId,
        action: 'CYCLE_INCREMENT',
        description: 'Battery cycle incremented after sortie close: $flightId',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'BATTERY',
        entityId: batteryId,
        operation: 'UPDATE',
      );
    }
  }

  void _validatePostFlightInputs({
    required String objectiveResult,
    String? missionRating,
    String? logStoredAt,
    String? followUpStatus,
    required bool followUpRequired,
    String? followUpNotes,
    String? followUpAssignedTo,
    DateTime? followUpDueDate,
  }) {
    if (!_allowedObjectiveResults.contains(objectiveResult)) {
      throw Exception('Invalid objective result: $objectiveResult');
    }

    if (missionRating != null &&
        missionRating.isNotEmpty &&
        !_allowedMissionRatings.contains(missionRating)) {
      throw Exception('Invalid mission rating: $missionRating');
    }

    if (logStoredAt != null &&
        logStoredAt.isNotEmpty &&
        !_allowedLogStoredAt.contains(logStoredAt)) {
      throw Exception('Invalid log storage value: $logStoredAt');
    }

    if (followUpStatus != null &&
        followUpStatus.isNotEmpty &&
        !_allowedFollowUpStatuses.contains(followUpStatus)) {
      throw Exception('Invalid follow-up status: $followUpStatus');
    }

    // Follow-up can be auto-flagged from objective/incident data before the
    // assignee, date, or notes are known.
  }

  List<String> _validateExistingPostFlightNoteForClosure(
    PostFlightNote note,
  ) {
    final issues = <String>[];

    final objectiveResult = _upper(note.objectiveResult);
    final missionRating = _nullableUpper(note.missionRating);
    final logStoredAt = _nullableUpper(note.logStoredAt);
    final followUpStatus = _upper(note.followUpStatus);

    if (!_allowedObjectiveResults.contains(objectiveResult)) {
      issues.add('Invalid objective result: ${note.objectiveResult}.');
    }

    if (missionRating != null &&
        !_allowedMissionRatings.contains(missionRating)) {
      issues.add('Invalid mission rating: ${note.missionRating}.');
    }

    if (logStoredAt != null && !_allowedLogStoredAt.contains(logStoredAt)) {
      issues.add('Invalid log storage value: ${note.logStoredAt}.');
    }

    if (!_allowedFollowUpStatuses.contains(followUpStatus)) {
      issues.add('Invalid follow-up status: ${note.followUpStatus}.');
    }

    return issues;
  }

  bool _requiresFollowUp({
    String? objectiveResult,
    String? issuesEncountered,
  }) {
    final normalizedObjectiveResult = _nullableUpper(objectiveResult);
    final hasIssue =
        issuesEncountered != null && issuesEncountered.trim().isNotEmpty;

    return hasIssue ||
        (normalizedObjectiveResult != null &&
            normalizedObjectiveResult != 'YES');
  }

  void _validateBatteryEndState({
    double? voltageEnd,
    int? percentEnd,
  }) {
    if (voltageEnd == null && percentEnd == null) {
      throw Exception('Battery end voltage or percent is required.');
    }

    if (voltageEnd != null && voltageEnd < 0) {
      throw Exception('Battery end voltage cannot be negative.');
    }

    if (percentEnd != null && (percentEnd < 0 || percentEnd > 100)) {
      throw Exception('Battery end percent must be between 0 and 100.');
    }
  }

  Future<void> _touchSortie(
    String flightId, {
    required DateTime now,
  }) {
    return (update(db.sorties)..where((v) => v.flightId.equals(flightId)))
        .write(
      SortiesCompanion(
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _touchSession(
    String sessionId, {
    required DateTime now,
  }) {
    return (update(db.fieldSessions)
          ..where((v) => v.sessionId.equals(sessionId)))
        .write(
      FieldSessionsCompanion(
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _insertAuditEvent({
    required String entityType,
    required String entityId,
    required String action,
    String? description,
    required String performedBy,
  }) {
    return into(db.auditEvents).insert(
      AuditEventsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        action: action,
        description: Value(description),
        performedBy: performedBy,
      ),
    );
  }

  Future<void> _enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        syncStatus: const Value('PENDING'),
      ),
    );
  }

  bool _isStatus(Sorty sortie, String status) {
    return _normalizeStatus(sortie.flightStatus) == status;
  }

  String _normalizeStatus(String value) {
    return value.trim().toUpperCase();
  }

  String _upper(String value) {
    return value.trim().toUpperCase();
  }

  String? _nullableUpper(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed.toUpperCase();
  }

  static const String _statusPreflight = 'PREFLIGHT';
  static const String _statusInProgress = 'IN_PROGRESS';
  static const String _statusFlown = 'FLOWN';
  static const String _statusAborted = 'ABORTED';
  static const String _statusClosed = 'CLOSED';

  static const String _followUpPending = 'PENDING';

  static const Set<String> _allowedObjectiveResults = {
    'YES',
    'NO',
    'PARTIAL',
  };

  static const Set<String> _allowedMissionRatings = {
    'EXCELLENT',
    'GOOD',
    'AVERAGE',
    'POOR',
  };

  static const Set<String> _allowedLogStoredAt = {
    'LOCAL',
    'CLOUD',
    'BOTH',
  };

  static const Set<String> _allowedFollowUpStatuses = {
    'PENDING',
    'IN_PROGRESS',
    'DONE',
    'CANCELLED',
  };
}
