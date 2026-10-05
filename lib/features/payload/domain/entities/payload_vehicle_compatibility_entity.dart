class PayloadVehicleCompatibilityEntity {
  final String id;
  final String payloadId;
  final String vehicleType;
  final DateTime createdAt;

  const PayloadVehicleCompatibilityEntity({
    required this.id,
    required this.payloadId,
    required this.vehicleType,
    required this.createdAt,
  });
}
