import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/field_session_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/payload_compatibility_issue_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_equipment_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/pre_field_summary_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_battery_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_equipment_check_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_user_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_vehicle_entity.dart';

enum PreFieldViewStatus { initial, loading, loaded, saving, failure }

class PreFieldState {
  static const Object _unset = Object();

  final PreFieldViewStatus viewStatus;
  final List<FieldSessionEntity> sessions;
  final FieldSessionEntity? selectedSession;
  final PreFieldSummaryEntity? summary;
  final List<SessionUserWithUserEntity> sessionUsers;
  final List<SessionVehicleWithVehicleEntity> sessionVehicles;
  final List<SessionBatteryWithBatteryEntity> sessionBatteries;
  final List<SessionEquipmentCheckWithItemEntity> equipmentChecks;
  final List<PreFieldEquipmentEntity> equipmentList;
  final List<PayloadEntity> sessionVehiclePayloads;
  final List<PayloadCompatibilityIssueEntity> compatibilityIssues;
  final String? errorMessage;
  final String? successMessage;

  const PreFieldState({
    required this.viewStatus,
    required this.sessions,
    required this.selectedSession,
    required this.summary,
    required this.sessionUsers,
    required this.sessionVehicles,
    required this.sessionBatteries,
    required this.equipmentChecks,
    required this.equipmentList,
    required this.sessionVehiclePayloads,
    required this.compatibilityIssues,
    required this.errorMessage,
    required this.successMessage,
  });

  factory PreFieldState.initial() {
    return const PreFieldState(
      viewStatus: PreFieldViewStatus.initial,
      sessions: [],
      selectedSession: null,
      summary: null,
      sessionUsers: [],
      sessionVehicles: [],
      sessionBatteries: [],
      equipmentChecks: [],
      equipmentList: [],
      sessionVehiclePayloads: [],
      compatibilityIssues: [],
      errorMessage: null,
      successMessage: null,
    );
  }

  PreFieldState copyWith({
    PreFieldViewStatus? viewStatus,
    List<FieldSessionEntity>? sessions,
    Object? selectedSession = _unset,
    Object? summary = _unset,
    List<SessionUserWithUserEntity>? sessionUsers,
    List<SessionVehicleWithVehicleEntity>? sessionVehicles,
    List<SessionBatteryWithBatteryEntity>? sessionBatteries,
    List<SessionEquipmentCheckWithItemEntity>? equipmentChecks,
    List<PreFieldEquipmentEntity>? equipmentList,
    List<PayloadEntity>? sessionVehiclePayloads,
    List<PayloadCompatibilityIssueEntity>? compatibilityIssues,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return PreFieldState(
      viewStatus: viewStatus ?? this.viewStatus,
      sessions: sessions ?? this.sessions,
      selectedSession: identical(selectedSession, _unset)
          ? this.selectedSession
          : selectedSession as FieldSessionEntity?,
      summary: identical(summary, _unset)
          ? this.summary
          : summary as PreFieldSummaryEntity?,
      sessionUsers: sessionUsers ?? this.sessionUsers,
      sessionVehicles: sessionVehicles ?? this.sessionVehicles,
      sessionBatteries: sessionBatteries ?? this.sessionBatteries,
      equipmentChecks: equipmentChecks ?? this.equipmentChecks,
      equipmentList: equipmentList ?? this.equipmentList,
      sessionVehiclePayloads:
          sessionVehiclePayloads ?? this.sessionVehiclePayloads,
      compatibilityIssues: compatibilityIssues ?? this.compatibilityIssues,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _unset)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  bool get isLoading => viewStatus == PreFieldViewStatus.loading;

  bool get isSaving => viewStatus == PreFieldViewStatus.saving;

  bool get isLoaded => viewStatus == PreFieldViewStatus.loaded;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get hasSuccess =>
      successMessage != null && successMessage!.trim().isNotEmpty;
}
