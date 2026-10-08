import 'package:drift/drift.dart';

import 'app_database.dart';
import 'database_constants.dart';

/// The query that finds the sortie (flight_id) an audited record belongs
/// to, by entity type; `?` is the record's id.
const auditFlightScopeSql = <String, String>{
  'SORTIE': 'SELECT flight_id FROM sorties WHERE flight_id = ?',
  'SORTIE_USER': 'SELECT flight_id FROM sortie_users WHERE id = ?',
  'SORTIE_PAYLOAD': 'SELECT flight_id FROM sortie_payloads WHERE id = ?',
  'SORTIE_BATTERY': 'SELECT flight_id FROM sortie_batteries WHERE id = ?',
  'CHECKLIST_RESPONSE':
      'SELECT flight_id FROM checklist_responses WHERE id = ?',
  'CHECKLIST_OVERRIDE':
      'SELECT flight_id FROM checklist_overrides WHERE id = ?',
  'POST_FLIGHT_NOTE': 'SELECT flight_id FROM post_flight_notes WHERE id = ?',
  'RECORD_AMENDMENT':
      'SELECT n.flight_id FROM record_amendments a '
      'JOIN post_flight_notes n ON n.id = a.entity_id WHERE a.id = ?',
};

/// The query that finds the session an audited record belongs to, for
/// records that aren't part of a sortie.
const auditSessionScopeSql = <String, String>{
  'FIELD_SESSION':
      'SELECT session_id FROM field_sessions WHERE session_id = ?',
  'SESSION_USER': 'SELECT session_id FROM session_users WHERE id = ?',
  'SESSION_VEHICLE': 'SELECT session_id FROM session_vehicles WHERE id = ?',
  'SESSION_BATTERY': 'SELECT session_id FROM session_batteries WHERE id = ?',
  'SESSION_EQUIPMENT_CHECK':
      'SELECT session_id FROM session_equipment_checks WHERE id = ?',
  'SESSION_VEHICLE_PAYLOAD':
      'SELECT sv.session_id FROM session_vehicle_payload p '
      'JOIN session_vehicles sv ON sv.id = p.session_vehicle_id '
      'WHERE p.id = ?',
};

/// Audit-trail and sync-queue writes shared by every DAO.
mixin DaoWriteHelpers on DatabaseAccessor<AppDatabase> {
  /// Records an audit event, tagged with the session / sortie it belongs to
  /// (looked up from [entityType] and [entityId] unless given), so a
  /// record's audit trail is one indexed query.
  Future<void> insertAuditEvent({
    required String entityType,
    required String entityId,
    required String action,
    String? description,
    required String performedBy,
    String? sessionId,
    String? flightId,
  }) async {
    flightId ??= await _scalar(auditFlightScopeSql[entityType], entityId);
    if (flightId != null) {
      sessionId ??= await _scalar(
        'SELECT session_id FROM sorties WHERE flight_id = ?',
        flightId,
      );
    }
    sessionId ??= await _scalar(auditSessionScopeSql[entityType], entityId);

    await into(db.auditEvents).insert(
      AuditEventsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        action: action,
        description: Value(description),
        performedBy: performedBy,
        sessionId: Value(sessionId),
        flightId: Value(flightId),
      ),
    );
  }

  /// Marks a record as needing upload. Each record keeps one pending row,
  /// merged with the new [operation]: created-then-edited stays an INSERT,
  /// created-then-deleted is dropped (the server never saw it), and
  /// deleted-then-recreated becomes an UPDATE.
  Future<void> enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
  }) async {
    final pending =
        await (select(db.syncQueue)
              ..where(
                (q) =>
                    q.entityType.equals(entityType) &
                    q.entityId.equals(entityId) &
                    q.syncStatus.equals(DbStatuses.pending),
              )
              ..limit(1))
            .getSingleOrNull();

    if (pending == null) {
      await into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          syncStatus: const Value(DbStatuses.pending),
        ),
      );
      return;
    }

    final merged = mergeSyncOperations(pending.operation, operation);
    if (merged == null) {
      await (delete(db.syncQueue)..where((q) => q.id.equals(pending.id))).go();
    } else {
      await (update(
        db.syncQueue,
      )..where((q) => q.id.equals(pending.id))).write(
        SyncQueueCompanion(
          operation: Value(merged),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<String?> _scalar(String? sql, String id) async {
    if (sql == null) return null;
    final row = await customSelect(
      sql,
      variables: [Variable.withString(id)],
    ).getSingleOrNull();
    return row?.data.values.first as String?;
  }
}

/// The single operation a pending upload should do after [previous]
/// followed by [next]; null when nothing needs uploading any more.
String? mergeSyncOperations(String previous, String next) {
  const insert = DbSyncOperations.insert;
  const update = DbSyncOperations.update;
  const delete = DbSyncOperations.delete;
  if (previous == insert && next == delete) return null;
  if (previous == insert) return insert;
  if (previous == delete && next == insert) return update;
  if (next == delete) return delete;
  return update;
}
