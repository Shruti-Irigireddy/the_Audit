import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';

class SessionUserDraft {
  final String id;
  final String userId;
  final String role;

  const SessionUserDraft({
    required this.id,
    required this.userId,
    required this.role,
  });
}

class SessionVehicleDraft {
  final String id;
  final String vehicleId;
  final String? objective;

  const SessionVehicleDraft({
    required this.id,
    required this.vehicleId,
    this.objective,
  });
}

class PayloadCompatibilityIssue {
  final String vehicleId;
  final String sessionVehicleId;
  final String vehicleName;
  final String vehicleType;
  final String payloadId;
  final String payloadName;
  final String message;

  const PayloadCompatibilityIssue({
    required this.vehicleId,
    required this.sessionVehicleId,
    required this.vehicleName,
    required this.vehicleType,
    required this.payloadId,
    required this.payloadName,
    required this.message,
  });
}

class PreFieldSummaryData {
  final FieldSession session;
  final List<SessionUserWithUser> teamMembers;
  final List<SessionVehicleWithVehicle> vehicles;
  final List<SessionBatteryWithBattery> batteries;
  final List<SessionEquipmentCheckWithItem> equipmentChecks;
  final List<PayloadCompatibilityIssue> payloadCompatibilityIssues;

  const PreFieldSummaryData({
    required this.session,
    required this.teamMembers,
    required this.vehicles,
    required this.batteries,
    required this.equipmentChecks,
    required this.payloadCompatibilityIssues,
  });
}
