import 'package:drift/drift.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';

part 'export_dao.g.dart';

@DriftAccessor(
  tables: [
    Users,
    FieldSessions,
    Sorties,
    Vehicles,
    Payloads,
    Batteries,
    PostFlightNotes,
    ExportRecords,
    AuditEvents,
    SyncQueue,
  ],
)
class ExportDao extends DatabaseAccessor<AppDatabase> with _$ExportDaoMixin {
  ExportDao(super.db);

  static const _log = AppLogger('ExportDao');

  Future<int> createExportRecord({
    required String entityType,
    required String entityId,
    required String exportFormat,
    required String generatedBy,
  }) async {
    _log.t(
      'createExportRecord(entityType: $entityType, entityId: $entityId, '
      'format: $exportFormat)',
    );
    return _log.trace('createExportRecord', () async {
      final normalizedEntityType = _normalizeEntityType(entityType);
      final normalizedFormat = exportFormat.trim().toUpperCase();

      _validateExportFormat(normalizedFormat);
      await _ensureExportEntityExists(
        entityType: normalizedEntityType,
        entityId: entityId,
      );

      return transaction(() async {
        final exportId = await into(db.exportRecords).insert(
          ExportRecordsCompanion.insert(
            entityType: normalizedEntityType,
            entityId: entityId,
            exportFormat: normalizedFormat,
            generatedBy: generatedBy,
            exportStatus: const Value('PENDING'),
          ),
        );

        await _insertAuditEvent(
          entityType: normalizedEntityType,
          entityId: entityId,
          action: 'EXPORT_REQUESTED',
          description: '$normalizedFormat export requested',
          performedBy: generatedBy,
        );

        await _enqueueSync(
          entityType: 'EXPORT_RECORD',
          entityId: exportId.toString(),
          operation: 'INSERT',
        );

        return exportId;
      });
    });
  }

  Future<void> markExportInProgress({
    required int exportId,
    required String performedBy,
  }) async {
    _log.t('markExportInProgress(exportId: $exportId)');
    return _log.trace('markExportInProgress', () async {
      final record = await _requireExportRecord(exportId);

      if (record.exportStatus == 'COMPLETED') {
        _log.w('Cannot restart a completed export: $exportId');
        throw AppFailure('Cannot restart a completed export.');
      }

      await transaction(() async {
        await (update(
          db.exportRecords,
        )..where((v) => v.id.equals(exportId))).write(
          ExportRecordsCompanion(
            exportStatus: const Value('IN_PROGRESS'),
            errorMessage: const Value(null),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: record.entityType,
          entityId: record.entityId,
          action: 'EXPORT_IN_PROGRESS',
          description: '${record.exportFormat} export started',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'EXPORT_RECORD',
          entityId: exportId.toString(),
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> markExportCompleted({
    required int exportId,
    required String exportLocation,
    required String performedBy,
  }) async {
    _log.t('markExportCompleted(exportId: $exportId)');
    return _log.trace('markExportCompleted', () async {
      final record = await _requireExportRecord(exportId);

      if (exportLocation.trim().isEmpty) {
        _log.w('Export location cannot be empty: $exportId');
        throw AppFailure('Export location cannot be empty.');
      }

      await transaction(() async {
        await (update(
          db.exportRecords,
        )..where((v) => v.id.equals(exportId))).write(
          ExportRecordsCompanion(
            exportStatus: const Value('COMPLETED'),
            exportLocation: Value(exportLocation),
            errorMessage: const Value(null),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: record.entityType,
          entityId: record.entityId,
          action: 'EXPORTED',
          description:
              '${record.exportFormat} export completed at $exportLocation',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'EXPORT_RECORD',
          entityId: exportId.toString(),
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> markExportFailed({
    required int exportId,
    required String errorMessage,
    required String performedBy,
  }) async {
    _log.t('markExportFailed(exportId: $exportId)');
    return _log.trace('markExportFailed', () async {
      final record = await _requireExportRecord(exportId);

      if (errorMessage.trim().isEmpty) {
        _log.w('Export failure reason cannot be empty: $exportId');
        throw AppFailure('Export failure reason cannot be empty.');
      }

      await transaction(() async {
        await (update(
          db.exportRecords,
        )..where((v) => v.id.equals(exportId))).write(
          ExportRecordsCompanion(
            exportStatus: const Value('FAILED'),
            errorMessage: Value(errorMessage),
            retryCount: Value(record.retryCount + 1),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: record.entityType,
          entityId: record.entityId,
          action: 'EXPORT_FAILED',
          description: errorMessage,
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'EXPORT_RECORD',
          entityId: exportId.toString(),
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> retryExport({
    required int exportId,
    required String performedBy,
  }) async {
    _log.t('retryExport(exportId: $exportId)');
    return _log.trace('retryExport', () async {
      final record = await _requireExportRecord(exportId);

      if (record.exportStatus != 'FAILED') {
        _log.w('Only failed exports can be retried: $exportId');
        throw AppFailure('Only failed exports can be retried.');
      }

      await transaction(() async {
        await (update(
          db.exportRecords,
        )..where((v) => v.id.equals(exportId))).write(
          ExportRecordsCompanion(
            exportStatus: const Value('PENDING'),
            errorMessage: const Value(null),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: record.entityType,
          entityId: record.entityId,
          action: 'EXPORT_RETRY',
          description: '${record.exportFormat} export queued for retry',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'EXPORT_RECORD',
          entityId: exportId.toString(),
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<ExportRecord?> getExportById(int exportId) {
    _log.t('getExportById(exportId: $exportId)');
    return (select(
      db.exportRecords,
    )..where((v) => v.id.equals(exportId))).getSingleOrNull();
  }

  Future<List<ExportRecord>> getExportsForEntity({
    required String entityType,
    required String entityId,
  }) {
    _log.t('getExportsForEntity(entityType: $entityType, entityId: $entityId)');
    final normalizedEntityType = _normalizeEntityType(entityType);

    return (select(db.exportRecords)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId),
          )
          ..orderBy([(v) => OrderingTerm.desc(v.generatedAt)]))
        .get();
  }

  Future<List<ExportRecord>> getPendingExports({int limit = 50}) {
    _log.t('getPendingExports(limit: $limit)');
    return (select(db.exportRecords)
          ..where((v) => v.exportStatus.equals('PENDING'))
          ..orderBy([(v) => OrderingTerm.asc(v.generatedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<ExportRecord>> getInProgressExports({int limit = 50}) {
    _log.t('getInProgressExports(limit: $limit)');
    return (select(db.exportRecords)
          ..where((v) => v.exportStatus.equals('IN_PROGRESS'))
          ..orderBy([(v) => OrderingTerm.asc(v.lastAttemptAt)])
          ..limit(limit))
        .get();
  }

  Future<List<ExportRecord>> getFailedExports({int limit = 50}) {
    _log.t('getFailedExports(limit: $limit)');
    return (select(db.exportRecords)
          ..where((v) => v.exportStatus.equals('FAILED'))
          ..orderBy([(v) => OrderingTerm.desc(v.lastAttemptAt)])
          ..limit(limit))
        .get();
  }

  Future<List<ExportRecord>> getRecentCompletedExports({int limit = 50}) {
    _log.t('getRecentCompletedExports(limit: $limit)');
    return (select(db.exportRecords)
          ..where((v) => v.exportStatus.equals('COMPLETED'))
          ..orderBy([(v) => OrderingTerm.desc(v.generatedAt)])
          ..limit(limit))
        .get();
  }

  Future<ExportRecord?> getLatestCompletedExportForEntity({
    required String entityType,
    required String entityId,
    required String exportFormat,
  }) {
    _log.t(
      'getLatestCompletedExportForEntity(entityType: $entityType, '
      'entityId: $entityId, format: $exportFormat)',
    );
    final normalizedEntityType = _normalizeEntityType(entityType);
    final normalizedFormat = exportFormat.trim().toUpperCase();

    return (select(db.exportRecords)
          ..where(
            (v) =>
                v.entityType.equals(normalizedEntityType) &
                v.entityId.equals(entityId) &
                v.exportFormat.equals(normalizedFormat) &
                v.exportStatus.equals('COMPLETED'),
          )
          ..orderBy([(v) => OrderingTerm.desc(v.generatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> countPendingExports() async {
    _log.t('countPendingExports()');
    final countExp = db.exportRecords.id.count();

    final query = selectOnly(db.exportRecords)
      ..addColumns([countExp])
      ..where(db.exportRecords.exportStatus.equals('PENDING'));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<int> countFailedExports() async {
    _log.t('countFailedExports()');
    final countExp = db.exportRecords.id.count();

    final query = selectOnly(db.exportRecords)
      ..addColumns([countExp])
      ..where(db.exportRecords.exportStatus.equals('FAILED'));

    final row = await query.getSingle();

    return row.read(countExp) ?? 0;
  }

  Future<ExportRecord> _requireExportRecord(int exportId) async {
    final record = await getExportById(exportId);

    if (record == null) {
      _log.w('Export record not found: $exportId');
      throw AppFailure('Export record not found: $exportId');
    }

    return record;
  }

  String _normalizeEntityType(String entityType) {
    final value = entityType.trim().toUpperCase();

    if (value == 'FLIGHT') {
      return 'SORTIE';
    }

    return value;
  }

  void _validateExportFormat(String exportFormat) {
    if (exportFormat != 'PDF' && exportFormat != 'CSV') {
      _log.w('Invalid export format: $exportFormat');
      throw AppFailure('Export format must be PDF or CSV.');
    }
  }

  Future<void> _ensureExportEntityExists({
    required String entityType,
    required String entityId,
  }) async {
    final exists = switch (entityType) {
      'FIELD_SESSION' =>
        await (select(
              db.fieldSessions,
            )..where((v) => v.sessionId.equals(entityId))).getSingleOrNull() !=
            null,
      'SORTIE' =>
        await (select(
              db.sorties,
            )..where((v) => v.flightId.equals(entityId))).getSingleOrNull() !=
            null,
      'VEHICLE' =>
        await (select(
              db.vehicles,
            )..where((v) => v.id.equals(entityId))).getSingleOrNull() !=
            null,
      'PAYLOAD' =>
        await (select(
              db.payloads,
            )..where((v) => v.payloadId.equals(entityId))).getSingleOrNull() !=
            null,
      'BATTERY' =>
        await (select(
              db.batteries,
            )..where((v) => v.batteryId.equals(entityId))).getSingleOrNull() !=
            null,
      'USER' =>
        await (select(
              db.users,
            )..where((v) => v.id.equals(entityId))).getSingleOrNull() !=
            null,
      'POST_FLIGHT_NOTE' =>
        await (select(
              db.postFlightNotes,
            )..where((v) => v.id.equals(entityId))).getSingleOrNull() !=
            null,
      _ => throw AppFailure('Unsupported export entity type: $entityType'),
    };

    if (!exists) {
      _log.w('Cannot export missing entity: $entityType $entityId');
      throw AppFailure('Cannot export missing entity: $entityType $entityId');
    }
  }

  Future<void> _insertAuditEvent({
    required String entityType,
    required String entityId,
    required String action,
    String? description,
    required String performedBy,
  }) {
    return into(db.auditEvents).insert(
      AuditEventsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        action: action,
        description: Value(description),
        performedBy: performedBy,
      ),
    );
  }

  Future<void> _enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        syncStatus: const Value('PENDING'),
      ),
    );
  }
}
