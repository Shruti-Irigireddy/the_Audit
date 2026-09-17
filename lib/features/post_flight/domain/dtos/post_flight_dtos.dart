class BatteryEndStateDraft {
  final String batteryId;
  final double? voltageEnd;
  final int? percentEnd;

  const BatteryEndStateDraft({
    required this.batteryId,
    this.voltageEnd,
    this.percentEnd,
  });
}