import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';

extension BatteryDbMapper on Battery {
  BatteryEntity toEntity(){
    return BatteryEntity(
      batteryId: batteryId,
      config: config,
      capacity: capacity,
      voltage: voltage,
      cycleCount: cycleCount,
      status: status,
      updatedAt: updatedAt,
      createdAt: createdAt
    );
  }
}

extension BatteryDbListMapper on List<Battery>{
  List<BatteryEntity> toEntities(){
    return map((battery) => battery.toEntity()).toList();
  }
}