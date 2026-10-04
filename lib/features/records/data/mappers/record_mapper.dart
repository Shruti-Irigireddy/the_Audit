import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';
import 'package:the_audit/features/records/domain/entities/record_entity.dart';

extension FieldSessionDbMapper on FieldSession {
  FieldSessionEntity toEntity() {
    return FieldSessionEntity(
      sessionId: sessionId,
      date: date,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      missionType: missionType,
      sessionStatus: sessionStatus,
      createdAt: createdAt,
      updatedAt: updatedAt,
      closedAt: closedAt,
      closedBy: closedBy,
    );
  }
}

extension UserDbRecordMapper on User {
  UserRecordEntity toRecordEntity() {
    return UserRecordEntity(
      id: id,
      name: name,
      role: role,
      defaultPic: defaultPic,
      email: email,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension VehicleDbRecordMapper on Vehicle {
  VehicleRecordEntity toRecordEntity() {
    return VehicleRecordEntity(
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

extension PayloadDbRecordMapper on Payload {
  PayloadRecordEntity toRecordEntity() {
    return PayloadRecordEntity(
      payloadId: payloadId,
      name: name,
      category: category,
      storageType: storageType,
      storageCapacity: storageCapacity,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension BatteryDbRecordMapper on Battery {
  BatteryRecordEntity toRecordEntity() {
    return BatteryRecordEntity(
      batteryId: batteryId,
      config: config,
      capacity: capacity,
      voltage: voltage,
      cycleCount: cycleCount,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension EquipmentListDbRecordMapper on EquipmentList {
  EquipmentListRecordEntity toRecordEntity() {
    return EquipmentListRecordEntity(
      id: id,
      name: name,
      category: category,
      isActive: isActive,
    );
  }
}

extension SessionUserWithUserMapper on SessionUserWithUser {
  SessionUserWithUserEntity toEntity() {
    return SessionUserWithUserEntity(
      id: sessionUser.id,
      sessionId: sessionUser.sessionId,
      role: sessionUser.role,
      createdAt: sessionUser.createdAt,
      user: user.toRecordEntity(),
    );
  }
}

extension SessionVehicleWithVehicleMapper on SessionVehicleWithVehicle {
  SessionVehicleWithVehicleEntity toEntity() {
    return SessionVehicleWithVehicleEntity(
      id: sessionVehicle.id,
      sessionId: sessionVehicle.sessionId,
      vehicleId: sessionVehicle.vehicleId,
      objective: sessionVehicle.objective,
      createdAt: sessionVehicle.createdAt,
      vehicle: vehicle.toRecordEntity(),
    );
  }
}

extension SessionBatteryWithBatteryMapper on SessionBatteryWithBattery {
  SessionBatteryWithBatteryEntity toEntity() {
    return SessionBatteryWithBatteryEntity(
      id: sessionBattery.id,
      sessionId: sessionBattery.sessionId,
      batteryId: sessionBattery.batteryId,
      createdAt: sessionBattery.createdAt,
      battery: battery.toRecordEntity(),
    );
  }
}

extension SessionEquipmentCheckWithItemMapper on SessionEquipmentCheckWithItem {
  SessionEquipmentCheckWithItemEntity toEntity() {
    return SessionEquipmentCheckWithItemEntity(
      id: sessionEquipmentCheck.id,
      sessionId: sessionEquipmentCheck.sessionId,
      equipmentId: sessionEquipmentCheck.equipmentId,
      isPacked: sessionEquipmentCheck.isPacked,
      notes: sessionEquipmentCheck.notes,
      checkedAt: sessionEquipmentCheck.checkedAt,
      checkedBy: sessionEquipmentCheck.checkedBy,
      createdAt: sessionEquipmentCheck.createdAt,
      updatedAt: sessionEquipmentCheck.updatedAt,
      equipmentList: equipmentList.toRecordEntity(),
    );
  }
}

extension SortyDbRecordMapper on Sorty {
  SortieEntity toEntity() {
    return SortieEntity(
      flightId: flightId,
      sessionId: sessionId,
      sequenceNo: sequenceNo,
      sessionVehicleId: sessionVehicleId,
      picUserId: picUserId,
      objective: objective,
      checklistTemplateId: checklistTemplateId,
      checklistTemplateVersion: checklistTemplateVersion,
      takeoffAt: takeoffAt,
      landingAt: landingAt,
      flightStatus: flightStatus,
      closedAt: closedAt,
      closedBy: closedBy,
      finalDecision: finalDecision,
      decisionReason: decisionReason,
      decisionBy: decisionBy,
      decisionAt: decisionAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension SortieUserWithUserMapper on SortieUserWithUser {
  SortieUserWithUserEntity toEntity() {
    return SortieUserWithUserEntity(
      id: sortieUser.id,
      flightId: sortieUser.flightId,
      userId: sortieUser.userId,
      role: sortieUser.role,
      createdAt: sortieUser.createdAt,
      user: user.toRecordEntity(),
    );
  }
}

extension SortiePayloadWithPayloadMapper on SortiePayloadWithPayload {
  SortiePayloadWithPayloadEntity toEntity() {
    return SortiePayloadWithPayloadEntity(
      id: sortiePayload.id,
      flightId: sortiePayload.flightId,
      payloadId: sortiePayload.payloadId,
      createdAt: sortiePayload.createdAt,
      payload: payload.toRecordEntity(),
    );
  }
}

extension SortieBatteryWithBatteryMapper on SortieBatteryWithBattery {
  SortieBatteryWithBatteryEntity toEntity() {
    return SortieBatteryWithBatteryEntity(
      id: sortieBattery.id,
      flightId: sortieBattery.flightId,
      batteryId: sortieBattery.batteryId,
      voltageStart: sortieBattery.voltageStart,
      voltageEnd: sortieBattery.voltageEnd,
      percentStart: sortieBattery.percentStart,
      percentEnd: sortieBattery.percentEnd,
      createdAt: sortieBattery.createdAt,
      updatedAt: sortieBattery.updatedAt,
      battery: battery.toRecordEntity(),
    );
  }
}

extension ChecklistItemDbRecordMapper on ChecklistItem {
  ChecklistItemRecordEntity toRecordEntity() {
    return ChecklistItemRecordEntity(
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
      updatedAt: updatedAt,
    );
  }
}

extension ChecklistResponseWithItemMapper on ChecklistResponseWithItem {
  ChecklistResponseWithItemEntity toEntity() {
    return ChecklistResponseWithItemEntity(
      id: response.id,
      flightId: response.flightId,
      itemId: response.itemId,
      response: response.response,
      valueText: response.valueText,
      valueNumber: response.valueNumber,
      notes: response.notes,
      createdBy: response.createdBy,
      responseAt: response.responseAt,
      createdAt: response.createdAt,
      updatedAt: response.updatedAt,
      item: item.toRecordEntity(),
    );
  }
}

extension ChecklistOverrideDbRecordMapper on ChecklistOverride {
  ChecklistOverrideEntity toEntity() {
    return ChecklistOverrideEntity(
      id: id,
      flightId: flightId,
      itemId: itemId,
      overrideReason: overrideReason,
      overriddenBy: overriddenBy,
      createdAt: createdAt,
    );
  }
}

extension PostFlightNoteDbRecordMapper on PostFlightNote {
  PostFlightNoteEntity toEntity() {
    return PostFlightNoteEntity(
      id: id,
      flightId: flightId,
      objectiveResult: objectiveResult,
      objectiveNotes: objectiveNotes,
      missionRating: missionRating,
      issuesEncountered: issuesEncountered,
      logStoredAt: logStoredAt,
      logLocation: logLocation,
      logNotes: logNotes,
      flightDurationSeconds: flightDurationSeconds,
      followUpRequired: followUpRequired,
      followUpNotes: followUpNotes,
      followUpAssignedTo: followUpAssignedTo,
      followUpDueDate: followUpDueDate,
      followUpStatus: followUpStatus,
      notes: notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension AuditEventDbRecordMapper on AuditEvent {
  AuditEventEntity toEntity() {
    return AuditEventEntity(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      description: description,
      performedBy: performedBy,
      performedAt: performedAt,
    );
  }
}

extension RecordAmendmentDbRecordMapper on RecordAmendment {
  RecordAmendmentEntity toEntity() {
    return RecordAmendmentEntity(
      id: id,
      entityType: entityType,
      entityId: entityId,
      amendmentText: amendmentText,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

extension ExportRecordDbRecordMapper on ExportRecord {
  ExportRecordSummaryEntity toRecordSummaryEntity() {
    return ExportRecordSummaryEntity(
      id: id,
      entityType: entityType,
      entityId: entityId,
      exportFormat: exportFormat,
      exportLocation: exportLocation,
      exportStatus: exportStatus,
      generatedBy: generatedBy,
      retryCount: retryCount,
      lastAttemptAt: lastAttemptAt,
      errorMessage: errorMessage,
      generatedAt: generatedAt,
    );
  }
}
