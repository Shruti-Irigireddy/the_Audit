import 'field_session_entity.dart';
import 'payload_compatibility_issue_entity.dart';
import 'session_battery_entity.dart';
import 'session_equipment_check_entity.dart';
import 'session_user_entity.dart';
import 'session_vehicle_entity.dart';

class PreFieldSummaryEntity {
  final FieldSessionEntity session;
  final List<SessionUserWithUserEntity> teamMembers;
  final List<SessionVehicleWithVehicleEntity> vehicles;
  final List<SessionBatteryWithBatteryEntity> batteries;
  final List<SessionEquipmentCheckWithItemEntity> equipmentChecks;
  final List<PayloadCompatibilityIssueEntity> payloadCompatibilityIssues;

  const PreFieldSummaryEntity({
    required this.session,
    required this.teamMembers,
    required this.vehicles,
    required this.batteries,
    required this.equipmentChecks,
    required this.payloadCompatibilityIssues,
  });
}
