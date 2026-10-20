class FieldSessionEntity {
  final String sessionId;
  final DateTime date;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String missionType;
  final String sessionStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final String? closedBy;

  const FieldSessionEntity({
    required this.sessionId,
    required this.date,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.missionType,
    required this.sessionStatus,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.closedBy,
  });
}
