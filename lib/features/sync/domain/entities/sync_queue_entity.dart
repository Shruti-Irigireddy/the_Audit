class SyncQueueEntity {
  final int id;
  final String entityType;
  final String entityId;
  final String operation;
  final String syncStatus;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncQueueEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.syncStatus,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastAttemptAt,
    this.syncedAt,
    this.errorMessage,
  });

  bool get isPending => syncStatus == 'PENDING';

  bool get isInProgress => syncStatus == 'IN_PROGRESS';

  bool get isFailed => syncStatus == 'FAILED';

  bool get isCompleted => syncStatus == 'COMPLETED';

  bool get canRetry => isFailed;
}