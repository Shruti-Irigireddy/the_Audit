class SyncQueueDraft {
  final String entityType;
  final String entityId;
  final String operation;

  const SyncQueueDraft({
    required this.entityType,
    required this.entityId,
    required this.operation,
  });
}

class SyncFailureDraft {
  final int syncQueueId;
  final String errorMessage;

  const SyncFailureDraft({
    required this.syncQueueId,
    required this.errorMessage,
  });
}
