import 'package:bloc/bloc.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/sync/domain/repositories/sync_repository.dart';
import 'package:the_audit/features/sync/domain/services/sync_backend_service.dart';
import 'sync_state.dart';

class SyncCubit extends Cubit<SyncState> {
  static const _log = AppLogger('SyncCubit');

  final SyncRepository _repository;
  final SyncBackendService? _backendService;

  SyncCubit(this._repository, {SyncBackendService? backendService})
    : _backendService = backendService,
      super(const SyncState());

  Future<void> loadSyncQueue({int limit = 50}) async {
    _log.t('loadSyncQueue(limit: $limit)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      final pendingItems = await _repository.getPendingSyncItems(limit: limit);
      final failedItems = await _repository.getFailedSyncItems(limit: limit);
      final inProgressItems = await _repository.getInProgressSyncItems(
        limit: limit,
      );
      final completedItems = await _repository.getCompletedSyncItems(
        limit: limit,
      );
      final pendingCount = await _repository.countPendingSyncItems();
      final failedCount = await _repository.countFailedSyncItems();
      final inProgressCount = await _repository.countInProgressSyncItems();
      final completedCount = await _repository.countCompletedSyncItems();
      final hasPendingOrFailedItems = await _repository
          .hasPendingOrFailedSyncItems();
      _log.d(
        'sync queue: pending=$pendingCount failed=$failedCount '
        'inProgress=$inProgressCount completed=$completedCount',
      );

      emit(
        state.copyWith(
          status: SyncStatus.loaded,
          pendingItems: pendingItems,
          failedItems: failedItems,
          inProgressItems: inProgressItems,
          completedItems: completedItems,
          pendingCount: pendingCount,
          failedCount: failedCount,
          inProgressCount: inProgressCount,
          completedCount: completedCount,
          hasPendingOrFailedItems: hasPendingOrFailedItems,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSyncQueue failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> enqueueSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    bool coalesce = true,
  }) async {
    _log.i('enqueueSyncOperation($entityType, $entityId, $operation)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.enqueueSyncOperation(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        coalesce: coalesce,
      );
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('enqueueSyncOperation failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> processPendingBatch({int limit = 25}) async {
    _log.i('processPendingBatch(limit: $limit)');
    final backendService = _backendService;

    if (backendService == null) {
      _log.w('processPendingBatch: backend service not configured');
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: 'Sync backend service is not configured.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: SyncStatus.syncing, clearError: true));

    try {
      final batch = await _repository.claimNextPendingBatch(limit: limit);
      final conflicts = await backendService.detectConflicts(localItems: batch);
      _log.d('claimed ${batch.length} items, ${conflicts.length} conflicts');

      if (conflicts.isNotEmpty) {
        _log.w('sync halted: ${conflicts.length} conflicts need resolution');
        emit(
          state.copyWith(
            status: SyncStatus.failure,
            conflicts: conflicts,
            errorMessage: 'Sync conflicts require resolution.',
          ),
        );
        return;
      }

      for (final item in batch) {
        try {
          await backendService.pushSyncItem(item);
          await _repository.markSyncCompleted(item.id);
        } catch (error) {
          await _repository.markSyncFailed(
            syncId: item.id,
            errorMessage: error.toString(),
          );
        }
      }
      _log.i('sync batch done: ${batch.length} items attempted');

      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('processPendingBatch failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> retryFailedSync(int syncId) async {
    _log.i('retryFailedSync($syncId)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.retryFailedSync(syncId);
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('retryFailedSync failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> retryAllFailedSyncItems() async {
    _log.i('retryAllFailedSyncItems()');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.retryAllFailedSyncItems();
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('retryAllFailedSyncItems failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> clearCompletedSyncItems() async {
    _log.i('clearCompletedSyncItems()');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.deleteCompletedSyncItems();
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('clearCompletedSyncItems failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadSyncItem(int syncId) async {
    _log.t('loadSyncItem($syncId)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      final item = await _repository.getSyncItemById(syncId);
      emit(
        state.copyWith(
          status: SyncStatus.loaded,
          selectedItem: item,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSyncItem failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadSyncItemsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    _log.t('loadSyncItemsForEntity($entityType, $entityId)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      final items = await _repository.getSyncItemsForEntity(
        entityType: entityType,
        entityId: entityId,
      );
      emit(
        state.copyWith(
          status: SyncStatus.loaded,
          pendingItems: items,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSyncItemsForEntity failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markSyncInProgress(int syncId) async {
    _log.t('markSyncInProgress($syncId)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.markSyncInProgress(syncId);
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('markSyncInProgress failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markSyncCompleted(int syncId) async {
    _log.i('markSyncCompleted($syncId)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.markSyncCompleted(syncId);
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('markSyncCompleted failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markSyncFailed({
    required int syncId,
    required String errorMessage,
  }) async {
    _log.i('markSyncFailed($syncId)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.markSyncFailed(
        syncId: syncId,
        errorMessage: errorMessage,
      );
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('markSyncFailed failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> resetAllInProgressToPending() async {
    _log.i('resetAllInProgressToPending()');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.resetAllInProgressToPending();
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('resetAllInProgressToPending failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> deleteSyncItem(int syncId) async {
    _log.i('deleteSyncItem($syncId)');
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.deleteSyncItem(syncId);
      await loadSyncQueue();
    } catch (error, stackTrace) {
      _log.e('deleteSyncItem failed', error, stackTrace);
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
