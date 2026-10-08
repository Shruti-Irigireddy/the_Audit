import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/pre_field_dtos.dart'
    as db_pre_field;
import 'package:the_audit/core/database/dtos/shared_dtos.dart' as db_shared;

import 'package:the_audit/features/auth/data/mappers/user_mapper.dart';
import 'package:the_audit/features/battery/data/mappers/battery_mapper.dart';
import 'package:the_audit/features/payload/data/mappers/payload_mapper.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/vehicle/data/mappers/vehicle_mapper.dart';

import 'package:the_audit/features/pre_field/domain/entities/field_session_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/payload_compatibility_issue_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_equipment_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_summary_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_battery_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_equipment_check_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_user_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_vehicle_entity.dart';

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

extension SessionUserDbMapper on SessionUser {
  SessionUserEntity toEntity() {
    return SessionUserEntity(
      id: id,
      sessionId: sessionId,
      userId: userId,
      role: role,
      createdAt: createdAt,
    );
  }
}

extension SessionUserWithUserDbMapper on db_shared.SessionUserWithUser {
  SessionUserWithUserEntity toEntity() {
    return SessionUserWithUserEntity(
      sessionUser: sessionUser.toEntity(),
      user: user.toEntity(),
    );
  }
}

extension SessionVehicleDbMapper on SessionVehicle {
  SessionVehicleEntity toEntity() {
    return SessionVehicleEntity(
      id: id,
      sessionId: sessionId,
      vehicleId: vehicleId,
      objective: objective,
      createdAt: createdAt,
    );
  }
}

extension SessionVehicleWithVehicleDbMapper
    on db_shared.SessionVehicleWithVehicle {
  SessionVehicleWithVehicleEntity toEntity() {
    return SessionVehicleWithVehicleEntity(
      sessionVehicle: sessionVehicle.toEntity(),
      vehicle: vehicle.toEntity(),
    );
  }
}

extension SessionBatteryDbMapper on SessionBattery {
  SessionBatteryEntity toEntity() {
    return SessionBatteryEntity(
      id: id,
      sessionId: sessionId,
      batteryId: batteryId,
      createdAt: createdAt,
    );
  }
}

extension SessionBatteryWithBatteryDbMapper
    on db_shared.SessionBatteryWithBattery {
  SessionBatteryWithBatteryEntity toEntity() {
    return SessionBatteryWithBatteryEntity(
      sessionBattery: sessionBattery.toEntity(),
      battery: battery.toEntity(),
    );
  }
}

extension EquipmentListDbMapper on EquipmentList {
  PreFieldEquipmentEntity toPreFieldEntity() {
    return PreFieldEquipmentEntity(
      id: id,
      name: name,
      category: category,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }
}

extension SessionEquipmentCheckDbMapper on SessionEquipmentCheck {
  SessionEquipmentCheckEntity toEntity() {
    return SessionEquipmentCheckEntity(
      id: id,
      sessionId: sessionId,
      equipmentId: equipmentId,
      isPacked: isPacked,
      notes: notes,
      checkedAt: checkedAt,
      checkedBy: checkedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension SessionEquipmentCheckWithItemDbMapper
    on db_shared.SessionEquipmentCheckWithItem {
  SessionEquipmentCheckWithItemEntity toEntity() {
    return SessionEquipmentCheckWithItemEntity(
      sessionEquipmentCheck: sessionEquipmentCheck.toEntity(),
      equipmentList: equipmentList.toPreFieldEntity(),
    );
  }
}

extension PayloadCompatibilityIssueDbMapper
    on db_pre_field.PayloadCompatibilityIssue {
  PayloadCompatibilityIssueEntity toEntity() {
    return PayloadCompatibilityIssueEntity(
      vehicleId: vehicleId,
      sessionVehicleId: sessionVehicleId,
      vehicleName: vehicleName,
      vehicleType: vehicleType,
      payloadId: payloadId,
      payloadName: payloadName,
      message: message,
    );
  }
}

extension PreFieldSummaryDataDbMapper on db_pre_field.PreFieldSummaryData {
  PreFieldSummaryEntity toEntity() {
    return PreFieldSummaryEntity(
      session: session.toEntity(),
      teamMembers: teamMembers.map((item) => item.toEntity()).toList(),
      vehicles: vehicles.map((item) => item.toEntity()).toList(),
      batteries: batteries.map((item) => item.toEntity()).toList(),
      equipmentChecks: equipmentChecks.map((item) => item.toEntity()).toList(),
      payloadCompatibilityIssues: payloadCompatibilityIssues
          .map((item) => item.toEntity())
          .toList(),
    );
  }
}

extension PayloadListDbMapper on List<Payload> {
  List<PayloadEntity> toPayloadEntities() {
    return map((payload) => payload.toEntity()).toList();
  }
}
