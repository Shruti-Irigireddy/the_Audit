import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_checklist_template_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_entity.dart';

extension VehicleDbMapper on Vehicle {
  VehicleEntity toEntity() {
    return VehicleEntity (
      id: id,
      name: name,
      type: type,
      frameMake: frameMake,
      frameModel: frameModel,
      motorCount: motorCount,
      frameStyle: frameStyle,
      firmwareTarget: firmwareTarget,
      defaultFailSafeProfile: defaultFailSafeProfile,
      status: status,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension ChecklistItemDbMapper on ChecklistItem {
  ChecklistItemEntity toEntity() {
    return ChecklistItemEntity(
      id: id,
      templateId: templateId,
      section: section,
      label: label,
      responseType: responseType,
      isRequired: isRequired,
      blocksArming: blocksArming,
      sortOrder: sortOrder,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt
    );
  }
}

extension VehicleChecklistTemplateDbMapper on VehicleChecklistTemplate {
  VehicleChecklistTemplateEntity toEntity(){
    return VehicleChecklistTemplateEntity(
      id: id,
      vehicleId: vehicleId,
      version: version,
      isActive: isActive,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deactivatedAt: deactivatedAt,
      deactivatedBy: deactivatedBy,
      deactivationReason: deactivationReason,
    );
  }
}