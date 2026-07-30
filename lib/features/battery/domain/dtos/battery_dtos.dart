class BatteryDraft {
  final String batteryId;
  final String config;
  final int? capacity;
  final double? voltage;
  final int? cycleCount;
  final String status;

  const BatteryDraft({
    required this.batteryId,
    required this.config,
    required this.status,
    this.capacity,
    this.voltage,
    this.cycleCount,
  });
}

class BatteryUpdateDraft {
  final String batteryId;
  final String? config;
  final int? capacity;
  final double? voltage;
  final int? cycleCount;
  final String? status;

  const BatteryUpdateDraft({
    required this.batteryId,
    this.config,
    this.capacity,
    this.voltage,
    this.cycleCount,
    this.status,
  });
}

class BatteryStatusDraft {
  final String batteryId;
  final String status;

  const BatteryStatusDraft({
    required this.batteryId,
    required this.status,
  });
}
