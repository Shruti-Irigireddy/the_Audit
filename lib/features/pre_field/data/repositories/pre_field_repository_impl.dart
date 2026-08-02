import 'package:the_audit/core/database/daos/pre_field/pre_field_dao.dart';
import 'package:the_audit/core/database/dtos/pre_field_dtos.dart'
    as db_pre_field;

import 'package:the_audit/features/payload/data/mappers/payload_mapper.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';

import 'package:the_audit/features/pre_field/data/mappers/pre_field_mapper.dart';
import 'package:the_audit/features/pre_field/domain/dtos/pre_field_dtos.dart'
    as domain_pre_field;
import 'package:the_audit/features/pre_field/domain/entities/field_session_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/payload_compatibility_issue_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_equipment_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_summary_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_battery_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_equipment_check_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_user_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_vehicle_entity.dart';
import 'package:the_audit/features/pre_field/domain/repositories/pre_field_repository.dart';

class PreFieldRepositoryImpl implements PreFieldRepository {
  final PreFieldDao _preFieldDao;

  PreFieldRepositoryImpl(this._preFieldDao);

  @override
  Future<String> createFieldSession({
    String? sessionId,
    required DateTime date,
    required String locationName,
    required double latitude,
    required double longitude,
    required String missionType,
    required String createdBy,
  }) {
    return  _preFieldDao.createFieldSession(
      sessionId: sessionId,
      date: date,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      missionType: missionType,
      createdBy: createdBy,
    );
  }

@override
Future<void> updateFieldSessionBasicInfo({
    required String sessionId,
    DateTime? date,
    String? locationName,
    double? latitude,
    double? longitude,
    String? missionType,
    required String performedBy,
  }) {
    return _preFieldDao.updateFieldSessionBasicInfo(
      sessionId: sessionId,
      date: date,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      missionType: missionType,
      performedBy: performedBy,
    );
  }

  @override
  Future<FieldSessionEntity?> getFieldSessionById(String sessionId) async {
    final session = await _preFieldDao.getFieldSessionById(sessionId);
    return session?.toEntity();
  }

  @override
  Future<List<FieldSessionEntity>> getInProgressFieldSessions() async {
    final sessions = await _preFieldDao.getInProgressFieldSessions();
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<void> closeFieldSession({
    required String sessionId,
    required String closedBy,
  }) {
    return _preFieldDao.closeFieldSession(
      sessionId: sessionId,
      closedBy: closedBy,
    );
  }

  @override
  Future<String> addUserToSession({
    required String sessionId,
    required String userId,
    required String role,
    required String performedBy,
  }) {
    return _preFieldDao.addUserToSession(
      sessionId: sessionId,
      userId: userId,
      role: role,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> removeUserFromSession({
    required String sessionUserId,
    required String performedBy,
  }) {
    return _preFieldDao.removeUserFromSession(
      sessionUserId: sessionUserId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> replaceSessionUsers({
    required String sessionId,
    required List<domain_pre_field.SessionUserDraft> users,
    required String performedBy,
  }) {
    return _preFieldDao.replaceSessionUsers(
      sessionId: sessionId,
      users: users.map((user) => db_pre_field.SessionUserDraft(
        id: user.id,
        userId: user.userId,
        role: user.role,
      )).toList(),
      performedBy: performedBy,
    );
  }

  @override
  Future<List<SessionUserWithUserEntity>> getSessionUsers(String sessionId) async {
    final sessionUsers = await _preFieldDao.getSessionUsers(sessionId);
    return sessionUsers.map((sessionUser) => sessionUser.toEntity()).toList();
  }

  @override
  Future<int> countSessionUsersByRole({
    required String sessionId,
    required String role,
  }) {
    return _preFieldDao.countSessionUsersByRole(
      sessionId: sessionId,
      role: role,
    );
  }

  @override
  Future<String> addVehicleToSession({
    required String sessionId,
    required String vehicleId,
    String? objective,
    required String performedBy,
  }) {
    return _preFieldDao.addVehicleToSession(
      sessionId: sessionId,
      vehicleId: vehicleId,
      objective: objective,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> removeVehicleFromSession({
    required String sessionVehicleId,
    required String performedBy,
  }) {
    return _preFieldDao.removeVehicleFromSession(
      sessionVehicleId: sessionVehicleId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateSessionVehicleObjective({
    required String sessionVehicleId,
    String? objective,
    required String performedBy,
  }) {
    return _preFieldDao.updateSessionVehicleObjective(
      sessionVehicleId: sessionVehicleId,
      objective: objective,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> replaceSessionVehicles({
    required String sessionId,
    required List<domain_pre_field.SessionVehicleDraft> vehicles,
    required String performedBy,
  }) {
    return _preFieldDao.replaceSessionVehicles(
      sessionId: sessionId,
      vehicles: vehicles.map((vehicle) => db_pre_field.SessionVehicleDraft(
        id: vehicle.id,
        vehicleId: vehicle.vehicleId,
        objective: vehicle.objective,
      )).toList(),
      performedBy: performedBy,
    );
  }

  @override
  Future<List<SessionVehicleWithVehicleEntity>> getSessionVehicles(String sessionId) async {
    final sessionVehicles = await _preFieldDao.getSessionVehicles(sessionId);
    return sessionVehicles.map((sessionVehicle) => sessionVehicle.toEntity()).toList();
  }

  @override
  Future<int> countSessionVehicles(String sessionId) {
    return _preFieldDao.countSessionVehicles(sessionId);
  }

  @override
  Future<int> countSortiesForSessionVehicle(String sessionVehicleId) {
    return _preFieldDao.countSortiesForSessionVehicle(sessionVehicleId);
  }

  @override
  Future<String> addPayloadToSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) {
    return _preFieldDao.addPayloadToSessionVehicle(
      sessionVehicleId: sessionVehicleId,
      payloadId: payloadId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> removePayloadFromSessionVehicle({
    required String sessionVehicleId,
    required String payloadId,
    required String performedBy,
  }) {
    return _preFieldDao.removePayloadFromSessionVehicle(
      sessionVehicleId: sessionVehicleId,
      payloadId: payloadId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> replacePayloadsForSessionVehicle({
    required String sessionVehicleId,
    required List<String> payloadIds,
    required String performedBy,
  }) {
    return _preFieldDao.replacePayloadsForSessionVehicle(
      sessionVehicleId: sessionVehicleId,
      payloadIds: payloadIds,
      performedBy: performedBy,
    );
  }

  @override
  Future<List<PayloadEntity>> getPayloadsForSessionVehicle(String sessionVehicleId) async {
    final payloads = await _preFieldDao.getPayloadsForSessionVehicle(sessionVehicleId);
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<int> countPayloadsForSessionVehicle(String sessionVehicleId) {
    return _preFieldDao.countPayloadsForSessionVehicle(sessionVehicleId);
  }

  @override
  Future<List<PayloadCompatibilityIssueEntity>> getPayloadCompatibilityIssues(String sessionId) async {
    final issues = await _preFieldDao.getPayloadCompatibilityIssues(sessionId);
    return issues.map((issue) => issue.toEntity()).toList();
  }

  @override
  Future<String> addBatteryToSession({
    required String sessionId,
    required String batteryId,
    required String performedBy,
  }) {
    return _preFieldDao.addBatteryToSession(
      sessionId: sessionId,
      batteryId: batteryId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> removeBatteryFromSession({
    required String sessionBatteryId,
    required String performedBy,
  }) {
    return _preFieldDao.removeBatteryFromSession(
      sessionBatteryId: sessionBatteryId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> replaceSessionBatteries({
    required String sessionId,
    required List<domain_pre_field.SessionBatteryDraft> batteries,
    required String performedBy,
  }) {
    return _preFieldDao.replaceSessionBatteries(
      sessionId: sessionId,
      batteries: batteries.map((battery) => db_pre_field.SessionBatteryDraft(
        id: battery.id,
        batteryId: battery.batteryId,
      )).toList(),
      performedBy: performedBy,
    );
  }

  @override
  Future<List<SessionBatteryWithBatteryEntity>> getSessionBatteries(String sessionId) async {
    final sessionBatteries = await _preFieldDao.getSessionBatteries(sessionId);
    return sessionBatteries.map((sessionBattery) => sessionBattery.toEntity()).toList();
  }

  @override
  Future<List<PreFieldEquipmentEntity>> getActiveEquipmentList() async {
    final equipmentList = await _preFieldDao.getActiveEquipmentList();
    return equipmentList.map((equipment) => equipment.toPreFieldEntity()).toList();
  }

  @override
  Future<void> createEquipmentChecksForSession({
    required String sessionId,
    required String checkedBy,
  }) {
    return _preFieldDao.createEquipmentChecksForSession(
      sessionId: sessionId,
      checkedBy: checkedBy,
    );
  }

  @override
  Future<void> updateEquipmentCheck({
    required String equipmentCheckId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  }) {
    return _preFieldDao.updateEquipmentCheck(
      equipmentCheckId: equipmentCheckId,
      isPacked: isPacked,
      notes: notes,
      checkedBy: checkedBy,
    );
  }

  @override
  Future<List<SessionEquipmentCheckWithItemEntity>> getSessionEquipmentChecks(String sessionId) async {
    final equipmentChecks = await _preFieldDao.getSessionEquipmentChecks(sessionId);
    return equipmentChecks.map((check) => check.toEntity()).toList();
  }

  @override
  Future<String> addCustomEquipmentCheckToSession({
    required String sessionId,
    required String equipmentId,
    required bool isPacked,
    String? notes,
    required String checkedBy,
  }) {
    return _preFieldDao.addCustomEquipmentCheckToSession(
      sessionId: sessionId,
      equipmentId: equipmentId,
      isPacked: isPacked,
      notes: notes,
      checkedBy: checkedBy,
    );
  }

  @override
  Future<int> countUnpackedEquipmentChecks(String sessionId) {
    return _preFieldDao.countUnpackedEquipmentChecks(sessionId);
  }

  @override
  Future<String> createEquipmentItem({
    String? id,
    required String name,
    required String category,
    required String performedBy,
  }) {
    return _preFieldDao.createEquipmentItem(
      id: id,
      name: name,
      category: category,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateEquipmentItem({
    required String equipmentId,
    String? name,
    String? category,
    bool? isActive,
    required String performedBy,
  }) {
    return _preFieldDao.updateEquipmentItem(
      equipmentId: equipmentId,
      name: name,
      category: category,
      isActive: isActive,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> deactivateEquipmentItem({
    required String equipmentId,
    required String performedBy,
  }) {
    return _preFieldDao.deactivateEquipmentItem(
      equipmentId: equipmentId,
      performedBy: performedBy,
    );
  }

  @override
  Future<PreFieldSummaryEntity> getPreFieldSummary(String sessionId) async {
    final summaryData = await _preFieldDao.getPreFieldSummary(sessionId);
    return summaryData.toEntity();
  }
}
