import 'package:the_audit/features/export/domain/entities/export_entity.dart';

abstract class ExportRepository {

  Future<int> createExportRecord({
    required String entityType,
    required String entityId,
    required String exportFormat,
    required String generatedBy,
  });

  Future<void> markExportInProgress({
    required int exportId,
    required String performedBy,
  });

  Future<void> markExportCompleted({
    required int exportId,
    required String exportLocation,
    required String performedBy,
  });

  Future<void> markExportFailed({
    required int exportId,
    required String errorMessage,
    required String performedBy,
  });

  Future<void> retryExport({
    required int exportId,
    required String performedBy,
  });

  Future<ExportEntity?> getExportById(int exportId);

  Future<List<ExportEntity>> getExportsForEntity({
    required String entityType,
    required String entityId,
  });

  Future<List<ExportEntity>> getPendingExports({
    int limit = 50,
  });

  Future<List<ExportEntity>> getInProgressExports({
    int limit = 50,
  });

  Future<List<ExportEntity>> getFailedExports({
    int limit = 50,
  });

  Future<List<ExportEntity>> getRecentCompletedExports({
    int limit = 50,
  });

  Future<ExportEntity?> getLatestCompletedExportForEntity({
    required String entityType,
    required String entityId,
    required String exportFormat,
  });

  Future<int> countPendingExports();

  Future<int> countFailedExports();
}