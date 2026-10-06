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
