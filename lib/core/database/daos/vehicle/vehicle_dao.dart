import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/checklists/common_preflight.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/vehicle/domain/dtos/vehicle_dtos.dart';

part 'vehicle_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(
  tables: [
    Vehicles,
    VehicleChecklistTemplates,
    ChecklistItems,
    AuditEvents,
    SyncQueue,
  ],
)
class VehicleDao extends DatabaseAccessor<AppDatabase> with _$VehicleDaoMixin {
  VehicleDao(super.db);

  static const _log = AppLogger('VehicleDao');

  Future<String> createVehicleWithChecklist({
    String? vehicleId,
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
    _log.t(
      'createVehicleWithChecklist(vehicleId: $vehicleId, name: $name, '
      'type: $type, items: ${checklistItems.length})',
    );
    return _log.trace('createVehicleWithChecklist', () async {
      _validateVehicleType(type);
      _validateChecklistItems(checklistItems);

      final resolvedVehicleId = vehicleId ?? _uuid.v4();
      final templateId = _uuid.v4();

      await transaction(() async {
        await into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: resolvedVehicleId,
            name: name.trim(),
            type: type,
            frameMake: Value(frameMake),
            frameModel: Value(frameModel),
            motorCount: Value(motorCount),
            frameStyle: Value(frameStyle),
            firmwareTarget: Value(firmwareTarget),
            defaultFailSafeProfile: Value(defaultFailSafeProfile),
            notes: Value(notes),
          ),
        );

        await into(db.vehicleChecklistTemplates).insert(
          VehicleChecklistTemplatesCompanion.insert(
            id: templateId,
            vehicleId: resolvedVehicleId,
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
              section: item.section.trim(),
              label: item.label.trim(),
              responseType: item.responseType,
              isRequired: Value(item.isRequired),
              blocksArming: Value(item.blocksArming),
              sortOrder: i + 1,
            ),
          );
        }

        await _insertAuditEvent(
          entityType: 'VEHICLE',
          entityId: resolvedVehicleId,
          action: 'CREATE',
          description: 'Vehicle and checklist template created',
          performedBy: createdByUserId,
        );

        await _enqueueSync(
          entityType: 'VEHICLE',
          entityId: resolvedVehicleId,
          operation: 'INSERT',
        );

        await _enqueueSync(
          entityType: 'VEHICLE_CHECKLIST_TEMPLATE',
          entityId: templateId,
          operation: 'INSERT',
        );
      });

      return resolvedVehicleId;
    });
  }

  Future<Vehicle?> getVehicleById(String vehicleId) {
    _log.t('getVehicleById(vehicleId: $vehicleId)');
    return (select(
      db.vehicles,
    )..where((v) => v.id.equals(vehicleId))).getSingleOrNull();
  }

  Future<List<Vehicle>> getActiveVehicles() {
    _log.t('getActiveVehicles()');
    return (select(db.vehicles)
          ..where((v) => v.status.equals('ACTIVE'))
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .get();
  }

  Future<List<Vehicle>> getAllVehicles() {
    _log.t('getAllVehicles()');
    return (select(
      db.vehicles,
    )..orderBy([(v) => OrderingTerm.asc(v.name)])).get();
  }

  Future<List<Vehicle>> searchVehicles(String query) {
    _log.t('searchVehicles(query: $query)');
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return getAllVehicles();
    }

    final likeQuery = '%$normalizedQuery%';

    return (select(db.vehicles)
          ..where(
            (v) =>
                v.name.like(likeQuery) |
                v.type.like(likeQuery) |
                v.status.like(likeQuery) |
                v.frameMake.like(likeQuery) |
                v.frameModel.like(likeQuery),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .get();
  }

  Future<void> updateVehicle({
    required String vehicleId,
    String? name,
    String? type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? status,
    String? notes,
    required String performedBy,
  }) async {
    _log.t(
      'updateVehicle(vehicleId: $vehicleId, type: $type, status: $status)',
    );
    return _log.trace('updateVehicle', () async {
      await _requireVehicle(vehicleId);

      if (type != null) {
        _validateVehicleType(type);
      }

      if (status != null) {
        _validateVehicleStatus(status);
      }

      await transaction(() async {
        await (update(db.vehicles)..where((v) => v.id.equals(vehicleId))).write(
          VehiclesCompanion(
            name: name == null ? const Value.absent() : Value(name.trim()),
            type: type == null ? const Value.absent() : Value(type),
            frameMake: frameMake == null
                ? const Value.absent()
                : Value(frameMake),
            frameModel: frameModel == null
                ? const Value.absent()
                : Value(frameModel),
            motorCount: motorCount == null
                ? const Value.absent()
                : Value(motorCount),
            frameStyle: frameStyle == null
                ? const Value.absent()
                : Value(frameStyle),
            firmwareTarget: firmwareTarget == null
                ? const Value.absent()
                : Value(firmwareTarget),
            defaultFailSafeProfile: defaultFailSafeProfile == null
                ? const Value.absent()
                : Value(defaultFailSafeProfile),
            status: status == null ? const Value.absent() : Value(status),
            notes: notes == null ? const Value.absent() : Value(notes),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _insertAuditEvent(
          entityType: 'VEHICLE',
          entityId: vehicleId,
          action: 'UPDATE',
          description: 'Vehicle updated',
          performedBy: performedBy,
        );

        await _enqueueSync(
          entityType: 'VEHICLE',
          entityId: vehicleId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<void> markVehicleActive({
    required String vehicleId,
    required String performedBy,
  }) {
    _log.t('markVehicleActive(vehicleId: $vehicleId)');
    return updateVehicle(
      vehicleId: vehicleId,
      status: 'ACTIVE',
      performedBy: performedBy,
    );
  }

  Future<void> markVehicleInactive({
    required String vehicleId,
    required String performedBy,
  }) {
    _log.t('markVehicleInactive(vehicleId: $vehicleId)');
    return updateVehicle(
      vehicleId: vehicleId,
      status: 'INACTIVE',
      performedBy: performedBy,
    );
  }

  Future<void> retireVehicle({
    required String vehicleId,
    required String performedBy,
  }) {
    _log.t('retireVehicle(vehicleId: $vehicleId)');
    return updateVehicle(
      vehicleId: vehicleId,
      status: 'RETIRED',
      performedBy: performedBy,
    );
  }

  Future<VehicleChecklistTemplate?> getActiveChecklistTemplateForVehicle(
    String vehicleId,
  ) {
    _log.t('getActiveChecklistTemplateForVehicle(vehicleId: $vehicleId)');
    return (select(db.vehicleChecklistTemplates)
          ..where((v) => v.vehicleId.equals(vehicleId))
          ..where((v) => v.isActive.equals(true))
          ..orderBy([(v) => OrderingTerm.desc(v.version)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<VehicleChecklistTemplate>> getChecklistTemplatesForVehicle(
    String vehicleId,
  ) {
    _log.t('getChecklistTemplatesForVehicle(vehicleId: $vehicleId)');
    return (select(db.vehicleChecklistTemplates)
          ..where((v) => v.vehicleId.equals(vehicleId))
          ..orderBy([(v) => OrderingTerm.desc(v.version)]))
        .get();
  }

  Future<List<ChecklistItem>> getChecklistForVehicle(String vehicleId) async {
    _log.t('getChecklistForVehicle(vehicleId: $vehicleId)');
    final template = await getActiveChecklistTemplateForVehicle(vehicleId);

    if (template == null) {
      _log.d('No active checklist template for vehicle $vehicleId');
      return [];
    }

    return getChecklistItemsForTemplate(template.id);
  }

  Future<List<ChecklistItem>> getChecklistItemsForTemplate(String templateId) {
    _log.t('getChecklistItemsForTemplate(templateId: $templateId)');
    return (select(db.checklistItems)
          ..where((v) => v.templateId.equals(templateId))
          ..where((v) => v.isActive.equals(true))
          ..orderBy([(v) => OrderingTerm.asc(v.sortOrder)]))
        .get();
  }

  Future<String> createNewChecklistVersionForVehicle({
    required String vehicleId,
    required List<ChecklistItemDraft> checklistItems,
    required String createdBy,
    String? deactivationReason,
  }) async {
    _log.t(
      'createNewChecklistVersionForVehicle(vehicleId: $vehicleId, '
      'items: ${checklistItems.length})',
    );
    return _log.trace('createNewChecklistVersionForVehicle', () async {
      await _requireVehicle(vehicleId);
      _validateChecklistItems(checklistItems);

      final existingTemplates = await getChecklistTemplatesForVehicle(
        vehicleId,
      );

      final maxVersion = existingTemplates.fold<int>(
        0,
        (currentMax, template) =>
            template.version > currentMax ? template.version : currentMax,
      );

      final nextVersion = maxVersion + 1;
      _log.d('Creating checklist version $nextVersion for vehicle $vehicleId');
      final newTemplateId = _uuid.v4();
      final now = DateTime.now();

      await transaction(() async {
        await (update(db.vehicleChecklistTemplates)..where(
              (v) => v.vehicleId.equals(vehicleId) & v.isActive.equals(true),
            ))
            .write(
              VehicleChecklistTemplatesCompanion(
                isActive: const Value(false),
                deactivatedAt: Value(now),
                deactivatedBy: Value(createdBy),
                deactivationReason: Value(
                  deactivationReason ?? 'Replaced by version $nextVersion',
                ),
                updatedAt: Value(now),
              ),
            );

        await into(db.vehicleChecklistTemplates).insert(
          VehicleChecklistTemplatesCompanion.insert(
            id: newTemplateId,
            vehicleId: vehicleId,
            version: nextVersion,
            createdBy: Value(createdBy),
          ),
        );

        for (var i = 0; i < checklistItems.length; i++) {
          final item = checklistItems[i];

          await into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: _uuid.v4(),
              templateId: newTemplateId,
              section: item.section.trim(),
              label: item.label.trim(),
              responseType: item.responseType,
              isRequired: Value(item.isRequired),
              blocksArming: Value(item.blocksArming),
              sortOrder: i + 1,
            ),
          );
        }

        await _insertAuditEvent(
          entityType: 'VEHICLE',
          entityId: vehicleId,
          action: 'CHECKLIST_VERSION_CREATED',
          description: 'Checklist version $nextVersion created',
          performedBy: createdBy,
        );

        await _enqueueSync(
          entityType: 'VEHICLE_CHECKLIST_TEMPLATE',
          entityId: newTemplateId,
          operation: 'INSERT',
        );

        await _enqueueSync(
          entityType: 'VEHICLE',
          entityId: vehicleId,
          operation: 'UPDATE',
        );
      });

      return newTemplateId;
    });
  }

  Future<void> deactivateChecklistTemplate({
    required String templateId,
    required String deactivatedBy,
    String? deactivationReason,
  }) async {
    _log.t('deactivateChecklistTemplate(templateId: $templateId)');
    return _log.trace('deactivateChecklistTemplate', () async {
      final template = await _requireChecklistTemplate(templateId);
      final now = DateTime.now();

      await transaction(() async {
        await (update(
          db.vehicleChecklistTemplates,
        )..where((v) => v.id.equals(templateId))).write(
          VehicleChecklistTemplatesCompanion(
            isActive: const Value(false),
            deactivatedAt: Value(now),
            deactivatedBy: Value(deactivatedBy),
            deactivationReason: Value(
              deactivationReason ?? 'Checklist template deactivated',
            ),
            updatedAt: Value(now),
          ),
        );

        await _insertAuditEvent(
          entityType: 'VEHICLE_CHECKLIST_TEMPLATE',
          entityId: templateId,
          action: 'DEACTIVATE',
          description: 'Checklist template deactivated',
          performedBy: deactivatedBy,
        );

        await _enqueueSync(
          entityType: 'VEHICLE_CHECKLIST_TEMPLATE',
          entityId: templateId,
          operation: 'UPDATE',
        );

        await _enqueueSync(
          entityType: 'VEHICLE',
          entityId: template.vehicleId,
          operation: 'UPDATE',
        );
      });
    });
  }

  Future<Vehicle> _requireVehicle(String vehicleId) async {
    final vehicle = await getVehicleById(vehicleId);

    if (vehicle == null) {
      _log.w('Vehicle not found: $vehicleId');
      throw Exception('Vehicle not found: $vehicleId');
    }

    return vehicle;
  }

  Future<VehicleChecklistTemplate> _requireChecklistTemplate(
    String templateId,
  ) async {
    final template = await (select(
      db.vehicleChecklistTemplates,
    )..where((v) => v.id.equals(templateId))).getSingleOrNull();

    if (template == null) {
      _log.w('Checklist template not found: $templateId');
      throw Exception('Checklist template not found: $templateId');
    }

    return template;
  }

  void _validateVehicleType(String type) {
    const allowedTypes = {'MULTIROTOR', 'FIXED_WING', 'VTOL'};

    if (!allowedTypes.contains(type)) {
      _log.w('Invalid vehicle type: $type');
      throw Exception('Invalid vehicle type: $type');
    }
  }

  void _validateVehicleStatus(String status) {
    const allowedStatuses = {'ACTIVE', 'INACTIVE', 'RETIRED'};

    if (!allowedStatuses.contains(status)) {
      _log.w('Invalid vehicle status: $status');
      throw Exception('Invalid vehicle status: $status');
    }
  }

  void _validateChecklistItems(List<ChecklistItemDraft> checklistItems) {
    if (checklistItems.isEmpty) {
      _log.w('Vehicle checklist cannot be empty.');
      throw Exception('Vehicle checklist cannot be empty.');
    }

    for (final item in checklistItems) {
      if (item.section.trim().isEmpty) {
        _log.w('Checklist item section cannot be empty.');
        throw Exception('Checklist item section cannot be empty.');
      }

      if (item.label.trim().isEmpty) {
        _log.w('Checklist item label cannot be empty.');
        throw Exception('Checklist item label cannot be empty.');
      }

      _validateChecklistResponseType(item.responseType);
    }
  }

  void _validateChecklistResponseType(String responseType) {
    const allowedResponseTypes = {
      ...ChecklistResponseTypes.all,
      'CHECKBOX',
      'TEXT',
    };

    if (!allowedResponseTypes.contains(responseType)) {
      _log.w('Invalid checklist response type: $responseType');
      throw Exception('Invalid checklist response type: $responseType');
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
        performedAt: Value(DateTime.now()),
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
      ),
    );
  }
}
