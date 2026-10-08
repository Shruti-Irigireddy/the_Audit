import 'package:the_audit/features/records/domain/entities/record_entity.dart';

abstract class RecordRepository {
  Future<FieldSessionEntity?> getSessionById(String sessionId);

  Future<List<FieldSessionEntity>> getRecentSessions({int limit = 50});

  /// Recent sessions, updated live.
  Stream<List<FieldSessionEntity>> watchRecentSessions({int limit = 50});

  Future<List<FieldSessionEntity>> getRecentClosedSessions({int limit = 50});

  Future<List<FieldSessionEntity>> getInProgressSessions({int limit = 50});

  Future<List<FieldSessionEntity>> searchSessions({
    required String query,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? vehicleId,
    String? picUserId,
    int limit = 50,
  });

  Future<int> countSessionsByStatus(String status);

  Future<List<SessionUserWithUserEntity>> getSessionUsers(String sessionId);

  Future<List<SessionVehicleWithVehicleEntity>> getSessionVehicles(
    String sessionId,
  );

  Future<List<PayloadRecordEntity>> getPayloadsForSessionVehicle(
    String sessionVehicleId,
  );

  Future<List<SessionBatteryWithBatteryEntity>> getSessionBatteries(
    String sessionId,
  );

  Future<List<SessionEquipmentCheckWithItemEntity>> getSessionEquipmentChecks(
    String sessionId,
  );

  Future<SortieEntity?> getSortieById(String flightId);

  Future<List<SortieEntity>> getSortiesForSession(String sessionId);

  Future<List<SortieEntity>> getClosedSortiesForSession(String sessionId);

  Future<List<SortieUserWithUserEntity>> getSortieUsers(String flightId);

  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  );

  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  );

  Future<List<ChecklistResponseWithItemEntity>> getChecklistResponsesForFlight(
    String flightId,
  );

  Future<List<ChecklistOverrideEntity>> getOverridesForFlight(String flightId);

  Future<PostFlightNoteEntity?> getPostFlightNoteForFlight(String flightId);

  Future<List<AuditEventEntity>> getAuditEventsForEntity({
    required String entityType,
    required String entityId,
  });

  Future<List<AuditEventEntity>> getAuditTrailForSession(String sessionId);

  Future<List<AuditEventEntity>> getRecentAuditEvents({int limit = 100});

  Future<void> addRecordAmendment({
    String? id,
    required String entityType,
    required String entityId,
    required String amendmentText,
    required String createdBy,
  });

  Future<List<RecordAmendmentEntity>> getAmendmentsForEntity({
    required String entityType,
    required String entityId,
  });

  Future<List<RecordAmendmentEntity>> getAmendmentsForSession(String sessionId);

  Future<List<ExportRecordSummaryEntity>> getExportsForEntity({
    required String entityType,
    required String entityId,
  });

  Future<List<ExportRecordSummaryEntity>> getExportsForSession(
    String sessionId,
  );

  Future<SessionRecordViewEntity> getSessionRecordView(String sessionId);

  Future<List<SortieEntity>> getSortiesForVehicle({
    required String vehicleId,
    int limit = 50,
  });

  Future<int> countSortiesForVehicle(String vehicleId);

  Future<int> countSessionsForSite(String locationName);
}
