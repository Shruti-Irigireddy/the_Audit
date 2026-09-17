import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';

class SortieUserDraft {
  final String id;
  final String userId;
  final String role;

  const SortieUserDraft({
    required this.id,
    required this.userId,
    required this.role,
  });
}

class SortieBatteryDraft {
  final String id;
  final String batteryId;
  final double? voltageStart;
  final int? percentStart;

  const SortieBatteryDraft({
    required this.id,
    required this.batteryId,
    this.voltageStart,
    this.percentStart,
  });
}

class BatteryStartDefaults {
  final double? voltageStart;
  final int? percentStart;
  final String sourceFlightId;

  const BatteryStartDefaults({
    required this.voltageStart,
    required this.percentStart,
    required this.sourceFlightId,
  });
}

class ChecklistResponseDraft {
  final String itemId;
  final String response;
  final String? valueText;
  final double? valueNumber;
  final String? notes;

  const ChecklistResponseDraft({
    required this.itemId,
    required this.response,
    this.valueText,
    this.valueNumber,
    this.notes,
  });
}

class BlockingChecklistIssue {
  final ChecklistItem item;
  final ChecklistResponse? response;
  final bool hasOverride;
  final String reason;

  const BlockingChecklistIssue({
    required this.item,
    required this.response,
    required this.hasOverride,
    required this.reason,
  });
}

class ReadyToArmValidationResult {
  final bool canProceed;
  final List<BlockingChecklistIssue> missingItems;
  final List<BlockingChecklistIssue> failedItems;
  final List<ChecklistOverride> overrides;

  const ReadyToArmValidationResult({
    required this.canProceed,
    required this.missingItems,
    required this.failedItems,
    required this.overrides,
  });
}

class PreFlightSetupData {
  final Sorty sortie;
  final SessionVehicle sessionVehicle;
  final Vehicle vehicle;
  final List<ChecklistItem> checklistItems;
  final List<SortiePayloadWithPayload> payloads;
  final List<SortieBatteryWithBattery> batteries;
  final List<SortieUserWithUser> crew;
  final List<ChecklistResponseWithItem> responses;
  final List<ChecklistOverride> overrides;

  const PreFlightSetupData({
    required this.sortie,
    required this.sessionVehicle,
    required this.vehicle,
    required this.checklistItems,
    required this.payloads,
    required this.batteries,
    required this.crew,
    required this.responses,
    required this.overrides,
  });
}
