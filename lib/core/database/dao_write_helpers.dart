import 'package:drift/drift.dart';

import 'app_database.dart';
import 'database_constants.dart';

mixin DaoWriteHelpers on DatabaseAccessor<AppDatabase> {
  Future<void> insertAuditEvent({
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

  Future<void> enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        syncStatus: const Value(DbStatuses.pending),
      ),
    );
  }
}
