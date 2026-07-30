import 'package:the_audit/core/database/daos/sync/sync_dao.dart';
import 'package:the_audit/features/sync/data/mappers/sync_mapper.dart';
import 'package:the_audit/features/sync/domain/entities/sync_queue_entity.dart';
import 'package:the_audit/features/sync/domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  final SyncDao _dao;

  const SyncRepositoryImpl(this._dao);

  @override
  Future<int> enqueueSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    bool coalesce = true,
  }) {
    return _dao.enqueueSyncOperation(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      coalesce: coalesce,
    );
  }

  @override
  Future<SyncQueueEntity?> getSyncItemById(int syncId) async {
    final item = await _dao.getSyncItemById(syncId);
    return item?.toEntity();
  }

  @override
  Future<List<SyncQueueEntity>> getPendingSyncItems({int limit = 50}) async {
    final items = await _dao.getPendingSyncItems(limit: limit);
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getFailedSyncItems({int limit = 50}) async {
    final items = await _dao.getFailedSyncItems(limit: limit);
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getInProgressSyncItems({
    int limit = 50,
  }) async {
    final items = await _dao.getInProgressSyncItems(limit: limit);
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getCompletedSyncItems({
    int limit = 50,
  }) async {
    final items = await _dao.getCompletedSyncItems(limit: limit);
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getSyncItemsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    final items = await _dao.getSyncItemsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> claimNextPendingBatch({
    int limit = 25,
  }) async {
    final items = await _dao.claimNextPendingBatch(limit: limit);
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<void> markSyncInProgress(int syncId) {
    return _dao.markSyncInProgress(syncId);
  }

  @override
  Future<void> markSyncCompleted(int syncId) {
    return _dao.markSyncCompleted(syncId);
  }

  @override
  Future<void> markSyncFailed({
    required int syncId,
    required String errorMessage,
  }) {
    return _dao.markSyncFailed(syncId: syncId, errorMessage: errorMessage);
  }

  @override
  Future<void> retryFailedSync(int syncId) {
    return _dao.retryFailedSync(syncId);
  }

  @override
  Future<void> retryAllFailedSyncItems() {
    return _dao.retryAllFailedSyncItems();
  }

  @override
  Future<void> resetAllInProgressToPending() {
    return _dao.resetAllInProgressToPending();
  }

  @override
  Future<int> countPendingSyncItems() {
    return _dao.countPendingSyncItems();
  }

  @override
  Future<int> countFailedSyncItems() {
    return _dao.countFailedSyncItems();
  }

  @override
  Future<int> countInProgressSyncItems() {
    return _dao.countInProgressSyncItems();
  }

  @override
  Future<int> countCompletedSyncItems() {
    return _dao.countCompletedSyncItems();
  }

  @override
  Future<bool> hasPendingOrFailedSyncItems() {
    return _dao.hasPendingOrFailedSyncItems();
  }

  @override
  Future<void> deleteCompletedSyncItems() {
    return _dao.deleteCompletedSyncItems();
  }

  @override
  Future<void> deleteSyncItem(int syncId) {
    return _dao.deleteSyncItem(syncId);
  }
}
