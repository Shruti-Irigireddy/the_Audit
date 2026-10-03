import 'package:the_audit/core/database/daos/vehicle/vehicle_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';

import 'package:the_audit/features/vehicle/data/mappers/vehicle_mapper.dart';
import 'package:the_audit/features/vehicle/domain/dtos/vehicle_dtos.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_checklist_template_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_with_checklist_entity.dart';
import 'package:the_audit/features/vehicle/domain/repositories/vehicle_repository.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  static const _log = AppLogger('VehicleRepositoryImpl');

  final VehicleDao _vehicleDao;

  const VehicleRepositoryImpl(this._vehicleDao);

  @override
  Future<String> createVehicleWithChecklist({
    String? vehicleId,
    required String name,
    required String type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? notes,
    required String createdBy,
    required List<ChecklistItemDraft> checklistItems,
  }) {
    _log.t('createVehicleWithChecklist(vehicleId: $vehicleId)');
    return _vehicleDao.createVehicleWithChecklist(
      vehicleId: vehicleId,
      name: name,
      type: type,
      frameMake: frameMake,
      frameModel: frameModel,
      motorCount: motorCount,
      frameStyle: frameStyle,
      firmwareTarget: firmwareTarget,
      defaultFailSafeProfile: defaultFailSafeProfile,
      notes: notes,
      createdByUserId: createdBy,
      checklistItems: checklistItems,
    );
  }

  @override
  Future<VehicleEntity?> getVehicleById(String vehicleId) async {
    _log.t('getVehicleById(vehicleId: $vehicleId)');
    final vehicle = await _vehicleDao.getVehicleById(vehicleId);
    return vehicle?.toEntity();
  }

  @override
  Future<VehicleWithChecklistEntity?> getVehicleWithActiveChecklist(
    String vehicleId,
  ) async {
    _log.t('getVehicleWithActiveChecklist(vehicleId: $vehicleId)');
    final vehicle = await _vehicleDao.getVehicleById(vehicleId);

    if (vehicle == null) return null;

    final template = await _vehicleDao.getActiveChecklistTemplateForVehicle(
      vehicleId,
    );
    final checklistItems = await _vehicleDao.getChecklistForVehicle(vehicleId);

    return VehicleWithChecklistEntity(
      vehicle: vehicle.toEntity(),
      activeTemplate: template?.toEntity(),
      checklistItems: checklistItems.map((item) => item.toEntity()).toList(),
    );
  }

  @override
  Future<List<VehicleEntity>> getActiveVehicles() async {
    _log.t('getActiveVehicles()');
    final vehicles = await _vehicleDao.getActiveVehicles();
    _log.d('getActiveVehicles: ${vehicles.length} items');
    return vehicles.map((vehicles) => vehicles.toEntity()).toList();
  }

  @override
  Future<List<VehicleEntity>> getAllVehicles() async {
    _log.t('getAllVehicles()');
    final vehicles = await _vehicleDao.getAllVehicles();
    _log.d('getAllVehicles: ${vehicles.length} items');
    return vehicles.map((vehicles) => vehicles.toEntity()).toList();
  }

  @override
  Future<List<VehicleEntity>> searchVehicles(String query) async {
    _log.t('searchVehicles(query: $query)');
    final vehicles = await _vehicleDao.searchVehicles(query);
    _log.d('searchVehicles: ${vehicles.length} items');
    return vehicles.map((vehicles) => vehicles.toEntity()).toList();
  }

  @override
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
  }) {
    _log.t('updateVehicle(vehicleId: $vehicleId, status: $status)');
    return _vehicleDao.updateVehicle(
      vehicleId: vehicleId,
      name: name,
      type: type,
      frameMake: frameMake,
      frameModel: frameModel,
      motorCount: motorCount,
      frameStyle: frameStyle,
      firmwareTarget: firmwareTarget,
      defaultFailSafeProfile: defaultFailSafeProfile,
      status: status,
      notes: notes,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> markVehicleActive({
    required String vehicleId,
    required String performedBy,
  }) {
    _log.t('markVehicleActive(vehicleId: $vehicleId)');
    return _vehicleDao.markVehicleActive(
      vehicleId: vehicleId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> markVehicleInactive({
    required String vehicleId,
    required String performedBy,
  }) {
    _log.t('markVehicleInactive(vehicleId: $vehicleId)');
    return _vehicleDao.markVehicleInactive(
      vehicleId: vehicleId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> retireVehicle({
    required String vehicleId,
    required String performedBy,
  }) {
    _log.t('retireVehicle(vehicleId: $vehicleId)');
    return _vehicleDao.retireVehicle(
      vehicleId: vehicleId,
      performedBy: performedBy,
    );
  }

  @override
  Future<VehicleChecklistTemplateEntity?> getActiveChecklistTemplateForVehicle(
    String vehicleId,
  ) async {
    _log.t('getActiveChecklistTemplateForVehicle(vehicleId: $vehicleId)');
    final template = await _vehicleDao.getActiveChecklistTemplateForVehicle(
      vehicleId,
    );
    return template?.toEntity();
  }

  @override
  Future<List<VehicleChecklistTemplateEntity>> getChecklistTemplatesForVehicle(
    String vehicleId,
  ) async {
    _log.t('getChecklistTemplatesForVehicle(vehicleId: $vehicleId)');
    final templates = await _vehicleDao.getChecklistTemplatesForVehicle(
      vehicleId,
    );
    _log.d('getChecklistTemplatesForVehicle: ${templates.length} items');
    return templates.map((templates) => templates.toEntity()).toList();
  }

  @override
  Future<List<ChecklistItemEntity>> getChecklistForVehicle(
    String vehicleId,
  ) async {
    _log.t('getChecklistForVehicle(vehicleId: $vehicleId)');
    final checklistItems = await _vehicleDao.getChecklistForVehicle(vehicleId);
    _log.d('getChecklistForVehicle: ${checklistItems.length} items');
    return checklistItems
        .map((checklistItems) => checklistItems.toEntity())
        .toList();
  }

  @override
  Future<List<ChecklistItemEntity>> getChecklistItemsForTemplate(
    String templateId,
  ) async {
    _log.t('getChecklistItemsForTemplate(templateId: $templateId)');
    final checklistItems = await _vehicleDao.getChecklistItemsForTemplate(
      templateId,
    );
    _log.d('getChecklistItemsForTemplate: ${checklistItems.length} items');
    return checklistItems
        .map((checklistItems) => checklistItems.toEntity())
        .toList();
  }

  @override
  Future<String> createNewChecklistVersionForVehicle({
    required String vehicleId,
    required List<ChecklistItemDraft> checklistItems,
    required String createdBy,
    String? deactivationReason,
  }) {
    _log.t('createNewChecklistVersionForVehicle(vehicleId: $vehicleId)');
    return _vehicleDao.createNewChecklistVersionForVehicle(
      vehicleId: vehicleId,
      checklistItems: checklistItems,
      createdBy: createdBy,
      deactivationReason: deactivationReason,
    );
  }

  @override
  Future<void> deactivateChecklistTemplate({
    required String templateId,
    required String deactivatedBy,
    String? deactivationReason,
  }) {
    _log.t('deactivateChecklistTemplate(templateId: $templateId)');
    return _vehicleDao.deactivateChecklistTemplate(
      templateId: templateId,
      deactivatedBy: deactivatedBy,
      deactivationReason: deactivationReason,
    );
  }
}
