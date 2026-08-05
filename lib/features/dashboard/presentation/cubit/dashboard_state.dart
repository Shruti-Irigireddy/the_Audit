enum DashboardViewStatus { initial, loading, loaded, failure }

class DashboardState {
  final DashboardViewStatus viewStatus;
  final int inProgressSessionCount;
  final int closedSessionCount;
  final int pendingSyncCount;
  final int failedSyncCount;
  final int pendingExportCount;
  final int failedExportCount;
  final String? errorMessage;

  const DashboardState({
    required this.viewStatus,
    required this.inProgressSessionCount,
    required this.closedSessionCount,
    required this.pendingSyncCount,
    required this.failedSyncCount,
    required this.pendingExportCount,
    required this.failedExportCount,
    required this.errorMessage,
  });

  factory DashboardState.initial() {
    return const DashboardState(
      viewStatus: DashboardViewStatus.initial,
      inProgressSessionCount: 0,
      closedSessionCount: 0,
      pendingSyncCount: 0,
      failedSyncCount: 0,
      pendingExportCount: 0,
      failedExportCount: 0,
      errorMessage: null,
    );
  }

  DashboardState copyWith({
    DashboardViewStatus? viewStatus,
    int? inProgressSessionCount,
    int? closedSessionCount,
    int? pendingSyncCount,
    int? failedSyncCount,
    int? pendingExportCount,
    int? failedExportCount,
    Object? errorMessage = _unset,
  }) {
    return DashboardState(
      viewStatus: viewStatus ?? this.viewStatus,
      inProgressSessionCount:
          inProgressSessionCount ?? this.inProgressSessionCount,
      closedSessionCount: closedSessionCount ?? this.closedSessionCount,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      failedSyncCount: failedSyncCount ?? this.failedSyncCount,
      pendingExportCount: pendingExportCount ?? this.pendingExportCount,
      failedExportCount: failedExportCount ?? this.failedExportCount,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _unset = Object();

  bool get isLoading => viewStatus == DashboardViewStatus.loading;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}
