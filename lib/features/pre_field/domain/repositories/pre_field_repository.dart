import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';

import 'package:the_audit/features/pre_field/domain/dtos/pre_field_dtos.dart';
import 'package:the_audit/features/pre_field/domain/entities/field_session_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/payload_compatibility_issue_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_equipment_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_summary_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_battery_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_equipment_check_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_user_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_vehicle_entity.dart';

abstract class PreFieldRepository {
  Future<String> createFieldSession({
    String? sessionId,
    required DateTime date,
    required String locationName,
    required double latitude,
    required double longitude,
    required String missionType,
    required String createdBy,
  });

  Future<void> updateFieldSessionBasicInfo({
    required String sessionId,
    DateTime? date,
    String? locationName,
    double? latitude,
    double? longitude,
    String? missionType,
    required String performedBy,
  });

  Future<FieldSessionEntity?> getFieldSessionById(String sessionId);

  Future<List<FieldSessionEntity>> getInProgressFieldSessions();

  Future<void> closeFieldSession({
    required String sessionId,
    required String closedBy,
  });

  Future<void> addUserToSession({
    required String id,
    required String sessionId,
    required String userId,
    required String role,
    required String performedBy,
  });

  Future<void> removeUserFromSession({
    required String sessionUserId,
    required String performedBy,
  });

  Future<void> replaceSessionUsers({
    required String sessionId,
    required List<SessionUserDraft> users,
    required String performedBy,
  });

  Future<List<SessionUserWithUserEntity>> getSessionUsers(String sessionId);

  Future<int> countSessionUsersByRole({
    required String sessionId,
    required String role,
  });

  Future<void> addVehicleToSession({
    required String id,
    required String sessionId,
    required String vehicleId,
    String? objective,
    required String performedBy,
  });

  Future<void> removeVehicleFromSession({
    required String sessionVehicleId,
    required String performedBy,
  });

  Future<void> updateSessionVehicleObjective({
    required String sessionVehicleId,
    String? objective,
    required String performedBy,
  });

  Future<void> replaceSessionVehicles({
    required String sessionId,
    required List<SessionVehicleDraft> vehicles,
    required String performedBy,
  });

  Future<List<SessionVehicleWithVehicleEntity>> getSessionVehicles(
    String sessionId,
  );

  Future<int> countSessionVehicles(String sessionId);

  Future<int> countSortiesForSessionVehicle(String sessionVehicleId);

  Future<void> addPayloadToSessionVehicle({
    required String id,
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  });

  Future<void> removePayloadFromSessionVehicle({
    required String sessionVehiclePayloadId,
    required String performedBy,
  });

  Future<void> replacePayloadsForSessionVehicle({
    required String sessionVehicleId,
    required List<String> payloadIds,
    required String performedBy,
  });

  Future<List<PayloadEntity>> getPayloadsForSessionVehicle(
    String sessionVehicleId,
  );

  Future<int> countPayloadsForSessionVehicle(String sessionVehicleId);

  Future<List<PayloadCompatibilityIssueEntity>> getPayloadCompatibilityIssues(
    String sessionId,
  );

  Future<void> addBatteryToSession({
    required String id,
    required String sessionId,
    required String batteryId,
    required String performedBy,
  });

  Future<void> removeBatteryFromSession({
    required String sessionBatteryId,
    required String performedBy,
  });

  Future<void> replaceSessionBatteries({
    required String sessionId,
    required List<SessionBatteryDraft> batteries,
    required String performedBy,
  });

  Future<List<SessionBatteryWithBatteryEntity>> getSessionBatteries(
    String sessionId,
  );

  Future<List<PreFieldEquipmentEntity>> getActiveEquipmentList();

  Future<void> createEquipmentChecksForSession({
    required String sessionId,
    required String checkedBy,
  });

  Future<void> updateEquipmentCheck({
    required String equipmentCheckId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  });

  Future<List<SessionEquipmentCheckWithItemEntity>> getSessionEquipmentChecks(
    String sessionId,
  );

  Future<void> addCustomEquipmentCheckToSession({
    required String id,
    required String sessionId,
    required String equipmentId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  });

  Future<int> countUnpackedEquipmentChecks(String sessionId);

  Future<String> createEquipmentItem({
    String? id,
    required String name,
    required String category,
    required String performedBy,
  });

  Future<void> updateEquipmentItem({
    required String equipmentId,
    String? name,
    String? category,
    bool? isActive,
    required String performedBy,
  });

  Future<void> deactivateEquipmentItem({
    required String equipmentId,
    required String performedBy,
  });

  Future<PreFieldSummaryEntity> getPreFieldSummary(String sessionId);
}
