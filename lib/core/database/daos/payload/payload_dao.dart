import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import '../../app_database.dart';

part 'payload_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(
  tables: [
    Payloads,
    PayloadVehicleCompatibility,
    AuditEvents,
    SyncQueue,
  ],
)

class PayloadDao extends DatabaseAccessor<AppDatabase> with _$PayloadDaoMixin{
  PayloadDao(super.db);

  Future<void> CreatePayload({
    required String payloadId,
    required String name,
    required String category,
    String? storageType,
    String? storageCapacity,
    List<String> compatibleVehicleTypes = const [],
    required String performedBy,
  }) async {
    await transaction(() async {
      await into(db.payloads).insert(
        PayloadsCompanion.insert(
          payloadId: payloadId, 
          name: name, 
          category: category,
          storageType: Value(storageType),
          storageCapacity: Value(storageCapacity),
          ),
      );

      final uniqueTypes = compatibleVehicleTypes.toSet();

      for(final vehicleType in uniqueTypes){
        await into(db.payloadVehicleCompatibility).insert(
          PayloadVehicleCompatibilityCompanion.insert(
            id: _uuid.v4(), 
            payloadId: payloadId, 
            vehicleType: vehicleType
            ),
        );
      }

      await into(db.auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: 'PAYLOAD', 
          entityId: payloadId, 
          action: 'CREATE', 
          description: Value('Payload is created'),
          performedBy: performedBy,
          ),
      );

      await into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          entityType: 'PAYLOAD', 
          entityId: payloadId, 
          operation: 'INSERT'
          ),
      );
    });
  }

  Future<Payload?> getPayloadById(String payloadId){
    return (select(db.payloads)
            ..where((v) => v.payloadId.equals(payloadId)))
            .getSingleOrNull();
  }

  Future<List<Payload>> getAllPayloads() {
    return (select(db.payloads)
          ..orderBy([
            (v) => OrderingTerm.asc(v.name),
          ]))
          .get();
  }

  Future<List<String>> getCompatibleVehicleTypes(String payloadId) async {
    final rows = await (select(db.payloadVehicleCompatibility)
                  ..where((v) => v.payloadId.equals(payloadId)))
                  .get();
    return rows.map((row) => row.vehicleType).toList();
  }

  Future<bool> isPayloadCompatibleWithVehicleType({
    required String payloadId,
    required String vehicleType,
  }) async {
    final compatibilityRows = await (select(db.payloadVehicleCompatibility)
          ..where((v) => v.payloadId.equals(payloadId)))
          .get();

          if (compatibilityRows.isEmpty){
            return true;
          }
    return compatibilityRows.any((rows) => rows.vehicleType == vehicleType);
  }
  Future<List<Payload>> getPayloadsExplicitlyCompatibleWithVehicleType(String vehicleType) async {
    final query = select(db.payloads).join([
      innerJoin(
        db.payloadVehicleCompatibility,
        db.payloadVehicleCompatibility.payloadId.equalsExp(db.payloads.payloadId),
      ),
    ])
      ..where(db.payloadVehicleCompatibility.vehicleType.equals(vehicleType))
      ..orderBy([
        OrderingTerm.asc(db.payloads.name),
      ]);

    final rows = await query.get();

    return rows.map((row) => row.readTable(db.payloads)).toList();
  }

Future<void> replacePayloadCompatibility({
  required String payloadId,
  required List<String> compatibleVehicleTypes,
}) async {
  await transaction(() async {
    await (delete(db.payloadVehicleCompatibility)
          ..where((tbl) => tbl.payloadId.equals(payloadId)))
        .go();

    final uniqueTypes = compatibleVehicleTypes.toSet();

    for (final vehicleType in uniqueTypes) {
      await into(db.payloadVehicleCompatibility).insert(
        PayloadVehicleCompatibilityCompanion.insert(
          id: _uuid.v4(),
          payloadId: payloadId,
          vehicleType: vehicleType,
        ),
      );
    }
  });
}

Future<void> addPayloadCompatibility({
  required String payloadId,
  required String vehicleType,
}) async {
  await into(db.payloadVehicleCompatibility).insertOnConflictUpdate(
    PayloadVehicleCompatibilityCompanion.insert(
      id: _uuid.v4(),
      payloadId: payloadId,
      vehicleType: vehicleType,
    ),
  );
}

Future<void> removePayloadCompatibility({
  required String payloadId,
  required String vehicleType,
}) async {
  await (delete(db.payloadVehicleCompatibility)
        ..where((tbl) =>
            tbl.payloadId.equals(payloadId) &
            tbl.vehicleType.equals(vehicleType)))
      .go();
}

Future<void> updatePayload({
  required String payloadId,
  String? name,
  String? category,
  String? storageType,
  String? storageCapacity,
  required String performedBy,
}) async {
  await transaction(() async {
    await (update(db.payloads)
          ..where((tbl) => tbl.payloadId.equals(payloadId)))
        .write(
      PayloadsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        category: category == null ? const Value.absent() : Value(category),
        storageType:
            storageType == null ? const Value.absent() : Value(storageType),
        storageCapacity: storageCapacity == null
            ? const Value.absent()
            : Value(storageCapacity),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await into(db.auditEvents).insert(
      AuditEventsCompanion.insert(
        entityType: 'PAYLOAD',
        entityId: payloadId,
        action: 'UPDATE',
        description: const Value('Payload updated'),
        performedBy: performedBy,
      ),
    );

    await into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: 'PAYLOAD',
        entityId: payloadId,
        operation: 'UPDATE',
      ),
    );
  });
}
}
