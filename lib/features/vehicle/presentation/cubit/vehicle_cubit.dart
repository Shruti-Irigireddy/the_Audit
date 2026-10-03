import 'package:bloc/bloc.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/vehicle/domain/dtos/vehicle_dtos.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:the_audit/features/vehicle/domain/repositories/vehicle_repository.dart';
import 'vehicle_state.dart';

class VehicleCubit extends Cubit<VehicleState> {
  static const _log = AppLogger('VehicleCubit');

  final VehicleRepository _repository;

  VehicleCubit(this._repository) : super(VehicleState.initial());

  Future<void> loadVehicles() async {
    _log.t('loadVehicles()');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.loading, errorMessage: null),
    );

    try {
      final vehicles = await _repository.getAllVehicles();
      _log.d('${vehicles.length} vehicles loaded');
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          vehicles: vehicles,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadVehicles failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadActiveVehicles() async {
    _log.t('loadActiveVehicles()');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.loading, errorMessage: null),
    );

    try {
      final vehicles = await _repository.getActiveVehicles();
      _log.d('${vehicles.length} active vehicles loaded');
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          vehicleStatus: VehicleStatus.ACTIVE,
          vehicles: vehicles,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadActiveVehicles failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> searchVehicles(String query) async {
    _log.t('searchVehicles("$query")');
    emit(
      state.copyWith(
        viewStatus: VehicleViewStatus.loading,
        searchQuery: query,
        errorMessage: null,
      ),
    );

    try {
      final vehicles = query.trim().isEmpty
          ? await _repository.getAllVehicles()
          : await _repository.searchVehicles(query);
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          vehicles: vehicles,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('searchVehicles failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> selectVehicle(String vehicleId) async {
    _log.t('selectVehicle($vehicleId)');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.loading, errorMessage: null),
    );

    try {
      final vehicle = await _repository.getVehicleById(vehicleId);
      final vehicleWithChecklist = await _repository
          .getVehicleWithActiveChecklist(vehicleId);
      final checklistItems = await _repository.getChecklistForVehicle(
        vehicleId,
      );
      final checklistTemplates = await _repository
          .getChecklistTemplatesForVehicle(vehicleId);

      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          selectedVehicle: vehicle,
          selectedVehicleWithChecklist: vehicleWithChecklist,
          checklistItems: checklistItems,
          checklistTemplates: checklistTemplates,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('selectVehicle failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> createVehicleWithChecklist({
    String? vehicleId,
    required String name,
    required VehicleType type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? notes,
    required String createdBy,
    required List<ChecklistItemDraft> checklistItems,
  }) async {
    _log.i(
      'createVehicleWithChecklist(id: $vehicleId, type: ${type.name}, ${checklistItems.length} checklist items)',
    );
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.saving, errorMessage: null),
    );

    try {
      final id = await _repository.createVehicleWithChecklist(
        vehicleId: vehicleId,
        name: name,
        type: type.name,
        frameMake: frameMake,
        frameModel: frameModel,
        motorCount: motorCount,
        frameStyle: frameStyle,
        firmwareTarget: firmwareTarget,
        defaultFailSafeProfile: defaultFailSafeProfile,
        notes: notes,
        createdBy: createdBy,
        checklistItems: checklistItems,
      );
      _log.i('vehicle created: $id');
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          vehicleTypeValue: type,
          successMessage: 'Vehicle saved.',
          errorMessage: null,
        ),
      );
      await selectVehicle(id);
      await loadVehicles();
    } catch (error, stackTrace) {
      _log.e('createVehicleWithChecklist failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updateVehicle({
    required String vehicleId,
    String? name,
    VehicleType? type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    VehicleStatus? status,
    String? notes,
    required String performedBy,
  }) async {
    _log.i('updateVehicle($vehicleId, status: ${status?.name})');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.updateVehicle(
        vehicleId: vehicleId,
        name: name,
        type: type?.name,
        frameMake: frameMake,
        frameModel: frameModel,
        motorCount: motorCount,
        frameStyle: frameStyle,
        firmwareTarget: firmwareTarget,
        defaultFailSafeProfile: defaultFailSafeProfile,
        status: status?.name,
        notes: notes,
        performedBy: performedBy,
      );
      await selectVehicle(vehicleId);
    } catch (error, stackTrace) {
      _log.e('updateVehicle failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> retireVehicle({
    required String vehicleId,
    required String performedBy,
  }) async {
    _log.i('retireVehicle($vehicleId)');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.retireVehicle(
        vehicleId: vehicleId,
        performedBy: performedBy,
      );
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          vehicleStatus: VehicleStatus.RETIRED,
          successMessage: 'Vehicle retired.',
          errorMessage: null,
        ),
      );
      await loadVehicles();
    } catch (error, stackTrace) {
      _log.e('retireVehicle failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> markVehicleActive({
    required String vehicleId,
    required String performedBy,
  }) async {
    _log.i('markVehicleActive($vehicleId)');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.markVehicleActive(
        vehicleId: vehicleId,
        performedBy: performedBy,
      );
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          vehicleStatus: VehicleStatus.ACTIVE,
          successMessage: 'Vehicle marked active.',
          errorMessage: null,
        ),
      );
      await selectVehicle(vehicleId);
      await loadVehicles();
    } catch (error, stackTrace) {
      _log.e('markVehicleActive failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> markVehicleInactive({
    required String vehicleId,
    required String performedBy,
  }) async {
    _log.i('markVehicleInactive($vehicleId)');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.markVehicleInactive(
        vehicleId: vehicleId,
        performedBy: performedBy,
      );
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          vehicleStatus: VehicleStatus.INACTIVE,
          successMessage: 'Vehicle marked inactive.',
          errorMessage: null,
        ),
      );
      await selectVehicle(vehicleId);
      await loadVehicles();
    } catch (error, stackTrace) {
      _log.e('markVehicleInactive failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadChecklistItemsForTemplate(String templateId) async {
    _log.t('loadChecklistItemsForTemplate($templateId)');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.loading, errorMessage: null),
    );

    try {
      final checklistItems = await _repository.getChecklistItemsForTemplate(
        templateId,
      );
      emit(
        state.copyWith(
          viewStatus: VehicleViewStatus.loaded,
          checklistItems: checklistItems,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadChecklistItemsForTemplate failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> createNewChecklistVersionForVehicle({
    required String vehicleId,
    required List<ChecklistItemDraft> checklistItems,
    required String createdBy,
    String? deactivationReason,
  }) async {
    _log.i(
      'createNewChecklistVersionForVehicle($vehicleId, ${checklistItems.length} items)',
    );
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.createNewChecklistVersionForVehicle(
        vehicleId: vehicleId,
        checklistItems: checklistItems,
        createdBy: createdBy,
        deactivationReason: deactivationReason,
      );
      await selectVehicle(vehicleId);
    } catch (error, stackTrace) {
      _log.e('createNewChecklistVersionForVehicle failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> deactivateChecklistTemplate({
    required String templateId,
    required String vehicleId,
    required String deactivatedBy,
    String? deactivationReason,
  }) async {
    _log.i('deactivateChecklistTemplate($templateId, vehicle: $vehicleId)');
    emit(
      state.copyWith(viewStatus: VehicleViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.deactivateChecklistTemplate(
        templateId: templateId,
        deactivatedBy: deactivatedBy,
        deactivationReason: deactivationReason,
      );
      await selectVehicle(vehicleId);
    } catch (error, stackTrace) {
      _log.e('deactivateChecklistTemplate failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  void setSelectedVehicle(VehicleEntity? vehicle) {
    emit(state.copyWith(selectedVehicle: vehicle));
  }

  void _emitFailure(Object error) {
    emit(
      state.copyWith(
        viewStatus: VehicleViewStatus.failure,
        errorMessage: error.toString(),
      ),
    );
  }
}
