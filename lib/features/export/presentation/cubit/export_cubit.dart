import 'package:bloc/bloc.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/export/domain/repositories/export_repository.dart';
import 'package:the_audit/features/export/domain/services/export_generation_service.dart';
import 'package:the_audit/features/export/domain/services/export_share_service.dart';
import 'export_state.dart';

class ExportCubit extends Cubit<ExportState> {
  static const _log = AppLogger('ExportCubit');

  final ExportRepository _repository;
  final ExportGenerationService? _generationService;
  final ExportShareService? _shareService;

  ExportCubit(
    this._repository, {
    ExportGenerationService? generationService,
    ExportShareService? shareService,
  }) : _generationService = generationService,
       _shareService = shareService,
       super(const ExportState());

  Future<void> loadExports({int limit = 50}) async {
    _log.t('loadExports(limit: $limit)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      final pendingExports = await _repository.getPendingExports(limit: limit);
      final inProgressExports = await _repository.getInProgressExports(
        limit: limit,
      );
      final failedExports = await _repository.getFailedExports(limit: limit);
      final completedExports = await _repository.getRecentCompletedExports(
        limit: limit,
      );
      final pendingCount = await _repository.countPendingExports();
      final failedCount = await _repository.countFailedExports();
      _log.d(
        'exports loaded: pending=$pendingCount failed=$failedCount '
        'completed=${completedExports.length}',
      );

      emit(
        state.copyWith(
          status: ExportStatus.loaded,
          pendingExports: pendingExports,
          inProgressExports: inProgressExports,
          failedExports: failedExports,
          completedExports: completedExports,
          pendingCount: pendingCount,
          failedCount: failedCount,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadExports failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadExportsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    _log.t('loadExportsForEntity($entityType, $entityId)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      final exports = await _repository.getExportsForEntity(
        entityType: entityType,
        entityId: entityId,
      );
      emit(
        state.copyWith(
          status: ExportStatus.loaded,
          entityExports: exports,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadExportsForEntity failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> createExportRecord({
    required String entityType,
    required String entityId,
    required String exportFormat,
    required String generatedBy,
  }) async {
    _log.i('createExportRecord($entityType, $entityId, $exportFormat)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      final exportId = await _repository.createExportRecord(
        entityType: entityType,
        entityId: entityId,
        exportFormat: exportFormat,
        generatedBy: generatedBy,
      );
      _log.d('export record created: $exportId');
      final export = await _repository.getExportById(exportId);
      emit(
        state.copyWith(
          status: ExportStatus.loaded,
          selectedExport: export,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('createExportRecord failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadExport(int exportId) async {
    _log.t('loadExport($exportId)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      final export = await _repository.getExportById(exportId);
      emit(
        state.copyWith(
          status: ExportStatus.loaded,
          selectedExport: export,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadExport failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadLatestCompletedExportForEntity({
    required String entityType,
    required String entityId,
    required String exportFormat,
  }) async {
    _log.t(
      'loadLatestCompletedExportForEntity($entityType, $entityId, $exportFormat)',
    );
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      final export = await _repository.getLatestCompletedExportForEntity(
        entityType: entityType,
        entityId: entityId,
        exportFormat: exportFormat,
      );
      emit(
        state.copyWith(
          status: ExportStatus.loaded,
          selectedExport: export,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadLatestCompletedExportForEntity failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> generateSessionExport({
    required String sessionId,
    required String exportFormat,
    required String generatedBy,
    bool shareAfterGenerate = false,
  }) async {
    _log.i(
      'generateSessionExport($sessionId, $exportFormat, share: $shareAfterGenerate)',
    );
    await _generateExport(
      entityType: 'FIELD_SESSION',
      entityId: sessionId,
      exportFormat: exportFormat,
      generatedBy: generatedBy,
      shareAfterGenerate: shareAfterGenerate,
      generate: () => _generationService!.generateSessionExport(
        sessionId: sessionId,
        exportFormat: exportFormat,
      ),
    );
  }

  Future<void> generateFlightExport({
    required String flightId,
    required String exportFormat,
    required String generatedBy,
    bool shareAfterGenerate = false,
  }) async {
    _log.i(
      'generateFlightExport($flightId, $exportFormat, share: $shareAfterGenerate)',
    );
    await _generateExport(
      entityType: 'SORTIE',
      entityId: flightId,
      exportFormat: exportFormat,
      generatedBy: generatedBy,
      shareAfterGenerate: shareAfterGenerate,
      generate: () => _generationService!.generateFlightExport(
        flightId: flightId,
        exportFormat: exportFormat,
      ),
    );
  }

  Future<void> retryExport({
    required int exportId,
    required String performedBy,
  }) async {
    _log.i('retryExport($exportId)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      await _repository.retryExport(
        exportId: exportId,
        performedBy: performedBy,
      );
      await loadExports();
    } catch (error, stackTrace) {
      _log.e('retryExport failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markExportInProgress({
    required int exportId,
    required String performedBy,
  }) async {
    _log.t('markExportInProgress($exportId)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      await _repository.markExportInProgress(
        exportId: exportId,
        performedBy: performedBy,
      );
      await loadExport(exportId);
    } catch (error, stackTrace) {
      _log.e('markExportInProgress failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markExportCompleted({
    required int exportId,
    required String exportLocation,
    required String performedBy,
  }) async {
    _log.i('markExportCompleted($exportId)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      await _repository.markExportCompleted(
        exportId: exportId,
        exportLocation: exportLocation,
        performedBy: performedBy,
      );
      await loadExport(exportId);
    } catch (error, stackTrace) {
      _log.e('markExportCompleted failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> markExportFailed({
    required int exportId,
    required String errorMessage,
    required String performedBy,
  }) async {
    _log.i('markExportFailed($exportId)');
    emit(state.copyWith(status: ExportStatus.loading, clearError: true));

    try {
      await _repository.markExportFailed(
        exportId: exportId,
        errorMessage: errorMessage,
        performedBy: performedBy,
      );
      await loadExport(exportId);
    } catch (error, stackTrace) {
      _log.e('markExportFailed failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> shareLatestArtifact() async {
    _log.i('shareLatestArtifact()');
    final shareService = _shareService;
    final artifact = state.latestArtifact;

    if (shareService == null) {
      _log.w('shareLatestArtifact: share service not configured');
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: 'Export share service is not configured.',
        ),
      );
      return;
    }

    if (artifact == null) {
      _log.w('shareLatestArtifact: no artifact to share');
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: 'No generated export is available to share.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ExportStatus.sharing, clearError: true));

    try {
      await shareService.shareExport(artifact);
      emit(state.copyWith(status: ExportStatus.loaded, clearError: true));
    } catch (error, stackTrace) {
      _log.e('shareLatestArtifact failed', error, stackTrace);
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _generateExport({
    required String entityType,
    required String entityId,
    required String exportFormat,
    required String generatedBy,
    required bool shareAfterGenerate,
    required Future<ExportArtifact> Function() generate,
  }) async {
    final generationService = _generationService;

    if (generationService == null) {
      _log.w('_generateExport: generation service not configured');
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: 'Export generation service is not configured.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ExportStatus.generating, clearError: true));

    int? exportId;

    try {
      exportId = await _repository.createExportRecord(
        entityType: entityType,
        entityId: entityId,
        exportFormat: exportFormat,
        generatedBy: generatedBy,
      );
      await _repository.markExportInProgress(
        exportId: exportId,
        performedBy: generatedBy,
      );
      _log.d('export $exportId in progress ($entityType $entityId)');

      final artifact = await generate();
      _log.d('export $exportId generated');

      await _repository.markExportCompleted(
        exportId: exportId,
        exportLocation: artifact.filePath,
        performedBy: generatedBy,
      );

      if (shareAfterGenerate) {
        final shareService = _shareService;
        if (shareService == null) {
          throw Exception('Export share service is not configured.');
        }
        emit(state.copyWith(status: ExportStatus.sharing, clearError: true));
        await shareService.shareExport(artifact);
        _log.d('export $exportId shared');
      }

      final export = await _repository.getExportById(exportId);
      emit(
        state.copyWith(
          status: ExportStatus.loaded,
          selectedExport: export,
          latestArtifact: artifact,
          clearError: true,
        ),
      );
      _log.i('export $exportId completed');
    } catch (error, stackTrace) {
      _log.e('_generateExport failed', error, stackTrace);
      if (exportId != null) {
        await _repository.markExportFailed(
          exportId: exportId,
          errorMessage: error.toString(),
          performedBy: generatedBy,
        );
      }
      emit(
        state.copyWith(
          status: ExportStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
