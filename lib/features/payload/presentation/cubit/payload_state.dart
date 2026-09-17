import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';

enum PayloadCategory { RGB, THERMAL, MULTISPECTRAL, LIDAR, MAPPING, OTHER }

enum PayloadStatus { ACTIVE, INACTIVE, MAINTENANCE, LOADED }

enum PayloadViewStatus { initial, loading, loaded, saving, failure }

class PayloadState {
  static const Object _unset = Object();

  final PayloadViewStatus viewStatus;
  final PayloadCategory? category;
  final PayloadStatus? payloadStatus;

  final List<PayloadEntity> payloads;
  final PayloadEntity? selectedPayload;

  final List<String> compatibleVehicleTypes;
  final String searchQuery;

  final String? errorMessage;
  final String? successMessage;

  const PayloadState({
    required this.viewStatus,
    required this.category,
    required this.payloadStatus,
    required this.payloads,
    required this.selectedPayload,
    required this.compatibleVehicleTypes,
    required this.searchQuery,
    required this.errorMessage,
    required this.successMessage,
  });

  factory PayloadState.initial() {
    return const PayloadState(
      viewStatus: PayloadViewStatus.initial,
      category: null,
      payloadStatus: null,
      payloads: [],
      selectedPayload: null,
      compatibleVehicleTypes: [],
      searchQuery: '',
      errorMessage: null,
      successMessage: null,
    );
  }

  PayloadState copyWith({
    PayloadViewStatus? viewStatus,
    Object? category = _unset,
    Object? payloadStatus = _unset,
    List<PayloadEntity>? payloads,
    Object? selectedPayload = _unset,
    List<String>? compatibleVehicleTypes,
    String? searchQuery,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return PayloadState(
      viewStatus: viewStatus ?? this.viewStatus,
      category: identical(category, _unset)
          ? this.category
          : category as PayloadCategory?,
      payloadStatus: identical(payloadStatus, _unset)
          ? this.payloadStatus
          : payloadStatus as PayloadStatus?,
      payloads: payloads ?? this.payloads,
      selectedPayload: identical(selectedPayload, _unset)
          ? this.selectedPayload
          : selectedPayload as PayloadEntity?,
      compatibleVehicleTypes:
          compatibleVehicleTypes ?? this.compatibleVehicleTypes,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _unset)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  bool get isLoading => viewStatus == PayloadViewStatus.loading;

  bool get isSaving => viewStatus == PayloadViewStatus.saving;

  bool get isLoaded => viewStatus == PayloadViewStatus.loaded;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get hasSuccess =>
      successMessage != null && successMessage!.trim().isNotEmpty;
}
