import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';

import '../../app_database.dart';

part 'payload_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(
  tables: [
    Payloads,
    PayloadVehicleCompatibility,
    PayloadVehicles,
    SessionVehiclePayload,
    SortiePayloads,
    AuditEvents,
    SyncQueue,
  ],
)
class PayloadDao extends DatabaseAccessor<AppDatabase> with _$PayloadDaoMixin {
  PayloadDao(super.db);

  static const _log = AppLogger('PayloadDao');

  Future<String> createPayload({
    String? payloadId,
    required String name,
    required String category,
    String? storageType,
    String? storageCapacity,
    String? status,
    List<String> compatibleVehicleTypes = const [],
    required String performedBy,
  }) async {
    _log.t(
      'createPayload(payloadId: $payloadId, name: $name, category: $category, '
      'types: ${compatibleVehicleTypes.length})',
    );
    return _log.trace('createPayload', () async {
      final id = payloadId ?? _uuid.v4();
      final resolvedStatus = status ?? 'ACTIVE';

      await transaction(() async {
        await into(db.payloads).insert(
          PayloadsCompanion.insert(
            payloadId: id,
            name: name,
            category: category,
            storageType: Value(storageType),
            storageCapacity: Value(storageCapacity),
            status: Value(resolvedStatus),
          ),
        );

        final uniqueTypes = _normalizeVehicleTypes(compatibleVehicleTypes);

        for (final vehicleType in uniqueTypes) {
          await _insertCompatibilityRow(
            payloadId: id,
            vehicleType: vehicleType,
          );
        }

        await _insertAuditEvent(
          entityType: 'PAYLOAD',
          entityId: id,
          action: 'CREATE',
          description: 'Payload created',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'PAYLOAD',
          entityId: id,
          operation: 'INSERT',
        );
      });

      return id;
    });
  }

  Future<Payload?> getPayloadById(String payloadId) {
    _log.t('getPayloadById(payloadId: $payloadId)');
    return (select(
      db.payloads,
    )..where((v) => v.payloadId.equals(payloadId))).getSingleOrNull();
  }

  Future<List<Payload>> getAllPayloads() {
    _log.t('getAllPayloads()');
    return (select(
      db.payloads,
    )..orderBy([(v) => OrderingTerm.asc(v.name)])).get();
  }

  Future<List<Payload>> searchPayloads(String query) {
    _log.t('searchPayloads(query: $query)');
    final cleanedQuery = query.trim();

    if (cleanedQuery.isEmpty) {
      return getAllPayloads();
    }

    final likeQuery = '%$cleanedQuery%';

    return (select(db.payloads)
          ..where(
            (v) =>
                v.name.like(likeQuery) |
                v.category.like(likeQuery) |
                v.status.like(likeQuery) |
                v.storageType.like(likeQuery) |
                v.storageCapacity.like(likeQuery),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .get();
  }

  Future<List<PayloadVehicleCompatibilityData>> getCompatibilityRulesForPayload(
    String payloadId,
  ) {
    _log.t('getCompatibilityRulesForPayload(payloadId: $payloadId)');
    return (select(db.payloadVehicleCompatibility)
          ..where((v) => v.payloadId.equals(payloadId))
          ..orderBy([(v) => OrderingTerm.asc(v.vehicleType)]))
        .get();
  }

  /// Specific vehicles [payloadId] is limited to; empty means no per-vehicle
  /// limit (its vehicle-type rules apply).
  Future<List<String>> getLimitedVehicleIds(String payloadId) async {
    _log.t('getLimitedVehicleIds(payloadId: $payloadId)');
    final rows = await (select(
      payloadVehicles,
    )..where((t) => t.payloadId.equals(payloadId))).get();
    return [for (final row in rows) row.vehicleId];
  }

  Future<List<String>> getCompatibleVehicleTypes(String payloadId) async {
    _log.t('getCompatibleVehicleTypes(payloadId: $payloadId)');
    final rows = await getCompatibilityRulesForPayload(payloadId);

    return rows.map((row) => row.vehicleType).toList();
  }

  Future<bool> isPayloadCompatibleWithVehicleType({
    required String payloadId,
    required String vehicleType,
  }) async {
    _log.t(
      'isPayloadCompatibleWithVehicleType(payloadId: $payloadId, '
      'vehicleType: $vehicleType)',
    );
    final rows = await getCompatibilityRulesForPayload(payloadId);

    // No rows means unrestricted payload.
    // It can be used with any vehicle type.
    if (rows.isEmpty) {
      return true;
    }

    final normalizedVehicleType = vehicleType.trim().toUpperCase();

    return rows.any(
      (row) => row.vehicleType.trim().toUpperCase() == normalizedVehicleType,
    );
  }

  Future<List<Payload>> getPayloadsCompatibleWithVehicleType(
    String vehicleType,
  ) async {
    _log.t('getPayloadsCompatibleWithVehicleType(vehicleType: $vehicleType)');
    final allPayloads = await getAllPayloads();
    final compatiblePayloads = <Payload>[];

    for (final payload in allPayloads) {
      final isCompatible = await isPayloadCompatibleWithVehicleType(
        payloadId: payload.payloadId,
        vehicleType: vehicleType,
      );

      if (isCompatible) {
        compatiblePayloads.add(payload);
      }
    }

    _log.d(
      '${compatiblePayloads.length}/${allPayloads.length} payloads compatible '
      'with $vehicleType',
    );
    return compatiblePayloads;
  }

  Future<List<Payload>> getPayloadsExplicitlyCompatibleWithVehicleType(
    String vehicleType,
  ) async {
    _log.t(
      'getPayloadsExplicitlyCompatibleWithVehicleType(vehicleType: $vehicleType)',
    );
    final normalizedVehicleType = vehicleType.trim().toUpperCase();

    final query =
        select(db.payloads).join([
            innerJoin(
              db.payloadVehicleCompatibility,
              db.payloadVehicleCompatibility.payloadId.equalsExp(
                db.payloads.payloadId,
              ),
            ),
          ])
          ..where(
            db.payloadVehicleCompatibility.vehicleType.equals(
              normalizedVehicleType,
            ),
          )
          ..orderBy([OrderingTerm.asc(db.payloads.name)]);

    final rows = await query.get();

    return rows.map((row) => row.readTable(db.payloads)).toList();
  }

  Future<void> updatePayload({
    required String payloadId,
    String? name,
    String? category,
    String? storageType,
    String? storageCapacity,
    String? status,
    required String performedBy,
  }) async {
    _log.t('updatePayload(payloadId: $payloadId, status: $status)');
    return _log.trace('updatePayload', () async {
      await _requirePayloadExists(payloadId);

      await transaction(() async {
        await (update(
          db.payloads,
        )..where((v) => v.payloadId.equals(payloadId))).write(
          PayloadsCompanion(
            name: name == null ? const Value.absent() : Value(name),
            category: category == null ? const Value.absent() : Value(category),
            storageType: storageType == null
                ? const Value.absent()
                : Value(storageType),
            storageCapacity: storageCapacity == null
                ? const Value.absent()
                : Value(storageCapacity),
            status: status == null ? const Value.absent() : Value(status),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          action: 'UPDATE',
          description: 'Payload updated',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> retirePayload({
    required String payloadId,
    required String performedBy,
  }) {
    _log.t('retirePayload(payloadId: $payloadId)');
    return updatePayload(
      payloadId: payloadId,
      status: 'RETIRED',
      performedBy: performedBy,
    );
  }

  Future<void> deletePayload({
    required String payloadId,
    required String performedBy,
  }) async {
    _log.t('deletePayload(payloadId: $payloadId)');
    return _log.trace('deletePayload', () async {
      await _requirePayloadExists(payloadId);

      final usageCount = await _countPayloadUsage(payloadId);

      if (usageCount > 0) {
        _log.w(
          'Cannot delete payload $payloadId: used in $usageCount sessions/sorties',
        );
        throw AppFailure(
          'Cannot delete payload because it is already used in sessions or sorties.',
        );
      }

      await transaction(() async {
        await (delete(
          db.payloadVehicleCompatibility,
        )..where((v) => v.payloadId.equals(payloadId))).go();

        // Vehicle limits point at the payload too.
        await (delete(
          db.payloadVehicles,
        )..where((v) => v.payloadId.equals(payloadId))).go();

        await (delete(
          db.payloads,
        )..where((v) => v.payloadId.equals(payloadId))).go();

        await _insertAuditEvent(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          action: 'DELETE',
          description: 'Payload deleted',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          operation: 'DELETE',
        );
      });
    });
  }

  Future<void> replacePayloadCompatibility({
    required String payloadId,
    required List<String> compatibleVehicleTypes,
    required String performedBy,
  }) async {
    _log.t(
      'replacePayloadCompatibility(payloadId: $payloadId, '
      'types: ${compatibleVehicleTypes.length})',
    );
    return _log.trace('replacePayloadCompatibility', () async {
      await _requirePayloadExists(payloadId);

      await transaction(() async {
        await (delete(
          db.payloadVehicleCompatibility,
        )..where((v) => v.payloadId.equals(payloadId))).go();

        final uniqueTypes = _normalizeVehicleTypes(compatibleVehicleTypes);

        for (final vehicleType in uniqueTypes) {
          await _insertCompatibilityRow(
            payloadId: payloadId,
            vehicleType: vehicleType,
          );
        }

        await _insertAuditEvent(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          action: 'REPLACE_COMPATIBILITY',
          description: 'Payload compatibility replaced',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> addPayloadCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  }) async {
    _log.t(
      'addPayloadCompatibility(payloadId: $payloadId, vehicleType: $vehicleType)',
    );
    return _log.trace('addPayloadCompatibility', () async {
      await _requirePayloadExists(payloadId);

      final normalizedVehicleType = vehicleType.trim().toUpperCase();

      if (normalizedVehicleType.isEmpty) {
        _log.w('Vehicle type cannot be empty.');
        throw AppFailure('Vehicle type cannot be empty.');
      }

      final existing =
          await (select(db.payloadVehicleCompatibility)..where(
                (v) =>
                    v.payloadId.equals(payloadId) &
                    v.vehicleType.equals(normalizedVehicleType),
              ))
              .getSingleOrNull();

      if (existing != null) {
        _log.d(
          'Compatibility already exists: $payloadId $normalizedVehicleType',
        );
        return;
      }

      await transaction(() async {
        await _insertCompatibilityRow(
          payloadId: payloadId,
          vehicleType: normalizedVehicleType,
        );

        await _insertAuditEvent(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          action: 'ADD_COMPATIBILITY',
          description: 'Payload compatibility added: $normalizedVehicleType',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> removePayloadCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  }) async {
    _log.t(
      'removePayloadCompatibility(payloadId: $payloadId, '
      'vehicleType: $vehicleType)',
    );
    return _log.trace('removePayloadCompatibility', () async {
      await _requirePayloadExists(payloadId);

      final normalizedVehicleType = vehicleType.trim().toUpperCase();

      await transaction(() async {
        await (delete(db.payloadVehicleCompatibility)..where(
              (v) =>
                  v.payloadId.equals(payloadId) &
                  v.vehicleType.equals(normalizedVehicleType),
            ))
            .go();

        await _insertAuditEvent(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          action: 'REMOVE_COMPATIBILITY',
          description: 'Payload compatibility removed: $normalizedVehicleType',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'PAYLOAD',
          entityId: payloadId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> _requirePayloadExists(String payloadId) async {
    final payload = await getPayloadById(payloadId);

    if (payload == null) {
      _log.w('Payload not found: $payloadId');
      throw AppFailure('Payload not found: $payloadId');
    }
  }

  Future<void> _insertCompatibilityRow({
    required String payloadId,
    required String vehicleType,
  }) async {
    await into(db.payloadVehicleCompatibility).insert(
      PayloadVehicleCompatibilityCompanion.insert(
        id: _uuid.v4(),
        payloadId: payloadId,
        vehicleType: vehicleType.trim().toUpperCase(),
      ),
    );
  }

  Set<String> _normalizeVehicleTypes(List<String> vehicleTypes) {
    return vehicleTypes
        .map((type) => type.trim().toUpperCase())
        .where((type) => type.isNotEmpty)
        .toSet();
  }

  Future<int> _countPayloadUsage(String payloadId) async {
    final sessionPayloads = await (select(
      db.sessionVehiclePayload,
    )..where((v) => v.payloadId.equals(payloadId))).get();

    final sortiePayloads = await (select(
      db.sortiePayloads,
    )..where((v) => v.payloadId.equals(payloadId))).get();

    return sessionPayloads.length + sortiePayloads.length;
  }

  Future<void> _insertAuditEvent({
    required String entityType,
    required String entityId,
    required String action,
    String? description,
    required String performedBy,
  }) async {
    await into(db.auditEvents).insert(
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
  }) async {
    await into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
      ),
    );
  }
}
