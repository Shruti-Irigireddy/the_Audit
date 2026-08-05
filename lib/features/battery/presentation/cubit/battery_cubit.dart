import 'package:bloc/bloc.dart';

import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/battery/domain/repositories/battery_repository.dart';
import 'battery_state.dart';

class BatteryCubit extends Cubit<BatteryState> {
  final BatteryRepository _repository;

  BatteryCubit(this._repository) : super(BatteryState.initial());

  Future<void> loadAllBatteries() async {
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.loading, errorMessage: null),
    );

    try {
      final batteries = await _repository.getAllBatteries();
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          batteries: batteries,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> loadActiveBatteries() async {
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.loading, errorMessage: null),
    );

    try {
      final batteries = await _repository.getActiveBatteries();
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          batteries: batteries,
          batteryStatus: BatteryStatus.ACTIVE,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> selectBattery(String batteryId) async {
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.loading, errorMessage: null),
    );

    try {
      final battery = await _repository.getBatteryById(batteryId);
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          selectedBattery: battery,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> createBattery({
    String? batteryId,
    required String config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    required BatteryStatus status,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.saving, errorMessage: null),
    );

    try {
      final id = await _repository.createBattery(
        batteryId: batteryId,
        config: config,
        capacity: capacity,
        voltage: voltage,
        cycleCount: cycleCount,
        status: status.name,
        performedBy: performedBy,
      );
      final battery = await _repository.getBatteryById(id);
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          selectedBattery: battery,
          successMessage: 'Battery saved.',
          errorMessage: null,
        ),
      );
      await loadAllBatteries();
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> updateBattery({
    required String batteryId,
    String? config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    BatteryStatus? status,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.updateBattery(
        batteryId: batteryId,
        config: config,
        capacity: capacity,
        voltage: voltage,
        cycleCount: cycleCount,
        status: status?.name,
        performedBy: performedBy,
      );
      final battery = await _repository.getBatteryById(batteryId);
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          selectedBattery: battery,
          successMessage: 'Battery updated.',
          errorMessage: null,
        ),
      );
      await loadAllBatteries();
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> retireBattery({
    required String batteryId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.retireBattery(
        batteryId: batteryId,
        performedBy: performedBy,
      );
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          successMessage: 'Battery retired.',
          errorMessage: null,
        ),
      );
      await loadAllBatteries();
    } catch (error) {
      _emitFailure(error);
    }
  }

  Future<void> incrementCycleCount({
    required String batteryId,
    required String performedBy,
  }) async {
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.incrementCycleCount(
        batteryId: batteryId,
        performedBy: performedBy,
      );
      final battery = await _repository.getBatteryById(batteryId);
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          selectedBattery: battery,
          successMessage: 'Battery cycle count updated.',
          errorMessage: null,
        ),
      );
      await loadAllBatteries();
    } catch (error) {
      _emitFailure(error);
    }
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void setSelectedBattery(BatteryEntity? battery) {
    emit(state.copyWith(selectedBattery: battery));
  }

  void _emitFailure(Object error) {
    emit(
      state.copyWith(
        viewStatus: BatteryViewStatus.failure,
        errorMessage: error.toString(),
      ),
    );
  }
}
