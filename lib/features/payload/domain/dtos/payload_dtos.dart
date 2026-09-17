class PayloadDraft {
  final String payloadId;
  final String name;
  final String category;
  final String? storageType;
  final String? storageCapacity;
  final String? status;
  final List<String> compatibleVehicleTypes;

  const PayloadDraft({
    required this.payloadId,
    required this.name,
    required this.category,
    this.storageType,
    this.storageCapacity,
    this.status,
    this.compatibleVehicleTypes = const [],
  });
}

class PayloadUpdateDraft {
  final String payloadId;
  final String? name;
  final String? category;
  final String? storageType;
  final String? storageCapacity;
  final String? status;

  const PayloadUpdateDraft({
    required this.payloadId,
    this.name,
    this.category,
    this.storageType,
    this.storageCapacity,
    this.status,
  });
}

class PayloadCompatibilityDraft {
  final String payloadId;
  final String vehicleType;

  const PayloadCompatibilityDraft({
    required this.payloadId,
    required this.vehicleType,
  });
}

class PayloadCompatibilitySetDraft {
  final String payloadId;
  final List<String> compatibleVehicleTypes;

  const PayloadCompatibilitySetDraft({
    required this.payloadId,
    required this.compatibleVehicleTypes,
  });
}
