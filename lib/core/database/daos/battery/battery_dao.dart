import 'package:drift/drift.dart';
import 'dart:async';

import '../../app_database.dart';
import '../../dao_write_helpers.dart';
import '../../database_constants.dart';

part 'battery_dao.g.dart';

@DriftAccessor(
  tables: [
    Batteries,
    AuditEvents,
    SyncQueue,
  ],
)

class BatteryDao extends DatabaseAccessor<AppDatabase> with _$BatteryDaoMixin, DaoWriteHelpers{
  BatteryDao(super.db);

  Future<void> createBattery({
    required String batteryId,
    required String config,
    int? capacity,
    double? voltage,  
    int? cycleCount,
    required String status,
    required String performedBy,
  }) async {
    await transaction(() async {
      await into(db.batteries).insert(
        BatteriesCompanion.insert(
          batteryId: batteryId, 
          config: config,
          capacity: Value(capacity),
          voltage: Value(voltage),
          cycleCount: cycleCount != null ? Value(cycleCount) : const Value.absent(),
          status: Value(status),
        ),
      );

      await insertAuditEvent(
        entityType: DbEntityTypes.battery,
        entityId: batteryId,
        action: DbActions.create,
        description: 'Batteries info tab created',
        performedBy: performedBy,
      );

      await enqueueSync(
        entityType: DbEntityTypes.battery,
        entityId: batteryId,
        operation: DbSyncOperations.insert,
      );
    });
  }

  Future<Battery?> getBatteryById(String batteryId){
    return (select(db.batteries) 
          ..where((v) => v.batteryId.equals(batteryId)))
          .getSingleOrNull();
  }

  Future<List<Battery>> getAllActiveBatteries(){
    return (select(db.batteries)
          ..where((v) => v.status.equals(DbStatuses.active))
          ..orderBy([
            (v) => OrderingTerm.asc(v.capacity)
          ]))
          .get();
  }

  Future<List<Battery>> getAllBatteries(){
    return (select(db.batteries)
        ..orderBy([
          (v) => OrderingTerm.asc(v.capacity)
        ]))
        .get();
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
    await transaction(() async{
      await (update(db.batteries)
          ..where((v) => v.batteryId.equals(batteryId)))
          .write(
            BatteriesCompanion(
              config: config == null? Value.absent() : Value(config),
              capacity: capacity == null ? Value.absent() : Value(capacity),
              voltage: voltage == null ? Value.absent() : Value(voltage),
              cycleCount: cycleCount == null ? Value.absent() : Value(cycleCount),
              status: status == null ? Value.absent() : Value(status),
              updatedAt: Value(DateTime.now())
            )
          );
    
    await insertAuditEvent(
      entityType: DbEntityTypes.battery,
      entityId: batteryId,
      action: DbActions.update,
      description: 'Batteries updated',
      performedBy: performedBy,
    );

    await enqueueSync(
      entityType: DbEntityTypes.battery,
      entityId: batteryId,
      operation: DbSyncOperations.update,
    );
    });
  }

  Future<void> retireBattery({
    required String batteryId,
    required String performedBy,
  }) async {
    await transaction(() async {
      await (update(db.batteries)
      ..where((v) => v.batteryId.equals(batteryId)))
      .write(
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
  }

  Future<void> incrementCycleCount ({
    required String batteryId,
    required String performedBy,
  }) async {
    final battery = await getBatteryById(batteryId);

    if (battery == null){
      throw Exception('Battery not found: $batteryId');
    }

    await updateBattery(
      batteryId: batteryId, 
      cycleCount: (battery.cycleCount ?? 0) + 1,
      performedBy: performedBy,
    );
  }
}
