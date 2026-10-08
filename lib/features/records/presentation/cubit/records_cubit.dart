import 'dart:async';

import 'package:bloc/bloc.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/records/domain/entities/record_entity.dart';
import 'package:the_audit/features/records/domain/repositories/records_repository.dart';
import 'records_state.dart';

class RecordsCubit extends Cubit<RecordsState> {
  static const _log = AppLogger('RecordsCubit');

  final RecordRepository _repository;

  RecordsCubit(this._repository) : super(const RecordsState());

  StreamSubscription<List<FieldSessionEntity>>? _sessionsWatch;

  /// Keeps [RecordsState.sessions] in step with the database.
  void watchRecentSessions({int limit = 50}) {
    _log.t('watchRecentSessions(limit: $limit)');
    _sessionsWatch?.cancel();
    _sessionsWatch = _repository
        .watchRecentSessions(limit: limit)
        .listen(
          (sessions) => emit(
            state.copyWith(
              status: RecordsStatus.loaded,
              sessions: sessions,
              clearError: true,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            _log.e('watchRecentSessions failed', error, stackTrace);
            emit(
              state.copyWith(
                status: RecordsStatus.failure,
                errorMessage: friendlyError(error),
              ),
            );
          },
        );
  }

  @override
  Future<void> close() async {
    await _sessionsWatch?.cancel();
    return super.close();
  }

  Future<void> loadRecentSessions({int limit = 50}) async {
    _log.t('loadRecentSessions(limit: $limit)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      final sessions = await _repository.getRecentSessions(limit: limit);
      _log.d('${sessions.length} recent sessions loaded');
      emit(
        state.copyWith(
          status: RecordsStatus.loaded,
          sessions: sessions,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadRecentSessions failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> loadClosedSessions({int limit = 50}) async {
    _log.t('loadClosedSessions(limit: $limit)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      final sessions = await _repository.getRecentClosedSessions(limit: limit);
      _log.d('${sessions.length} closed sessions loaded');
      emit(
        state.copyWith(
          status: RecordsStatus.loaded,
          sessions: sessions,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadClosedSessions failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> loadInProgressSessions({int limit = 50}) async {
    _log.t('loadInProgressSessions(limit: $limit)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      final sessions = await _repository.getInProgressSessions(limit: limit);
      _log.d('${sessions.length} in-progress sessions loaded');
      emit(
        state.copyWith(
          status: RecordsStatus.loaded,
          sessions: sessions,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadInProgressSessions failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> searchSessions({
    required String query,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? vehicleId,
    String? picUserId,
    int limit = 50,
  }) async {
    _log.t('searchSessions("$query", status: $status, vehicle: $vehicleId)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      final sessions = await _repository.searchSessions(
        query: query,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
        vehicleId: vehicleId,
        picUserId: picUserId,
        limit: limit,
      );
      _log.d('search matched ${sessions.length} sessions');
      emit(
        state.copyWith(
          status: RecordsStatus.loaded,
          sessions: sessions,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('searchSessions failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> loadSessionRecordView(String sessionId) async {
    _log.t('loadSessionRecordView($sessionId)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      final record = await _repository.getSessionRecordView(sessionId);
      _log.d('record view loaded: $sessionId');
      emit(
        state.copyWith(
          status: RecordsStatus.loaded,
          selectedRecord: record,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSessionRecordView failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> addRecordAmendment({
    String? id,
    required String entityType,
    required String entityId,
    required String amendmentText,
    required String createdBy,
  }) async {
    _log.i('addRecordAmendment($entityType, $entityId)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      await _repository.addRecordAmendment(
        id: id,
        entityType: entityType,
        entityId: entityId,
        amendmentText: amendmentText,
        createdBy: createdBy,
      );
      emit(state.copyWith(status: RecordsStatus.loaded, clearError: true));
    } catch (error, stackTrace) {
      _log.e('addRecordAmendment failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> loadVehicleSortieCount(String vehicleId) async {
    _log.t('loadVehicleSortieCount($vehicleId)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      final count = await _repository.countSortiesForVehicle(vehicleId);
      emit(
        state.copyWith(
          status: RecordsStatus.loaded,
          vehicleSortieCount: count,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadVehicleSortieCount failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> loadSiteSessionCount(String locationName) async {
    _log.t('loadSiteSessionCount($locationName)');
    emit(state.copyWith(status: RecordsStatus.loading, clearError: true));

    try {
      final count = await _repository.countSessionsForSite(locationName);
      emit(
        state.copyWith(
          status: RecordsStatus.loaded,
          siteSessionCount: count,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSiteSessionCount failed', error, stackTrace);
      emit(
        state.copyWith(
          status: RecordsStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<FieldSessionEntity?> getSessionById(String sessionId) {
    return _repository.getSessionById(sessionId);
  }

  Future<int> countSessionsByStatus(String status) {
    return _repository.countSessionsByStatus(status);
  }

  Future<List<SessionUserWithUserEntity>> getSessionUsers(String sessionId) {
    return _repository.getSessionUsers(sessionId);
  }

  Future<List<SessionVehicleWithVehicleEntity>> getSessionVehicles(
    String sessionId,
  ) {
    return _repository.getSessionVehicles(sessionId);
  }

  Future<List<PayloadRecordEntity>> getPayloadsForSessionVehicle(
    String sessionVehicleId,
  ) {
    return _repository.getPayloadsForSessionVehicle(sessionVehicleId);
  }

  Future<List<SessionBatteryWithBatteryEntity>> getSessionBatteries(
    String sessionId,
  ) {
    return _repository.getSessionBatteries(sessionId);
  }

  Future<List<SessionEquipmentCheckWithItemEntity>> getSessionEquipmentChecks(
    String sessionId,
  ) {
    return _repository.getSessionEquipmentChecks(sessionId);
  }

  Future<SortieEntity?> getSortieById(String flightId) {
    return _repository.getSortieById(flightId);
  }

  Future<List<SortieEntity>> getSortiesForSession(String sessionId) {
    return _repository.getSortiesForSession(sessionId);
  }

  Future<List<SortieEntity>> getClosedSortiesForSession(String sessionId) {
    return _repository.getClosedSortiesForSession(sessionId);
  }

  Future<List<SortieUserWithUserEntity>> getSortieUsers(String flightId) {
    return _repository.getSortieUsers(flightId);
  }

  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  ) {
    return _repository.getSortiePayloads(flightId);
  }

  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  ) {
    return _repository.getSortieBatteries(flightId);
  }

  Future<List<ChecklistResponseWithItemEntity>> getChecklistResponsesForFlight(
    String flightId,
  ) {
    return _repository.getChecklistResponsesForFlight(flightId);
  }

  Future<List<ChecklistOverrideEntity>> getOverridesForFlight(String flightId) {
    return _repository.getOverridesForFlight(flightId);
  }

  Future<PostFlightNoteEntity?> getPostFlightNoteForFlight(String flightId) {
    return _repository.getPostFlightNoteForFlight(flightId);
  }

  Future<List<AuditEventEntity>> getAuditEventsForEntity({
    required String entityType,
    required String entityId,
  }) {
    return _repository.getAuditEventsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
  }

  Future<List<AuditEventEntity>> getAuditTrailForSession(String sessionId) {
    return _repository.getAuditTrailForSession(sessionId);
  }

  Future<List<AuditEventEntity>> getRecentAuditEvents({int limit = 100}) {
    return _repository.getRecentAuditEvents(limit: limit);
  }

  Future<List<RecordAmendmentEntity>> getAmendmentsForEntity({
    required String entityType,
    required String entityId,
  }) {
    return _repository.getAmendmentsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
  }

  Future<List<RecordAmendmentEntity>> getAmendmentsForSession(
    String sessionId,
  ) {
    return _repository.getAmendmentsForSession(sessionId);
  }

  Future<List<ExportRecordSummaryEntity>> getExportsForEntity({
    required String entityType,
    required String entityId,
  }) {
    return _repository.getExportsForEntity(
      entityType: entityType,
      entityId: entityId,
    );
  }

  Future<List<ExportRecordSummaryEntity>> getExportsForSession(
    String sessionId,
  ) {
    return _repository.getExportsForSession(sessionId);
  }

  Future<List<SortieEntity>> getSortiesForVehicle({
    required String vehicleId,
    int limit = 50,
  }) {
    return _repository.getSortiesForVehicle(vehicleId: vehicleId, limit: limit);
  }
}
