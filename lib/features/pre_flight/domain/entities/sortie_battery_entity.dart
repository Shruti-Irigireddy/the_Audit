import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';

class SortieBatteryEntity {
  final String id;
  final String flightId;
  final String batteryId;
  final double? voltageStart;
  final double? voltageEnd;
  final int? percentStart;
  final int? percentEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SortieBatteryEntity({
    required this.id,
    required this.flightId,
    required this.batteryId,
    this.voltageStart,
    this.voltageEnd,
    this.percentStart,
    this.percentEnd,
    required this.createdAt,
    required this.updatedAt,
  });
}

class SortieBatteryWithBatteryEntity {
  final SortieBatteryEntity sortieBattery;
  final BatteryEntity battery;

  const SortieBatteryWithBatteryEntity({
    required this.sortieBattery,
    required this.battery,
  });
}
