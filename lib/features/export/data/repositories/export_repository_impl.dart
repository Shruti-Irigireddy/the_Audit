import 'package:the_audit/core/database/daos/export/export_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/export/data/mappers/export_mapper.dart';
import 'package:the_audit/features/export/domain/entities/export_entity.dart';
import 'package:the_audit/features/export/domain/repositories/export_repository.dart';

class ExportRepositoryImpl implements ExportRepository {
  static const _log = AppLogger('ExportRepositoryImpl');

  final ExportDao _dao;

  const ExportRepositoryImpl(this._dao);

  @override
  Future<int> createExportRecord({
    required String entityType,
    required String entityId,
    required String exportFormat,
    required String generatedBy,
  }) {
    _log.t(
      'createExportRecord(entityType: $entityType, entityId: $entityId, exportFormat: $exportFormat)',
    );
    return _dao.createExportRecord(
      entityType: entityType,
      entityId: entityId,
      exportFormat: exportFormat,
      generatedBy: generatedBy,
    );
  }

  @override
  Future<void> markExportInProgress({
    required int exportId,
    required String performedBy,
  }) {
    _log.t('markExportInProgress(exportId: $exportId)');
    return _dao.markExportInProgress(
      exportId: exportId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> markExportCompleted({
    required int exportId,
    required String exportLocation,
    required String performedBy,
  }) {
    _log.t('markExportCompleted(exportId: $exportId)');
    return _dao.markExportCompleted(
      exportId: exportId,
      exportLocation: exportLocation,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> markExportFailed({
    required int exportId,
    required String errorMessage,
    required String performedBy,
  }) {
    _log.t('markExportFailed(exportId: $exportId)');
    return _dao.markExportFailed(
      exportId: exportId,
      errorMessage: errorMessage,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> retryExport({
    required int exportId,
    required String performedBy,
  }) {
    _log.t('retryExport(exportId: $exportId)');
    return _dao.retryExport(exportId: exportId, performedBy: performedBy);
  }

  @override
  Future<ExportEntity?> getExportById(int exportId) async {
    _log.t('getExportById(exportId: $exportId)');
    final export = await _dao.getExportById(exportId);
    return export?.toEntity();
  }

  @override
  Future<List<ExportEntity>> getExportsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    _log.t('getExportsForEntity(entityType: $entityType, entityId: $entityId)');
    final exports = await _dao.getExportsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    _log.d('getExportsForEntity: ${exports.length} items');
    return exports.map((export) => export.toEntity()).toList();
  }

  @override
  Future<List<ExportEntity>> getPendingExports({int limit = 50}) async {
    _log.t('getPendingExports(limit: $limit)');
    final exports = await _dao.getPendingExports(limit: limit);
    _log.d('getPendingExports: ${exports.length} items');
    return exports.map((export) => export.toEntity()).toList();
  }

  @override
  Future<List<ExportEntity>> getInProgressExports({int limit = 50}) async {
    _log.t('getInProgressExports(limit: $limit)');
    final exports = await _dao.getInProgressExports(limit: limit);
    _log.d('getInProgressExports: ${exports.length} items');
    return exports.map((export) => export.toEntity()).toList();
  }

  @override
  Future<List<ExportEntity>> getFailedExports({int limit = 50}) async {
    _log.t('getFailedExports(limit: $limit)');
    final exports = await _dao.getFailedExports(limit: limit);
    _log.d('getFailedExports: ${exports.length} items');
    return exports.map((export) => export.toEntity()).toList();
  }

  @override
  Future<List<ExportEntity>> getRecentCompletedExports({int limit = 50}) async {
    _log.t('getRecentCompletedExports(limit: $limit)');
    final exports = await _dao.getRecentCompletedExports(limit: limit);
    _log.d('getRecentCompletedExports: ${exports.length} items');
    return exports.map((export) => export.toEntity()).toList();
  }

  @override
  Future<ExportEntity?> getLatestCompletedExportForEntity({
    required String entityType,
    required String entityId,
    required String exportFormat,
  }) async {
    _log.t(
      'getLatestCompletedExportForEntity(entityType: $entityType, entityId: $entityId, exportFormat: $exportFormat)',
    );
    final export = await _dao.getLatestCompletedExportForEntity(
      entityType: entityType,
      entityId: entityId,
      exportFormat: exportFormat,
    );
    return export?.toEntity();
  }

  @override
  Future<int> countPendingExports() {
    _log.t('countPendingExports()');
    return _dao.countPendingExports();
  }

  @override
  Future<int> countFailedExports() {
    _log.t('countFailedExports()');
    return _dao.countFailedExports();
  }
}
