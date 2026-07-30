import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';

class SessionBatteryEntity {
  final String id;
  final String sessionId;
  final String batteryId;
  final DateTime createdAt;

  const SessionBatteryEntity({
    required this.id,
    required this.sessionId,
    required this.batteryId,
    required this.createdAt,
  });
}

class SessionBatteryWithBatteryEntity {
  final SessionBatteryEntity sessionBattery;
  final BatteryEntity battery;

  const SessionBatteryWithBatteryEntity({
    required this.sessionBattery,
    required this.battery,
  });
}
