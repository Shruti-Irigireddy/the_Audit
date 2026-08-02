class FieldSessionEntity {
  final String sessionId;
  final DateTime date;
  final String locationName;
  final double latitude;
  final double longitude;
  final String missionType;
  final String sessionStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final String? closedBy;

  const FieldSessionEntity({
    required this.sessionId,
    required this.date,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.missionType,
    required this.sessionStatus,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.closedBy,
  });
}

class UserRecordEntity {
  final String id;
  final String name;
  final String role;
  final bool defaultPic;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserRecordEntity({
    required this.id,
    required this.name,
    required this.role,
    required this.defaultPic,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
  });
}

class VehicleRecordEntity {
  final String id;
  final String name;
  final String type;
  final String? frameMake;
  final String? frameModel;
  final int? motorCount;
  final String? frameStyle;
  final String? firmwareTarget;
  final String? defaultFailSafeProfile;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VehicleRecordEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.frameMake,
    this.frameModel,
    this.motorCount,
    this.frameStyle,
    this.firmwareTarget,
    this.defaultFailSafeProfile,
    this.notes,
  });
}

class PayloadRecordEntity {
  final String payloadId;
  final String name;
  final String category;
  final String? storageType;
  final String? storageCapacity;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayloadRecordEntity({
    required this.payloadId,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.storageType,
    this.storageCapacity,
  });
}

class BatteryRecordEntity {
  final String batteryId;
  final String config;
  final int? capacity;
  final double? voltage;
  final int? cycleCount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BatteryRecordEntity({
    required this.batteryId,
    required this.config,
    required this.cycleCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.capacity,
    this.voltage,
  });
}

class EquipmentListRecordEntity {
  final String id;
  final String name;
  final String category;
  final bool isActive;

  const EquipmentListRecordEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.isActive,
  });
}

class SessionUserWithUserEntity {
  final String id;
  final String sessionId;
  final String role;
  final DateTime createdAt;
  final UserRecordEntity user;

  const SessionUserWithUserEntity({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.createdAt,
    required this.user,
  });
}

class SessionVehicleWithVehicleEntity {
  final String id;
  final String sessionId;
  final String vehicleId;
  final String? objective;
  final DateTime createdAt;
  final VehicleRecordEntity vehicle;

  const SessionVehicleWithVehicleEntity({
    required this.id,
    required this.sessionId,
    required this.vehicleId,
    required this.createdAt,
    required this.vehicle,
    this.objective,
  });
}

class SessionBatteryWithBatteryEntity {
  final String id;
  final String sessionId;
  final String batteryId;
  final DateTime createdAt;
  final BatteryRecordEntity battery;

  const SessionBatteryWithBatteryEntity({
    required this.id,
    required this.sessionId,
    required this.batteryId,
    required this.createdAt,
    required this.battery,
  });
}

class SessionEquipmentCheckWithItemEntity {
  final String id;
  final String sessionId;
  final String equipmentId;
  final bool isPacked;
  final String? notes;
  final DateTime checkedAt;
  final String checkedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EquipmentListRecordEntity equipmentList;

  const SessionEquipmentCheckWithItemEntity({
    required this.id,
    required this.sessionId,
    required this.equipmentId,
    required this.isPacked,
    required this.checkedAt,
    required this.checkedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.equipmentList,
    this.notes,
  });
}

class SortieEntity {
  final String flightId;
  final String sessionId;
  final int sequenceNo;
  final String sessionVehicleId;
  final String picUserId;
  final String? objective;
  final String checklistTemplateId;
  final int checklistTemplateVersion;
  final DateTime? takeoffAt;
  final DateTime? landingAt;
  final String flightStatus;
  final DateTime? closedAt;
  final String? closedBy;
  final String? finalDecision;
  final String? decisionReason;
  final String? decisionBy;
  final DateTime? decisionAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SortieEntity({
    required this.flightId,
    required this.sessionId,
    required this.sequenceNo,
    required this.sessionVehicleId,
    required this.picUserId,
    required this.checklistTemplateId,
    required this.checklistTemplateVersion,
    required this.flightStatus,
    required this.createdAt,
    required this.updatedAt,
    this.objective,
    this.takeoffAt,
    this.landingAt,
    this.closedAt,
    this.closedBy,
    this.finalDecision,
    this.decisionReason,
    this.decisionBy,
    this.decisionAt,
  });
}

class SortieUserWithUserEntity {
  final String id;
  final String flightId;
  final String userId;
  final String role;
  final DateTime createdAt;
  final UserRecordEntity user;

  const SortieUserWithUserEntity({
    required this.id,
    required this.flightId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.user,
  });
}

class SortiePayloadWithPayloadEntity {
  final String id;
  final String flightId;
  final String payloadId;
  final DateTime createdAt;
  final PayloadRecordEntity payload;

  const SortiePayloadWithPayloadEntity({
    required this.id,
    required this.flightId,
    required this.payloadId,
    required this.createdAt,
    required this.payload,
  });
}

class SortieBatteryWithBatteryEntity {
  final String id;
  final String flightId;
  final String batteryId;
  final double? voltageStart;
  final double? voltageEnd;
  final int? percentStart;
  final int? percentEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BatteryRecordEntity battery;

  const SortieBatteryWithBatteryEntity({
    required this.id,
    required this.flightId,
    required this.batteryId,
    required this.createdAt,
    required this.updatedAt,
    required this.battery,
    this.voltageStart,
    this.voltageEnd,
    this.percentStart,
    this.percentEnd,
  });
}

class ChecklistItemRecordEntity {
  final String id;
  final String templateId;
  final String section;
  final String label;
  final String responseType;
  final bool isRequired;
  final bool blocksArming;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistItemRecordEntity({
    required this.id,
    required this.templateId,
    required this.section,
    required this.label,
    required this.responseType,
    required this.isRequired,
    required this.blocksArming,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

class ChecklistResponseWithItemEntity {
  final String id;
  final String flightId;
  final String itemId;
  final String response;
  final String? valueText;
  final double? valueNumber;
  final String? notes;
  final String createdBy;
  final DateTime responseAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ChecklistItemRecordEntity item;

  const ChecklistResponseWithItemEntity({
    required this.id,
    required this.flightId,
    required this.itemId,
    required this.response,
    required this.createdBy,
    required this.responseAt,
    required this.createdAt,
    required this.updatedAt,
    required this.item,
    this.valueText,
    this.valueNumber,
    this.notes,
  });
}

class ChecklistOverrideEntity {
  final String id;
  final String flightId;
  final String itemId;
  final String overrideReason;
  final String overriddenBy;
  final DateTime createdAt;

  const ChecklistOverrideEntity({
    required this.id,
    required this.flightId,
    required this.itemId,
    required this.overrideReason,
    required this.overriddenBy,
    required this.createdAt,
  });
}

class PostFlightNoteEntity {
  final String id;
  final String flightId;
  final String objectiveResult;
  final String? objectiveNotes;
  final String? missionRating;
  final String? issuesEncountered;
  final String? logStoredAt;
  final String? logLocation;
  final String? logNotes;
  final int? flightDurationSeconds;
  final bool followUpRequired;
  final String? followUpNotes;
  final String? followUpAssignedTo;
  final DateTime? followUpDueDate;
  final String followUpStatus;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostFlightNoteEntity({
    required this.id,
    required this.flightId,
    required this.objectiveResult,
    required this.followUpRequired,
    required this.followUpStatus,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.objectiveNotes,
    this.missionRating,
    this.issuesEncountered,
    this.logStoredAt,
    this.logLocation,
    this.logNotes,
    this.flightDurationSeconds,
    this.followUpNotes,
    this.followUpAssignedTo,
    this.followUpDueDate,
    this.notes,
  });
}

class AuditEventEntity {
  final int id;
  final String entityType;
  final String entityId;
  final String action;
  final String? description;
  final String performedBy;
  final DateTime performedAt;

  const AuditEventEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.performedBy,
    required this.performedAt,
    this.description,
  });
}

class RecordAmendmentEntity {
  final String id;
  final String entityType;
  final String entityId;
  final String amendmentText;
  final String createdBy;
  final DateTime createdAt;

  const RecordAmendmentEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.amendmentText,
    required this.createdBy,
    required this.createdAt,
  });
}

class ExportRecordSummaryEntity {
  final int id;
  final String entityType;
  final String entityId;
  final String exportFormat;
  final String? exportLocation;
  final String exportStatus;
  final String generatedBy;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? errorMessage;
  final DateTime generatedAt;

  const ExportRecordSummaryEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.exportFormat,
    required this.exportStatus,
    required this.generatedBy,
    required this.retryCount,
    required this.generatedAt,
    this.exportLocation,
    this.lastAttemptAt,
    this.errorMessage,
  });
}

class SessionRecordViewEntity {
  final FieldSessionEntity session;
  final List<SessionUserWithUserEntity> sessionUsers;
  final List<SessionVehicleWithVehicleEntity> sessionVehicles;
  final List<SessionBatteryWithBatteryEntity> sessionBatteries;
  final List<SessionEquipmentCheckWithItemEntity> equipmentChecks;
  final List<SortieEntity> sorties;
  final Map<String, List<SortieUserWithUserEntity>> sortieUsersByFlightId;
  final Map<String, List<SortiePayloadWithPayloadEntity>> sortiePayloadsByFlightId;
  final Map<String, List<SortieBatteryWithBatteryEntity>> sortieBatteriesByFlightId;
  final Map<String, List<ChecklistResponseWithItemEntity>> checklistResponsesByFlightId;
  final Map<String, List<ChecklistOverrideEntity>> overridesByFlightId;
  final Map<String, PostFlightNoteEntity?> postFlightNotesByFlightId;
  final List<AuditEventEntity> auditTrail;
  final List<RecordAmendmentEntity> amendments;
  final List<ExportRecordSummaryEntity> exports;

  const SessionRecordViewEntity({
    required this.session,
    required this.sessionUsers,
    required this.sessionVehicles,
    required this.sessionBatteries,
    required this.equipmentChecks,
    required this.sorties,
    required this.sortieUsersByFlightId,
    required this.sortiePayloadsByFlightId,
    required this.sortieBatteriesByFlightId,
    required this.checklistResponsesByFlightId,
    required this.overridesByFlightId,
    required this.postFlightNotesByFlightId,
    required this.auditTrail,
    required this.amendments,
    required this.exports,
  });
}
