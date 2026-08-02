import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';

abstract class BatteryRepository {

  Future<String> createBattery({
    String? batteryId,
    required String config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    required String status,
    required String performedBy,
  });

  Future<BatteryEntity?> getBatteryById(String batteryId);

  Future<List<BatteryEntity>> getActiveBatteries();

  Future<List<BatteryEntity>> getAllBatteries();

  Future<void> updateBattery({
    required String batteryId,
    String? config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    String? status,
    required String performedBy,
  });

  Future<void> retireBattery({
    required String batteryId,
    required String performedBy,
  });

  Future<void> incrementCycleCount({
    required String batteryId,
    required String performedBy,
  });
}