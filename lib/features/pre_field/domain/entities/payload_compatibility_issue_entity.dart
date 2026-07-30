class PayloadCompatibilityIssueEntity {
  final String vehicleId;
  final String sessionVehicleId;
  final String vehicleName;
  final String vehicleType;
  final String payloadId;
  final String payloadName;
  final String message;

  const PayloadCompatibilityIssueEntity({
    required this.vehicleId,
    required this.sessionVehicleId,
    required this.vehicleName,
    required this.vehicleType,
    required this.payloadId,
    required this.payloadName,
    required this.message,
  });
}
