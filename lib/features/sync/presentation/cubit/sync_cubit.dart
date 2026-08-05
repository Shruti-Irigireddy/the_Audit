import 'package:bloc/bloc.dart';

import 'package:the_audit/features/sync/domain/repositories/sync_repository.dart';
import 'package:the_audit/features/sync/domain/services/sync_backend_service.dart';
import 'sync_state.dart';

class SyncCubit extends Cubit<SyncState> {
  final SyncRepository _repository;
  final SyncBackendService? _backendService;

  SyncCubit(this._repository, {SyncBackendService? backendService})
    : _backendService = backendService,
      super(const SyncState());

  Future<void> loadSyncQueue({int limit = 50}) async {
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
    } catch (error) {
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
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.enqueueSyncOperation(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        coalesce: coalesce,
      );
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> processPendingBatch({int limit = 25}) async {
    final backendService = _backendService;

    if (backendService == null) {
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

      if (conflicts.isNotEmpty) {
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

      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> retryFailedSync(int syncId) async {
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.retryFailedSync(syncId);
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> retryAllFailedSyncItems() async {
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.retryAllFailedSyncItems();
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> clearCompletedSyncItems() async {
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.deleteCompletedSyncItems();
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadSyncItem(int syncId) async {
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
    } catch (error) {
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
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markSyncInProgress(int syncId) async {
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.markSyncInProgress(syncId);
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markSyncCompleted(int syncId) async {
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.markSyncCompleted(syncId);
      await loadSyncQueue();
    } catch (error) {
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
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.markSyncFailed(
        syncId: syncId,
        errorMessage: errorMessage,
      );
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> resetAllInProgressToPending() async {
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.resetAllInProgressToPending();
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> deleteSyncItem(int syncId) async {
    emit(state.copyWith(status: SyncStatus.loading, clearError: true));

    try {
      await _repository.deleteSyncItem(syncId);
      await loadSyncQueue();
    } catch (error) {
      emit(
        state.copyWith(
          status: SyncStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
