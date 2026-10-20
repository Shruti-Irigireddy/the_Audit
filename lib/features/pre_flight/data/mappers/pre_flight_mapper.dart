import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/pre_flight_dtos.dart'
    as db_pre_flight;
import 'package:the_audit/core/database/dtos/shared_dtos.dart' as db_shared;

import 'package:the_audit/features/auth/data/mappers/user_mapper.dart';
import 'package:the_audit/features/battery/data/mappers/battery_mapper.dart';
import 'package:the_audit/features/payload/data/mappers/payload_mapper.dart';
import 'package:the_audit/features/pre_field/data/mappers/pre_field_mapper.dart';
import 'package:the_audit/features/vehicle/data/mappers/vehicle_mapper.dart';

import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/pre_flight/domain/dtos/pre_flight_dtos.dart';
import 'package:the_audit/features/pre_flight/domain/entities/blocking_checklist_issue_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_override_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/pre_flight_setup_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/ready_to_arm_validation_result_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_user_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';

extension SortieDbMapper on Sorty {
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
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
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

extension SortieUserDbMapper on SortieUser {
  SortieUserEntity toEntity() {
    return SortieUserEntity(
      id: id,
      flightId: flightId,
      userId: userId,
      role: role,
      createdAt: createdAt,
    );
  }
}

extension SortieUserWithUserDbMapper on db_shared.SortieUserWithUser {
  SortieUserWithUserEntity toEntity() {
    return SortieUserWithUserEntity(
      sortieUser: sortieUser.toEntity(),
      user: user.toEntity(),
    );
  }
}

extension SortiePayloadDbMapper on SortiePayload {
  SortiePayloadEntity toEntity() {
    return SortiePayloadEntity(
      id: id,
      flightId: flightId,
      payloadId: payloadId,
      createdAt: createdAt,
    );
  }
}

extension SortiePayloadWithPayloadDbMapper
    on db_shared.SortiePayloadWithPayload {
  SortiePayloadWithPayloadEntity toEntity() {
    return SortiePayloadWithPayloadEntity(
      sortiePayload: sortiePayload.toEntity(),
      payload: payload.toEntity(),
    );
  }
}

extension SortieBatteryDbMapper on SortieBattery {
  SortieBatteryEntity toEntity() {
    return SortieBatteryEntity(
      id: id,
      flightId: flightId,
      batteryId: batteryId,
      voltageStart: voltageStart,
      voltageEnd: voltageEnd,
      percentStart: percentStart,
      percentEnd: percentEnd,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension SortieBatteryWithBatteryDbMapper
    on db_shared.SortieBatteryWithBattery {
  SortieBatteryWithBatteryEntity toEntity() {
    return SortieBatteryWithBatteryEntity(
      sortieBattery: sortieBattery.toEntity(),
      battery: battery.toEntity(),
    );
  }
}

extension ChecklistResponseDbMapper on ChecklistResponse {
  ChecklistResponseEntity toEntity() {
    return ChecklistResponseEntity(
      id: id,
      flightId: flightId,
      itemId: itemId,
      response: response,
      valueText: valueText,
      valueNumber: valueNumber,
      notes: notes,
      createdBy: createdBy,
      responseAt: responseAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension ChecklistResponseWithItemDbMapper
    on db_shared.ChecklistResponseWithItem {
  ChecklistResponseWithItemEntity toEntity() {
    return ChecklistResponseWithItemEntity(
      checklistResponse: response.toEntity(),
      checklistItem: item.toEntity(),
    );
  }
}

extension ChecklistOverrideDbMapper on ChecklistOverride {
  ChecklistOverrideEntity toEntity() {
    return ChecklistOverrideEntity(
      id: id,
      flightId: flightId,
      itemId: itemId,
      checklistResponseId: checklistResponseId ?? '',
      overrideReason: overrideReason,
      overriddenBy: overriddenBy,
      createdAt: createdAt,
    );
  }
}

extension BlockingChechlistIssueDbMapper
    on db_pre_flight.BlockingChecklistIssue {
  BlockingChecklistIssueEntity toEntity() {
    return BlockingChecklistIssueEntity(
      checklistItem: item.toEntity(),
      checklistResponse: response?.toEntity(),
      hasOverride: hasOverride,
      reason: reason,
    );
  }
}

extension ReadyToArmValidationResultDbMapper
    on db_pre_flight.ReadyToArmValidationResult {
  ReadyToArmValidationResultEntity toEntity() {
    return ReadyToArmValidationResultEntity(
      canProceed: canProceed,
      missingItems: missingItems.map((item) => item.toEntity()).toList(),
      failedItems: failedItems.map((item) => item.toEntity()).toList(),
      overrides: overrides.map((item) => item.toEntity()).toList(),
    );
  }
}

extension PreFlightSetupDataDbMapper on db_pre_flight.PreFlightSetupData {
  PreFlightSetupEntity toEntity() {
    return PreFlightSetupEntity(
      sortie: sortie.toEntity(),
      sessionVehicle: sessionVehicle.toEntity(),
      vehicle: vehicle.toEntity(),
      checklistItems: checklistItems.map((item) => item.toEntity()).toList(),
      payloads: payloads.map((item) => item.toEntity()).toList(),
      batteries: batteries.map((item) => item.toEntity()).toList(),
      crew: crew.map((item) => item.toEntity()).toList(),
      responses: responses.map((item) => item.toEntity()).toList(),
      overrides: overrides.map((item) => item.toEntity()).toList(),
    );
  }
}

extension BatteryStartDefaultDbMapper on db_pre_flight.BatteryStartDefaults {
  BatteryStartDefaults toDomainDto() {
    return BatteryStartDefaults(
      voltageStart: voltageStart,
      percentStart: percentStart,
      sourceFlightId: sourceFlightId,
    );
  }
}

extension PayloadListDbMapper on List<Payload> {
  List<PayloadEntity> toPayloadEntities() {
    return map((payload) => payload.toEntity()).toList();
  }
}

extension BatteryListDbMapper on List<Battery> {
  List<BatteryEntity> toBatteryEntities() {
    return map((battery) => battery.toEntity()).toList();
  }
}

extension ChecklistItemListDbMapper on List<ChecklistItem> {
  List<ChecklistItemEntity> toChecklistItemEntities() {
    return map((item) => item.toEntity()).toList();
  }
}

extension ChecklistOverrideListDbMapper on List<ChecklistOverride> {
  List<ChecklistOverrideEntity> toChecklistOverrideEntities() {
    return map((item) => item.toEntity()).toList();
  }
}
