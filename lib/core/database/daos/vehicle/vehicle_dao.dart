import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import '../../app_database.dart';

part 'vehicle_dao.g.dart';

const _uuid = Uuid();

class ChecklistItemDraft {
  final String section;
  final String label;
  final String responseType;
  final bool isRequired;
  final bool blocksArming;

  const ChecklistItemDraft({
    required this.section,
    required this.label,
    required this.responseType,
    this.isRequired = true,
    this.blocksArming = false,
  });
}

@DriftAccessor(
  tables: [
    Vehicles,
    VehicleChecklistTemplates,
    ChecklistItems,
    Payloads,
    PayloadVehicleCompatibility,
    Batteries,
    AuditEvents,
    SyncQueue
  ],
)

class VehicleDao extends DatabaseAccessor<AppDatabase> with _$VehicleDaoMixin {
  VehicleDao(super.db);

  Future<void> CreateVehicleWithChecklist({
    required String vehicleId,
    required String name,
    required String type,
    required String createdByUserId,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? notes,
    required List<ChecklistItemDraft> checklistItems,
  }) async {
      await transaction (() async {
        await into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            name: name,
            type: type,
            frameMake: Value(frameMake),
            frameModel: Value(frameModel),
            motorCount: Value(motorCount),
            firmwareTarget: Value(firmwareTarget),
            defaultFailSafeProfile: Value(defaultFailSafeProfile),
            notes: Value(notes),
          ),
        );
        final templateId = _uuid.v4();
        
        await into(db.vehicleChecklistTemplates).insert(
          VehicleChecklistTemplatesCompanion.insert(
            id: templateId,
            vehicleId:vehicleId,
            version: 1,
            createdBy: Value(createdByUserId),
          ),
        );
        
        for (var i = 0; i < checklistItems.length; i++) {
          final item = checklistItems[i];

          await into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: _uuid.v4(),
              templateId: templateId,
              section: item.section,
              label: item.label,
              responseType: item.responseType,
              isRequired: Value(item.isRequired),
              blocksArming: Value(item.blocksArming),
              sortOrder: i + 1,
            ),
          );
        }

        await into(db.auditEvents).insert(
          AuditEventsCompanion.insert(
            entityId: vehicleId,
            entityType: 'VEHICLE',
            action: 'CREATE',
            description: Value('Vechile and checklist templates are created'),
            performedBy: createdByUserId,
          ),
        );

        await into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            entityType: 'VEHICLE', 
            entityId: vehicleId, 
            operation: 'INSERT'
          ),
        );
      });
    }

    Future<List<Vehicle>> getActiveVehicles() {
      return (select(db.vehicles)
              ..where((tbl) => tbl.status.equals('ACTIVE'))
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.name),
              ]))
              .get();
    }
    Future<List<ChecklistItem>> getChecklistForVehicle(String vehicleId) async {
      final template = await (select(db.vehicleChecklistTemplates)
            ..where((tbl) => tbl.vehicleId.equals(vehicleId))
            ..where((tbl) => tbl.isActive.equals(true))
            ..orderBy([
              (tbl) => OrderingTerm.desc(tbl.version),
            ])
            ..limit(1))
            .getSingle();
      return (select(db.checklistItems)
            ..where((tbl) => tbl.templateId.equals(template.id))
            ..where((tbl) => tbl.isActive.equals(true))
            ..orderBy([
              (tbl) => OrderingTerm.asc(tbl.sortOrder),
            ]))
            .get();
    }
}