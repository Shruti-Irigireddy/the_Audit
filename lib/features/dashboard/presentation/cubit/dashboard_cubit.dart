import 'package:bloc/bloc.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/export/domain/repositories/export_repository.dart';
import 'package:the_audit/features/records/domain/repositories/records_repository.dart';
import 'package:the_audit/features/sync/domain/repositories/sync_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  static const _log = AppLogger('DashboardCubit');

  final RecordRepository _recordRepository;
  final SyncRepository _syncRepository;
  final ExportRepository _exportRepository;

  DashboardCubit({
    required RecordRepository recordRepository,
    required SyncRepository syncRepository,
    required ExportRepository exportRepository,
  }) : _recordRepository = recordRepository,
       _syncRepository = syncRepository,
       _exportRepository = exportRepository,
       super(DashboardState.initial());

  Future<void> loadDashboard() async {
    _log.t('loadDashboard()');
    emit(
      state.copyWith(
        viewStatus: DashboardViewStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final inProgressSessionCount = await _recordRepository
          .countSessionsByStatus('IN_PROGRESS');
      final closedSessionCount = await _recordRepository.countSessionsByStatus(
        'CLOSED',
      );
      final pendingSyncCount = await _syncRepository.countPendingSyncItems();
      final failedSyncCount = await _syncRepository.countFailedSyncItems();
      final pendingExportCount = await _exportRepository.countPendingExports();
      final failedExportCount = await _exportRepository.countFailedExports();
      _log.d(
        'dashboard: sessions in-progress=$inProgressSessionCount '
        'closed=$closedSessionCount, sync pending=$pendingSyncCount '
        'failed=$failedSyncCount, export pending=$pendingExportCount '
        'failed=$failedExportCount',
      );

      emit(
        state.copyWith(
          viewStatus: DashboardViewStatus.loaded,
          inProgressSessionCount: inProgressSessionCount,
          closedSessionCount: closedSessionCount,
          pendingSyncCount: pendingSyncCount,
          failedSyncCount: failedSyncCount,
          pendingExportCount: pendingExportCount,
          failedExportCount: failedExportCount,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadDashboard failed', error, stackTrace);
      emit(
        state.copyWith(
          viewStatus: DashboardViewStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
