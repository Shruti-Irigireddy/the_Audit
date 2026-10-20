class SortieEntity {
  final String flightId;
  final String sessionId;
  final int sequenceNo;
  final String sessionVehicleId;
  final String picUserId;
  final String? objective;
  final String checklistTemplateId;
  final int checklistTemplateVersion;
  final DateTime? takeoffAt;
  final DateTime? landingAt;

  /// Take-off location, set in pre-flight.
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String flightStatus;
  final DateTime? closedAt;
  final String? closedBy;
  final String? finalDecision;
  final String? decisionReason;
  final String? decisionBy;
  final DateTime? decisionAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SortieEntity({
    required this.flightId,
    required this.sessionId,
    required this.sequenceNo,
    required this.sessionVehicleId,
    required this.picUserId,
    this.objective,
    required this.checklistTemplateId,
    required this.checklistTemplateVersion,
    this.takeoffAt,
    this.landingAt,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.flightStatus,
    this.closedAt,
    this.closedBy,
    this.finalDecision,
    this.decisionReason,
    this.decisionBy,
    this.decisionAt,
    required this.createdAt,
    required this.updatedAt,
  });
}
