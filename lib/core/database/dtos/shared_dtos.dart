import 'package:the_audit/core/database/app_database.dart';

class SessionUserWithUser {
  final SessionUser sessionUser;
  final User user;

  const SessionUserWithUser({required this.sessionUser, required this.user});
}

class SessionVehicleWithVehicle {
  final SessionVehicle sessionVehicle;
  final Vehicle vehicle;

  const SessionVehicleWithVehicle({
    required this.sessionVehicle,
    required this.vehicle,
  });
}

class SessionBatteryWithBattery {
  final SessionBattery sessionBattery;
  final Battery battery;

  const SessionBatteryWithBattery({
    required this.sessionBattery,
    required this.battery,
  });
}

class SessionEquipmentCheckWithItem {
  final SessionEquipmentCheck sessionEquipmentCheck;
  final EquipmentList equipmentList;

  const SessionEquipmentCheckWithItem({
    required this.sessionEquipmentCheck,
    required this.equipmentList,
  });
}

class SortiePayloadWithPayload {
  final SortiePayload sortiePayload;
  final Payload payload;

  const SortiePayloadWithPayload({
    required this.sortiePayload,
    required this.payload,
  });
}

class SortieBatteryWithBattery {
  final SortieBattery sortieBattery;
  final Battery battery;

  const SortieBatteryWithBattery({
    required this.sortieBattery,
    required this.battery,
  });
}

class SortieUserWithUser {
  final SortieUser sortieUser;
  final User user;

  const SortieUserWithUser({required this.sortieUser, required this.user});
}

class ChecklistResponseWithItem {
  final ChecklistResponse response;
  final ChecklistItem item;

  const ChecklistResponseWithItem({required this.response, required this.item});
}
