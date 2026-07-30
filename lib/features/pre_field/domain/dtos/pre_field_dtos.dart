class SessionUserDraft {
  final String id;
  final String userId;
  final String role;

  const SessionUserDraft({
    required this.id,
    required this.userId,
    required this.role,
  });
}

class SessionVehicleDraft {
  final String id;
  final String vehicleId;
  final String? objective;

  const SessionVehicleDraft({
    required this.id,
    required this.vehicleId,
    this.objective,
  });
}

class SessionBatteryDraft {
  final String id;
  final String batteryId;

  const SessionBatteryDraft({
    required this.id,
    required this.batteryId,
  });
}
