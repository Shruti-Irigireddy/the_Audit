class ExportEntity {
  final int id;
  final String entityType;
  final String entityId;
  final String exportFormat;
  final String? exportLocation;
  final String exportStatus;
  final String generatedBy;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? errorMessage;
  final DateTime generatedAt;

  const ExportEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.exportFormat,
    required this.exportStatus,
    required this.generatedBy,
    required this.retryCount,
    required this.generatedAt,
    this.exportLocation,
    this.lastAttemptAt,
    this.errorMessage,
  });

  bool get isPending => exportStatus == 'PENDING';

  bool get isInProgress => exportStatus == 'IN_PROGRESS';

  bool get isCompleted => exportStatus == 'COMPLETED';

  bool get isFailed => exportStatus == 'FAILED';

  bool get canRetry => isFailed;
}
