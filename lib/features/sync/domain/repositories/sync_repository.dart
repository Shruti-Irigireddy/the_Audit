import 'package:the_audit/features/sync/domain/entities/sync_queue_entity.dart';

abstract class SyncRepository {

  Future<int> enqueueSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    bool coalesce = true,
  });

  Future<SyncQueueEntity?> getSyncItemById(int syncId);

  Future<List<SyncQueueEntity>> getPendingSyncItems({
    int limit = 50,
  });

  Future<List<SyncQueueEntity>> getFailedSyncItems({
    int limit = 50,
  });

  Future<List<SyncQueueEntity>> getInProgressSyncItems({
    int limit = 50,
  });

  Future<List<SyncQueueEntity>> getCompletedSyncItems({
    int limit = 50,
  });

  Future<List<SyncQueueEntity>> getSyncItemsForEntity({
    required String entityType,
    required String entityId,
  });

  Future<List<SyncQueueEntity>> claimNextPendingBatch({
    int limit = 25,
  });

  Future<void> markSyncInProgress(int syncId);

  Future<void> markSyncCompleted(int syncId);

  Future<void> markSyncFailed({
    required int syncId,
    required String errorMessage,
  });

  Future<void> retryFailedSync(int syncId);

  Future<void> retryAllFailedSyncItems();

  Future<void> resetAllInProgressToPending();

  Future<int> countPendingSyncItems();

  Future<int> countFailedSyncItems();

  Future<int> countInProgressSyncItems();

  Future<int> countCompletedSyncItems();

  Future<bool> hasPendingOrFailedSyncItems();

  Future<void> deleteCompletedSyncItems();

  Future<void> deleteSyncItem(int syncId);
}