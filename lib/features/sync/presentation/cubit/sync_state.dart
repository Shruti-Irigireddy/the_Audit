import 'package:the_audit/features/sync/domain/entities/sync_queue_entity.dart';
import 'package:the_audit/features/sync/domain/services/sync_backend_service.dart';

enum SyncStatus { initial, loading, loaded, syncing, failure }

class SyncState {
  final SyncStatus status;
  final List<SyncQueueEntity> pendingItems;
  final List<SyncQueueEntity> failedItems;
  final List<SyncQueueEntity> inProgressItems;
  final List<SyncQueueEntity> completedItems;
  final SyncQueueEntity? selectedItem;
  final List<SyncConflict> conflicts;
  final int pendingCount;
  final int failedCount;
  final int inProgressCount;
  final int completedCount;
  final bool hasPendingOrFailedItems;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.initial,
    this.pendingItems = const [],
    this.failedItems = const [],
    this.inProgressItems = const [],
    this.completedItems = const [],
    this.selectedItem,
    this.conflicts = const [],
    this.pendingCount = 0,
    this.failedCount = 0,
    this.inProgressCount = 0,
    this.completedCount = 0,
    this.hasPendingOrFailedItems = false,
    this.errorMessage,
  });

  bool get isBusy =>
      status == SyncStatus.loading || status == SyncStatus.syncing;

  SyncState copyWith({
    SyncStatus? status,
    List<SyncQueueEntity>? pendingItems,
    List<SyncQueueEntity>? failedItems,
    List<SyncQueueEntity>? inProgressItems,
    List<SyncQueueEntity>? completedItems,
    SyncQueueEntity? selectedItem,
    bool clearSelectedItem = false,
    List<SyncConflict>? conflicts,
    int? pendingCount,
    int? failedCount,
    int? inProgressCount,
    int? completedCount,
    bool? hasPendingOrFailedItems,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingItems: pendingItems ?? this.pendingItems,
      failedItems: failedItems ?? this.failedItems,
      inProgressItems: inProgressItems ?? this.inProgressItems,
      completedItems: completedItems ?? this.completedItems,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      conflicts: conflicts ?? this.conflicts,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      inProgressCount: inProgressCount ?? this.inProgressCount,
      completedCount: completedCount ?? this.completedCount,
      hasPendingOrFailedItems:
          hasPendingOrFailedItems ?? this.hasPendingOrFailedItems,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
