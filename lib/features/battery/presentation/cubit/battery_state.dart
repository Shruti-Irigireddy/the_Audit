import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';

enum BatteryViewStatus { initial, loading, loaded, saving, failure }

enum BatteryStatus { ACTIVE, NO_VOLTAGE, ZERO_PERCENT, INACTIVE, RETIRED }

class BatteryState {
  static const Object _unset = Object();

  final BatteryViewStatus viewStatus;
  final BatteryStatus batteryStatus;

  final List<BatteryEntity> batteries;
  final BatteryEntity? selectedBattery;

  final String searchQuery;

  final String? errorMessage;
  final String? successMessage;

  const BatteryState({
    required this.viewStatus,
    required this.batteryStatus,
    required this.batteries,
    required this.selectedBattery,
    required this.searchQuery,
    required this.errorMessage,
    required this.successMessage,
  });

  factory BatteryState.initial() {
    return const BatteryState(
      viewStatus: BatteryViewStatus.initial,
      batteryStatus: BatteryStatus.ACTIVE,
      batteries: [],
      selectedBattery: null,
      searchQuery: '',
      errorMessage: null,
      successMessage: null,
    );
  }

  BatteryState copyWith({
    BatteryViewStatus? viewStatus,
    BatteryStatus? batteryStatus,
    List<BatteryEntity>? batteries,
    Object? selectedBattery = _unset,
    String? searchQuery,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return BatteryState(
      viewStatus: viewStatus ?? this.viewStatus,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      batteries: batteries ?? this.batteries,
      selectedBattery: identical(selectedBattery, _unset)
          ? this.selectedBattery
          : selectedBattery as BatteryEntity?,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _unset)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  bool get isLoading => viewStatus == BatteryViewStatus.loading;

  bool get isSaving => viewStatus == BatteryViewStatus.saving;

  bool get isLoaded => viewStatus == BatteryViewStatus.loaded;

  bool get isActive => batteryStatus == BatteryStatus.ACTIVE;

  bool get hasNoVoltage => batteryStatus == BatteryStatus.NO_VOLTAGE;

  bool get isZeroPercent => batteryStatus == BatteryStatus.ZERO_PERCENT;

  bool get isInactive => batteryStatus == BatteryStatus.INACTIVE;

  bool get isRetired => batteryStatus == BatteryStatus.RETIRED;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get hasSuccess =>
      successMessage != null && successMessage!.trim().isNotEmpty;
}
