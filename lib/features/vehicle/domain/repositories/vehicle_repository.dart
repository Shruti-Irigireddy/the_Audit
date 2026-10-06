import 'package:the_audit/features/vehicle/domain/dtos/vehicle_dtos.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_checklist_template_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_with_checklist_entity.dart';

abstract class VehicleRepository {
  Future<String> createVehicleWithChecklist({
    String? vehicleId,
    required String name,
    required String type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? notes,
    required String createdBy,
    required List<ChecklistItemDraft> checklistItems,
  });

  Future<VehicleEntity?> getVehicleById(String vehicleId);

  Future<VehicleWithChecklistEntity?> getVehicleWithActiveChecklist(
    String vehicleId,
  );

  Future<List<VehicleEntity>> getActiveVehicles();

  Future<List<VehicleEntity>> getAllVehicles();

  Future<List<VehicleEntity>> searchVehicles(String query);

  Future<void> updateVehicle({
    required String vehicleId,
    String? name,
    String? type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? status,
    String? notes,
    required String performedBy,
  });

  Future<void> markVehicleActive({
    required String vehicleId,
    required String performedBy,
  });

  Future<void> markVehicleInactive({
    required String vehicleId,
    required String performedBy,
  });

  Future<void> retireVehicle({
    required String vehicleId,
    required String performedBy,
  });

  Future<VehicleChecklistTemplateEntity?> getActiveChecklistTemplateForVehicle(
    String vehicleId,
  );

  Future<List<VehicleChecklistTemplateEntity>> getChecklistTemplatesForVehicle(
    String vehicleId,
  );

  Future<List<ChecklistItemEntity>> getChecklistForVehicle(String vehicleId);

  Future<List<ChecklistItemEntity>> getChecklistItemsForTemplate(
    String templateId,
  );

  Future<String> createNewChecklistVersionForVehicle({
    required String vehicleId,
    required List<ChecklistItemDraft> checklistItems,
    required String createdBy,
    String? deactivationReason,
  });

  Future<void> deactivateChecklistTemplate({
    required String templateId,
    required String deactivatedBy,
    String? deactivationReason,
  });
}
