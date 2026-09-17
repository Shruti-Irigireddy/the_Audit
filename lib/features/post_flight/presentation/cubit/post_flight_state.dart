import 'package:the_audit/features/post_flight/domain/entities/post_flight_note_entity.dart';
import 'package:the_audit/features/post_flight/domain/entities/post_flight_setup_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';

enum PostFlightViewStatus {
  initial,
  loading,
  loaded,
  saving,
  validating,
  failure,
}

class PostFlightState {
  static const Object _unset = Object();

  final PostFlightViewStatus viewStatus;
  final List<SortieEntity> pendingSorties;
  final List<SortieEntity> closedSorties;
  final SortieEntity? selectedSortie;
  final PostFlightSetupEntity? setup;
  final PostFlightNoteEntity? note;
  final List<SortieBatteryWithBatteryEntity> batteries;
  final List<SortiePayloadWithPayloadEntity> payloads;
  final List<String> completionIssues;
  final int batteriesWithoutEndStateCount;
  final bool allBatteriesHaveEndState;
  final String? errorMessage;
  final String? successMessage;

  const PostFlightState({
    required this.viewStatus,
    required this.pendingSorties,
    required this.closedSorties,
    required this.selectedSortie,
    required this.setup,
    required this.note,
    required this.batteries,
    required this.payloads,
    required this.completionIssues,
    required this.batteriesWithoutEndStateCount,
    required this.allBatteriesHaveEndState,
    required this.errorMessage,
    required this.successMessage,
  });

  factory PostFlightState.initial() {
    return const PostFlightState(
      viewStatus: PostFlightViewStatus.initial,
      pendingSorties: [],
      closedSorties: [],
      selectedSortie: null,
      setup: null,
      note: null,
      batteries: [],
      payloads: [],
      completionIssues: [],
      batteriesWithoutEndStateCount: 0,
      allBatteriesHaveEndState: false,
      errorMessage: null,
      successMessage: null,
    );
  }

  PostFlightState copyWith({
    PostFlightViewStatus? viewStatus,
    List<SortieEntity>? pendingSorties,
    List<SortieEntity>? closedSorties,
    Object? selectedSortie = _unset,
    Object? setup = _unset,
    Object? note = _unset,
    List<SortieBatteryWithBatteryEntity>? batteries,
    List<SortiePayloadWithPayloadEntity>? payloads,
    List<String>? completionIssues,
    int? batteriesWithoutEndStateCount,
    bool? allBatteriesHaveEndState,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return PostFlightState(
      viewStatus: viewStatus ?? this.viewStatus,
      pendingSorties: pendingSorties ?? this.pendingSorties,
      closedSorties: closedSorties ?? this.closedSorties,
      selectedSortie: identical(selectedSortie, _unset)
          ? this.selectedSortie
          : selectedSortie as SortieEntity?,
      setup: identical(setup, _unset)
          ? this.setup
          : setup as PostFlightSetupEntity?,
      note: identical(note, _unset) ? this.note : note as PostFlightNoteEntity?,
      batteries: batteries ?? this.batteries,
      payloads: payloads ?? this.payloads,
      completionIssues: completionIssues ?? this.completionIssues,
      batteriesWithoutEndStateCount:
          batteriesWithoutEndStateCount ?? this.batteriesWithoutEndStateCount,
      allBatteriesHaveEndState:
          allBatteriesHaveEndState ?? this.allBatteriesHaveEndState,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _unset)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  bool get isLoading => viewStatus == PostFlightViewStatus.loading;

  bool get isSaving => viewStatus == PostFlightViewStatus.saving;

  bool get isValidating => viewStatus == PostFlightViewStatus.validating;

  bool get hasBlockingIssues => completionIssues.isNotEmpty;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}
