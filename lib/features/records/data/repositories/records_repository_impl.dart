import 'package:the_audit/core/database/daos/records/record_dao.dart';
import 'package:the_audit/features/records/data/mappers/record_mapper.dart';
import 'package:the_audit/features/records/domain/entities/record_entity.dart';
import 'package:the_audit/features/records/domain/repositories/records_repository.dart';

class RecordRepositoryImpl implements RecordRepository {
  final RecordDao _dao;

  const RecordRepositoryImpl(this._dao);

  @override
  Future<FieldSessionEntity?> getSessionById(String sessionId) async {
    final session = await _dao.getSessionById(sessionId);
    return session?.toEntity();
  }

  @override
  Future<List<FieldSessionEntity>> getRecentSessions({int limit = 50}) async {
    final sessions = await _dao.getRecentSessions(limit: limit);
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<List<FieldSessionEntity>> getRecentClosedSessions({
    int limit = 50,
  }) async {
    final sessions = await _dao.getRecentClosedSessions(limit: limit);
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<List<FieldSessionEntity>> getInProgressSessions({
    int limit = 50,
  }) async {
    final sessions = await _dao.getInProgressSessions(limit: limit);
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<List<FieldSessionEntity>> searchSessions({
    required String query,
    String? status,
    int limit = 50,
  }) async {
    final sessions = await _dao.searchSessions(
      query: query,
      status: status,
      limit: limit,
    );
    return sessions.map((session) => session.toEntity()).toList();
  }

  @override
  Future<int> countSessionsByStatus(String status) {
    return _dao.countSessionsByStatus(status);
  }

  @override
  Future<List<SessionUserWithUserEntity>> getSessionUsers(
    String sessionId,
  ) async {
    final users = await _dao.getSessionUsers(sessionId);
    return users.map((user) => user.toEntity()).toList();
  }

  @override
  Future<List<SessionVehicleWithVehicleEntity>> getSessionVehicles(
    String sessionId,
  ) async {
    final vehicles = await _dao.getSessionVehicles(sessionId);
    return vehicles.map((vehicle) => vehicle.toEntity()).toList();
  }

  @override
  Future<List<PayloadRecordEntity>> getPayloadsForSessionVehicle(
    String sessionVehicleId,
  ) async {
    final payloads = await _dao.getPayloadsForSessionVehicle(sessionVehicleId);
    return payloads.map((payload) => payload.toRecordEntity()).toList();
  }

  @override
  Future<List<SessionBatteryWithBatteryEntity>> getSessionBatteries(
    String sessionId,
  ) async {
    final batteries = await _dao.getSessionBatteries(sessionId);
    return batteries.map((battery) => battery.toEntity()).toList();
  }

  @override
  Future<List<SessionEquipmentCheckWithItemEntity>> getSessionEquipmentChecks(
    String sessionId,
  ) async {
    final checks = await _dao.getSessionEquipmentChecks(sessionId);
    return checks.map((check) => check.toEntity()).toList();
  }

  @override
  Future<SortieEntity?> getSortieById(String flightId) async {
    final sortie = await _dao.getSortieById(flightId);
    return sortie?.toEntity();
  }

  @override
  Future<List<SortieEntity>> getSortiesForSession(String sessionId) async {
    final sorties = await _dao.getSortiesForSession(sessionId);
    return sorties.map((sortie) => sortie.toEntity()).toList();
  }

  @override
  Future<List<SortieEntity>> getClosedSortiesForSession(
    String sessionId,
  ) async {
    final sorties = await _dao.getClosedSortiesForSession(sessionId);
    return sorties.map((sortie) => sortie.toEntity()).toList();
  }

  @override
  Future<List<SortieUserWithUserEntity>> getSortieUsers(
    String flightId,
  ) async {
    final users = await _dao.getSortieUsers(flightId);
    return users.map((user) => user.toEntity()).toList();
  }

  @override
  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  ) async {
    final payloads = await _dao.getSortiePayloads(flightId);
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  ) async {
    final batteries = await _dao.getSortieBatteries(flightId);
    return batteries.map((battery) => battery.toEntity()).toList();
  }

  @override
  Future<List<ChecklistResponseWithItemEntity>>
      getChecklistResponsesForFlight(String flightId) async {
    final responses = await _dao.getChecklistResponsesForFlight(flightId);
    return responses.map((response) => response.toEntity()).toList();
  }

  @override
  Future<List<ChecklistOverrideEntity>> getOverridesForFlight(
    String flightId,
  ) async {
    final overrides = await _dao.getOverridesForFlight(flightId);
    return overrides.map((override) => override.toEntity()).toList();
  }

  @override
  Future<PostFlightNoteEntity?> getPostFlightNoteForFlight(
    String flightId,
  ) async {
    final note = await _dao.getPostFlightNoteForFlight(flightId);
    return note?.toEntity();
  }

  @override
  Future<List<AuditEventEntity>> getAuditEventsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    final events = await _dao.getAuditEventsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    return events.map((event) => event.toEntity()).toList();
  }

  @override
  Future<List<AuditEventEntity>> getAuditTrailForSession(
    String sessionId,
  ) async {
    final events = await _dao.getAuditTrailForSession(sessionId);
    return events.map((event) => event.toEntity()).toList();
  }

  @override
  Future<List<AuditEventEntity>> getRecentAuditEvents({
    int limit = 100,
  }) async {
    final events = await _dao.getRecentAuditEvents(limit: limit);
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
    final amendments = await _dao.getAmendmentsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    return amendments.map((amendment) => amendment.toEntity()).toList();
  }

  @override
  Future<List<RecordAmendmentEntity>> getAmendmentsForSession(
    String sessionId,
  ) async {
    final amendments = await _dao.getAmendmentsForSession(sessionId);
    return amendments.map((amendment) => amendment.toEntity()).toList();
  }

  @override
  Future<List<ExportRecordSummaryEntity>> getExportsForEntity({
    required String entityType,
    required String entityId,
  }) async {
    final exports = await _dao.getExportsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
    return exports.map((export) => export.toRecordSummaryEntity()).toList();
  }

  @override
  Future<List<ExportRecordSummaryEntity>> getExportsForSession(
    String sessionId,
  ) async {
    final exports = await _dao.getExportsForSession(sessionId);
    return exports.map((export) => export.toRecordSummaryEntity()).toList();
  }
}
