class VehicleChecklistTemplateEntity {
  final String id;
  final String vehicleId;
  final int version;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deactivatedAt;
  final String? deactivatedBy;
  final String? deactivationReason;

  const VehicleChecklistTemplateEntity({
    required this.id,
    required this.vehicleId,
    required this.version,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deactivatedAt,
    this.deactivatedBy,
    this.deactivationReason,
  });
}
