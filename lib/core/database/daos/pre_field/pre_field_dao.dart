import 'package:drift/drift.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/pre_field_dtos.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

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
  
  Future<void> createFieldSession ({
    required String sessionId,
    required DateTime date,
    required String locationName,
    required double latitude,
    required double longitude,
    required String missionType,
    required String createdBy,
  }) async {
    await transaction(() async {
      await into(db.fieldSessions).insert(
        FieldSessionsCompanion.insert(
          sessionId: sessionId, 
          date: date, 
          locationName: locationName, 
          latitude: latitude, 
          longitude: longitude, 
          missionType: missionType, 
          sessionStatus: 'IN_PROGRESS'
        ),
      );

       await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'CREATE',
        description: 'Field session created',
        performedBy: createdBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'INSERT',
      );
    });
  }

  Future<void> updateFieldSession ({
    required String sessionId,
    DateTime? date,
    String? locationName,
    double? latitude,
    double? longitude,
    String? missionType,
    required String performedBy,
  }) async {
    await transaction(() async {
        await (update(fieldSessions)
              ..where((v) => v.sessionId.equals(sessionId)))
              .write(
                FieldSessionsCompanion(
                  date: date == null ? const Value.absent() : Value(date),
                  locationName: locationName == null ? const Value.absent() : Value(locationName),
                  latitude: latitude == null ? const Value.absent() : Value(latitude),
                  longitude: longitude == null ? const Value.absent() : Value(longitude),
                  missionType: missionType == null ? const Value.absent() : Value(missionType),
                  updatedAt: Value(DateTime.now())
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

  Future<List<FieldSession?>> getInProgressFieldSessions() {
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
      await transaction(() async {
        await (update(db.fieldSessions)
              ..where((v) => v.sessionId.equals(sessionId)))
              .write(
                FieldSessionsCompanion(
                  sessionStatus: const Value('CLOSED'),
                  closedAt: Value(DateTime.now()),
                  closedBy: Value(closedBy),
                  updatedAt: Value(DateTime.now())
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

  Future<void> addUserToSession ({
    required String sessionUserId,
    required String sessionId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    await transaction(() async {
      await into(db.sessionUsers).insert(
        SessionUsersCompanion.insert(
          id: sessionUserId, 
          sessionId: sessionId, 
          userId: userId, 
          role: role
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
  }

  Future<void> removeUserFromSession ({
    required String sessionUserId,
    required String performedBy,
  }) async {
    final sessionUser = await (select(sessionUsers)
        ..where((v) => v.id.equals(sessionUserId)))
      .getSingleOrNull();

  if (sessionUser == null) {
    throw Exception('Session user not found: $sessionUserId');
  }

  await transaction(() async {
    await (delete(sessionUsers)
          ..where((v) => v.id.equals(sessionUserId)))
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
    await transaction(() async {
      await (delete(db.sessionUsers)
          ..where((v) => v.sessionId.equals(sessionId)))
          .go();

      for(final user in users) {
        await into(db.sessionUsers).insert(
          SessionUsersCompanion.insert(
            id: user.id, 
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
    final query = select(sessionUsers).join([
      innerJoin(
        users,
        users.id.equalsExp(sessionUsers.userId),
      ),
    ])
      ..where(sessionUsers.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.asc(sessionUsers.role),
        OrderingTerm.asc(users.name),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionUserWithUser(
        sessionUser: row.readTable(sessionUsers),
        user: row.readTable(users),
      );
    }).toList();
  }
  
  Future<int> countSessionUsersByRole({
    required String sessionId,
    required String role,
  }) async {
    final countExp = sessionUsers.id.count();

    final query = selectOnly(sessionUsers)
      ..addColumns([countExp])
      ..where(
        sessionUsers.sessionId.equals(sessionId) &
            sessionUsers.role.equals(role),
      );

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<void> addVehicleToSession({
    required String sessionVehicleId,
    required String sessionId,
    required String vehicleId,
    String? objective,
    required String performedBy
  }) async {
    await transaction(() async {
      await into(db.sessionVehicles).insert(
        SessionVehiclesCompanion.insert(
          id: sessionVehicleId, 
          sessionId: sessionId, 
          vehicleId: vehicleId,
          objective: Value(objective)
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
  }

Future<void> removeVehicleFromSession({
    required String sessionVehicleId,
    required String performedBy,
  }) async {
    final sessionVehicle = await (select(sessionVehicles)
          ..where((v) => v.id.equals(sessionVehicleId)))
        .getSingleOrNull();

    if (sessionVehicle == null) {
      throw Exception('Session vehicle not found: $sessionVehicleId');
    }

    final sortieCount = await countSortiesForSessionVehicle(sessionVehicleId);

    if(sortieCount > 0){
      throw Exception('Cannot remove Vehicle from session because it is being used in a sortie');
    }

    await transaction(() async {
      await (delete(sessionVehiclePayload)
            ..where((v) => v.sessionVehicleId.equals(sessionVehicleId)))
          .go();

      await (delete(sessionVehicles)
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


  Future<void> updateSessionVehicleObjective ({
    required String sessionVehicleId,
    required String objective,
    required String performedBy
  }) async {
    final sessionVehicle = await (select(sessionVehicles)
          ..where((v) => v.id.equals(sessionVehicleId)))
        .getSingleOrNull();

    if (sessionVehicle == null) {
      throw Exception('Session vehicle not found: $sessionVehicleId');
    }

    await transaction(() async {
      await (update(db.sessionVehicles)
        ..where((v) => v.id.equals(sessionVehicleId)))
        .write(
          SessionVehiclesCompanion(
            objective: Value(objective)
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

  Future<void> replaceSessionVehicles ({
    required String sessionId,
    required List<SessionVehicleDraft> vehicles,
    required String performedBy
  }) async {
    final sortieCount = await countSortiesForSession(sessionId);

    if (sortieCount > 0) {
      throw Exception(
        'Cannot replace session vehicles because sorties already exist.',
      );
    }

    await transaction(() async {
      final existingSessionVehicle = await (select(db.sessionVehicles)
          ..where((v) => v.sessionId.equals(sessionId)))
          .get();

      for (final sessionVehicle in existingSessionVehicle){
        await (delete(db.sessionVehiclePayload)
            ..where((v) => v.sessionVehicleId.equals(sessionVehicle.id)))
            .go();
      }
        await (delete(db.sessionVehicles)
            ..where((v) => v.sessionId.equals(sessionId)))
            .go();

      for (final vehicle in vehicles) {
        await into(db.sessionVehicles).insert(
          SessionVehiclesCompanion.insert(
            id: vehicle.id, 
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
    final query = select(sessionVehicles).join([
      innerJoin(
        vehicles,
        vehicles.id.equalsExp(sessionVehicles.vehicleId),
      ),
    ])
      ..where(sessionVehicles.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.asc(vehicles.name),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionVehicleWithVehicle(
        sessionVehicle: row.readTable(sessionVehicles),
        vehicle: row.readTable(vehicles),
      );
    }).toList();
  }

  Future<int> countSessionVehicles(String sessionId) async {
    final countExp = sessionVehicles.id.count();

    final query = selectOnly(sessionVehicles)
      ..addColumns([countExp])
      ..where(sessionVehicles.sessionId.equals(sessionId));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<int> countSortiesForSession (String sessionId) async{
    final countExp = sorties.flightId.count();

    final query = selectOnly(db.sorties)
          ..addColumns([countExp])
          ..where(sorties.sessionId.equals(sessionId));
        
    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<int> countSortiesForSessionVehicle(String sessionVehicleId) async {
    final countExp = sorties.flightId.count();

    final query = selectOnly(sorties)
      ..addColumns([countExp])
      ..where(sorties.sessionVehicleId.equals(sessionVehicleId));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

Future<void> addPayloadToSessionVehicle({
    required String id,
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    final sessionVehicle = await (select(sessionVehicles)
          ..where((v) => v.id.equals(sessionVehicleId)))
        .getSingleOrNull();

    if (sessionVehicle == null) {
      throw Exception('Session vehicle not found: $sessionVehicleId');
    }

    await transaction(() async {
      await into(sessionVehiclePayload).insert(
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
  }

Future<void> removePayloadFromSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) async {
    final sessionVehicle = await (select(sessionVehicles)
          ..where((v) => v.id.equals(sessionVehicleId)))
        .getSingleOrNull();

    if (sessionVehicle == null) {
      throw Exception('Session vehicle not found: $sessionVehicleId');
    }

    await transaction(() async {
      await (delete(sessionVehiclePayload)
            ..where(
              (v) =>
                  v.sessionVehicleId.equals(sessionVehicleId) &
                  v.payloadId.equals(payloadId),
            ))
          .go();

      await _touchSession(sessionVehicle.sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        action: 'REMOVE_PAYLOAD',
        description: 'Payload removed from session vehicle: $payloadId',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_VEHICLE',
        entityId: sessionVehicleId,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> replacePayloadsForSessionVehicle({
    required String sessionVehicleId,
    required List<String> payloadIds,
    required String performedBy,
  }) async {
    final sessionVehicle = await (select(sessionVehicles)
          ..where((v) => v.id.equals(sessionVehicleId)))
        .getSingleOrNull();

    if (sessionVehicle == null) {
      throw Exception('Session vehicle not found: $sessionVehicleId');
    }

    await transaction(() async {
      await (delete(sessionVehiclePayload)
            ..where((v) => v.sessionVehicleId.equals(sessionVehicleId)))
          .go();

      for (final payloadId in payloadIds.toSet()) {
        await into(sessionVehiclePayload).insert(
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
      OrderingTerm.asc(payloads.name)
    ]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(db.payloads)).toList();
  }

  Future<int> countPayloadsForSessionVehicle(String sessionVehicleId) async {
    final countExp = sessionVehiclePayload.id.count();

    final query = selectOnly(db.sessionVehiclePayload)
          ..addColumns([countExp])
          ..where(sessionVehiclePayload.sessionVehicleId.equals(sessionVehicleId));
    
    final rows = await query.getSingle();
    return rows.read(countExp) ?? 0;
  }

  Future<List<PayloadCompatibilityIssue>> getPayloadCompatibilityIssues (String sessionVehicleId) async {
    final sessionVehicle = await (select(sessionVehicles)
          ..where((v) => v.id.equals(sessionVehicleId)))
        .getSingleOrNull();

    if (sessionVehicle == null) {
      throw Exception('Session vehicle not found: $sessionVehicleId');
    }

    final vehicle = await (select(vehicles)
          ..where((v) => v.id.equals(sessionVehicle.vehicleId)))
        .getSingleOrNull();

    if (vehicle == null) {
      throw Exception('Vehicle not found: ${sessionVehicle.vehicleId}');
    }
    final selectedPayloads = await getPayloadsForSessionVehicle(sessionVehicleId);

    final issues = <PayloadCompatibilityIssue> [];

    for (final payload in selectedPayloads) {
      final compatibilityRows = await (select(db.payloadVehicleCompatibility)
                            ..where((v) => v.payloadId.equals(payload.payloadId)))
                            .get();
      if (compatibilityRows.isEmpty) continue;

      final isCompatible = compatibilityRows.any(
        (row) => row.vehicleType == vehicle.type,
      );

      if(!isCompatible){
        issues.add(
          PayloadCompatibilityIssue(
            vehicleId: vehicle.id, 
            sessionVehicleId: sessionVehicleId, 
            vehicleName: vehicle.name, 
            vehicleType: vehicle.type, 
            payloadId: payload.payloadId, 
            payloadName: payload.name, 
            message: 'Payload ${payload.name} is not marked compatible with ${vehicle.type}',
          ),
        );
      }
    }
    return issues;
  }

Future<void> addBatteryToSession({
    required String id,
    required String sessionId,
    required String batteryId,
    required String performedBy,
  }) async {
    await transaction(() async {
      await into(sessionBatteries).insert(
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
  }

  Future<void> removeBatteryFromSession({
    required String sessionId,
    required String batteryId,
    required String performedBy,
  }) async {
    await transaction(() async {
      await (delete(sessionBatteries)
            ..where(
              (v) =>
                  v.sessionId.equals(sessionId) &
                  v.batteryId.equals(batteryId),
            ))
          .go();

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'REMOVE_BATTERY',
        description: 'Battery removed from session: $batteryId',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> replaceSessionBatteries({
    required String sessionId,
    required List<String> batteryIds,
    required String performedBy,
  }) async {
    await transaction(() async {
      await (delete(sessionBatteries)
            ..where((v) => v.sessionId.equals(sessionId)))
          .go();

      for (final batteryId in batteryIds.toSet()) {
        await into(sessionBatteries).insert(
          SessionBatteriesCompanion.insert(
            id: _uuid.v4(),
            sessionId: sessionId,
            batteryId: batteryId,
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
    final query = select(sessionBatteries).join([
      innerJoin(
        batteries,
        batteries.batteryId.equalsExp(sessionBatteries.batteryId),
      ),
    ])
      ..where(sessionBatteries.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.asc(batteries.batteryId),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionBatteryWithBattery(
        sessionBattery: row.readTable(sessionBatteries),
        battery: row.readTable(batteries),
      );
    }).toList();
  }

  Future<List<EquipmentList>> getActiveEquipmentList() {
    return (select(equipmentLists)
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
    final activeEquipment = await getActiveEquipmentList();

    await transaction(() async {
      for (final item in activeEquipment) {
        await into(sessionEquipmentChecks).insert(
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
    required String sessionId,
    required String equipmentId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  }) async {
    await transaction(() async {
      await (update(sessionEquipmentChecks)
            ..where(
              (v) =>
                  v.sessionId.equals(sessionId) &
                  v.equipmentId.equals(equipmentId),
            ))
          .write(
        SessionEquipmentChecksCompanion(
          isPacked: Value(isPacked),
          notes: notes == null ? const Value.absent() : Value(notes),
          checkedAt: Value(DateTime.now()),
          checkedBy: Value(checkedBy),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        action: 'UPDATE_EQUIPMENT_CHECK',
        description: 'Equipment check updated: $equipmentId',
        performedBy: checkedBy,
      );

      await _enqueueSync(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        operation: 'UPDATE',
      );
    });
  }

  Future<List<SessionEquipmentCheckWithItem>> getSessionEquipmentChecks(
    String sessionId,
  ) async {
    final query = select(sessionEquipmentChecks).join([
      innerJoin(
        equipmentLists,
        equipmentLists.id.equalsExp(sessionEquipmentChecks.equipmentId),
      ),
    ])
      ..where(sessionEquipmentChecks.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.asc(equipmentLists.category),
        OrderingTerm.asc(equipmentLists.name),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return SessionEquipmentCheckWithItem(
        sessionEquipmentCheck: row.readTable(sessionEquipmentChecks),
        equipmentList: row.readTable(equipmentLists),
      );
    }).toList();
  }

  Future<void> addCustomEquipmentCheckToSession ({
    required String sessionCheckId,
    required String equipmentId,
    required String sessionId,
    required String checkedBy,
  }) async {
    await transaction(() async {
      await into(sessionEquipmentChecks).insert(
        SessionEquipmentChecksCompanion.insert(
          id: sessionCheckId,
          sessionId: sessionId,
          equipmentId: equipmentId,
          checkedBy: checkedBy,
        ),
      );

      await _touchSession(sessionId);

      await _insertAuditEvent(
        entityType: 'SESSION_EQUIPMENT_CHECK',
        entityId: sessionCheckId,
        action: 'CREATE',
        description: 'Custom equipment check added to session',
        performedBy: checkedBy,
      );

      await _enqueueSync(
        entityType: 'SESSION_EQUIPMENT_CHECK',
        entityId: sessionCheckId,
        operation: 'INSERT',
      );
    });
  }

  Future<int> countUnpackedEquipmentChecks(String sessionId) async {
    final countExp = sessionEquipmentChecks.id.count();

    final query = selectOnly(sessionEquipmentChecks)
      ..addColumns([countExp])
      ..where(
        sessionEquipmentChecks.sessionId.equals(sessionId) &
            sessionEquipmentChecks.isPacked.equals(false),
      );

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<void> createEquipmentItem({
    required String id,
    required String name,
    required String category,
    required String performedBy,
  }) async {
    await transaction(() async {
      await into(equipmentLists).insert(
        EquipmentListsCompanion.insert(
          id: id,
          name: name,
          category: category,
        ),
      );

      await _insertAuditEvent(
        entityType: 'EQUIPMENT_ITEM',
        entityId: id,
        action: 'CREATE',
        description: 'Equipment item created',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'EQUIPMENT_ITEM',
        entityId: id,
        operation: 'INSERT',
      );
    });
  }

  Future<void> updateEquipmentItem({
    required String id,
    String? name,
    String? category,
    bool? isActive,
    required String performedBy,
  }) async {
    await transaction(() async {
      await (update(equipmentLists)..where((v) => v.id.equals(id))).write(
        EquipmentListsCompanion(
          name: name == null ? const Value.absent() : Value(name),
          category: category == null ? const Value.absent() : Value(category),
          isActive: isActive == null ? const Value.absent() : Value(isActive),
        ),
      );

      await _insertAuditEvent(
        entityType: 'EQUIPMENT_ITEM',
        entityId: id,
        action: 'UPDATE',
        description: 'Equipment item updated',
        performedBy: performedBy,
      );

      await _enqueueSync(
        entityType: 'EQUIPMENT_ITEM',
        entityId: id,
        operation: 'UPDATE',
      );
    });
  }

  Future<void> deactivateEquipmentItem({
    required String id,
    required String performedBy,
  }) async {
    await updateEquipmentItem(
      id: id,
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

    final issue = <PayloadCompatibilityIssue>[];

    for (final item in sessionVehicleList){
      final vehicleIssues = await getPayloadCompatibilityIssues(item.sessionVehicle.id);
      issue.addAll(vehicleIssues);
    }

    return PreFieldSummaryData(
      session: session, 
      teamMembers: teamMembers, 
      vehicles: sessionVehicleList, 
      batteries: batteriesList, 
      equipmentChecks: equipmentChecks, 
      payloadCompatibilityIssues: issue);
  }

  Future<void> _insertAuditEvent({
    required String entityType,
    required String entityId,
    required String action,
    String? description,
    required String performedBy,
  }) {
    return into(auditEvents).insert(
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
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        syncStatus: const Value('PENDING'),
      ),
    );
  }

  Future<void> _touchSession(String sessionId) {
    return (update(fieldSessions)
          ..where((v) => v.sessionId.equals(sessionId)))
        .write(
      FieldSessionsCompanion(
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
