import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/database/daos/records/record_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/records/data/mappers/record_mapper.dart';
import 'package:the_audit/features/records/domain/entities/record_entity.dart';
import 'package:the_audit/features/records/domain/repositories/records_repository.dart';

class RecordRepositoryImpl implements RecordRepository {
  static const _log = AppLogger('RecordRepositoryImpl');

  final RecordDao _dao;

  const RecordRepositoryImpl(this._dao);

  @override
  Future<FieldSessionEntity?> getSessionById(String sessionId) async {
    _log.t('getSessionById(sessionId: $sessionId)');
    final session = await _dao.getSessionById(sessionId);
    return session?.toEntity();
  }

  @override
  Future<List<FieldSessionEntity>> getRecentSessions({int limit = 50}) async {
    _log.t('getRecentSessions(limit: $limit)');
    final sessions = await _dao.getRecentSessions(limit: limit);
    _log.d('getRecentSessions: ${sessions.length} items');
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<List<FieldSessionEntity>> getRecentClosedSessions({
    int limit = 50,
  }) async {
    _log.t('getRecentClosedSessions(limit: $limit)');
    final sessions = await _dao.getRecentClosedSessions(limit: limit);
    _log.d('getRecentClosedSessions: ${sessions.length} items');
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<List<FieldSessionEntity>> getInProgressSessions({
    int limit = 50,
  }) async {
    _log.t('getInProgressSessions(limit: $limit)');
    final sessions = await _dao.getInProgressSessions(limit: limit);
    _log.d('getInProgressSessions: ${sessions.length} items');
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<List<FieldSessionEntity>> searchSessions({
    required String query,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? vehicleId,
    String? picUserId,
    int limit = 50,
  }) async {
    _log.t(
      'searchSessions(query: $query, status: $status, vehicleId: $vehicleId, picUserId: $picUserId, limit: $limit)',
    );
    final sessions = await _dao.searchSessions(
      query: query,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      vehicleId: vehicleId,
      picUserId: picUserId,
      limit: limit,
    );
    _log.d('searchSessions: ${sessions.length} items');
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<int> countSessionsByStatus(String status) {
    _log.t('countSessionsByStatus(status: $status)');
    return _dao.countSessionsByStatus(status);
  }

  @override
  Future<List<SessionUserWithUserEntity>> getSessionUsers(
    String sessionId,
  ) async {
    _log.t('getSessionUsers(sessionId: $sessionId)');
    final users = await _dao.getSessionUsers(sessionId);
    _log.d('getSessionUsers: ${users.length} items');
    return users.map((user) => user.toEntity()).toList();
  }

  @override
  Future<List<SessionVehicleWithVehicleEntity>> getSessionVehicles(
    String sessionId,
  ) async {
    _log.t('getSessionVehicles(sessionId: $sessionId)');
    final vehicles = await _dao.getSessionVehicles(sessionId);
    _log.d('getSessionVehicles: ${vehicles.length} items');
    return vehicles.map((vehicle) => vehicle.toEntity()).toList();
  }

  @override
  Future<List<PayloadRecordEntity>> getPayloadsForSessionVehicle(
    String sessionVehicleId,
  ) async {
    _log.t('getPayloadsForSessionVehicle(sessionVehicleId: $sessionVehicleId)');
    final payloads = await _dao.getPayloadsForSessionVehicle(sessionVehicleId);
    _log.d('getPayloadsForSessionVehicle: ${payloads.length} items');
    return payloads.map((payload) => payload.toRecordEntity()).toList();
  }

  @override
  Future<List<SessionBatteryWithBatteryEntity>> getSessionBatteries(
    String sessionId,
  ) async {
    _log.t('getSessionBatteries(sessionId: $sessionId)');
    final batteries = await _dao.getSessionBatteries(sessionId);
    _log.d('getSessionBatteries: ${batteries.length} items');
    return batteries.map((battery) => battery.toEntity()).toList();
  }

  @override
  Future<List<SessionEquipmentCheckWithItemEntity>> getSessionEquipmentChecks(
    String sessionId,
  ) async {
    _log.t('getSessionEquipmentChecks(sessionId: $sessionId)');
    final checks = await _dao.getSessionEquipmentChecks(sessionId);
    _log.d('getSessionEquipmentChecks: ${checks.length} items');
    return checks.map((check) => check.toEntity()).toList();
  }

  @override
  Future<SortieEntity?> getSortieById(String flightId) async {
    _log.t('getSortieById(flightId: $flightId)');
    final sortie = await _dao.getSortieById(flightId);
    return sortie?.toEntity();
  }

  @override
  Future<List<SortieEntity>> getSortiesForSession(String sessionId) async {
    _log.t('getSortiesForSession(sessionId: $sessionId)');
    final sorties = await _dao.getSortiesForSession(sessionId);
    _log.d('getSortiesForSession: ${sorties.length} items');
    return sorties.map((sortie) => sortie.toEntity()).toList();
  }

  @override
  Future<List<SortieEntity>> getClosedSortiesForSession(
    String sessionId,
  ) async {
    _log.t('getClosedSortiesForSession(sessionId: $sessionId)');
    final sorties = await _dao.getClosedSortiesForSession(sessionId);
    _log.d('getClosedSortiesForSession: ${sorties.length} items');
    return sorties.map((sortie) => sortie.toEntity()).toList();
  }

  @override
  Future<List<SortieUserWithUserEntity>> getSortieUsers(String flightId) async {
    _log.t('getSortieUsers(flightId: $flightId)');
    final users = await _dao.getSortieUsers(flightId);
    _log.d('getSortieUsers: ${users.length} items');
    return users.map((user) => user.toEntity()).toList();
  }

  @override
  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  ) async {
    _log.t('getSortiePayloads(flightId: $flightId)');
    final payloads = await _dao.getSortiePayloads(flightId);
    _log.d('getSortiePayloads: ${payloads.length} items');
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  ) async {
    _log.t('getSortieBatteries(flightId: $flightId)');
    final batteries = await _dao.getSortieBatteries(flightId);
    _log.d('getSortieBatteries: ${batteries.length} items');
    return batteries.map((battery) => battery.toEntity()).toList();
  }

  @override
  Future<List<ChecklistResponseWithItemEntity>> getChecklistResponsesForFlight(
    String flightId,
  ) async {
    _log.t('getChecklistResponsesForFlight(flightId: $flightId)');
    final responses = await _dao.getChecklistResponsesForFlight(flightId);
    _log.d('getChecklistResponsesForFlight: ${responses.length} items');
    return responses.map((response) => response.toEntity()).toList();
  }

  @override
  Future<List<ChecklistOverrideEntity>> getOverridesForFlight(
    String flightId,
  ) async {
    _log.t('getOverridesForFlight(flightId: $flightId)');
    final overrides = await _dao.getOverridesForFlight(flightId);
    _log.d('getOverridesForFlight: ${overrides.length} items');
    return overrides.map((override) => override.toEntity()).toList();
  }

  @override
  Future<PostFlightNoteEntity?> getPostFlightNoteForFlight(
    String flightId,
  ) async {
    _log.t('getPostFlightNoteForFlight(flightId: $flightId)');
    final note = await _dao.getPostFlightNoteForFlight(flightId);
    return note?.toEntity();
  }

  @override
  Future<List<AuditEventEntity>> getAuditEventsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    _log.t(
      'getAuditEventsForEntity(entityType: $entityType, entityId: $entityId)',
    );
    final events = await _dao.getAuditEventsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    _log.d('getAuditEventsForEntity: ${events.length} items');
    return events.map((event) => event.toEntity()).toList();
  }

  @override
  Future<List<AuditEventEntity>> getAuditTrailForSession(
    String sessionId,
  ) async {
    _log.t('getAuditTrailForSession(sessionId: $sessionId)');
    final events = await _dao.getAuditTrailForSession(sessionId);
    _log.d('getAuditTrailForSession: ${events.length} items');
    return events.map((event) => event.toEntity()).toList();
  }

  @override
  Future<List<AuditEventEntity>> getRecentAuditEvents({int limit = 100}) async {
    _log.t('getRecentAuditEvents(limit: $limit)');
    final events = await _dao.getRecentAuditEvents(limit: limit);
    _log.d('getRecentAuditEvents: ${events.length} items');
    return events.map((event) => event.toEntity()).toList();
  }

  @override
  Future<void> addRecordAmendment({
    String? id,
    required String entityType,
    required String entityId,
    required String amendmentText,
    required String createdBy,
  }) {
    _log.t(
      'addRecordAmendment(id: $id, entityType: $entityType, entityId: $entityId)',
    );
    return _dao.addRecordAmendment(
      id: id,
      entityType: entityType,
      entityId: entityId,
      amendmentText: amendmentText,
      createdBy: createdBy,
    );
  }

  @override
  Future<List<RecordAmendmentEntity>> getAmendmentsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    _log.t(
      'getAmendmentsForEntity(entityType: $entityType, entityId: $entityId)',
    );
    final amendments = await _dao.getAmendmentsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    _log.d('getAmendmentsForEntity: ${amendments.length} items');
    return amendments.map((amendment) => amendment.toEntity()).toList();
  }

  @override
  Future<List<RecordAmendmentEntity>> getAmendmentsForSession(
    String sessionId,
  ) async {
    _log.t('getAmendmentsForSession(sessionId: $sessionId)');
    final amendments = await _dao.getAmendmentsForSession(sessionId);
    _log.d('getAmendmentsForSession: ${amendments.length} items');
    return amendments.map((amendment) => amendment.toEntity()).toList();
  }

  @override
  Future<List<ExportRecordSummaryEntity>> getExportsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    _log.t('getExportsForEntity(entityType: $entityType, entityId: $entityId)');
    final exports = await _dao.getExportsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    _log.d('getExportsForEntity: ${exports.length} items');
    return exports.map((export) => export.toRecordSummaryEntity()).toList();
  }

  @override
  Future<List<ExportRecordSummaryEntity>> getExportsForSession(
    String sessionId,
  ) async {
    _log.t('getExportsForSession(sessionId: $sessionId)');
    final exports = await _dao.getExportsForSession(sessionId);
    _log.d('getExportsForSession: ${exports.length} items');
    return exports.map((export) => export.toRecordSummaryEntity()).toList();
  }

  @override
  Future<SessionRecordViewEntity> getSessionRecordView(String sessionId) async {
    _log.t('getSessionRecordView(sessionId: $sessionId)');
    final session = await getSessionById(sessionId);

    if (session == null) {
      throw AppFailure('Session not found: $sessionId');
    }

    final sessionUsers = await getSessionUsers(sessionId);
    final sessionVehicles = await getSessionVehicles(sessionId);
    final sessionBatteries = await getSessionBatteries(sessionId);
    final equipmentChecks = await getSessionEquipmentChecks(sessionId);
    final equipmentItems = [
      for (final item in await _dao.getSessionEquipmentItems(sessionId))
        SessionEquipmentItemRecordEntity(
          id: item.id,
          sessionVehicleId: item.sessionVehicleId,
          category: item.category,
          name: item.name,
          quantity: item.quantity,
          spares: item.spares,
          isPacked: item.isPacked,
          packedAt: item.packedAt,
          packedBy: item.packedBy,
        ),
    ];
    final sorties = await getSortiesForSession(sessionId);

    final sortieUsersByFlightId = <String, List<SortieUserWithUserEntity>>{};
    final sortiePayloadsByFlightId =
        <String, List<SortiePayloadWithPayloadEntity>>{};
    final sortieBatteriesByFlightId =
        <String, List<SortieBatteryWithBatteryEntity>>{};
    final checklistResponsesByFlightId =
        <String, List<ChecklistResponseWithItemEntity>>{};
    final overridesByFlightId = <String, List<ChecklistOverrideEntity>>{};
    final postFlightNotesByFlightId = <String, PostFlightNoteEntity?>{};

    for (final sortie in sorties) {
      sortieUsersByFlightId[sortie.flightId] = await getSortieUsers(
        sortie.flightId,
      );
      sortiePayloadsByFlightId[sortie.flightId] = await getSortiePayloads(
        sortie.flightId,
      );
      sortieBatteriesByFlightId[sortie.flightId] = await getSortieBatteries(
        sortie.flightId,
      );
      checklistResponsesByFlightId[sortie.flightId] =
          await getChecklistResponsesForFlight(sortie.flightId);
      overridesByFlightId[sortie.flightId] = await getOverridesForFlight(
        sortie.flightId,
      );
      postFlightNotesByFlightId[sortie.flightId] =
          await getPostFlightNoteForFlight(sortie.flightId);
    }
    _log.d('getSessionRecordView: ${sorties.length} sorties loaded');

    return SessionRecordViewEntity(
      session: session,
      sessionUsers: sessionUsers,
      sessionVehicles: sessionVehicles,
      sessionBatteries: sessionBatteries,
      equipmentChecks: equipmentChecks,
      equipmentItems: equipmentItems,
      sorties: sorties,
      sortieUsersByFlightId: sortieUsersByFlightId,
      sortiePayloadsByFlightId: sortiePayloadsByFlightId,
      sortieBatteriesByFlightId: sortieBatteriesByFlightId,
      checklistResponsesByFlightId: checklistResponsesByFlightId,
      overridesByFlightId: overridesByFlightId,
      postFlightNotesByFlightId: postFlightNotesByFlightId,
      auditTrail: await getAuditTrailForSession(sessionId),
      amendments: await getAmendmentsForSession(sessionId),
      exports: await getExportsForSession(sessionId),
    );
  }

  @override
  Future<List<SortieEntity>> getSortiesForVehicle({
    required String vehicleId,
    int limit = 50,
  }) async {
    _log.t('getSortiesForVehicle(vehicleId: $vehicleId, limit: $limit)');
    final sorties = await _dao.getSortiesForVehicle(
      vehicleId: vehicleId,
      limit: limit,
    );
    _log.d('getSortiesForVehicle: ${sorties.length} items');
    return sorties.map((sortie) => sortie.toEntity()).toList();
  }

  @override
  Future<int> countSortiesForVehicle(String vehicleId) {
    _log.t('countSortiesForVehicle(vehicleId: $vehicleId)');
    return _dao.countSortiesForVehicle(vehicleId);
  }

  @override
  Future<int> countSessionsForSite(String locationName) {
    _log.t('countSessionsForSite(locationName: $locationName)');
    return _dao.countSessionsForSite(locationName);
  }
}
