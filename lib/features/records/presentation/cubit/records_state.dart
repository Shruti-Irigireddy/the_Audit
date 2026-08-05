import 'package:the_audit/features/records/domain/entities/record_entity.dart';

enum RecordsStatus { initial, loading, loaded, failure }

class RecordsState {
  final RecordsStatus status;
  final List<FieldSessionEntity> sessions;
  final SessionRecordViewEntity? selectedRecord;
  final int? vehicleSortieCount;
  final int? siteSessionCount;
  final String? errorMessage;

  const RecordsState({
    this.status = RecordsStatus.initial,
    this.sessions = const [],
    this.selectedRecord,
    this.vehicleSortieCount,
    this.siteSessionCount,
    this.errorMessage,
  });

  bool get isLoading => status == RecordsStatus.loading;

  RecordsState copyWith({
    RecordsStatus? status,
    List<FieldSessionEntity>? sessions,
    SessionRecordViewEntity? selectedRecord,
    bool clearSelectedRecord = false,
    int? vehicleSortieCount,
    bool clearVehicleSortieCount = false,
    int? siteSessionCount,
    bool clearSiteSessionCount = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecordsState(
      status: status ?? this.status,
      sessions: sessions ?? this.sessions,
      selectedRecord: clearSelectedRecord
          ? null
          : selectedRecord ?? this.selectedRecord,
      vehicleSortieCount: clearVehicleSortieCount
          ? null
          : vehicleSortieCount ?? this.vehicleSortieCount,
      siteSessionCount: clearSiteSessionCount
          ? null
          : siteSessionCount ?? this.siteSessionCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
