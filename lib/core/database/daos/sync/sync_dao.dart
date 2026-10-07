import 'package:drift/drift.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  static const _log = AppLogger('SyncDao');

  Future<int> enqueueSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    bool coalesce = true,
  }) async {
    _log.t(
      'enqueueSyncOperation(entityType: $entityType, entityId: $entityId, '
      'operation: $operation, coalesce: $coalesce)',
    );
    return _log.trace('enqueueSyncOperation', () async {
      final normalizedEntityType = entityType.trim().toUpperCase();
      final normalizedOperation = operation.trim().toUpperCase();

      _validateOperation(normalizedOperation);

      if (!coalesce) {
        _log.d('Enqueueing without coalescing');
        return into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            entityType: normalizedEntityType,
            entityId: entityId,
            operation: normalizedOperation,
            syncStatus: const Value('PENDING'),
          ),
        );
      }

      final existing =
          await (select(db.syncQueue)
                ..where(
                  (v) =>
                      v.entityType.equals(normalizedEntityType) &
                      v.entityId.equals(entityId) &
                      v.syncStatus.equals('PENDING'),
                )
                ..orderBy([(v) => OrderingTerm.desc(v.updatedAt)])
                ..limit(1))
              .getSingleOrNull();

      if (existing == null) {
        _log.d('No pending item to coalesce, inserting new');
        return into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            entityType: normalizedEntityType,
            entityId: entityId,
            operation: normalizedOperation,
            syncStatus: const Value('PENDING'),
          ),
        );
      }

      final resolvedOperation = _resolveCoalescedOperation(
        oldOperation: existing.operation,
        newOperation: normalizedOperation,
      );
      _log.d(
        'Coalescing into sync item ${existing.id}: '
        '${existing.operation} + $normalizedOperation -> $resolvedOperation',
      );

      await (update(
        db.syncQueue,
      )..where((v) => v.id.equals(existing.id))).write(
        SyncQueueCompanion(
          operation: Value(resolvedOperation),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return existing.id;
    });
  }

  Future<SyncQueueData?> getSyncItemById(int syncId) {
    _log.t('getSyncItemById(syncId: $syncId)');
    return (select(
      db.syncQueue,
    )..where((v) => v.id.equals(syncId))).getSingleOrNull();
  }

  Future<List<SyncQueueData>> getPendingSyncItems({int limit = 50}) {
    _log.t('getPendingSyncItems(limit: $limit)');
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('PENDING'))
          ..orderBy([(v) => OrderingTerm.asc(v.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getFailedSyncItems({int limit = 50}) {
    _log.t('getFailedSyncItems(limit: $limit)');
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('FAILED'))
          ..orderBy([(v) => OrderingTerm.desc(v.lastAttemptAt)])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getInProgressSyncItems({int limit = 50}) {
    _log.t('getInProgressSyncItems(limit: $limit)');
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('IN_PROGRESS'))
          ..orderBy([(v) => OrderingTerm.asc(v.updatedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getCompletedSyncItems({int limit = 50}) {
    _log.t('getCompletedSyncItems(limit: $limit)');
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('COMPLETED'))
          ..orderBy([(v) => OrderingTerm.desc(v.syncedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getSyncItemsForEntity({
    required String entityType,
    required String entityId,
  }) {
    _log.t(
      'getSyncItemsForEntity(entityType: $entityType, entityId: $entityId)',
    );
    final normalizedEntityType = entityType.trim().toUpperCase();

    return (select(db.syncQueue)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId),
          )
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .get();
  }

  Future<List<SyncQueueData>> claimNextPendingBatch({int limit = 25}) async {
    _log.t('claimNextPendingBatch(limit: $limit)');
    return _log.trace('claimNextPendingBatch', () async {
      return transaction(() async {
        final items = await getPendingSyncItems(limit: limit);

        for (final item in items) {
          await (update(
            db.syncQueue,
          )..where((v) => v.id.equals(item.id))).write(
            SyncQueueCompanion(
              syncStatus: const Value('IN_PROGRESS'),
              lastAttemptAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }

        _log.d('Claimed ${items.length} pending sync items');
        return items;
      });
    });
  }

  Future<void> markSyncInProgress(int syncId) async {
    _log.t('markSyncInProgress(syncId: $syncId)');
    return _log.trace('markSyncInProgress', () async {
      await _requireSyncItem(syncId);

      await (update(db.syncQueue)..where((v) => v.id.equals(syncId))).write(
        SyncQueueCompanion(
          syncStatus: const Value('IN_PROGRESS'),
          lastAttemptAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> markSyncCompleted(int syncId) async {
    _log.t('markSyncCompleted(syncId: $syncId)');
    return _log.trace('markSyncCompleted', () async {
      await _requireSyncItem(syncId);

      await (update(db.syncQueue)..where((v) => v.id.equals(syncId))).write(
        SyncQueueCompanion(
          syncStatus: const Value('COMPLETED'),
          syncedAt: Value(DateTime.now()),
          errorMessage: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> markSyncFailed({
    required int syncId,
    required String errorMessage,
  }) async {
    _log.t('markSyncFailed(syncId: $syncId)');
    return _log.trace('markSyncFailed', () async {
      final item = await _requireSyncItem(syncId);

      if (errorMessage.trim().isEmpty) {
        _log.w('Sync failure reason cannot be empty: $syncId');
        throw AppFailure('Sync failure reason cannot be empty.');
      }

      await (update(db.syncQueue)..where((v) => v.id.equals(syncId))).write(
        SyncQueueCompanion(
          syncStatus: const Value('FAILED'),
          retryCount: Value(item.retryCount + 1),
          lastAttemptAt: Value(DateTime.now()),
          errorMessage: Value(errorMessage),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> retryFailedSync(int syncId) async {
    _log.t('retryFailedSync(syncId: $syncId)');
    return _log.trace('retryFailedSync', () async {
      final item = await _requireSyncItem(syncId);

      if (item.syncStatus != 'FAILED') {
        _log.w('Only failed sync items can be retried: $syncId');
        throw AppFailure('Only failed sync items can be retried.');
      }

      await (update(db.syncQueue)..where((v) => v.id.equals(syncId))).write(
        SyncQueueCompanion(
          syncStatus: const Value('PENDING'),
          errorMessage: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> retryAllFailedSyncItems() async {
    _log.t('retryAllFailedSyncItems()');
    return _log.trace('retryAllFailedSyncItems', () async {
      await (update(
        db.syncQueue,
      )..where((v) => v.syncStatus.equals('FAILED'))).write(
        SyncQueueCompanion(
          syncStatus: const Value('PENDING'),
          errorMessage: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> resetAllInProgressToPending() async {
    _log.t('resetAllInProgressToPending()');
    return _log.trace('resetAllInProgressToPending', () async {
      await (update(
        db.syncQueue,
      )..where((v) => v.syncStatus.equals('IN_PROGRESS'))).write(
        SyncQueueCompanion(
          syncStatus: const Value('PENDING'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<int> countPendingSyncItems() {
    _log.t('countPendingSyncItems()');
    return _countByStatus('PENDING');
  }

  Future<int> countFailedSyncItems() {
    _log.t('countFailedSyncItems()');
    return _countByStatus('FAILED');
  }

  Future<int> countInProgressSyncItems() {
    _log.t('countInProgressSyncItems()');
    return _countByStatus('IN_PROGRESS');
  }

  Future<int> countCompletedSyncItems() {
    _log.t('countCompletedSyncItems()');
    return _countByStatus('COMPLETED');
  }

  Future<bool> hasPendingOrFailedSyncItems() async {
    _log.t('hasPendingOrFailedSyncItems()');
    final pending = await countPendingSyncItems();
    final failed = await countFailedSyncItems();

    return pending > 0 || failed > 0;
  }

  Future<void> deleteCompletedSyncItems() {
    _log.t('deleteCompletedSyncItems()');
    return _log.trace(
      'deleteCompletedSyncItems',
      () => (delete(
        db.syncQueue,
      )..where((v) => v.syncStatus.equals('COMPLETED'))).go(),
    );
  }

  Future<void> deleteSyncItem(int syncId) {
    _log.t('deleteSyncItem(syncId: $syncId)');
    return _log.trace(
      'deleteSyncItem',
      () => (delete(db.syncQueue)..where((v) => v.id.equals(syncId))).go(),
    );
  }

  Future<SyncQueueData> _requireSyncItem(int syncId) async {
    final item = await getSyncItemById(syncId);

    if (item == null) {
      _log.w('Sync item not found: $syncId');
      throw AppFailure('Sync item not found: $syncId');
    }

    return item;
  }

  Future<int> _countByStatus(String status) async {
    final normalizedStatus = status.trim().toUpperCase();
    final countExp = db.syncQueue.id.count();

    final query = selectOnly(db.syncQueue)
      ..addColumns([countExp])
      ..where(db.syncQueue.syncStatus.equals(normalizedStatus));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  void _validateOperation(String operation) {
    if (operation != 'INSERT' &&
        operation != 'UPDATE' &&
        operation != 'DELETE') {
      _log.w('Invalid sync operation: $operation');
      throw AppFailure('Sync operation must be INSERT, UPDATE, or DELETE.');
    }
  }

  String _resolveCoalescedOperation({
    required String oldOperation,
    required String newOperation,
  }) {
    final oldValue = oldOperation.trim().toUpperCase();
    final newValue = newOperation.trim().toUpperCase();

    if (newValue == 'DELETE') {
      return 'DELETE';
    }

    if (oldValue == 'INSERT' && newValue == 'UPDATE') {
      return 'INSERT';
    }

    if (oldValue == 'INSERT' && newValue == 'DELETE') {
      return 'DELETE';
    }

    return newValue;
  }
}
