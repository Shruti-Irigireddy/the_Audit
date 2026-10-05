class BatteryEntity{
  final String batteryId;
  final String config;
  final int? capacity;
  final double? voltage;
  final int? cycleCount;
  final String status;
  final DateTime updatedAt;
  final DateTime createdAt;

  const BatteryEntity ({
    required this.batteryId,
    required this.config,
    this.capacity,
    this.voltage,
    this.cycleCount,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
  });


  bool get isActive => status.trim().toUpperCase() == 'ACTIVE';

  bool get isRetired => status.trim().toUpperCase() == 'RETIRED';

  bool get hasCapacity => capacity != null && capacity! > 0;

  bool get hasVoltage => voltage != null && voltage! > 0;

}
