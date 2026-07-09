import 'package:drift/drift.dart';

import '../../app_database.dart';

part 'export_dao.g.dart';


@DriftAccessor(
  tables: [
    ExportRecords,
    AuditEvents,
    SyncQueue,
  ],
)

class ExportDao extends DatabaseAccessor<AppDatabase> with _$ExportDaoMixin{
  ExportDao(super.db);

  Future<int> createExportRecord({
    required String entityType,
    required String entityId,
    required String exportFormat,
    required String generatedBy,
  }) async {
    return await transaction(() async {
      final exportId = await into(db.exportRecords).insert(
        ExportRecordsCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          exportFormat: exportFormat,
          generatedBy: generatedBy,
          exportStatus: const Value('PENDING'),
        ),
      );

      await into(db.auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          action: 'EXPORT_REQUESTED',
          description: Value('Export requested as $exportFormat'),
          performedBy: generatedBy,
        ),
      );

      return exportId;
    });
  }

  Future<void> markExportInProgress(int exportId){
    return (update(db.exportRecords)
          ..where((v) => v.id.equals(exportId)))
          .write(
            ExportRecordsCompanion(
              exportStatus: const Value('IN PROGRESS'),
              lastAttemptAt: Value(DateTime.now()),
              ),
          );
  }

  Future<void> markExportCompleted({
    required int exportId,
    required String exportLocation,
    required String performedBy,
    }) async {
      await transaction(() async {
        final record = await getExportById(exportId);

        if (record == null) {
          throw Exception('Export record not found $exportId');
        } 

        await (update(db.exportRecords)
        ..where((v) => v.id.equals(exportId)))
        .write(
          ExportRecordsCompanion(
            exportStatus: const Value('COMPLETED'),
            exportLocation: Value(exportLocation),
            errorMessage: const Value(null),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );

        await into(db.auditEvents).insert(
          AuditEventsCompanion.insert(
            entityType: record.entityType, 
            entityId: record.entityId, 
            action: "EXPORTED",
            description: Value('${record.exportFormat} created at $exportLocation'), 
            performedBy: performedBy
          ),
        );
      });
    }
  
  Future<void> markExportFailed({
    required int exportId,
    required String errorMessage,
  }) async {
    final record = await getExportById(exportId);
    final currentRetry = record?.retryCount ?? 0;

    await (update(db.exportRecords)..where((tbl) => tbl.id.equals(exportId)))
        .write(
      ExportRecordsCompanion(
        exportStatus: const Value('FAILED'),
        errorMessage: Value(errorMessage),
        retryCount: Value(currentRetry + 1),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> resetExportForRetry(int exportId) {
    return (update(db.exportRecords)..where((tbl) => tbl.id.equals(exportId)))
        .write(
      ExportRecordsCompanion(
        exportStatus: const Value('PENDING'),
        errorMessage: const Value(null),
        // updatedAt: const Value.absent(),
      ),
    );
  }

  Future<ExportRecord?> getExportById(int exportId) {
    return (select(db.exportRecords)..where((tbl) => tbl.id.equals(exportId)))
        .getSingleOrNull();
  }

  Future<List<ExportRecord>> getPendingExports() {
    return (select(db.exportRecords)
          ..where((tbl) => tbl.exportStatus.equals('PENDING'))
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.generatedAt),
          ]))
        .get();
  }

  Future<List<ExportRecord>> getFailedExports() {
    return (select(db.exportRecords)
          ..where((tbl) => tbl.exportStatus.equals('FAILED'))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.lastAttemptAt),
          ]))
        .get();
  }

  Future<List<ExportRecord>> getExportsForEntity({
    required String entityType,
    required String entityId,
  }) {
    return (select(db.exportRecords)
          ..where(
            (tbl) =>
                tbl.entityType.equals(entityType) &
                tbl.entityId.equals(entityId),
          )
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.generatedAt),
          ]))
        .get();
  }
}
