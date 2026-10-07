import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';

import '../../app_database.dart';
import '../../dao_write_helpers.dart';
import '../../database_constants.dart';

part 'battery_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Batteries, AuditEvents, SyncQueue])
class BatteryDao extends DatabaseAccessor<AppDatabase>
    with _$BatteryDaoMixin, DaoWriteHelpers {
  BatteryDao(super.db);

  static const _log = AppLogger('BatteryDao');

  Future<String> createBattery({
    String? batteryId,
    required String config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    String? status,
    required String performedBy,
  }) async {
    _log.t('createBattery(batteryId: $batteryId, status: $status)');
    return _log.trace('createBattery', () async {
      final id = batteryId ?? _uuid.v4();
      final resolvedStatus = status ?? DbStatuses.active;

      await transaction(() async {
        await into(db.batteries).insert(
          BatteriesCompanion.insert(
            batteryId: id,
            config: config.trim(),
            capacity: Value(capacity),
            voltage: Value(voltage),
            cycleCount: cycleCount == null
                ? const Value.absent()
                : Value(cycleCount),
            status: Value(resolvedStatus),
          ),
        );

        await insertAuditEvent(
          entityType: DbEntityTypes.battery,
          entityId: id,
          action: DbActions.create,
          description: 'Battery created',
          performedBy: performedBy,
        );

        await enqueueSync(
          entityType: DbEntityTypes.battery,
          entityId: id,
          operation: DbSyncOperations.insert,
        );
      });

      return id;
    });
  }

  Future<Battery?> getBatteryById(String batteryId) {
    _log.t('getBatteryById(batteryId: $batteryId)');
    return (select(
      db.batteries,
    )..where((v) => v.batteryId.equals(batteryId))).getSingleOrNull();
  }

  Future<List<Battery>> getAllActiveBatteries() {
    _log.t('getAllActiveBatteries()');
    return (select(db.batteries)
          ..where((v) => v.status.equals(DbStatuses.active))
          ..orderBy([(v) => OrderingTerm.asc(v.capacity)]))
        .get();
  }

  Future<List<Battery>> getAllBatteries() {
    _log.t('getAllBatteries()');
    return (select(
      db.batteries,
    )..orderBy([(v) => OrderingTerm.asc(v.capacity)])).get();
  }

  Future<void> updateBattery({
    required String batteryId,
    String? config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    String? status,
    required String performedBy,
  }) async {
    _log.t('updateBattery(batteryId: $batteryId, status: $status)');
    return _log.trace('updateBattery', () async {
      await _requireBatteryExists(batteryId);

      await transaction(() async {
        await (update(
          db.batteries,
        )..where((v) => v.batteryId.equals(batteryId))).write(
          BatteriesCompanion(
            config: config == null
                ? const Value.absent()
                : Value(config.trim()),
            capacity: capacity == null ? const Value.absent() : Value(capacity),
            voltage: voltage == null ? const Value.absent() : Value(voltage),
            cycleCount: cycleCount == null
                ? const Value.absent()
                : Value(cycleCount),
            status: status == null ? const Value.absent() : Value(status),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await insertAuditEvent(
          entityType: DbEntityTypes.battery,
          entityId: batteryId,
          action: DbActions.update,
          description: 'Battery updated',
          performedBy: performedBy,
        );

        await enqueueSync(
          entityType: DbEntityTypes.battery,
          entityId: batteryId,
          operation: DbSyncOperations.update,
        );
      });
    });
  }

  Future<void> retireBattery({
    required String batteryId,
    required String performedBy,
  }) async {
    _log.t('retireBattery(batteryId: $batteryId)');
    return _log.trace('retireBattery', () async {
      await _requireBatteryExists(batteryId);

      await transaction(() async {
        await (update(
          db.batteries,
        )..where((v) => v.batteryId.equals(batteryId))).write(
          BatteriesCompanion(
            status: const Value(DbStatuses.retired),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await insertAuditEvent(
          entityType: DbEntityTypes.battery,
          entityId: batteryId,
          action: DbActions.retire,
          description: 'Battery retired',
          performedBy: performedBy,
        );

        await enqueueSync(
          entityType: DbEntityTypes.battery,
          entityId: batteryId,
          operation: DbSyncOperations.update,
        );
      });
    });
  }

  Future<void> incrementCycleCount({
    required String batteryId,
    required String performedBy,
  }) async {
    _log.t('incrementCycleCount(batteryId: $batteryId)');
    return _log.trace('incrementCycleCount', () async {
      final battery = await _requireBatteryExists(batteryId);

      await updateBattery(
        batteryId: batteryId,
        cycleCount: (battery.cycleCount ?? 0) + 1,
        performedBy: performedBy,
      );
    });
  }

  Future<Battery> _requireBatteryExists(String batteryId) async {
    final battery = await getBatteryById(batteryId);

    if (battery == null) {
      _log.w('Battery not found: $batteryId');
      throw AppFailure('Battery not found: $batteryId');
    }

    return battery;
  }
}
