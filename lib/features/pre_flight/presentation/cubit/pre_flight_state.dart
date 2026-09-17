import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_override_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/pre_flight_setup_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/ready_to_arm_validation_result_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_user_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';

enum PreFlightViewStatus {
  initial,
  loading,
  loaded,
  saving,
  validating,
  failure,
}

class PreFlightState {
  static const Object _unset = Object();

  final PreFlightViewStatus viewStatus;
  final List<SortieEntity> sorties;
  final SortieEntity? selectedSortie;
  final PreFlightSetupEntity? setup;
  final List<SortieUserWithUserEntity> users;
  final List<PayloadEntity> selectablePayloads;
  final List<SortiePayloadWithPayloadEntity> payloads;
  final List<BatteryEntity> selectableBatteries;
  final List<SortieBatteryWithBatteryEntity> batteries;
  final List<ChecklistItemEntity> checklistItems;
  final List<ChecklistResponseWithItemEntity> checklistResponses;
  final List<ChecklistOverrideEntity> overrides;
  final ReadyToArmValidationResultEntity? readyToArmValidation;
  final List<String> completionIssues;
  final String? errorMessage;
  final String? successMessage;

  const PreFlightState({
    required this.viewStatus,
    required this.sorties,
    required this.selectedSortie,
    required this.setup,
    required this.users,
    required this.selectablePayloads,
    required this.payloads,
    required this.selectableBatteries,
    required this.batteries,
    required this.checklistItems,
    required this.checklistResponses,
    required this.overrides,
    required this.readyToArmValidation,
    required this.completionIssues,
    required this.errorMessage,
    required this.successMessage,
  });

  factory PreFlightState.initial() {
    return const PreFlightState(
      viewStatus: PreFlightViewStatus.initial,
      sorties: [],
      selectedSortie: null,
      setup: null,
      users: [],
      selectablePayloads: [],
      payloads: [],
      selectableBatteries: [],
      batteries: [],
      checklistItems: [],
      checklistResponses: [],
      overrides: [],
      readyToArmValidation: null,
      completionIssues: [],
      errorMessage: null,
      successMessage: null,
    );
  }

  PreFlightState copyWith({
    PreFlightViewStatus? viewStatus,
    List<SortieEntity>? sorties,
    Object? selectedSortie = _unset,
    Object? setup = _unset,
    List<SortieUserWithUserEntity>? users,
    List<PayloadEntity>? selectablePayloads,
    List<SortiePayloadWithPayloadEntity>? payloads,
    List<BatteryEntity>? selectableBatteries,
    List<SortieBatteryWithBatteryEntity>? batteries,
    List<ChecklistItemEntity>? checklistItems,
    List<ChecklistResponseWithItemEntity>? checklistResponses,
    List<ChecklistOverrideEntity>? overrides,
    Object? readyToArmValidation = _unset,
    List<String>? completionIssues,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return PreFlightState(
      viewStatus: viewStatus ?? this.viewStatus,
      sorties: sorties ?? this.sorties,
      selectedSortie: identical(selectedSortie, _unset)
          ? this.selectedSortie
          : selectedSortie as SortieEntity?,
      setup: identical(setup, _unset)
          ? this.setup
          : setup as PreFlightSetupEntity?,
      users: users ?? this.users,
      selectablePayloads: selectablePayloads ?? this.selectablePayloads,
      payloads: payloads ?? this.payloads,
      selectableBatteries: selectableBatteries ?? this.selectableBatteries,
      batteries: batteries ?? this.batteries,
      checklistItems: checklistItems ?? this.checklistItems,
      checklistResponses: checklistResponses ?? this.checklistResponses,
      overrides: overrides ?? this.overrides,
      readyToArmValidation: identical(readyToArmValidation, _unset)
          ? this.readyToArmValidation
          : readyToArmValidation as ReadyToArmValidationResultEntity?,
      completionIssues: completionIssues ?? this.completionIssues,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _unset)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  bool get isLoading => viewStatus == PreFlightViewStatus.loading;

  bool get isSaving => viewStatus == PreFlightViewStatus.saving;

  bool get isValidating => viewStatus == PreFlightViewStatus.validating;

  bool get hasBlockingIssues => completionIssues.isNotEmpty;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}
