import 'package:the_audit/core/database/daos/sync/sync_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/sync/data/mappers/sync_mapper.dart';
import 'package:the_audit/features/sync/domain/entities/sync_queue_entity.dart';
import 'package:the_audit/features/sync/domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  static const _log = AppLogger('SyncRepositoryImpl');

  final SyncDao _dao;

  const SyncRepositoryImpl(this._dao);

  @override
  Future<int> enqueueSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    bool coalesce = true,
  }) {
    _log.t(
      'enqueueSyncOperation(entityType: $entityType, entityId: $entityId)',
    );
    return _dao.enqueueSyncOperation(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      coalesce: coalesce,
    );
  }

  @override
  Future<SyncQueueEntity?> getSyncItemById(int syncId) async {
    _log.t('getSyncItemById(syncId: $syncId)');
    final item = await _dao.getSyncItemById(syncId);
    return item?.toEntity();
  }

  @override
  Future<List<SyncQueueEntity>> getPendingSyncItems({int limit = 50}) async {
    _log.t('getPendingSyncItems(limit: $limit)');
    final items = await _dao.getPendingSyncItems(limit: limit);
    _log.d('getPendingSyncItems: ${items.length} items');
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getFailedSyncItems({int limit = 50}) async {
    _log.t('getFailedSyncItems(limit: $limit)');
    final items = await _dao.getFailedSyncItems(limit: limit);
    _log.d('getFailedSyncItems: ${items.length} items');
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getInProgressSyncItems({int limit = 50}) async {
    _log.t('getInProgressSyncItems(limit: $limit)');
    final items = await _dao.getInProgressSyncItems(limit: limit);
    _log.d('getInProgressSyncItems: ${items.length} items');
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getCompletedSyncItems({int limit = 50}) async {
    _log.t('getCompletedSyncItems(limit: $limit)');
    final items = await _dao.getCompletedSyncItems(limit: limit);
    _log.d('getCompletedSyncItems: ${items.length} items');
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> getSyncItemsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    _log.t(
      'getSyncItemsForEntity(entityType: $entityType, entityId: $entityId)',
    );
    final items = await _dao.getSyncItemsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    _log.d('getSyncItemsForEntity: ${items.length} items');
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<SyncQueueEntity>> claimNextPendingBatch({int limit = 25}) async {
    _log.t('claimNextPendingBatch(limit: $limit)');
    final items = await _dao.claimNextPendingBatch(limit: limit);
    _log.d('claimNextPendingBatch: ${items.length} items');
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<void> markSyncInProgress(int syncId) {
    _log.t('markSyncInProgress(syncId: $syncId)');
    return _dao.markSyncInProgress(syncId);
  }

  @override
  Future<void> markSyncCompleted(int syncId) {
    _log.t('markSyncCompleted(syncId: $syncId)');
    return _dao.markSyncCompleted(syncId);
  }

  @override
  Future<void> markSyncFailed({
    required int syncId,
    required String errorMessage,
  }) {
    _log.t('markSyncFailed(syncId: $syncId)');
    return _dao.markSyncFailed(syncId: syncId, errorMessage: errorMessage);
  }

  @override
  Future<void> retryFailedSync(int syncId) {
    _log.t('retryFailedSync(syncId: $syncId)');
    return _dao.retryFailedSync(syncId);
  }

  @override
  Future<void> retryAllFailedSyncItems() {
    _log.t('retryAllFailedSyncItems()');
    return _dao.retryAllFailedSyncItems();
  }

  @override
  Future<void> resetAllInProgressToPending() {
    _log.t('resetAllInProgressToPending()');
    return _dao.resetAllInProgressToPending();
  }

  @override
  Future<int> countPendingSyncItems() {
    _log.t('countPendingSyncItems()');
    return _dao.countPendingSyncItems();
  }

  @override
  Future<int> countFailedSyncItems() {
    _log.t('countFailedSyncItems()');
    return _dao.countFailedSyncItems();
  }

  @override
  Future<int> countInProgressSyncItems() {
    _log.t('countInProgressSyncItems()');
    return _dao.countInProgressSyncItems();
  }

  @override
  Future<int> countCompletedSyncItems() {
    _log.t('countCompletedSyncItems()');
    return _dao.countCompletedSyncItems();
  }

  @override
  Future<bool> hasPendingOrFailedSyncItems() {
    _log.t('hasPendingOrFailedSyncItems()');
    return _dao.hasPendingOrFailedSyncItems();
  }

  @override
  Future<void> deleteCompletedSyncItems() {
    _log.t('deleteCompletedSyncItems()');
    return _dao.deleteCompletedSyncItems();
  }

  @override
  Future<void> deleteSyncItem(int syncId) {
    _log.t('deleteSyncItem(syncId: $syncId)');
    return _dao.deleteSyncItem(syncId);
  }
}
