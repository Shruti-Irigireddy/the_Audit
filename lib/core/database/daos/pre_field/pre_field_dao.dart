import 'package:drift/drift.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/pre_field_dtos.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';
import 'package:uuid/uuid.dart';

part 'pre_field_dao.g.dart';

final _uuid = Uuid();

@DriftAccessor(
  tables: [
    FieldSessions,
    SessionUsers,
    SessionBatteries,
    SessionVehicles,
    SessionEquipmentChecks,
    SessionVehiclePayload,
    Users,
    Vehicles,
    Payloads,
    Batteries,
    PayloadVehicleCompatibility,
    EquipmentLists,
    Sorties,
    AuditEvents,
    SyncQueue,
  ],
)
class PreFieldDao extends DatabaseAccessor<AppDatabase> with _$PreFieldDaoMixin {
  PreFieldDao(super.db);

  Future<String> createFieldSession ({
    String? sessionId,
    required DateTime date,
    required String locationName,
    required double latitude,
    required double longitude,
    required String missionType,
    required String sessionStatus,
    required String createdBy,
  }) async {
    final resolvedSessionId = sessionId ?? _uuid.v4();

    await transaction(() async {
      await into(db.fieldSessions).insert(
        FieldSessionsCompanion.insert(
          sessionId: resolvedSessionId,
          date: date,
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
          missionType: missionType,
          sessionStatus: sessionStatus,
        ),
      );

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: resolvedSessionId,
        action: 'CREATE',
        description: 'Field session created',
        performedBy: createdBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: resolvedSessionId,
        operation: 'INSERT',
      );
    });

    return resolvedSessionId;
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
    await _requireFieldSession(sessionId);

    await transaction(() async {
      await (update(db.fieldSessions)
            ..where((v) => v.sessionId.equals(sessionId)))
          .write(
        FieldSessionsCompanion(
          date: date == null ? const Value.absent() : Value(date),
          locationName:
              locationName == null ? const Value.absent() : Value(locationName),
          latitude: latitude == null ? const Value.absent() : Value(latitude),
          longitude: longitude == null ? const Value.absent() : Value(longitude),
          missionType:
              missionType == null ? const Value.absent() : Value(missionType),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'UPDATE',
        description: 'Field session basic info updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }

  Future<FieldSession?> getFieldSessionById (String sessionId){
    return (select(db.fieldSessions)
          ..where((v) => v.sessionId.equals(sessionId)))
          .getSingleOrNull();
  }

  Future<List<FieldSession>> getInProgressFieldSessions() {
    return (select(db.fieldSessions)
          ..where((v) => v.sessionStatus.equals('IN_PROGRESS'))
          ..orderBy([
            (v) => OrderingTerm.desc(v.updatedAt),
          ]))
        .get();
  }

  Future<void> closeFieldSession ({
    required String sessionId,
    required String closedBy,
  }) async {
    final session = await _requireFieldSession(sessionId);

    if (session.sessionStatus == 'CLOSED') {
      throw Exception('Field session is already closed: $sessionId');
    }

    final now = DateTime.now();

    await transaction(() async {
      await (update(db.fieldSessions)
            ..where((v) => v.sessionId.equals(sessionId)))
          .write(
        FieldSessionsCompanion(
          sessionStatus: const Value('CLOSED'),
          closedAt: Value(now),
          closedBy: Value(closedBy),
          updatedAt: Value(now),
        ),
      );

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'CLOSE',
        description: 'Field session closed',
        performedBy: closedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }


  Future<String> addUserToSession({
    required String sessionId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    await _requireFieldSession(sessionId);
    await _requireUser(userId);

    final sessionUserId = _uuid.v4();

    await transaction(() async {
      await into(db.sessionUsers).insert(
        SessionUsersCompanion.insert(
          id: sessionUserId,
          sessionId: sessionId,
          userId: userId,
          role: role,
        ),
      );

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_USER',
        entityId: sessionUserId,
        action: 'CREATE',
        description: 'User added to session as $role',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_USER',
        entityId: sessionUserId,
        operation: 'INSERT',
      );
    });

    return sessionUserId;
  }

  Future<void> removeUserFromSession ({
    required String sessionUserId,
    required String performedBy,
  }) async {
    final sessionUser = await (select(db.sessionUsers)
          ..where((v) => v.id.equals(sessionUserId)))
        .getSingleOrNull();

    if (sessionUser == null) {
      throw Exception('Session user not found: $sessionUserId');
    }

    await transaction(() async {
      await (delete(db.sessionUsers)..where((v) => v.id.equals(sessionUserId)))
          .go();

      await _touchSession(sessionUser.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_USER',
        entityId: sessionUserId,
        action: 'DELETE',
        description: 'User removed from session',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_USER',
        entityId: sessionUserId,
        operation: 'DELETE',
      );
    });
  }

  Future<void> replaceSessionUsers ({
    required String sessionId,
    required List<SessionUserDraft> users,
    required String performedBy,
  }) async {
    await _requireFieldSession(sessionId);

    await transaction(() async {
      await (delete(db.sessionUsers)
            ..where((v) => v.sessionId.equals(sessionId)))
          .go();

      final seen = <String>{};

      for (final user in users) {
        final key = '${user.userId}:${user.role}';

        if (!seen.add(key)) continue;

        await _requireUser(user.userId);

        await into(db.sessionUsers).insert(
          SessionUsersCompanion.insert(
            id: _uuid.v4(),
            sessionId: sessionId,
            userId: user.userId,
            role: user.role,
          ),
        );
      }

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'REPLACE_SESSION_USERS',
        description: 'Session users replaced',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }

  Future<List<SessionUserWithUser>> getSessionUsers(String sessionId) async {
    final query = select(db.sessionUsers).join([
      innerJoin(
        db.users,
        db.users.id.equalsExp(db.sessionUsers.userId),
      ),
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

  Future<int> countSessionUsersByRole({
    required String sessionId,
    required String role,
  }) async {
    final countExp = db.sessionUsers.id.count();

    final query = selectOnly(db.sessionUsers)
      ..addColumns([countExp])
      ..where(
        db.sessionUsers.sessionId.equals(sessionId) &
            db.sessionUsers.role.equals(role),
      );

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }


  Future<String> addVehicleToSession({
    required String sessionId,
    required String vehicleId,
    String? objective,
    required String performedBy,
  }) async {
    await _requireFieldSession(sessionId);
    await _requireVehicle(vehicleId);

    final existing = await (select(db.sessionVehicles)
          ..where(
            (v) =>
                v.sessionId.equals(sessionId) & v.vehicleId.equals(vehicleId),
          ))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    final sessionVehicleId = _uuid.v4();

    await transaction(() async {
      await into(db.sessionVehicles).insert(
        SessionVehiclesCompanion.insert(
          id: sessionVehicleId,
          sessionId: sessionId,
          vehicleId: vehicleId,
          objective: Value(objective),
        ),
      );

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        action: 'CREATE',
        description: 'Vehicle added to session',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        operation: 'INSERT',
      );
    });

    return sessionVehicleId;
  }

  Future<void> removeVehicleFromSession({
    required String sessionVehicleId,
    required String performedBy,
  }) async {
    final sessionVehicle = await _requireSessionVehicle(sessionVehicleId);

    final sortieCount = await countSortiesForSessionVehicle(sessionVehicleId);

    if (sortieCount > 0) {
      throw Exception(
        'Cannot remove vehicle from session because it is being used in a sortie.',
      );
    }

    await transaction(() async {
      await (delete(db.sessionVehiclePayload)
            ..where((v) => v.sessionVehicleId.equals(sessionVehicleId)))
          .go();

      await (delete(db.sessionVehicles)
            ..where((v) => v.id.equals(sessionVehicleId)))
          .go();

      await _touchSession(sessionVehicle.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        action: 'DELETE',
        description: 'Vehicle removed from session',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        operation: 'DELETE',
      );
    });
  }

  Future<void> updateSessionVehicleObjective({
    required String sessionVehicleId,
    String? objective,
    required String performedBy,
  }) async {
    final sessionVehicle = await _requireSessionVehicle(sessionVehicleId);

    await transaction(() async {
      await (update(db.sessionVehicles)
            ..where((v) => v.id.equals(sessionVehicleId)))
          .write(
        SessionVehiclesCompanion(
          objective: Value(objective),
        ),
      );

      await _touchSession(sessionVehicle.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        action: 'UPDATE_OBJECTIVE',
        description: 'Session vehicle objective updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> replaceSessionVehicles({
    required String sessionId,
    required List<SessionVehicleDraft> vehicles,
    required String performedBy,
  }) async {
    await _requireFieldSession(sessionId);

    final sortieCount = await countSortiesForSession(sessionId);

    if (sortieCount > 0) {
      throw Exception(
        'Cannot replace session vehicles because sorties already exist.',
      );
    }

    await transaction(() async {
      final existingSessionVehicles = await (select(db.sessionVehicles)
            ..where((v) => v.sessionId.equals(sessionId)))
          .get();

      for (final sessionVehicle in existingSessionVehicles) {
        await (delete(db.sessionVehiclePayload)
              ..where((v) => v.sessionVehicleId.equals(sessionVehicle.id)))
            .go();
      }

      await (delete(db.sessionVehicles)
            ..where((v) => v.sessionId.equals(sessionId)))
          .go();

      final seenVehicleIds = <String>{};

      for (final vehicle in vehicles) {
        if (!seenVehicleIds.add(vehicle.vehicleId)) continue;

        await _requireVehicle(vehicle.vehicleId);

        await into(db.sessionVehicles).insert(
          SessionVehiclesCompanion.insert(
            id: _uuid.v4(),
            sessionId: sessionId,
            vehicleId: vehicle.vehicleId,
            objective: Value(vehicle.objective),
          ),
        );
      }

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'REPLACE_SESSION_VEHICLES',
        description: 'Session vehicles replaced',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }

  Future<List<SessionVehicleWithVehicle>> getSessionVehicles(
    String sessionId,
  ) async {
    final query = select(db.sessionVehicles).join([
      innerJoin(
        db.vehicles,
        db.vehicles.id.equalsExp(db.sessionVehicles.vehicleId),
      ),
    ])
      ..where(db.sessionVehicles.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.asc(db.vehicles.name),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionVehicleWithVehicle(
        sessionVehicle: row.readTable(db.sessionVehicles),
        vehicle: row.readTable(db.vehicles),
      );
    }).toList();
  }

  Future<int> countSessionVehicles(String sessionId) async {
    final countExp = db.sessionVehicles.id.count();

    final query = selectOnly(db.sessionVehicles)
      ..addColumns([countExp])
      ..where(db.sessionVehicles.sessionId.equals(sessionId));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<int> countSortiesForSession(String sessionId) async {
    final countExp = db.sorties.flightId.count();

    final query = selectOnly(db.sorties)
      ..addColumns([countExp])
      ..where(db.sorties.sessionId.equals(sessionId));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<int> countSortiesForSessionVehicle(String sessionVehicleId) async {
    final countExp = db.sorties.flightId.count();

    final query = selectOnly(db.sorties)
      ..addColumns([countExp])
      ..where(db.sorties.sessionVehicleId.equals(sessionVehicleId));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }


  Future<String> addPayloadToSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    final sessionVehicle = await _requireSessionVehicle(sessionVehicleId);
    await _requirePayload(payloadId);

    final existing = await (select(db.sessionVehiclePayload)
          ..where(
            (v) =>
                v.sessionVehicleId.equals(sessionVehicleId) &
                v.payloadId.equals(payloadId),
          ))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    final id = _uuid.v4();

    await transaction(() async {
      await into(db.sessionVehiclePayload).insert(
        SessionVehiclePayloadCompanion.insert(
          id: id,
          sessionVehicleId: sessionVehicleId,
          payloadId: payloadId,
        ),
      );

      await _touchSession(sessionVehicle.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_VEHICLE_PAYLOAD',
        entityId: id,
        action: 'CREATE',
        description: 'Payload assigned to session vehicle',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_VEHICLE_PAYLOAD',
        entityId: id,
        operation: 'INSERT',
      );
    });

    return id;
  }

  Future<void> removePayloadFromSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    final sessionVehicle = await _requireSessionVehicle(sessionVehicleId);

    final payloadAssignment = await (select(db.sessionVehiclePayload)
          ..where(
            (v) =>
                v.sessionVehicleId.equals(sessionVehicleId) &
                v.payloadId.equals(payloadId),
          ))
        .getSingleOrNull();

    if (payloadAssignment == null) {
      throw Exception(
        'Payload $payloadId is not assigned to session vehicle $sessionVehicleId.',
      );
    }

    await transaction(() async {
      await (delete(db.sessionVehiclePayload)
            ..where((v) => v.id.equals(payloadAssignment.id)))
          .go();

      await _touchSession(sessionVehicle.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_VEHICLE_PAYLOAD',
        entityId: payloadAssignment.id,
        action: 'DELETE',
        description: 'Payload removed from session vehicle: $payloadId',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_VEHICLE_PAYLOAD',
        entityId: payloadAssignment.id,
        operation: 'DELETE',
      );
    });
  }

  Future<void> replacePayloadsForSessionVehicle({
    required String sessionVehicleId,
    required List<String> payloadIds,
    required String performedBy,
  }) async {
    final sessionVehicle = await _requireSessionVehicle(sessionVehicleId);

    await transaction(() async {
      await (delete(db.sessionVehiclePayload)
            ..where((v) => v.sessionVehicleId.equals(sessionVehicleId)))
          .go();

      for (final payloadId in payloadIds.toSet()) {
        await _requirePayload(payloadId);

        await into(db.sessionVehiclePayload).insert(
          SessionVehiclePayloadCompanion.insert(
            id: _uuid.v4(),
            sessionVehicleId: sessionVehicleId,
            payloadId: payloadId,
          ),
        );
      }

      await _touchSession(sessionVehicle.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        action: 'REPLACE_PAYLOADS',
        description: 'Payloads replaced for session vehicle',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        operation: 'UPDATE',
      );
    });
  }

  Future<List<Payload>> getPayloadsForSessionVehicle (String sessionVehicleId) async {
    final query = select(db.sessionVehiclePayload).join([
      innerJoin(
        db.payloads,
        db.payloads.payloadId.equalsExp(db.sessionVehiclePayload.payloadId),
      ),
    ])
      ..where(db.sessionVehiclePayload.sessionVehicleId.equals(sessionVehicleId))
      ..orderBy([
        OrderingTerm.asc(db.payloads.name),
      ]);

    final rows = await query.get();

    return rows.map((row) => row.readTable(db.payloads)).toList();
  }

  Future<int> countPayloadsForSessionVehicle(String sessionVehicleId) async {
    final countExp = db.sessionVehiclePayload.id.count();

    final query = selectOnly(db.sessionVehiclePayload)
      ..addColumns([countExp])
      ..where(db.sessionVehiclePayload.sessionVehicleId.equals(sessionVehicleId));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<List<PayloadCompatibilityIssue>>
      getPayloadCompatibilityIssuesForSessionVehicle(
    String sessionVehicleId,
  ) async {
    final sessionVehicle = await _requireSessionVehicle(sessionVehicleId);
    final vehicle = await _requireVehicle(sessionVehicle.vehicleId);
    final selectedPayloads = await getPayloadsForSessionVehicle(sessionVehicleId);

    final issues = <PayloadCompatibilityIssue>[];

    for (final payload in selectedPayloads) {
      final compatibilityRows = await (select(db.payloadVehicleCompatibility)
            ..where((v) => v.payloadId.equals(payload.payloadId)))
          .get();

      if (compatibilityRows.isEmpty) continue;

      final isCompatible = compatibilityRows.any(
        (row) => row.vehicleType == vehicle.type,
      );

      if (!isCompatible) {
        issues.add(
          PayloadCompatibilityIssue(
            vehicleId: vehicle.id,
            sessionVehicleId: sessionVehicleId,
            vehicleName: vehicle.name,
            vehicleType: vehicle.type,
            payloadId: payload.payloadId,
            payloadName: payload.name,
            message:
                'Payload ${payload.name} is not marked compatible with ${vehicle.type}',
          ),
        );
      }
    }

    return issues;
  }

  Future<List<PayloadCompatibilityIssue>> getPayloadCompatibilityIssues(
    String sessionId,
  ) async {
    await _requireFieldSession(sessionId);

    final sessionVehicleList = await getSessionVehicles(sessionId);
    final issues = <PayloadCompatibilityIssue>[];

    for (final item in sessionVehicleList) {
      final vehicleIssues =
          await getPayloadCompatibilityIssuesForSessionVehicle(
        item.sessionVehicle.id,
      );

      issues.addAll(vehicleIssues);
    }

    return issues;
  }

  Future<String> addBatteryToSession({
    required String sessionId,
    required String batteryId,
    required String performedBy,
  }) async {
    await _requireFieldSession(sessionId);
    await _requireBattery(batteryId);

    final existing = await (select(db.sessionBatteries)
          ..where(
            (v) =>
                v.sessionId.equals(sessionId) & v.batteryId.equals(batteryId),
          ))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    final id = _uuid.v4();

    await transaction(() async {
      await into(db.sessionBatteries).insert(
        SessionBatteriesCompanion.insert(
          id: id,
          sessionId: sessionId,
          batteryId: batteryId,
        ),
      );

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_BATTERY',
        entityId: id,
        action: 'CREATE',
        description: 'Battery added to session',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_BATTERY',
        entityId: id,
        operation: 'INSERT',
      );
    });

    return id;
  }

  Future<void> removeBatteryFromSession({
    required String sessionBatteryId,
    required String performedBy,
  }) async {
    final sessionBattery = await (select(db.sessionBatteries)
          ..where((v) => v.id.equals(sessionBatteryId)))
        .getSingleOrNull();

    if (sessionBattery == null) {
      throw Exception('Session battery not found: $sessionBatteryId');
    }

    await transaction(() async {
      await (delete(db.sessionBatteries)
            ..where((v) => v.id.equals(sessionBatteryId)))
          .go();

      await _touchSession(sessionBattery.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_BATTERY',
        entityId: sessionBatteryId,
        action: 'DELETE',
        description: 'Battery removed from session',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_BATTERY',
        entityId: sessionBatteryId,
        operation: 'DELETE',
      );
    });
  }

  Future<void> replaceSessionBatteries({
    required String sessionId,
    required List<SessionBatteryDraft> batteries,
    required String performedBy,
  }) async {
    await _requireFieldSession(sessionId);

    await transaction(() async {
      await (delete(db.sessionBatteries)
            ..where((v) => v.sessionId.equals(sessionId)))
          .go();

      final seenBatteryIds = <String>{};

      for (final battery in batteries) {
        if (!seenBatteryIds.add(battery.batteryId)) continue;

        await _requireBattery(battery.batteryId);

        await into(db.sessionBatteries).insert(
          SessionBatteriesCompanion.insert(
            id: _uuid.v4(),
            sessionId: sessionId,
            batteryId: battery.batteryId,
          ),
        );
      }

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'REPLACE_BATTERIES',
        description: 'Session batteries replaced',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }

  Future<List<SessionBatteryWithBattery>> getSessionBatteries(
    String sessionId,
  ) async {
    final query = select(db.sessionBatteries).join([
      innerJoin(
        db.batteries,
        db.batteries.batteryId.equalsExp(db.sessionBatteries.batteryId),
      ),
    ])
      ..where(db.sessionBatteries.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.asc(db.batteries.batteryId),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionBatteryWithBattery(
        sessionBattery: row.readTable(db.sessionBatteries),
        battery: row.readTable(db.batteries),
      );
    }).toList();
  }

  Future<List<EquipmentList>> getActiveEquipmentList() {
    return (select(db.equipmentLists)
          ..where((v) => v.isActive.equals(true))
          ..orderBy([
            (v) => OrderingTerm.asc(v.category),
            (v) => OrderingTerm.asc(v.name),
          ]))
        .get();
  }

  Future<void> createEquipmentChecksForSession({
    required String sessionId,
    required String checkedBy,
  }) async {
    await _requireFieldSession(sessionId);

    final activeEquipment = await getActiveEquipmentList();

    final existingChecks = await (select(db.sessionEquipmentChecks)
          ..where((v) => v.sessionId.equals(sessionId)))
        .get();

    final existingEquipmentIds =
        existingChecks.map((item) => item.equipmentId).toSet();

    await transaction(() async {
      for (final item in activeEquipment) {
        if (existingEquipmentIds.contains(item.id)) continue;

        await into(db.sessionEquipmentChecks).insert(
          SessionEquipmentChecksCompanion.insert(
            id: _uuid.v4(),
            sessionId: sessionId,
            equipmentId: item.id,
            checkedBy: checkedBy,
          ),
        );
      }

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'CREATE_EQUIPMENT_CHECKS',
        description: 'Equipment checklist created for session',
        performedBy: checkedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> updateEquipmentCheck({
    required String equipmentCheckId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  }) async {
    final equipmentCheck = await (select(db.sessionEquipmentChecks)
          ..where((v) => v.id.equals(equipmentCheckId)))
        .getSingleOrNull();

    if (equipmentCheck == null) {
      throw Exception('Equipment check not found: $equipmentCheckId');
    }

    final now = DateTime.now();

    await transaction(() async {
      await (update(db.sessionEquipmentChecks)
            ..where((v) => v.id.equals(equipmentCheckId)))
          .write(
        SessionEquipmentChecksCompanion(
          isPacked: Value(isPacked),
          notes: notes == null ? const Value.absent() : Value(notes),
          checkedAt: Value(now),
          checkedBy: Value(checkedBy),
          updatedAt: Value(now),
        ),
      );

      await _touchSession(equipmentCheck.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_EQUIPMENT_CHECK',
        entityId: equipmentCheckId,
        action: 'UPDATE',
        description: 'Equipment check updated',
        performedBy: checkedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_EQUIPMENT_CHECK',
        entityId: equipmentCheckId,
        operation: 'UPDATE',
      );
    });
  }

  Future<List<SessionEquipmentCheckWithItem>> getSessionEquipmentChecks(
    String sessionId,
  ) async {
    final query = select(db.sessionEquipmentChecks).join([
      innerJoin(
        db.equipmentLists,
        db.equipmentLists.id.equalsExp(db.sessionEquipmentChecks.equipmentId),
      ),
    ])
      ..where(db.sessionEquipmentChecks.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.asc(db.equipmentLists.category),
        OrderingTerm.asc(db.equipmentLists.name),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionEquipmentCheckWithItem(
        sessionEquipmentCheck: row.readTable(db.sessionEquipmentChecks),
        equipmentList: row.readTable(db.equipmentLists),
      );
    }).toList();
  }

  Future<String> addCustomEquipmentCheckToSession({
    required String sessionId,
    required String equipmentId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  }) async {
    await _requireFieldSession(sessionId);
    await _requireEquipmentItem(equipmentId);

    final existing = await (select(db.sessionEquipmentChecks)
          ..where(
            (v) =>
                v.sessionId.equals(sessionId) &
                v.equipmentId.equals(equipmentId),
          ))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    await transaction(() async {
      await into(db.sessionEquipmentChecks).insert(
        SessionEquipmentChecksCompanion.insert(
          id: id,
          sessionId: sessionId,
          equipmentId: equipmentId,
          checkedBy: checkedBy,
          isPacked: Value(isPacked),
          notes: Value(notes),
          checkedAt: Value(now),
        ),
      );

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_EQUIPMENT_CHECK',
        entityId: id,
        action: 'CREATE',
        description: 'Custom equipment check added to session',
        performedBy: checkedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_EQUIPMENT_CHECK',
        entityId: id,
        operation: 'INSERT',
      );
    });

    return id;
  }

  Future<int> countUnpackedEquipmentChecks(String sessionId) async {
    final countExp = db.sessionEquipmentChecks.id.count();

    final query = selectOnly(db.sessionEquipmentChecks)
      ..addColumns([countExp])
      ..where(
        db.sessionEquipmentChecks.sessionId.equals(sessionId) &
            db.sessionEquipmentChecks.isPacked.equals(false),
      );

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<String> createEquipmentItem({
    String? id,
    required String name,
    required String category,
    required String performedBy,
  }) async {
    final resolvedId = id ?? _uuid.v4();

    await transaction(() async {
      await into(db.equipmentLists).insert(
        EquipmentListsCompanion.insert(
          id: resolvedId,
          name: name,
          category: category,
        ),
      );

      await _insertAuditEvent(
        entityType: 'EQUIPMENT_ITEM',
        entityId: resolvedId,
        action: 'CREATE',
        description: 'Equipment item created',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'EQUIPMENT_ITEM',
        entityId: resolvedId,
        operation: 'INSERT',
      );
    });

    return resolvedId;
  }

  Future<void> updateEquipmentItem({
    required String equipmentId,
    String? name,
    String? category,
    bool? isActive,
    required String performedBy,
  }) async {
    await _requireEquipmentItem(equipmentId);

    await transaction(() async {
      await (update(db.equipmentLists)..where((v) => v.id.equals(equipmentId)))
          .write(
        EquipmentListsCompanion(
          name: name == null ? const Value.absent() : Value(name),
          category: category == null ? const Value.absent() : Value(category),
          isActive: isActive == null ? const Value.absent() : Value(isActive),
        ),
      );

      await _insertAuditEvent(
        entityType: 'EQUIPMENT_ITEM',
        entityId: equipmentId,
        action: 'UPDATE',
        description: 'Equipment item updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'EQUIPMENT_ITEM',
        entityId: equipmentId,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> deactivateEquipmentItem({
    required String equipmentId,
    required String performedBy,
  }) {
    return updateEquipmentItem(
      equipmentId: equipmentId,
      isActive: false,
      performedBy: performedBy,
    );
  }


  Future<PreFieldSummaryData> getPreFieldSummary (String sessionId) async {
    final session = await getFieldSessionById(sessionId);

    if (session == null) {
      throw Exception('Field session not found: $sessionId');
    }

    final teamMembers = await getSessionUsers(sessionId);
    final sessionVehicleList = await getSessionVehicles(sessionId);
    final batteriesList = await getSessionBatteries(sessionId);
    final equipmentChecks = await getSessionEquipmentChecks(sessionId);
    final issues = await getPayloadCompatibilityIssues(sessionId);

    return PreFieldSummaryData(
      session: session,
      teamMembers: teamMembers,
      vehicles: sessionVehicleList,
      batteries: batteriesList,
      equipmentChecks: equipmentChecks,
      payloadCompatibilityIssues: issues,
    );
  }

  Future<FieldSession> _requireFieldSession(String sessionId) async {
    final session = await getFieldSessionById(sessionId);

    if (session == null) {
      throw Exception('Field session not found: $sessionId');
    }

    return session;
  }

  Future<User> _requireUser(String userId) async {
    final user = await (select(db.users)..where((v) => v.id.equals(userId)))
        .getSingleOrNull();

    if (user == null) {
      throw Exception('User not found: $userId');
    }

    return user;
  }

  Future<Vehicle> _requireVehicle(String vehicleId) async {
    final vehicle = await (select(db.vehicles)
          ..where((v) => v.id.equals(vehicleId)))
        .getSingleOrNull();

    if (vehicle == null) {
      throw Exception('Vehicle not found: $vehicleId');
    }

    return vehicle;
  }

  Future<Payload> _requirePayload(String payloadId) async {
    final payload = await (select(db.payloads)
          ..where((v) => v.payloadId.equals(payloadId)))
        .getSingleOrNull();

    if (payload == null) {
      throw Exception('Payload not found: $payloadId');
    }

    return payload;
  }

  Future<Battery> _requireBattery(String batteryId) async {
    final battery = await (select(db.batteries)
          ..where((v) => v.batteryId.equals(batteryId)))
        .getSingleOrNull();

    if (battery == null) {
      throw Exception('Battery not found: $batteryId');
    }

    return battery;
  }

  Future<EquipmentList> _requireEquipmentItem(String equipmentId) async {
    final equipment = await (select(db.equipmentLists)
          ..where((v) => v.id.equals(equipmentId)))
        .getSingleOrNull();

    if (equipment == null) {
      throw Exception('Equipment item not found: $equipmentId');
    }

    return equipment;
  }

  Future<SessionVehicle> _requireSessionVehicle(
    String sessionVehicleId,
  ) async {
    final sessionVehicle = await (select(db.sessionVehicles)
          ..where((v) => v.id.equals(sessionVehicleId)))
        .getSingleOrNull();

    if (sessionVehicle == null) {
      throw Exception('Session vehicle not found: $sessionVehicleId');
    }

    return sessionVehicle;
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

  Future<void> _touchSession(String sessionId) {
    return (update(db.fieldSessions)
          ..where((v) => v.sessionId.equals(sessionId)))
        .write(
      FieldSessionsCompanion(
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
