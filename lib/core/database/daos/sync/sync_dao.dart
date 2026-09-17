import 'package:drift/drift.dart';

import 'package:the_audit/core/database/app_database.dart';

part 'sync_dao.g.dart';

@DriftAccessor(
  tables: [
    SyncQueue,
  ],
)
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  Future<int> enqueueSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    bool coalesce = true,
  }) async {
    final normalizedEntityType = entityType.trim().toUpperCase();
    final normalizedOperation = operation.trim().toUpperCase();

    _validateOperation(normalizedOperation);

    if (!coalesce) {
      return into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          entityType: normalizedEntityType,
          entityId: entityId,
          operation: normalizedOperation,
          syncStatus: const Value('PENDING'),
        ),
      );
    }

    final existing = await (select(db.syncQueue)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId) &
                v.syncStatus.equals('PENDING'),
          )
          ..orderBy([
            (v) => OrderingTerm.desc(v.updatedAt),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (existing == null) {
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

    await (update(db.syncQueue)..where((v) => v.id.equals(existing.id))).write(
      SyncQueueCompanion(
        operation: Value(resolvedOperation),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return existing.id;
  }

  Future<SyncQueueData?> getSyncItemById(int syncId) {
    return (select(db.syncQueue)..where((v) => v.id.equals(syncId)))
        .getSingleOrNull();
  }

  Future<List<SyncQueueData>> getPendingSyncItems({int limit = 50}) {
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('PENDING'))
          ..orderBy([
            (v) => OrderingTerm.asc(v.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getFailedSyncItems({int limit = 50}) {
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('FAILED'))
          ..orderBy([
            (v) => OrderingTerm.desc(v.lastAttemptAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getInProgressSyncItems({int limit = 50}) {
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('IN_PROGRESS'))
          ..orderBy([
            (v) => OrderingTerm.asc(v.updatedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getCompletedSyncItems({int limit = 50}) {
    return (select(db.syncQueue)
          ..where((v) => v.syncStatus.equals('COMPLETED'))
          ..orderBy([
            (v) => OrderingTerm.desc(v.syncedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<SyncQueueData>> getSyncItemsForEntity({
    required String entityType,
    required String entityId,
  }) {
    final normalizedEntityType = entityType.trim().toUpperCase();

    return (select(db.syncQueue)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId),
          )
          ..orderBy([
            (v) => OrderingTerm.desc(v.createdAt),
          ]))
        .get();
  }

  Future<List<SyncQueueData>> claimNextPendingBatch({
    int limit = 25,
  }) async {
    return transaction(() async {
      final items = await getPendingSyncItems(limit: limit);

      for (final item in items) {
        await (update(db.syncQueue)..where((v) => v.id.equals(item.id))).write(
          SyncQueueCompanion(
            syncStatus: const Value('IN_PROGRESS'),
            lastAttemptAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      return items;
    });
  }

  Future<void> markSyncInProgress(int syncId) async {
    await _requireSyncItem(syncId);

    await (update(db.syncQueue)..where((v) => v.id.equals(syncId))).write(
      SyncQueueCompanion(
        syncStatus: const Value('IN_PROGRESS'),
        lastAttemptAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markSyncCompleted(int syncId) async {
    await _requireSyncItem(syncId);

    await (update(db.syncQueue)..where((v) => v.id.equals(syncId))).write(
      SyncQueueCompanion(
        syncStatus: const Value('COMPLETED'),
        syncedAt: Value(DateTime.now()),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markSyncFailed({
    required int syncId,
    required String errorMessage,
  }) async {
    final item = await _requireSyncItem(syncId);

    if (errorMessage.trim().isEmpty) {
      throw Exception('Sync failure reason cannot be empty.');
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
  }

  Future<void> retryFailedSync(int syncId) async {
    final item = await _requireSyncItem(syncId);

    if (item.syncStatus != 'FAILED') {
      throw Exception('Only failed sync items can be retried.');
    }

    await (update(db.syncQueue)..where((v) => v.id.equals(syncId))).write(
      SyncQueueCompanion(
        syncStatus: const Value('PENDING'),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> retryAllFailedSyncItems() async {
    await (update(db.syncQueue)
          ..where((v) => v.syncStatus.equals('FAILED')))
        .write(
      SyncQueueCompanion(
        syncStatus: const Value('PENDING'),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> resetAllInProgressToPending() async {
    await (update(db.syncQueue)
          ..where((v) => v.syncStatus.equals('IN_PROGRESS')))
        .write(
      SyncQueueCompanion(
        syncStatus: const Value('PENDING'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countPendingSyncItems() {
    return _countByStatus('PENDING');
  }

  Future<int> countFailedSyncItems() {
    return _countByStatus('FAILED');
  }

  Future<int> countInProgressSyncItems() {
    return _countByStatus('IN_PROGRESS');
  }

  Future<int> countCompletedSyncItems() {
    return _countByStatus('COMPLETED');
  }

  Future<bool> hasPendingOrFailedSyncItems() async {
    final pending = await countPendingSyncItems();
    final failed = await countFailedSyncItems();

    return pending > 0 || failed > 0;
  }

  Future<void> deleteCompletedSyncItems() {
    return (delete(db.syncQueue)
          ..where((v) => v.syncStatus.equals('COMPLETED')))
        .go();
  }

  Future<void> deleteSyncItem(int syncId) {
    return (delete(db.syncQueue)..where((v) => v.id.equals(syncId))).go();
  }

  Future<SyncQueueData> _requireSyncItem(int syncId) async {
    final item = await getSyncItemById(syncId);

    if (item == null) {
      throw Exception('Sync item not found: $syncId');
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
    if (operation != 'INSERT' && operation != 'UPDATE' && operation != 'DELETE') {
      throw Exception('Sync operation must be INSERT, UPDATE, or DELETE.');
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