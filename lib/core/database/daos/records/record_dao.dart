import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';
export 'package:the_audit/core/database/dtos/shared_dtos.dart';

part 'record_dao.g.dart';

final _uuid = Uuid();

@DriftAccessor(
  tables: [
    Users,
    FieldSessions,
    SessionUsers,
    SessionVehicles,
    SessionVehiclePayload,
    SessionBatteries,
    SessionEquipmentChecks,
    EquipmentLists,
    Vehicles,
    Payloads,
    Batteries,
    Sorties,
    SortieUsers,
    SortiePayloads,
    SortieBatteries,
    VehicleChecklistTemplates,
    ChecklistItems,
    ChecklistResponses,
    ChecklistOverrides,
    PostFlightNotes,
    AuditEvents,
    RecordAmendments,
    ExportRecords,
    SyncQueue,
  ],
)
class RecordDao extends DatabaseAccessor<AppDatabase> with _$RecordDaoMixin {
  RecordDao(super.db);

  Future<FieldSession?> getSessionById(String sessionId) {
    return (select(
      db.fieldSessions,
    )..where((v) => v.sessionId.equals(sessionId))).getSingleOrNull();
  }

  Future<List<FieldSession>> getRecentSessions({int limit = 50}) {
    return (select(db.fieldSessions)
          ..orderBy([
            (v) => OrderingTerm.desc(v.date),
            (v) => OrderingTerm.desc(v.updatedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<FieldSession>> getRecentClosedSessions({int limit = 50}) {
    return (select(db.fieldSessions)
          ..where((v) => v.sessionStatus.equals('CLOSED'))
          ..orderBy([
            (v) => OrderingTerm.desc(v.closedAt),
            (v) => OrderingTerm.desc(v.date),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<FieldSession>> getInProgressSessions({int limit = 50}) {
    return (select(db.fieldSessions)
          ..where((v) => v.sessionStatus.equals('IN_PROGRESS'))
          ..orderBy([(v) => OrderingTerm.desc(v.updatedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<FieldSession>> searchSessions({
    required String query,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? vehicleId,
    String? picUserId,
    int limit = 50,
  }) async {
    final cleanQuery = query.trim();
    final normalizedStatus = status?.trim().toUpperCase();

    final selector = select(db.fieldSessions)
      ..orderBy([
        (v) => OrderingTerm.desc(v.date),
        (v) => OrderingTerm.desc(v.updatedAt),
      ])
      ..limit(limit);

    final matchingSessionIds = <String>{};

    if (cleanQuery.isNotEmpty) {
      final vehicleMatches = await (select(db.sessionVehicles).join([
        innerJoin(
          db.vehicles,
          db.vehicles.id.equalsExp(db.sessionVehicles.vehicleId),
        ),
      ])
            ..where(db.vehicles.name.contains(cleanQuery)))
          .get();

      matchingSessionIds.addAll(
        vehicleMatches.map((row) => row.readTable(db.sessionVehicles).sessionId),
      );

      final userMatches = await (select(db.sorties).join([
        innerJoin(db.users, db.users.id.equalsExp(db.sorties.picUserId)),
      ])
            ..where(db.users.name.contains(cleanQuery)))
          .get();

      matchingSessionIds.addAll(
        userMatches.map((row) => row.readTable(db.sorties).sessionId),
      );

      selector.where(
        (v) =>
            v.locationName.contains(cleanQuery) |
            v.missionType.contains(cleanQuery) |
            v.sessionStatus.contains(cleanQuery) |
            v.sessionId.isIn(matchingSessionIds.toList()),
      );
    }

    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      selector.where((v) => v.sessionStatus.equals(normalizedStatus));
    }

    if (dateFrom != null) {
      selector.where((v) => v.date.isBiggerOrEqualValue(dateFrom));
    }

    if (dateTo != null) {
      selector.where((v) => v.date.isSmallerOrEqualValue(dateTo));
    }

    if (vehicleId != null && vehicleId.trim().isNotEmpty) {
      final rows = await (select(db.sessionVehicles)
            ..where((v) => v.vehicleId.equals(vehicleId)))
          .get();
      selector.where((v) => v.sessionId.isIn(rows.map((row) => row.sessionId)));
    }

    if (picUserId != null && picUserId.trim().isNotEmpty) {
      final rows = await (select(db.sorties)
            ..where((v) => v.picUserId.equals(picUserId)))
          .get();
      selector.where((v) => v.sessionId.isIn(rows.map((row) => row.sessionId)));
    }

    return selector.get();
  }

  Future<int> countSessionsByStatus(String status) async {
    final normalizedStatus = status.trim().toUpperCase();
    final countExp = db.fieldSessions.sessionId.count();

    final query = selectOnly(db.fieldSessions)
      ..addColumns([countExp])
      ..where(db.fieldSessions.sessionStatus.equals(normalizedStatus));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<List<SessionUserWithUser>> getSessionUsers(String sessionId) async {
    final query =
        select(db.sessionUsers).join([
            innerJoin(db.users, db.users.id.equalsExp(db.sessionUsers.userId)),
          ])
          ..where(db.sessionUsers.sessionId.equals(sessionId))
          ..orderBy([
            OrderingTerm.asc(db.sessionUsers.role),
            OrderingTerm.asc(db.users.name),
          ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionUserWithUser(
        sessionUser: row.readTable(db.sessionUsers),
        user: row.readTable(db.users),
      );
    }).toList();
  }

  Future<List<SessionVehicleWithVehicle>> getSessionVehicles(
    String sessionId,
  ) async {
    final query =
        select(db.sessionVehicles).join([
            innerJoin(
              db.vehicles,
              db.vehicles.id.equalsExp(db.sessionVehicles.vehicleId),
            ),
          ])
          ..where(db.sessionVehicles.sessionId.equals(sessionId))
          ..orderBy([OrderingTerm.asc(db.vehicles.name)]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionVehicleWithVehicle(
        sessionVehicle: row.readTable(db.sessionVehicles),
        vehicle: row.readTable(db.vehicles),
      );
    }).toList();
  }

  Future<List<Payload>> getPayloadsForSessionVehicle(
    String sessionVehicleId,
  ) async {
    final query =
        select(db.sessionVehiclePayload).join([
            innerJoin(
              db.payloads,
              db.payloads.payloadId.equalsExp(
                db.sessionVehiclePayload.payloadId,
              ),
            ),
          ])
          ..where(
            db.sessionVehiclePayload.sessionVehicleId.equals(sessionVehicleId),
          )
          ..orderBy([OrderingTerm.asc(db.payloads.name)]);

    final rows = await query.get();

    return rows.map((row) => row.readTable(db.payloads)).toList();
  }

  Future<List<SessionBatteryWithBattery>> getSessionBatteries(
    String sessionId,
  ) async {
    final query =
        select(db.sessionBatteries).join([
            innerJoin(
              db.batteries,
              db.batteries.batteryId.equalsExp(db.sessionBatteries.batteryId),
            ),
          ])
          ..where(db.sessionBatteries.sessionId.equals(sessionId))
          ..orderBy([OrderingTerm.asc(db.batteries.batteryId)]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionBatteryWithBattery(
        sessionBattery: row.readTable(db.sessionBatteries),
        battery: row.readTable(db.batteries),
      );
    }).toList();
  }

  Future<List<SessionEquipmentCheckWithItem>> getSessionEquipmentChecks(
    String sessionId,
  ) async {
    final query =
        select(db.sessionEquipmentChecks).join([
            innerJoin(
              db.equipmentLists,
              db.equipmentLists.id.equalsExp(
                db.sessionEquipmentChecks.equipmentId,
              ),
            ),
          ])
          ..where(db.sessionEquipmentChecks.sessionId.equals(sessionId))
          ..orderBy([OrderingTerm.asc(db.sessionEquipmentChecks.checkedAt)]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionEquipmentCheckWithItem(
        sessionEquipmentCheck: row.readTable(db.sessionEquipmentChecks),
        equipmentList: row.readTable(db.equipmentLists),
      );
    }).toList();
  }

  Future<Sorty?> getSortieById(String flightId) {
    return (select(
      db.sorties,
    )..where((v) => v.flightId.equals(flightId))).getSingleOrNull();
  }

  Future<List<Sorty>> getSortiesForSession(String sessionId) {
    return (select(db.sorties)
          ..where((v) => v.sessionId.equals(sessionId))
          ..orderBy([(v) => OrderingTerm.asc(v.sequenceNo)]))
        .get();
  }

  Future<List<Sorty>> getClosedSortiesForSession(String sessionId) {
    return (select(db.sorties)
          ..where(
            (v) =>
                v.sessionId.equals(sessionId) & v.flightStatus.equals('CLOSED'),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.sequenceNo)]))
        .get();
  }

  Future<List<SortieUserWithUser>> getSortieUsers(String flightId) async {
    final query =
        select(db.sortieUsers).join([
            innerJoin(db.users, db.users.id.equalsExp(db.sortieUsers.userId)),
          ])
          ..where(db.sortieUsers.flightId.equals(flightId))
          ..orderBy([
            OrderingTerm.asc(db.sortieUsers.role),
            OrderingTerm.asc(db.users.name),
          ]);

    final rows = await query.get();

    return rows.map((row) {
      return SortieUserWithUser(
        sortieUser: row.readTable(db.sortieUsers),
        user: row.readTable(db.users),
      );
    }).toList();
  }

  Future<List<SortiePayloadWithPayload>> getSortiePayloads(
    String flightId,
  ) async {
    final query =
        select(db.sortiePayloads).join([
            innerJoin(
              db.payloads,
              db.payloads.payloadId.equalsExp(db.sortiePayloads.payloadId),
            ),
          ])
          ..where(db.sortiePayloads.flightId.equals(flightId))
          ..orderBy([OrderingTerm.asc(db.payloads.name)]);

    final rows = await query.get();

    return rows.map((row) {
      return SortiePayloadWithPayload(
        sortiePayload: row.readTable(db.sortiePayloads),
        payload: row.readTable(db.payloads),
      );
    }).toList();
  }

  Future<List<SortieBatteryWithBattery>> getSortieBatteries(
    String flightId,
  ) async {
    final query =
        select(db.sortieBatteries).join([
            innerJoin(
              db.batteries,
              db.batteries.batteryId.equalsExp(db.sortieBatteries.batteryId),
            ),
          ])
          ..where(db.sortieBatteries.flightId.equals(flightId))
          ..orderBy([OrderingTerm.asc(db.batteries.batteryId)]);

    final rows = await query.get();

    return rows.map((row) {
      return SortieBatteryWithBattery(
        sortieBattery: row.readTable(db.sortieBatteries),
        battery: row.readTable(db.batteries),
      );
    }).toList();
  }

  Future<List<ChecklistResponseWithItem>> getChecklistResponsesForFlight(
    String flightId,
  ) async {
    final query =
        select(db.checklistResponses).join([
            innerJoin(
              db.checklistItems,
              db.checklistItems.id.equalsExp(db.checklistResponses.itemId),
            ),
          ])
          ..where(db.checklistResponses.flightId.equals(flightId))
          ..orderBy([OrderingTerm.asc(db.checklistItems.sortOrder)]);

    final rows = await query.get();

    return rows.map((row) {
      return ChecklistResponseWithItem(
        response: row.readTable(db.checklistResponses),
        item: row.readTable(db.checklistItems),
      );
    }).toList();
  }

  Future<List<ChecklistOverride>> getOverridesForFlight(String flightId) {
    return (select(db.checklistOverrides)
          ..where((v) => v.flightId.equals(flightId))
          ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
        .get();
  }

  Future<PostFlightNote?> getPostFlightNoteForFlight(String flightId) {
    return (select(
      db.postFlightNotes,
    )..where((v) => v.flightId.equals(flightId))).getSingleOrNull();
  }

  Future<List<AuditEvent>> getAuditEventsForEntity({
    required String entityType,
    required String entityId,
  }) {
    final normalizedEntityType = _normalizeEntityType(entityType);

    return (select(db.auditEvents)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.performedAt)]))
        .get();
  }

  Future<List<AuditEvent>> getAuditTrailForSession(String sessionId) async {
    final entityIds = await _collectSessionEntityIds(sessionId);

    if (entityIds.isEmpty) {
      return [];
    }

    return (select(db.auditEvents)
          ..where((v) => v.entityId.isIn(entityIds.toList()))
          ..orderBy([(v) => OrderingTerm.asc(v.performedAt)]))
        .get();
  }

  Future<List<AuditEvent>> getRecentAuditEvents({int limit = 100}) {
    return (select(db.auditEvents)
          ..orderBy([(v) => OrderingTerm.desc(v.performedAt)])
          ..limit(limit))
        .get();
  }

  Future<void> addRecordAmendment({
    String? id,
    required String entityType,
    required String entityId,
    required String amendmentText,
    required String createdBy,
  }) async {
    final normalizedEntityType = _normalizeEntityType(entityType);

    if (amendmentText.trim().isEmpty) {
      throw Exception('Amendment text cannot be empty.');
    }

    await transaction(() async {
      final amendmentId = id ?? _uuid.v4();

      await into(db.recordAmendments).insert(
        RecordAmendmentsCompanion.insert(
          id: amendmentId,
          entityType: normalizedEntityType,
          entityId: entityId,
          amendmentText: amendmentText,
          createdBy: createdBy,
        ),
      );

      await _insertAuditEvent(
        entityType: normalizedEntityType,
        entityId: entityId,
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

  Future<List<RecordAmendment>> getAmendmentsForEntity({
    required String entityType,
    required String entityId,
  }) {
    final normalizedEntityType = _normalizeEntityType(entityType);

    return (select(db.recordAmendments)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
        .get();
  }

  Future<List<RecordAmendment>> getAmendmentsForSession(
    String sessionId,
  ) async {
    final entityIds = await _collectSessionEntityIds(sessionId);

    if (entityIds.isEmpty) {
      return [];
    }

    return (select(db.recordAmendments)
          ..where((v) => v.entityId.isIn(entityIds.toList()))
          ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
        .get();
  }

  Future<List<ExportRecord>> getExportsForEntity({
    required String entityType,
    required String entityId,
  }) {
    final normalizedEntityType = _normalizeEntityType(entityType);

    return (select(db.exportRecords)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId),
          )
          ..orderBy([(v) => OrderingTerm.desc(v.generatedAt)]))
        .get();
  }

  Future<List<ExportRecord>> getExportsForSession(String sessionId) {
    return getExportsForEntity(
      entityType: 'FIELD_SESSION',
      entityId: sessionId,
    );
  }

  Future<List<Sorty>> getSortiesForVehicle({
    required String vehicleId,
    int limit = 50,
  }) async {
    final query = select(db.sorties).join([
      innerJoin(
        db.sessionVehicles,
        db.sessionVehicles.id.equalsExp(db.sorties.sessionVehicleId),
      ),
    ])
      ..where(db.sessionVehicles.vehicleId.equals(vehicleId))
      ..orderBy([
        OrderingTerm.desc(db.sorties.landingAt),
        OrderingTerm.desc(db.sorties.updatedAt),
      ])
      ..limit(limit);

    final rows = await query.get();

    return rows.map((row) => row.readTable(db.sorties)).toList();
  }

  Future<int> countSortiesForVehicle(String vehicleId) async {
    final countExp = db.sorties.flightId.count();
    final query = selectOnly(db.sorties).join([
      innerJoin(
        db.sessionVehicles,
        db.sessionVehicles.id.equalsExp(db.sorties.sessionVehicleId),
      ),
    ])
      ..addColumns([countExp])
      ..where(db.sessionVehicles.vehicleId.equals(vehicleId));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<int> countSessionsForSite(String locationName) async {
    final countExp = db.fieldSessions.sessionId.count();
    final query = selectOnly(db.fieldSessions)
      ..addColumns([countExp])
      ..where(db.fieldSessions.locationName.equals(locationName));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  String _normalizeEntityType(String entityType) {
    final value = entityType.trim().toUpperCase();

    if (value == 'FLIGHT') {
      return 'SORTIE';
    }

    return value;
  }

  Future<Set<String>> _collectSessionEntityIds(String sessionId) async {
    final entityIds = <String>{sessionId};

    final sessionUsers = await (select(
      db.sessionUsers,
    )..where((v) => v.sessionId.equals(sessionId))).get();

    for (final item in sessionUsers) {
      entityIds.add(item.id);
    }

    final sessionVehicles = await (select(
      db.sessionVehicles,
    )..where((v) => v.sessionId.equals(sessionId))).get();

    for (final item in sessionVehicles) {
      entityIds.add(item.id);
    }

    final sessionBatteries = await (select(
      db.sessionBatteries,
    )..where((v) => v.sessionId.equals(sessionId))).get();

    for (final item in sessionBatteries) {
      entityIds.add(item.id);
    }

    final equipmentChecks = await (select(
      db.sessionEquipmentChecks,
    )..where((v) => v.sessionId.equals(sessionId))).get();

    for (final item in equipmentChecks) {
      entityIds.add(item.id);
    }

    final sorties = await getSortiesForSession(sessionId);

    for (final sortie in sorties) {
      entityIds.add(sortie.flightId);

      final sortieUsers = await (select(
        db.sortieUsers,
      )..where((v) => v.flightId.equals(sortie.flightId))).get();

      for (final item in sortieUsers) {
        entityIds.add(item.id);
      }

      final sortiePayloads = await (select(
        db.sortiePayloads,
      )..where((v) => v.flightId.equals(sortie.flightId))).get();

      for (final item in sortiePayloads) {
        entityIds.add(item.id);
      }

      final sortieBatteries = await (select(
        db.sortieBatteries,
      )..where((v) => v.flightId.equals(sortie.flightId))).get();

      for (final item in sortieBatteries) {
        entityIds.add(item.id);
        entityIds.add('${item.flightId}:${item.batteryId}');
      }

      final checklistResponses = await (select(
        db.checklistResponses,
      )..where((v) => v.flightId.equals(sortie.flightId))).get();

      for (final item in checklistResponses) {
        entityIds.add(item.id);
        entityIds.add('${item.flightId}:${item.itemId}');
      }

      final overrides = await (select(
        db.checklistOverrides,
      )..where((v) => v.flightId.equals(sortie.flightId))).get();

      for (final item in overrides) {
        entityIds.add(item.id);
      }

      final postFlightNote = await getPostFlightNoteForFlight(sortie.flightId);

      if (postFlightNote != null) {
        entityIds.add(postFlightNote.id);
        entityIds.add(postFlightNote.flightId);
      }
    }

    return entityIds;
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
}
