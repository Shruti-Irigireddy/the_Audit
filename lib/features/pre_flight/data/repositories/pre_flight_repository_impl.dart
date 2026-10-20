import 'package:the_audit/core/database/daos/pre_flight/pre_flight_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/database/dtos/pre_flight_dtos.dart' as db_dtos;
import 'package:uuid/uuid.dart';

import 'package:the_audit/features/battery/data/mappers/battery_mapper.dart';
import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/payload/data/mappers/payload_mapper.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';

import 'package:the_audit/features/pre_flight/data/mappers/pre_flight_mapper.dart';
import 'package:the_audit/features/pre_flight/domain/dtos/pre_flight_dtos.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_override_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/pre_flight_setup_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/ready_to_arm_validation_result_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_user_entity.dart';
import 'package:the_audit/features/pre_flight/domain/repositories/pre_flight_repository.dart';
import 'package:the_audit/features/vehicle/data/mappers/vehicle_mapper.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';

const _uuid = Uuid();

class PreFlightRepositoryImpl implements PreFlightRepository {
  static const _log = AppLogger('PreFlightRepositoryImpl');

  final PreFlightDao _preFlightDao;

  PreFlightRepositoryImpl(this._preFlightDao);

  @override
  Future<String> createSortie({
    String? flightId,
    required String sessionId,
    required String sessionVehicleId,
    required String picUserId,
    String? objective,
    required String performedBy,
    List<String> selectedPayloadIds = const [],
  }) {
    _log.t(
      'createSortie(flightId: $flightId, sessionId: $sessionId, sessionVehicleId: $sessionVehicleId, picUserId: $picUserId)',
    );
    return _preFlightDao.createSortie(
      flightId: flightId,
      sessionId: sessionId,
      sessionVehicleId: sessionVehicleId,
      picUserId: picUserId,
      objective: objective,
      performedBy: performedBy,
      selectedPayloadIds: selectedPayloadIds,
    );
  }

  @override
  Future<SortieEntity?> getSortieById(String flightId) async {
    _log.t('getSortieById(flightId: $flightId)');
    final sortie = await _preFlightDao.getSortieById(flightId);
    return sortie?.toEntity();
  }

  @override
  Future<List<SortieEntity>> getSortiesForSession(String sessionId) async {
    _log.t('getSortiesForSession(sessionId: $sessionId)');
    final sorties = await _preFlightDao.getSortiesForSession(sessionId);
    _log.d('getSortiesForSession: ${sorties.length} items');
    return sorties.map((sortie) => sortie.toEntity()).toList();
  }

  @override
  Stream<List<SortieEntity>> watchSortiesForSession(String sessionId) =>
      _preFlightDao
          .watchSortiesForSession(sessionId)
          .map((sorties) => [for (final s in sorties) s.toEntity()]);

  @override
  Future<PreFlightSetupEntity> getPreFlightSetup(String flightId) async {
    _log.t('getPreFlightSetup(flightId: $flightId)');
    final preFlightSetup = await _preFlightDao.getPreflightSetup(flightId);
    return preFlightSetup.toEntity();
  }

  @override
  Future<void> updateSortieLocation({
    required String flightId,
    required double latitude,
    required double longitude,
    required String performedBy,
  }) {
    _log.t('updateSortieLocation(flightId: $flightId)');
    return _preFlightDao.updateSortieLocation(
      flightId: flightId,
      latitude: latitude,
      longitude: longitude,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateSortieBasicInfo({
    required String flightId,
    String? picUserId,
    String? objective,
    required String performedBy,
  }) {
    _log.t('updateSortieBasicInfo(flightId: $flightId, picUserId: $picUserId)');
    return _preFlightDao.updateSortieBasicInfo(
      flightId: flightId,
      picUserId: picUserId,
      objective: objective,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> addUserToSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) {
    _log.t('addUserToSortie(flightId: $flightId, userId: $userId)');
    return _preFlightDao.addUserToSortie(
      id: _uuid.v4(),
      flightId: flightId,
      userId: userId,
      role: role,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> removeUserFromSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  }) {
    _log.t('removeUserFromSortie(flightId: $flightId, userId: $userId)');
    return _preFlightDao.removeUserFromSortie(
      flightId: flightId,
      userId: userId,
      role: role,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> replaceSortieUsers({
    required String flightId,
    required List<SortieUserDraft> users,
    required String performedBy,
  }) {
    _log.t('replaceSortieUsers(flightId: $flightId)');
    return _preFlightDao.replaceSortieUsers(
      flightId: flightId,
      users: users
          .map(
            (user) => db_dtos.SortieUserDraft(
              id: user.id,
              userId: user.userId,
              role: user.role,
            ),
          )
          .toList(),
      performedBy: performedBy,
    );
  }

  @override
  Future<List<SortieUserWithUserEntity>> getSortieUsers(String flightId) async {
    _log.t('getSortieUsers(flightId: $flightId)');
    final sortieUsers = await _preFlightDao.getSortieUsers(flightId);
    _log.d('getSortieUsers: ${sortieUsers.length} items');
    return sortieUsers.map((sortieUser) => sortieUser.toEntity()).toList();
  }

  @override
  Future<List<PayloadEntity>> getSelectablePayloadsForSortie(
    String flightId,
  ) async {
    _log.t('getSelectablePayloadsForSortie(flightId: $flightId)');
    final payloads = await _preFlightDao.getSelectablePayloadsForSortie(
      flightId,
    );
    _log.d('getSelectablePayloadsForSortie: ${payloads.length} items');
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<void> addPayloadToSortie({
    required String flightId,
    required String payloadId,
    required String createdBy,
  }) {
    _log.t('addPayloadToSortie(flightId: $flightId, payloadId: $payloadId)');
    return _preFlightDao.addPayloadToSortie(
      id: _uuid.v4(),
      flightId: flightId,
      payloadId: payloadId,
      performedBy: createdBy,
    );
  }

  @override
  Future<void> removePayloadFromSortie({
    required String flightId,
    required String payloadId,
    required String performedBy,
  }) {
    _log.t(
      'removePayloadFromSortie(flightId: $flightId, payloadId: $payloadId)',
    );
    return _preFlightDao.removePayloadFromSortie(
      flightId: flightId,
      payloadId: payloadId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> replaceSortiePayloads({
    required String flightId,
    required List<String> payloadIds,
    required String performedBy,
  }) {
    _log.t('replaceSortiePayloads(flightId: $flightId)');
    return _preFlightDao.replaceSortiePayloads(
      flightId: flightId,
      payloadIds: payloadIds,
      performedBy: performedBy,
    );
  }

  @override
  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  ) async {
    _log.t('getSortiePayloads(flightId: $flightId)');
    final sortiePayloads = await _preFlightDao.getSortiePayloads(flightId);
    _log.d('getSortiePayloads: ${sortiePayloads.length} items');
    return sortiePayloads
        .map((sortiePayload) => sortiePayload.toEntity())
        .toList();
  }

  @override
  Future<List<BatteryEntity>> getSelectableBatteriesForSortie(
    String flightId,
  ) async {
    _log.t('getSelectableBatteriesForSortie(flightId: $flightId)');
    final batteries = await _preFlightDao.getSelectableBatteriesForSortie(
      flightId,
    );
    _log.d('getSelectableBatteriesForSortie: ${batteries.length} items');
    return batteries.map((battery) => battery.toEntity()).toList();
  }

  @override
  Future<void> addBatteryToSortie({
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String createdBy,
  }) {
    _log.t('addBatteryToSortie(flightId: $flightId, batteryId: $batteryId)');
    return _preFlightDao.addBatteryToSortie(
      id: _uuid.v4(),
      flightId: flightId,
      batteryId: batteryId,
      voltageStart: voltageStart,
      percentStart: percentStart,
      performedBy: createdBy,
    );
  }

  @override
  Future<void> replaceAllSortieBatteries({
    required String flightId,
    required List<SortieBatteryDraft> batteries,
    required String performedBy,
  }) {
    _log.t('replaceAllSortieBatteries(flightId: $flightId)');
    return _preFlightDao.replaceSortieBatteries(
      flightId: flightId,
      batteries: batteries
          .map(
            (battery) => db_dtos.SortieBatteryDraft(
              id: battery.id,
              batteryId: battery.batteryId,
              voltageStart: battery.voltageStart,
              percentStart: battery.percentStart,
            ),
          )
          .toList(),
      performedBy: performedBy,
    );
  }

  @override
  Future<void> replaceSortieBattery({
    required String flightId,
    required String oldBatteryId,
    required String newBatteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  }) async {
    _log.t(
      'replaceSortieBattery(flightId: $flightId, oldBatteryId: $oldBatteryId, newBatteryId: $newBatteryId)',
    );
    await _preFlightDao.removeBatteryFromSortie(
      flightId: flightId,
      batteryId: oldBatteryId,
      performedBy: performedBy,
    );

    await _preFlightDao.addBatteryToSortie(
      id: _uuid.v4(),
      flightId: flightId,
      batteryId: newBatteryId,
      voltageStart: voltageStart,
      percentStart: percentStart,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> updateSortieBatteryStartState({
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  }) {
    _log.t(
      'updateSortieBatteryStartState(flightId: $flightId, batteryId: $batteryId)',
    );
    return _preFlightDao.updateSortieBatteryStartState(
      flightId: flightId,
      batteryId: batteryId,
      voltageStart: voltageStart,
      percentStart: percentStart,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> removeBatteryFromSortie({
    required String flightId,
    required String batteryId,
    required String performedBy,
  }) {
    _log.t(
      'removeBatteryFromSortie(flightId: $flightId, batteryId: $batteryId)',
    );
    return _preFlightDao.removeBatteryFromSortie(
      flightId: flightId,
      batteryId: batteryId,
      performedBy: performedBy,
    );
  }

  @override
  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  ) async {
    _log.t('getSortieBatteries(flightId: $flightId)');
    final sortieBatteries = await _preFlightDao.getSortieBatteries(flightId);
    _log.d('getSortieBatteries: ${sortieBatteries.length} items');
    return sortieBatteries
        .map((sortieBattery) => sortieBattery.toEntity())
        .toList();
  }

  @override
  Future<BatteryStartDefaults?> getLatestBatteryEndStateAsStartDefault({
    required String batteryId,
    String? excludeFlightId,
  }) async {
    _log.t(
      'getLatestBatteryEndStateAsStartDefault(batteryId: $batteryId, excludeFlightId: $excludeFlightId)',
    );
    final defaults = await _preFlightDao.getLatestBatteryEndStateAsStartDefault(
      batteryId: batteryId,
      excludeFlightId: excludeFlightId,
    );

    if (defaults == null) return null;

    return BatteryStartDefaults(
      voltageStart: defaults.voltageStart,
      percentStart: defaults.percentStart,
      sourceFlightId: defaults.sourceFlightId,
    );
  }

  @override
  Future<List<ChecklistItemEntity>> loadChecklistForSortie(
    String flightId,
  ) async {
    _log.t('loadChecklistForSortie(flightId: $flightId)');
    final checklistItems = await _preFlightDao.loadChecklistForSortie(flightId);
    _log.d('loadChecklistForSortie: ${checklistItems.length} items');
    return checklistItems.map((item) => item.toEntity()).toList();
  }

  @override
  Future<List<ChecklistItemEntity>> loadBlockingChecklistItemsForSortie(
    String flightId,
  ) async {
    _log.t('loadBlockingChecklistItemsForSortie(flightId: $flightId)');
    final blockingItems = await _preFlightDao
        .loadBlockingChecklistItemsForSortie(flightId);
    _log.d(
      'loadBlockingChecklistItemsForSortie: ${blockingItems.length} items',
    );
    return blockingItems.map((item) => item.toEntity()).toList();
  }

  @override
  Future<void> saveChecklistResponse({
    required String flightId,
    required String itemId,
    required String response,
    String? valueText,
    double? valueNumber,
    String? notes,
    required String createdBy,
  }) {
    _log.t('saveChecklistResponse(flightId: $flightId, itemId: $itemId)');
    return _preFlightDao.saveChecklistResponse(
      flightId: flightId,
      itemId: itemId,
      response: response,
      valueText: valueText,
      valueNumber: valueNumber,
      notes: notes,
      createdBy: createdBy,
    );
  }

  @override
  Future<void> saveChecklistResponses({
    required String flightId,
    required List<ChecklistResponseDraft> responses,
    required String createdBy,
  }) {
    _log.t('saveChecklistResponses(flightId: $flightId)');
    return _preFlightDao.saveChecklistResponses(
      flightId: flightId,
      responses: responses
          .map(
            (response) => db_dtos.ChecklistResponseDraft(
              itemId: response.itemId,
              response: response.response,
              valueText: response.valueText,
              valueNumber: response.valueNumber,
              notes: response.notes,
            ),
          )
          .toList(),
      createdBy: createdBy,
    );
  }

  @override
  Future<List<ChecklistResponseWithItemEntity>> getChecklistResponsesForFlight(
    String flightId,
  ) async {
    _log.t('getChecklistResponsesForFlight(flightId: $flightId)');
    final responses = await _preFlightDao.getChecklistResponsesForFlight(
      flightId,
    );
    _log.d('getChecklistResponsesForFlight: ${responses.length} items');
    return responses.map((response) => response.toEntity()).toList();
  }

  @override
  Future<ReadyToArmValidationResultEntity> validateReadyToArm(
    String flightId,
  ) async {
    _log.t('validateReadyToArm(flightId: $flightId)');
    final validationResult = await _preFlightDao.validateReadyToArm(flightId);
    return validationResult.toEntity();
  }

  @override
  Future<List<String>> validatePreflightCompletion(String flightId) {
    _log.t('validatePreflightCompletion(flightId: $flightId)');
    return _preFlightDao.validatePreflightCompletion(flightId);
  }

  @override
  Future<void> createChecklistOverride({
    required String flightId,
    required String itemId,
    required String overriddenReason,
    required String overriddenBy,
  }) {
    _log.t('createChecklistOverride(flightId: $flightId, itemId: $itemId)');
    return _preFlightDao.createChecklistOverride(
      id: _uuid.v4(),
      flightId: flightId,
      itemId: itemId,
      overrideReason: overriddenReason,
      overriddenBy: overriddenBy,
    );
  }

  @override
  Future<List<ChecklistOverrideEntity>> getOverridesForFlight(
    String flightId,
  ) async {
    _log.t('getOverridesForFlight(flightId: $flightId)');
    final overrides = await _preFlightDao.getOverridesForFlight(flightId);
    _log.d('getOverridesForFlight: ${overrides.length} items');
    return overrides.map((override) => override.toEntity()).toList();
  }

  @override
  Future<void> submitGoNoGoDecision({
    required String flightId,
    required String finalDecision,
    String? decisionReason,
    required String decisionBy,
  }) {
    _log.t('submitGoNoGoDecision(flightId: $flightId)');
    return _preFlightDao.submitGoNoGoDecision(
      flightId: flightId,
      decision: finalDecision,
      reason: decisionReason,
      decisionBy: decisionBy,
    );
  }

  @override
  Future<void> markFlightInProgress({
    required String flightId,
    DateTime? takeoffAt,
    required String performedBy,
  }) {
    _log.t('markFlightInProgress(flightId: $flightId)');
    return _preFlightDao.markFlightInProgress(
      flightId: flightId,
      takeoffAt: takeoffAt,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> recordLanding({
    required String flightId,
    DateTime? landingAt,
    required String performedBy,
  }) {
    _log.t('recordLanding(flightId: $flightId)');
    return _preFlightDao.recordLanding(
      flightId: flightId,
      landingAt: landingAt,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> abortSortie({
    required String flightId,
    required String reason,
    required String performedBy,
  }) {
    _log.t('abortSortie(flightId: $flightId)');
    return _preFlightDao.abortSortie(
      flightId: flightId,
      reason: reason,
      performedBy: performedBy,
    );
  }
}
