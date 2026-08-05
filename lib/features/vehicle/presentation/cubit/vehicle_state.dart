import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_checklist_template_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_with_checklist_entity.dart';

enum VehicleStatus { ACTIVE, INACTIVE, MAINTENANCE, RETIRED }

enum VehicleType { MULTIROTOR, VTOL, FIXED_WING }

enum VehicleViewStatus { initial, loading, loaded, saving, failure }

class VehicleState {
  static const Object _unset = Object();

  final VehicleViewStatus viewStatus;
  final VehicleStatus vehicleStatus;
  final VehicleType? vehicleType;

  final List<VehicleEntity> vehicles;
  final VehicleEntity? selectedVehicleEntity;
  final VehicleWithChecklistEntity? selectedVehicleChecklist;

  final List<ChecklistItemEntity> checklistItems;
  final List<VehicleChecklistTemplateEntity> checklistTemplates;

  final String searchQuery;

  final String? errorMessage;
  final String? successMessage;

  const VehicleState({
    required this.viewStatus,
    required this.vehicleStatus,
    required this.vehicleType,
    required this.vehicles,
    this.selectedVehicleEntity,
    this.selectedVehicleChecklist,
    required this.checklistItems,
    required this.checklistTemplates,
    required this.searchQuery,
    this.errorMessage,
    this.successMessage,
  });

  factory VehicleState.initial() {
    return const VehicleState(
      viewStatus: VehicleViewStatus.initial,
      vehicleStatus: VehicleStatus.ACTIVE,
      vehicleType: null,
      vehicles: [],
      selectedVehicleEntity: null,
      selectedVehicleChecklist: null,
      checklistItems: [],
      checklistTemplates: [],
      searchQuery: '',
      errorMessage: null,
      successMessage: null,
    );
  }

  VehicleState copyWith({
    VehicleViewStatus? viewStatus,
    VehicleStatus? vehicleStatus,
    Object? vehicleTypeValue = _unset,
    List<VehicleEntity>? vehicles,
    Object? selectedVehicle = _unset,
    Object? selectedVehicleWithChecklist = _unset,
    List<VehicleChecklistTemplateEntity>? checklistTemplates,
    List<ChecklistItemEntity>? checklistItems,
    String? searchQuery,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return VehicleState(
      viewStatus: viewStatus ?? this.viewStatus,
      vehicleStatus: vehicleStatus ?? this.vehicleStatus,
      vehicleType: identical(vehicleTypeValue, _unset)
          ? vehicleType
          : vehicleTypeValue as VehicleType?,
      vehicles: vehicles ?? this.vehicles,
      selectedVehicleEntity: identical(selectedVehicle, _unset)
          ? selectedVehicleEntity
          : selectedVehicle as VehicleEntity?,
      selectedVehicleChecklist: identical(selectedVehicleWithChecklist, _unset)
          ? selectedVehicleChecklist
          : selectedVehicleWithChecklist as VehicleWithChecklistEntity?,
      checklistItems: checklistItems ?? this.checklistItems,
      checklistTemplates: checklistTemplates ?? this.checklistTemplates,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _unset)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  bool get isLoading => viewStatus == VehicleViewStatus.loading;

  bool get isSaving => viewStatus == VehicleViewStatus.saving;

  bool get isLoaded => viewStatus == VehicleViewStatus.loaded;

  bool get isInMaintenance => vehicleStatus == VehicleStatus.MAINTENANCE;

  bool get isRetired => vehicleStatus == VehicleStatus.RETIRED;

  bool get isActive => vehicleStatus == VehicleStatus.ACTIVE;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get hasSuccess =>
      successMessage != null && successMessage!.trim().isNotEmpty;
}
