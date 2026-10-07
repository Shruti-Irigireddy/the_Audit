import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/pre_flight_dtos.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';
import 'package:the_audit/core/utils/app_logger.dart';

part 'pre_flight_dao.g.dart';

final _uuid = Uuid();

@DriftAccessor(
  tables: [
    Users,
    Vehicles,
    Payloads,
    Batteries,
    FieldSessions,
    SessionVehicles,
    SessionVehiclePayload,
    SessionBatteries,
    PayloadVehicleCompatibility,
    Sorties,
    SortieUsers,
    SortiePayloads,
    SortieBatteries,
    VehicleChecklistTemplates,
    ChecklistItems,
    ChecklistResponses,
    ChecklistOverrides,
    AuditEvents,
    SyncQueue,
  ],
)
class PreFlightDao extends DatabaseAccessor<AppDatabase>
    with _$PreFlightDaoMixin {
  PreFlightDao(super.db);

  static const _log = AppLogger('PreFlightDao');

  // ---------------------------------------------------------------------------
  // SORTIE CREATION / READ
  // ---------------------------------------------------------------------------

  Future<String> createSortie({
    String? flightId,
    required String sessionId,
    required String sessionVehicleId,
    required String picUserId,
    String? objective,
    required String performedBy,
    List<String> selectedPayloadIds = const [],
  }) async {
    _log.t(
      'createSortie(flightId: $flightId, sessionId: $sessionId, sessionVehicleId: $sessionVehicleId, picUserId: $picUserId, selectedPayloads: ${selectedPayloadIds.length})',
    );
    return _log.trace('createSortie', () async {
      final id = flightId ?? _uuid.v4();

      final session = await (select(
        db.fieldSessions,
      )..where((v) => v.sessionId.equals(sessionId))).getSingleOrNull();

      if (session == null) {
        _log.w('Field session not found: $sessionId');
        throw AppFailure('Field session not found: $sessionId');
      }

      if (session.sessionStatus == 'CLOSED') {
        _log.w(
          'Field session is closed. Cannot create a sortie in a closed session.',
        );
        throw AppFailure(
          'Field session is closed. Cannot create a sortie in a closed session.',
        );
      }

      final sessionVehicle = await (select(
        db.sessionVehicles,
      )..where((v) => v.id.equals(sessionVehicleId))).getSingleOrNull();

      if (sessionVehicle == null) {
        _log.w('Session vehicle not found: $sessionVehicleId');
        throw AppFailure('Session vehicle not found: $sessionVehicleId');
      }

      if (sessionVehicle.sessionId != sessionId) {
        _log.w('Vehicle was not brought to the selected field session.');
        throw AppFailure(
          'Vehicle was not brought to the selected field session.',
        );
      }

      final activeTemplate = await _getActiveTemplateForVehicle(
        sessionVehicle.vehicleId,
      );

      final nextSequenceNo = await _getNextSequenceNo(sessionId);

      final uniquePayloadIds = selectedPayloadIds.toSet();

      for (final payloadId in uniquePayloadIds) {
        final isAllowed = await _isPayloadSelectableForSessionVehicle(
          sessionVehicleId: sessionVehicleId,
          payloadId: payloadId,
        );

        if (!isAllowed) {
          _log.w(
            'Payload $payloadId is not planned for this vehicle or is not compatible.',
          );
          throw AppFailure(
            'Payload $payloadId is not planned for this vehicle or is not compatible.',
          );
        }
      }

      await transaction(() async {
        await into(db.sorties).insert(
          SortiesCompanion.insert(
            flightId: id,
            sessionId: sessionId,
            sequenceNo: nextSequenceNo,
            sessionVehicleId: sessionVehicleId,
            picUserId: picUserId,
            objective: Value(objective ?? sessionVehicle.objective),
            checklistTemplateId: activeTemplate.id,
            checklistTemplateVersion: activeTemplate.version,
            flightStatus: const Value('PREFLIGHT'),
          ),
        );

        for (final payloadId in uniquePayloadIds) {
          await into(db.sortiePayloads).insert(
            SortiePayloadsCompanion.insert(
              id: _uuid.v4(),
              flightId: id,
              payloadId: payloadId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }

        await _touchSession(sessionId);

        // The first pre-flight starts the field work: PLANNED -> IN_PROGRESS.
        if (session.sessionStatus == 'PLANNED') {
          await (update(
            db.fieldSessions,
          )..where((v) => v.sessionId.equals(sessionId))).write(
            const FieldSessionsCompanion(sessionStatus: Value('IN_PROGRESS')),
          );
          await _insertAuditEvent(
            entityType: 'FIELD_SESSION',
            entityId: sessionId,
            action: 'UPDATE',
            description: 'Session started (PLANNED -> IN_PROGRESS)',
            performedBy: performedBy,
          );
          await _enqueueSync(
            entityType: 'FIELD_SESSION',
            entityId: sessionId,
            operation: 'UPDATE',
          );
          _log.i('session $sessionId started: PLANNED -> IN_PROGRESS');
        }

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: id,
          action: 'CREATE',
          description:
              'Sortie created with checklist template v${activeTemplate.version}',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: id,
          operation: 'INSERT',
        );
      });

      return id;
    });
  }

  Future<Sorty?> getSortieById(String flightId) {
    _log.t('getSortieById(flightId: $flightId)');
    return (select(
      db.sorties,
    )..where((v) => v.flightId.equals(flightId))).getSingleOrNull();
  }

  Future<List<Sorty>> getSortiesForSession(String sessionId) {
    _log.t('getSortiesForSession(sessionId: $sessionId)');
    return (select(db.sorties)
          ..where((v) => v.sessionId.equals(sessionId))
          ..orderBy([(v) => OrderingTerm.asc(v.sequenceNo)]))
        .get();
  }

  Future<void> updateSortieBasicInfo({
    required String flightId,
    String? picUserId,
    String? objective,
    required String performedBy,
  }) async {
    _log.t('updateSortieBasicInfo(flightId: $flightId, picUserId: $picUserId)');
    return _log.trace('updateSortieBasicInfo', () async {
      await _ensureSortieEditable(flightId);

      await transaction(() async {
        await (update(
          db.sorties,
        )..where((v) => v.flightId.equals(flightId))).write(
          SortiesCompanion(
            picUserId: picUserId == null
                ? const Value.absent()
                : Value(picUserId),
            objective: objective == null
                ? const Value.absent()
                : Value(objective),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'UPDATE_BASIC_INFO',
          description: 'Sortie basic info updated',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<PreFlightSetupData> getPreflightSetup(String flightId) async {
    _log.t('getPreflightSetup(flightId: $flightId)');
    final sortie = await _requireSortie(flightId);

    final sessionVehicle = await (select(
      db.sessionVehicles,
    )..where((v) => v.id.equals(sortie.sessionVehicleId))).getSingleOrNull();

    if (sessionVehicle == null) {
      _log.w('Session vehicle not found: ${sortie.sessionVehicleId}');
      throw AppFailure('Session vehicle not found: ${sortie.sessionVehicleId}');
    }

    final vehicle = await (select(
      db.vehicles,
    )..where((v) => v.id.equals(sessionVehicle.vehicleId))).getSingleOrNull();

    if (vehicle == null) {
      _log.w('Vehicle not found: ${sessionVehicle.vehicleId}');
      throw AppFailure('Vehicle not found: ${sessionVehicle.vehicleId}');
    }

    final checklistItems = await loadChecklistForSortie(flightId);
    final payloads = await getSortiePayloads(flightId);
    final batteries = await getSortieBatteries(flightId);
    final crew = await getSortieUsers(flightId);
    final responses = await getChecklistResponsesForFlight(flightId);
    final overrides = await getOverridesForFlight(flightId);

    return PreFlightSetupData(
      sortie: sortie,
      sessionVehicle: sessionVehicle,
      vehicle: vehicle,
      checklistItems: checklistItems,
      payloads: payloads,
      batteries: batteries,
      crew: crew,
      responses: responses,
      overrides: overrides,
    );
  }

  // ---------------------------------------------------------------------------
  // SORTIE USERS
  // ---------------------------------------------------------------------------

  Future<void> addUserToSortie({
    required String id,
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    _log.t(
      'addUserToSortie(id: $id, flightId: $flightId, userId: $userId, role: $role)',
    );
    return _log.trace('addUserToSortie', () async {
      await _ensureSortieEditable(flightId);

      await transaction(() async {
        await into(db.sortieUsers).insert(
          SortieUsersCompanion.insert(
            id: id,
            flightId: flightId,
            userId: userId,
            role: role,
          ),
          mode: InsertMode.insertOrIgnore,
        );

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE_USER',
          entityId: id,
          action: 'CREATE',
          description: 'User added to sortie as $role',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE_USER',
          entityId: id,
          operation: 'INSERT',
        );
      });
    });
  }

  Future<void> removeUserFromSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) async {
    _log.t(
      'removeUserFromSortie(flightId: $flightId, userId: $userId, role: $role)',
    );
    return _log.trace('removeUserFromSortie', () async {
      await _ensureSortieEditable(flightId);

      await transaction(() async {
        await (delete(db.sortieUsers)..where(
              (v) =>
                  v.flightId.equals(flightId) &
                  v.userId.equals(userId) &
                  v.role.equals(role),
            ))
            .go();

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'REMOVE_SORTIE_USER',
          description: 'User removed from sortie: $userId as $role',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> replaceSortieUsers({
    required String flightId,
    required List<SortieUserDraft> users,
    required String performedBy,
  }) async {
    _log.t('replaceSortieUsers(flightId: $flightId, users: ${users.length})');
    return _log.trace('replaceSortieUsers', () async {
      await _ensureSortieEditable(flightId);

      await transaction(() async {
        await (delete(
          db.sortieUsers,
        )..where((v) => v.flightId.equals(flightId))).go();

        for (final user in users) {
          await into(db.sortieUsers).insert(
            SortieUsersCompanion.insert(
              id: user.id,
              flightId: flightId,
              userId: user.userId,
              role: user.role,
            ),
          );
        }

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'REPLACE_SORTIE_USERS',
          description: 'Sortie users replaced',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<List<SortieUserWithUser>> getSortieUsers(String flightId) async {
    _log.t('getSortieUsers(flightId: $flightId)');
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

  // ---------------------------------------------------------------------------
  // SORTIE PAYLOADS
  // ---------------------------------------------------------------------------

  Future<List<Payload>> getSelectablePayloadsForSortie(String flightId) async {
    _log.t('getSelectablePayloadsForSortie(flightId: $flightId)');
    final sortie = await _requireSortie(flightId);

    final sessionVehicle = await (select(
      db.sessionVehicles,
    )..where((v) => v.id.equals(sortie.sessionVehicleId))).getSingleOrNull();

    if (sessionVehicle == null) {
      _log.w('Session vehicle not found: ${sortie.sessionVehicleId}');
      throw AppFailure('Session vehicle not found: ${sortie.sessionVehicleId}');
    }

    final vehicle = await (select(
      db.vehicles,
    )..where((v) => v.id.equals(sessionVehicle.vehicleId))).getSingleOrNull();

    if (vehicle == null) {
      _log.w('Vehicle not found: ${sessionVehicle.vehicleId}');
      throw AppFailure('Vehicle not found: ${sessionVehicle.vehicleId}');
    }

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
            db.sessionVehiclePayload.sessionVehicleId.equals(
              sortie.sessionVehicleId,
            ),
          )
          ..orderBy([OrderingTerm.asc(db.payloads.name)]);

    final rows = await query.get();

    final plannedPayloads = rows.map((row) {
      return row.readTable(db.payloads);
    }).toList();

    final selectable = <Payload>[];

    for (final payload in plannedPayloads) {
      final compatibilityRows = await (select(
        db.payloadVehicleCompatibility,
      )..where((v) => v.payloadId.equals(payload.payloadId))).get();

      if (compatibilityRows.isEmpty ||
          compatibilityRows.any((row) => row.vehicleType == vehicle.type)) {
        selectable.add(payload);
      }
    }

    return selectable;
  }

  Future<void> addPayloadToSortie({
    required String id,
    required String flightId,
    required String payloadId,
    required String performedBy,
  }) async {
    _log.t(
      'addPayloadToSortie(id: $id, flightId: $flightId, payloadId: $payloadId)',
    );
    return _log.trace('addPayloadToSortie', () async {
      await _ensureSortieEditable(flightId);

      final sortie = await _requireSortie(flightId);

      final isAllowed = await _isPayloadSelectableForSessionVehicle(
        sessionVehicleId: sortie.sessionVehicleId,
        payloadId: payloadId,
      );

      if (!isAllowed) {
        _log.w(
          'Payload $payloadId is not planned for this vehicle or is not compatible.',
        );
        throw AppFailure(
          'Payload $payloadId is not planned for this vehicle or is not compatible.',
        );
      }

      await transaction(() async {
        await into(db.sortiePayloads).insert(
          SortiePayloadsCompanion.insert(
            id: id,
            flightId: flightId,
            payloadId: payloadId,
          ),
          mode: InsertMode.insertOrIgnore,
        );

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE_PAYLOAD',
          entityId: id,
          action: 'CREATE',
          description: 'Payload added to sortie',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE_PAYLOAD',
          entityId: id,
          operation: 'INSERT',
        );
      });
    });
  }

  Future<void> removePayloadFromSortie({
    required String flightId,
    required String payloadId,
    required String performedBy,
  }) async {
    _log.t(
      'removePayloadFromSortie(flightId: $flightId, payloadId: $payloadId)',
    );
    return _log.trace('removePayloadFromSortie', () async {
      await _ensureSortieEditable(flightId);

      await transaction(() async {
        await (delete(db.sortiePayloads)..where(
              (v) =>
                  v.flightId.equals(flightId) & v.payloadId.equals(payloadId),
            ))
            .go();

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'REMOVE_PAYLOAD',
          description: 'Payload removed from sortie: $payloadId',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> replaceSortiePayloads({
    required String flightId,
    required List<String> payloadIds,
    required String performedBy,
  }) async {
    _log.t(
      'replaceSortiePayloads(flightId: $flightId, payloads: ${payloadIds.length})',
    );
    return _log.trace('replaceSortiePayloads', () async {
      await _ensureSortieEditable(flightId);

      final sortie = await _requireSortie(flightId);
      final uniquePayloadIds = payloadIds.toSet();

      for (final payloadId in uniquePayloadIds) {
        final isAllowed = await _isPayloadSelectableForSessionVehicle(
          sessionVehicleId: sortie.sessionVehicleId,
          payloadId: payloadId,
        );

        if (!isAllowed) {
          _log.w(
            'Payload $payloadId is not planned for this vehicle or is not compatible.',
          );
          throw AppFailure(
            'Payload $payloadId is not planned for this vehicle or is not compatible.',
          );
        }
      }

      await transaction(() async {
        await (delete(
          db.sortiePayloads,
        )..where((v) => v.flightId.equals(flightId))).go();

        for (final payloadId in uniquePayloadIds) {
          await into(db.sortiePayloads).insert(
            SortiePayloadsCompanion.insert(
              id: _uuid.v4(),
              flightId: flightId,
              payloadId: payloadId,
            ),
          );
        }

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'REPLACE_PAYLOADS',
          description: 'Sortie payloads replaced',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<List<SortiePayloadWithPayload>> getSortiePayloads(
    String flightId,
  ) async {
    _log.t('getSortiePayloads(flightId: $flightId)');
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

  // ---------------------------------------------------------------------------
  // SORTIE BATTERIES
  // ---------------------------------------------------------------------------

  Future<List<Battery>> getSelectableBatteriesForSortie(String flightId) async {
    _log.t('getSelectableBatteriesForSortie(flightId: $flightId)');
    final sortie = await _requireSortie(flightId);

    final query =
        select(db.sessionBatteries).join([
            innerJoin(
              db.batteries,
              db.batteries.batteryId.equalsExp(db.sessionBatteries.batteryId),
            ),
          ])
          ..where(db.sessionBatteries.sessionId.equals(sortie.sessionId))
          ..where(db.batteries.status.equals('ACTIVE'))
          ..orderBy([OrderingTerm.asc(db.batteries.batteryId)]);

    final rows = await query.get();

    return rows.map((row) => row.readTable(db.batteries)).toList();
  }

  Future<void> addBatteryToSortie({
    required String id,
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  }) async {
    _log.t(
      'addBatteryToSortie(id: $id, flightId: $flightId, batteryId: $batteryId)',
    );
    return _log.trace('addBatteryToSortie', () async {
      await _ensureSortieEditable(flightId);

      await _ensureBatterySelectableForSortie(
        flightId: flightId,
        batteryId: batteryId,
      );

      final defaults = await getLatestBatteryEndStateAsStartDefault(
        batteryId: batteryId,
        excludeFlightId: flightId,
      );

      final resolvedVoltageStart = voltageStart ?? defaults?.voltageStart;
      final resolvedPercentStart = percentStart ?? defaults?.percentStart;

      await transaction(() async {
        await into(db.sortieBatteries).insert(
          SortieBatteriesCompanion.insert(
            id: id,
            flightId: flightId,
            batteryId: batteryId,
            voltageStart: Value(resolvedVoltageStart),
            percentStart: Value(resolvedPercentStart),
          ),
          mode: InsertMode.insertOrIgnore,
        );

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE_BATTERY',
          entityId: id,
          action: 'CREATE',
          description: defaults == null
              ? 'Battery added to sortie'
              : 'Battery added to sortie with start state defaulted from previous flight ${defaults.sourceFlightId}',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE_BATTERY',
          entityId: id,
          operation: 'INSERT',
        );
      });
    });
  }

  Future<void> replaceSortieBatteries({
    required String flightId,
    required List<SortieBatteryDraft> batteries,
    required String performedBy,
  }) async {
    _log.t(
      'replaceSortieBatteries(flightId: $flightId, batteries: ${batteries.length})',
    );
    return _log.trace('replaceSortieBatteries', () async {
      await _ensureSortieEditable(flightId);

      final seenBatteryIds = <String>{};

      for (final battery in batteries) {
        if (seenBatteryIds.contains(battery.batteryId)) {
          continue;
        }

        seenBatteryIds.add(battery.batteryId);

        await _ensureBatterySelectableForSortie(
          flightId: flightId,
          batteryId: battery.batteryId,
        );
      }

      await transaction(() async {
        await (delete(
          db.sortieBatteries,
        )..where((v) => v.flightId.equals(flightId))).go();

        final insertedBatteryIds = <String>{};

        for (final battery in batteries) {
          if (insertedBatteryIds.contains(battery.batteryId)) {
            continue;
          }

          insertedBatteryIds.add(battery.batteryId);

          final defaults = await getLatestBatteryEndStateAsStartDefault(
            batteryId: battery.batteryId,
            excludeFlightId: flightId,
          );

          final resolvedVoltageStart =
              battery.voltageStart ?? defaults?.voltageStart;
          final resolvedPercentStart =
              battery.percentStart ?? defaults?.percentStart;

          await into(db.sortieBatteries).insert(
            SortieBatteriesCompanion.insert(
              id: battery.id,
              flightId: flightId,
              batteryId: battery.batteryId,
              voltageStart: Value(resolvedVoltageStart),
              percentStart: Value(resolvedPercentStart),
            ),
          );
        }

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'REPLACE_BATTERIES',
          description: 'Sortie batteries replaced',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> updateSortieBatteryStartState({
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  }) async {
    _log.t(
      'updateSortieBatteryStartState(flightId: $flightId, batteryId: $batteryId)',
    );
    return _log.trace('updateSortieBatteryStartState', () async {
      await _ensureSortieEditable(flightId);

      await _ensureBatterySelectableForSortie(
        flightId: flightId,
        batteryId: batteryId,
      );

      final existing =
          await (select(db.sortieBatteries)..where(
                (v) =>
                    v.flightId.equals(flightId) & v.batteryId.equals(batteryId),
              ))
              .getSingleOrNull();

      if (existing == null) {
        _log.w('Battery $batteryId is not selected for this sortie.');
        throw AppFailure('Battery $batteryId is not selected for this sortie.');
      }

      await transaction(() async {
        await (update(db.sortieBatteries)..where(
              (v) =>
                  v.flightId.equals(flightId) & v.batteryId.equals(batteryId),
            ))
            .write(
              SortieBatteriesCompanion(
                voltageStart: Value(voltageStart),
                percentStart: Value(percentStart),
                updatedAt: Value(DateTime.now()),
              ),
            );

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE_BATTERY',
          entityId: '$flightId:$batteryId',
          action: 'UPDATE_START_STATE',
          description: 'Battery start state updated',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE_BATTERY',
          entityId: '$flightId:$batteryId',
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> removeBatteryFromSortie({
    required String flightId,
    required String batteryId,
    required String performedBy,
  }) async {
    _log.t(
      'removeBatteryFromSortie(flightId: $flightId, batteryId: $batteryId)',
    );
    return _log.trace('removeBatteryFromSortie', () async {
      await _ensureSortieEditable(flightId);

      await transaction(() async {
        await (delete(db.sortieBatteries)..where(
              (v) =>
                  v.flightId.equals(flightId) & v.batteryId.equals(batteryId),
            ))
            .go();

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'REMOVE_BATTERY',
          description: 'Battery removed from sortie: $batteryId',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<List<SortieBatteryWithBattery>> getSortieBatteries(
    String flightId,
  ) async {
    _log.t('getSortieBatteries(flightId: $flightId)');
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

  Future<BatteryStartDefaults?> getLatestBatteryEndStateAsStartDefault({
    required String batteryId,
    String? excludeFlightId,
  }) async {
    _log.t(
      'getLatestBatteryEndStateAsStartDefault(batteryId: $batteryId, excludeFlightId: $excludeFlightId)',
    );
    final query =
        select(db.sortieBatteries).join([
            innerJoin(
              db.sorties,
              db.sorties.flightId.equalsExp(db.sortieBatteries.flightId),
            ),
          ])
          ..where(db.sortieBatteries.batteryId.equals(batteryId))
          ..where(
            db.sortieBatteries.voltageEnd.isNotNull() |
                db.sortieBatteries.percentEnd.isNotNull(),
          )
          ..orderBy([
            OrderingTerm.desc(db.sorties.landingAt),
            OrderingTerm.desc(db.sortieBatteries.updatedAt),
            OrderingTerm.desc(db.sortieBatteries.createdAt),
          ])
          ..limit(1);

    if (excludeFlightId != null) {
      query.where(db.sortieBatteries.flightId.equals(excludeFlightId).not());
    }

    final rows = await query.get();

    if (rows.isEmpty) {
      return null;
    }

    final sortieBattery = rows.first.readTable(db.sortieBatteries);

    return BatteryStartDefaults(
      voltageStart: sortieBattery.voltageEnd,
      percentStart: sortieBattery.percentEnd,
      sourceFlightId: sortieBattery.flightId,
    );
  }

  // ---------------------------------------------------------------------------
  // CHECKLIST LOADING / RESPONSES
  // ---------------------------------------------------------------------------

  Future<List<ChecklistItem>> loadChecklistForSortie(String flightId) async {
    _log.t('loadChecklistForSortie(flightId: $flightId)');
    final sortie = await _requireSortie(flightId);

    return (select(db.checklistItems)
          ..where((v) => v.templateId.equals(sortie.checklistTemplateId))
          ..where((v) => v.isActive.equals(true))
          ..orderBy([(v) => OrderingTerm.asc(v.sortOrder)]))
        .get();
  }

  Future<List<ChecklistItem>> loadBlockingChecklistItemsForSortie(
    String flightId,
  ) async {
    _log.t('loadBlockingChecklistItemsForSortie(flightId: $flightId)');
    final sortie = await _requireSortie(flightId);

    return (select(db.checklistItems)
          ..where((v) => v.templateId.equals(sortie.checklistTemplateId))
          ..where((v) => v.isActive.equals(true))
          ..where((v) => v.blocksArming.equals(true))
          ..orderBy([(v) => OrderingTerm.asc(v.sortOrder)]))
        .get();
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
    _log.t(
      'saveChecklistResponse(flightId: $flightId, itemId: $itemId, response: $response)',
    );
    return _log.trace('saveChecklistResponse', () async {
      await _ensureSortieEditable(flightId);

      final sortie = await _requireSortie(flightId);

      final item = await (select(
        db.checklistItems,
      )..where((v) => v.id.equals(itemId))).getSingleOrNull();

      if (item == null) {
        _log.w('Checklist item not found: $itemId');
        throw AppFailure('Checklist item not found: $itemId');
      }

      if (item.templateId != sortie.checklistTemplateId) {
        _log.w('Checklist item does not belong to sortie template.');
        throw AppFailure('Checklist item does not belong to sortie template.');
      }

      await transaction(() async {
        final existingResponse =
            await (select(db.checklistResponses)..where(
                  (v) => v.flightId.equals(flightId) & v.itemId.equals(itemId),
                ))
                .getSingleOrNull();

        if (existingResponse == null) {
          await into(db.checklistResponses).insert(
            ChecklistResponsesCompanion.insert(
              id: _uuid.v4(),
              flightId: flightId,
              itemId: itemId,
              response: response,
              valueText: Value(valueText),
              valueNumber: Value(valueNumber),
              notes: Value(notes),
              createdBy: createdBy,
              responseAt: Value(DateTime.now()),
            ),
          );
        } else {
          await (update(
            db.checklistResponses,
          )..where((v) => v.id.equals(existingResponse.id))).write(
            ChecklistResponsesCompanion(
              response: Value(response),
              valueText: Value(valueText),
              valueNumber: Value(valueNumber),
              notes: Value(notes),
              responseAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'CHECKLIST_RESPONSE',
          entityId: '$flightId:$itemId',
          action: existingResponse == null ? 'CREATE' : 'UPDATE',
          description: 'Checklist response saved',
          performedBy: createdBy,
        );

        await _enqueueSync(
          entityType: 'CHECKLIST_RESPONSE',
          entityId: '$flightId:$itemId',
          operation: existingResponse == null ? 'INSERT' : 'UPDATE',
        );
      });
    });
  }

  Future<void> saveChecklistResponses({
    required String flightId,
    required List<ChecklistResponseDraft> responses,
    required String createdBy,
  }) async {
    _log.t(
      'saveChecklistResponses(flightId: $flightId, responses: ${responses.length})',
    );
    return _log.trace('saveChecklistResponses', () async {
      await _ensureSortieEditable(flightId);

      final sortie = await _requireSortie(flightId);
      final now = DateTime.now();

      await transaction(() async {
        for (final response in responses) {
          final item = await (select(
            db.checklistItems,
          )..where((v) => v.id.equals(response.itemId))).getSingleOrNull();

          if (item == null) {
            _log.w('Checklist item not found: ${response.itemId}');
            throw AppFailure('Checklist item not found: ${response.itemId}');
          }

          if (item.templateId != sortie.checklistTemplateId) {
            _log.w('Checklist item does not belong to sortie template.');
            throw AppFailure(
              'Checklist item does not belong to sortie template.',
            );
          }

          final existingResponse =
              await (select(db.checklistResponses)..where(
                    (v) =>
                        v.flightId.equals(flightId) &
                        v.itemId.equals(response.itemId),
                  ))
                  .getSingleOrNull();

          if (existingResponse == null) {
            await into(db.checklistResponses).insert(
              ChecklistResponsesCompanion.insert(
                id: _uuid.v4(),
                flightId: flightId,
                itemId: response.itemId,
                response: response.response,
                valueText: Value(response.valueText),
                valueNumber: Value(response.valueNumber),
                notes: Value(response.notes),
                createdBy: createdBy,
                responseAt: Value(now),
              ),
            );
          } else {
            await (update(
              db.checklistResponses,
            )..where((v) => v.id.equals(existingResponse.id))).write(
              ChecklistResponsesCompanion(
                response: Value(response.response),
                valueText: Value(response.valueText),
                valueNumber: Value(response.valueNumber),
                notes: Value(response.notes),
                responseAt: Value(now),
                updatedAt: Value(now),
              ),
            );
          }

          await _insertAuditEvent(
            entityType: 'CHECKLIST_RESPONSE',
            entityId: '$flightId:${response.itemId}',
            action: existingResponse == null ? 'CREATE' : 'UPDATE',
            description: 'Checklist response saved',
            performedBy: createdBy,
          );

          await _enqueueSync(
            entityType: 'CHECKLIST_RESPONSE',
            entityId: '$flightId:${response.itemId}',
            operation: existingResponse == null ? 'INSERT' : 'UPDATE',
          );
        }

        await _touchSortie(flightId);
      });
    });
  }

  Future<List<ChecklistResponseWithItem>> getChecklistResponsesForFlight(
    String flightId,
  ) async {
    _log.t('getChecklistResponsesForFlight(flightId: $flightId)');
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

  // ---------------------------------------------------------------------------
  // READY TO ARM / PREFLIGHT COMPLETION
  // ---------------------------------------------------------------------------

  Future<ReadyToArmValidationResult> validateReadyToArm(String flightId) async {
    _log.t('validateReadyToArm(flightId: $flightId)');
    final blockingItems = await loadBlockingChecklistItemsForSortie(flightId);

    final responses = await (select(
      db.checklistResponses,
    )..where((v) => v.flightId.equals(flightId))).get();

    final overrides = await getOverridesForFlight(flightId);

    final responseByItemId = {
      for (final response in responses) response.itemId: response,
    };

    final overrideByItemId = {
      for (final override in overrides) override.itemId: override,
    };

    final missingItems = <BlockingChecklistIssue>[];
    final failedItems = <BlockingChecklistIssue>[];

    for (final item in blockingItems) {
      final response = responseByItemId[item.id];
      final override = overrideByItemId[item.id];

      if (response == null) {
        if (override == null) {
          missingItems.add(
            BlockingChecklistIssue(
              item: item,
              response: null,
              hasOverride: false,
              reason: 'Required blocking item has no response',
            ),
          );
        }
        continue;
      }

      final satisfied = _isBlockingResponseSatisfied(
        item: item,
        response: response,
      );

      if (!satisfied && override == null) {
        failedItems.add(
          BlockingChecklistIssue(
            item: item,
            response: response,
            hasOverride: false,
            reason: 'Blocking item is not passed',
          ),
        );
      }
    }

    return ReadyToArmValidationResult(
      canProceed: missingItems.isEmpty && failedItems.isEmpty,
      missingItems: missingItems,
      failedItems: failedItems,
      overrides: overrides,
    );
  }

  Future<List<String>> validatePreflightCompletion(String flightId) async {
    _log.t('validatePreflightCompletion(flightId: $flightId)');
    final issues = <String>[];

    final sortie = await _requireSortie(flightId);

    if (sortie.picUserId.trim().isEmpty) {
      issues.add('PIC is required.');
    }

    // No battery selection (the Power item covers the battery), and only
    // blocking [A] items decide arming and Go: other items are optional and
    // may be left blank.
    final readyToArm = await validateReadyToArm(flightId);

    if (!readyToArm.canProceed) {
      issues.add('Ready-to-Arm validation failed.');
    }

    return issues;
  }

  bool _isBlockingResponseSatisfied({
    required ChecklistItem item,
    required ChecklistResponse response,
  }) {
    final normalizedResponse = response.response.trim().toUpperCase();
    final normalizedType = item.responseType.trim().toUpperCase();

    if (normalizedResponse == 'FAIL' || normalizedResponse == 'NO_GO') {
      return false;
    }

    if (normalizedResponse == 'PASS' || normalizedResponse == 'GO') {
      return true;
    }

    if (normalizedType == 'NUMBER') {
      return response.valueNumber != null;
    }

    if (normalizedType == 'VALUE') {
      final hasTextValue =
          response.valueText != null && response.valueText!.trim().isNotEmpty;
      final hasNumberValue = response.valueNumber != null;

      return hasTextValue || hasNumberValue;
    }

    if (normalizedType == 'TEXT') {
      return response.valueText != null &&
          response.valueText!.trim().isNotEmpty;
    }

    if (normalizedResponse == 'CHECKED' || normalizedResponse == 'YES') {
      return true;
    }

    if (normalizedResponse == 'NA' || normalizedResponse == 'N/A') {
      return false;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // OVERRIDES
  // ---------------------------------------------------------------------------

  Future<void> createChecklistOverride({
    required String id,
    required String flightId,
    required String itemId,
    required String overrideReason,
    required String overriddenBy,
  }) async {
    _log.t(
      'createChecklistOverride(id: $id, flightId: $flightId, itemId: $itemId)',
    );
    return _log.trace('createChecklistOverride', () async {
      await _ensureSortieEditable(flightId);

      final sortie = await _requireSortie(flightId);

      final item = await (select(
        db.checklistItems,
      )..where((v) => v.id.equals(itemId))).getSingleOrNull();

      if (item == null) {
        _log.w('Checklist item not found: $itemId');
        throw AppFailure('Checklist item not found: $itemId');
      }

      if (item.templateId != sortie.checklistTemplateId) {
        _log.w('Checklist item does not belong to sortie template.');
        throw AppFailure('Checklist item does not belong to sortie template.');
      }

      if (!item.blocksArming) {
        _log.w('Only blocking checklist items can be overridden.');
        throw AppFailure('Only blocking checklist items can be overridden.');
      }

      final response =
          await (select(db.checklistResponses)..where(
                (v) => v.flightId.equals(flightId) & v.itemId.equals(itemId),
              ))
              .getSingleOrNull();

      if (response == null) {
        _log.w('Cannot override an item without a checklist response.');
        throw AppFailure(
          'Cannot override an item without a checklist response.',
        );
      }

      if (_isBlockingResponseSatisfied(item: item, response: response)) {
        _log.w('Cannot override a checklist item that is already satisfied.');
        throw AppFailure(
          'Cannot override a checklist item that is already satisfied.',
        );
      }

      final existingOverride =
          await (select(db.checklistOverrides)..where(
                (v) => v.flightId.equals(flightId) & v.itemId.equals(itemId),
              ))
              .getSingleOrNull();

      if (existingOverride != null) {
        _log.w('This checklist item already has an override.');
        throw AppFailure('This checklist item already has an override.');
      }

      await transaction(() async {
        await into(db.checklistOverrides).insert(
          ChecklistOverridesCompanion.insert(
            id: id,
            flightId: flightId,
            itemId: itemId,
            overrideReason: overrideReason,
            overriddenBy: overriddenBy,
          ),
        );

        await _touchSortie(flightId);

        await _insertAuditEvent(
          entityType: 'CHECKLIST_OVERRIDE',
          entityId: id,
          action: 'CREATE',
          description: overrideReason,
          performedBy: overriddenBy,
        );

        await _enqueueSync(
          entityType: 'CHECKLIST_OVERRIDE',
          entityId: id,
          operation: 'INSERT',
        );
      });
    });
  }

  Future<List<ChecklistOverride>> getOverridesForFlight(String flightId) {
    _log.t('getOverridesForFlight(flightId: $flightId)');
    return (select(db.checklistOverrides)
          ..where((v) => v.flightId.equals(flightId))
          ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // GO / NO-GO
  // ---------------------------------------------------------------------------

  Future<void> submitGoNoGoDecision({
    required String flightId,
    required String decision,
    String? reason,
    required String decisionBy,
  }) async {
    _log.t('submitGoNoGoDecision(flightId: $flightId, decision: $decision)');
    return _log.trace('submitGoNoGoDecision', () async {
      await _ensureSortieEditable(flightId);

      final normalizedDecision = decision.trim().toUpperCase();

      if (normalizedDecision != 'GO' && normalizedDecision != 'NO_GO') {
        _log.w('Decision must be GO or NO_GO.');
        throw AppFailure('Decision must be GO or NO_GO.');
      }

      if (normalizedDecision == 'NO_GO' &&
          (reason == null || reason.trim().isEmpty)) {
        _log.w('No-Go requires a reason.');
        throw AppFailure('No-Go requires a reason.');
      }

      if (normalizedDecision == 'GO') {
        final issues = await validatePreflightCompletion(flightId);

        if (issues.isNotEmpty) {
          _log.w(issues.join('\n'));
          throw AppFailure(issues.join('\n'));
        }
      }

      await transaction(() async {
        await (update(
          db.sorties,
        )..where((v) => v.flightId.equals(flightId))).write(
          SortiesCompanion(
            finalDecision: Value(normalizedDecision),
            decisionReason: Value(reason),
            decisionBy: Value(decisionBy),
            decisionAt: Value(DateTime.now()),
            // Go: ready for post-flight (take-off and landing aren't
            // recorded). No-Go: aborted.
            flightStatus: normalizedDecision == 'NO_GO'
                ? const Value('ABORTED')
                : const Value('READY'),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: normalizedDecision == 'GO' ? 'GO_DECISION' : 'NO_GO_DECISION',
          description: reason,
          performedBy: decisionBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  // ---------------------------------------------------------------------------
  // FLIGHT STATE
  // ---------------------------------------------------------------------------

  Future<void> markFlightInProgress({
    required String flightId,
    DateTime? takeoffAt,
    required String performedBy,
  }) async {
    _log.t('markFlightInProgress(flightId: $flightId)');
    return _log.trace('markFlightInProgress', () async {
      final sortie = await _requireSortie(flightId);

      if (sortie.flightStatus == 'CLOSED') {
        _log.w('Cannot start a closed sortie.');
        throw AppFailure('Cannot start a closed sortie.');
      }

      if (sortie.flightStatus == 'ABORTED') {
        _log.w('Cannot start an aborted sortie.');
        throw AppFailure('Cannot start an aborted sortie.');
      }

      if (sortie.flightStatus == 'IN_PROGRESS') {
        _log.w('Flight is already in progress.');
        throw AppFailure('Flight is already in progress.');
      }

      if (sortie.flightStatus == 'FLOWN') {
        _log.w('Flight has already been flown.');
        throw AppFailure('Flight has already been flown.');
      }

      if (sortie.finalDecision != 'GO') {
        _log.w('Cannot start flight without GO decision.');
        throw AppFailure('Cannot start flight without GO decision.');
      }

      final issues = await validatePreflightCompletion(flightId);

      if (issues.isNotEmpty) {
        _log.w(issues.join('\n'));
        throw AppFailure(issues.join('\n'));
      }

      await transaction(() async {
        await (update(
          db.sorties,
        )..where((v) => v.flightId.equals(flightId))).write(
          SortiesCompanion(
            flightStatus: const Value('IN_PROGRESS'),
            takeoffAt: Value(takeoffAt ?? DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'TAKEOFF_RECORDED',
          description: 'Flight marked in progress',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> recordLanding({
    required String flightId,
    DateTime? landingAt,
    required String performedBy,
  }) async {
    _log.t('recordLanding(flightId: $flightId)');
    return _log.trace('recordLanding', () async {
      final sortie = await _requireSortie(flightId);

      if (sortie.flightStatus != 'IN_PROGRESS') {
        _log.w('Cannot record landing unless flight is in progress.');
        throw AppFailure('Cannot record landing unless flight is in progress.');
      }

      final resolvedLandingAt = landingAt ?? DateTime.now();

      if (sortie.takeoffAt != null &&
          resolvedLandingAt.isBefore(sortie.takeoffAt!)) {
        _log.w('Landing time cannot be before takeoff time.');
        throw AppFailure('Landing time cannot be before takeoff time.');
      }

      await transaction(() async {
        await (update(
          db.sorties,
        )..where((v) => v.flightId.equals(flightId))).write(
          SortiesCompanion(
            flightStatus: const Value('FLOWN'),
            landingAt: Value(resolvedLandingAt),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'LANDING_RECORDED',
          description: 'Landing recorded',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> abortSortie({
    required String flightId,
    required String reason,
    required String performedBy,
  }) async {
    _log.t('abortSortie(flightId: $flightId)');
    return _log.trace('abortSortie', () async {
      final sortie = await _requireSortie(flightId);

      if (sortie.flightStatus == 'CLOSED') {
        _log.w('Cannot abort a closed sortie.');
        throw AppFailure('Cannot abort a closed sortie.');
      }

      if (sortie.flightStatus == 'ABORTED') {
        _log.w('Sortie is already aborted.');
        throw AppFailure('Sortie is already aborted.');
      }

      if (sortie.flightStatus == 'FLOWN') {
        _log.w('Cannot abort a sortie after landing.');
        throw AppFailure('Cannot abort a sortie after landing.');
      }

      await transaction(() async {
        await (update(
          db.sorties,
        )..where((v) => v.flightId.equals(flightId))).write(
          SortiesCompanion(
            flightStatus: const Value('ABORTED'),
            decisionReason: Value(reason),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: 'SORTIE',
          entityId: flightId,
          action: 'ABORT',
          description: reason,
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'SORTIE',
          entityId: flightId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<Sorty> _requireSortie(String flightId) async {
    final sortie = await getSortieById(flightId);

    if (sortie == null) {
      _log.w('Sortie not found: $flightId');
      throw AppFailure('Sortie not found: $flightId');
    }

    return sortie;
  }

  Future<void> _ensureSortieEditable(String flightId) async {
    final sortie = await _requireSortie(flightId);

    if (sortie.flightStatus != 'PREFLIGHT') {
      _log.w('Sortie is not editable because it is ${sortie.flightStatus}.');
      throw AppFailure(
        'Sortie is not editable because it is ${sortie.flightStatus}.',
      );
    }
  }

  Future<VehicleChecklistTemplate> _getActiveTemplateForVehicle(
    String vehicleId,
  ) async {
    final template =
        await (select(db.vehicleChecklistTemplates)
              ..where((v) => v.vehicleId.equals(vehicleId))
              ..where((v) => v.isActive.equals(true))
              ..orderBy([(v) => OrderingTerm.desc(v.version)])
              ..limit(1))
            .getSingleOrNull();

    if (template == null) {
      _log.w('No active checklist template found for vehicle.');
      throw AppFailure('No active checklist template found for vehicle.');
    }

    return template;
  }

  Future<int> _getNextSequenceNo(String sessionId) async {
    final maxSeq = db.sorties.sequenceNo.max();

    final query = selectOnly(db.sorties)
      ..addColumns([maxSeq])
      ..where(db.sorties.sessionId.equals(sessionId));

    final row = await query.getSingle();

    final currentMaxSeq = row.read(maxSeq) ?? 0;

    return currentMaxSeq + 1;
  }

  Future<bool> _isPayloadSelectableForSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
  }) async {
    final plannedPayload =
        await (select(db.sessionVehiclePayload)..where(
              (v) =>
                  v.sessionVehicleId.equals(sessionVehicleId) &
                  v.payloadId.equals(payloadId),
            ))
            .getSingleOrNull();

    if (plannedPayload == null) {
      return false;
    }

    final sessionVehicle = await (select(
      db.sessionVehicles,
    )..where((v) => v.id.equals(sessionVehicleId))).getSingleOrNull();

    if (sessionVehicle == null) {
      return false;
    }

    final vehicle = await (select(
      db.vehicles,
    )..where((v) => v.id.equals(sessionVehicle.vehicleId))).getSingleOrNull();

    if (vehicle == null) {
      return false;
    }

    final compatibilityRows = await (select(
      db.payloadVehicleCompatibility,
    )..where((v) => v.payloadId.equals(payloadId))).get();

    if (compatibilityRows.isEmpty) {
      return true;
    }

    return compatibilityRows.any((row) => row.vehicleType == vehicle.type);
  }

  Future<void> _ensureBatterySelectableForSortie({
    required String flightId,
    required String batteryId,
  }) async {
    final sortie = await _requireSortie(flightId);

    final sessionBattery =
        await (select(db.sessionBatteries)..where(
              (v) =>
                  v.sessionId.equals(sortie.sessionId) &
                  v.batteryId.equals(batteryId),
            ))
            .getSingleOrNull();

    if (sessionBattery == null) {
      _log.w('Battery $batteryId was not added to this field session.');
      throw AppFailure(
        'Battery $batteryId was not added to this field session.',
      );
    }
  }

  Future<void> _touchSortie(String flightId) {
    return (update(db.sorties)..where((v) => v.flightId.equals(flightId)))
        .write(SortiesCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> _touchSession(String sessionId) {
    return (update(db.fieldSessions)
          ..where((v) => v.sessionId.equals(sessionId)))
        .write(FieldSessionsCompanion(updatedAt: Value(DateTime.now())));
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
