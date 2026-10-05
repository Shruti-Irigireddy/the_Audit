class VehicleEntity {
  final String id;
  final String name;
  final String type;
  final String? frameMake;
  final String? frameModel;
  final int? motorCount;
  final String? frameStyle;
  final String? firmwareTarget;
  final String? defaultFailSafeProfile;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VehicleEntity ({
    required this.id,
    required this.name,
    required this.type,
    this.frameMake,
    this.frameModel,
    this.motorCount,
    this.frameStyle,
    this.firmwareTarget,
    this.defaultFailSafeProfile,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
}
