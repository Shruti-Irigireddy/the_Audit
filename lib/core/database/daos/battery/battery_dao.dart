import 'package:drift/drift.dart';
import 'dart:async';

import '../../app_database.dart';

part 'battery_dao.g.dart';

@DriftAccessor(
  tables: [
    Batteries,
    AuditEvents,
    SyncQueue,
  ],
)

class BatteryDao extends DatabaseAccessor<AppDatabase> with _$BatteryDaoMixin{
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

      await into(db.auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: 'BATTERIES', 
          entityId: batteryId, 
          action: 'CREATE',
          description: Value('Batteries info tab created'), 
          performedBy: performedBy
        ),
      );

      await into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          entityType: 'BATTERIES', 
          entityId: batteryId, 
          operation: 'INSERT',
        ),
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
          ..where((v) => v.status.equals('ACTIVE'))
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
    
    await into(db.auditEvents).insert(
      AuditEventsCompanion.insert(
        entityType: 'BATTERY', 
        entityId: batteryId, 
        action: "UPDATE",
        description: Value('Batteries updated'), 
        performedBy: performedBy
      ),
    );

    await into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: 'BATTERY', 
        entityId: batteryId, 
        operation: 'UPDATE',
      ),
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
          status: const Value('RETIRED'),
          updatedAt: Value(DateTime.now()),
        ),
      );

    await into(db.auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: 'BATTERY',
          entityId: batteryId,
          action: 'RETIRE',
          description: Value('Battery retired'),
          performedBy: performedBy,
        ),
      );

      await into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          entityType: 'BATTERY',
          entityId: batteryId,
          operation: 'UPDATE',
        ),
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