class PostFlightNoteEntity {
  final String id;
  final String flightId;
  final String? objectiveNotes;
  final String objectiveResult;
  final String? missionRating;
  final String? issueEncountered;
  final String? logStoredAt;
  final String? logLocation;
  final String? logNotes;
  final int? flightDurationSeconds;
  final double? landedBatteryVoltage;
  final int? landedBatteryPercent;
  final bool followUpRequired;
  final String? followUpNotes;
  final String? followUpAssignedTo;
  final DateTime? followUpDueDate;
  final String? followUpStatus;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostFlightNoteEntity ({
    required this.id,
    required this.flightId,
    this.objectiveNotes,
    required this.objectiveResult,
    this.missionRating,
    this.issueEncountered,
    this.logStoredAt,
    this.logLocation,
    this.logNotes,
    this.flightDurationSeconds,
    this.landedBatteryVoltage,
    this.landedBatteryPercent,
    required this.followUpRequired,
    this.followUpNotes,
    this.followUpAssignedTo,
    this.followUpDueDate,
    this.followUpStatus,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
}
