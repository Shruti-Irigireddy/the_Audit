import 'package:bloc/bloc.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/battery/domain/repositories/battery_repository.dart';
import 'battery_state.dart';

class BatteryCubit extends Cubit<BatteryState> {
  static const _log = AppLogger('BatteryCubit');

  final BatteryRepository _repository;

  BatteryCubit(this._repository) : super(BatteryState.initial());

  Future<void> loadAllBatteries() async {
    _log.t('loadAllBatteries()');
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.loading, errorMessage: null),
    );

    try {
      final batteries = await _repository.getAllBatteries();
      _log.d('${batteries.length} batteries loaded');
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          batteries: batteries,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadAllBatteries failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadActiveBatteries() async {
    _log.t('loadActiveBatteries()');
    emit(
      state.copyWith(viewStatus: BatteryViewStatus.loading, errorMessage: null),
    );

    try {
      final batteries = await _repository.getActiveBatteries();
      _log.d('${batteries.length} active batteries loaded');
      emit(
        state.copyWith(
          viewStatus: BatteryViewStatus.loaded,
          batteries: batteries,
          batteryStatus: BatteryStatus.ACTIVE,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadActiveBatteries failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> selectBattery(String batteryId) async {
    _log.t('selectBattery($batteryId)');
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
    } catch (error, stackTrace) {
      _log.e('selectBattery failed', error, stackTrace);
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
    _log.i('createBattery(id: $batteryId, status: ${status.name})');
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
      _log.d('battery created: $id');
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
    } catch (error, stackTrace) {
      _log.e('createBattery failed', error, stackTrace);
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
    _log.i('updateBattery($batteryId, status: ${status?.name})');
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
    } catch (error, stackTrace) {
      _log.e('updateBattery failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> retireBattery({
    required String batteryId,
    required String performedBy,
  }) async {
    _log.i('retireBattery($batteryId)');
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
    } catch (error, stackTrace) {
      _log.e('retireBattery failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> incrementCycleCount({
    required String batteryId,
    required String performedBy,
  }) async {
    _log.i('incrementCycleCount($batteryId)');
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
    } catch (error, stackTrace) {
      _log.e('incrementCycleCount failed', error, stackTrace);
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
