import 'package:bloc/bloc.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/payload/domain/repositories/payload_repository.dart';
import 'payload_state.dart';

class PayloadCubit extends Cubit<PayloadState> {
  static const _log = AppLogger('PayloadCubit');

  final PayloadRepository _repository;

  PayloadCubit(this._repository) : super(PayloadState.initial());

  Future<void> loadPayloads() async {
    _log.t('loadPayloads()');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.loading, errorMessage: null),
    );

    try {
      final payloads = await _repository.getAllPayloads();
      _log.d('${payloads.length} payloads loaded');
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          payloads: payloads,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadPayloads failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> searchPayloads(String query) async {
    _log.t('searchPayloads("$query")');
    emit(
      state.copyWith(
        viewStatus: PayloadViewStatus.loading,
        searchQuery: query,
        errorMessage: null,
      ),
    );

    try {
      final payloads = query.trim().isEmpty
          ? await _repository.getAllPayloads()
          : await _repository.searchPayload(query);
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          payloads: payloads,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('searchPayloads failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> selectPayload(String payloadId) async {
    _log.t('selectPayload($payloadId)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.loading, errorMessage: null),
    );

    try {
      final payload = await _repository.getPayloadById(payloadId);
      final compatibleVehicleTypes = await _repository
          .getCompatibleVehicleTypes(payloadId);
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          selectedPayload: payload,
          compatibleVehicleTypes: compatibleVehicleTypes,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('selectPayload failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadPayloadWithCompatibility(String payloadId) async {
    _log.t('loadPayloadWithCompatibility($payloadId)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.loading, errorMessage: null),
    );

    try {
      final payloadWithCompatibility = await _repository
          .getPayloadWithCompatibility(payloadId);
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          selectedPayload: payloadWithCompatibility?.payload,
          compatibleVehicleTypes:
              payloadWithCompatibility?.compatibleVehicleTypes ?? [],
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadPayloadWithCompatibility failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadPayloadsCompatibleWithVehicleType(String vehicleType) async {
    _log.t('loadPayloadsCompatibleWithVehicleType($vehicleType)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.loading, errorMessage: null),
    );

    try {
      final payloads = await _repository.getPayloadsCompatibleWithVehicleType(
        vehicleType,
      );
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          payloads: payloads,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadPayloadsCompatibleWithVehicleType failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> loadPayloadsExplicitlyCompatibleWithVehicleType(
    String vehicleType,
  ) async {
    _log.t('loadPayloadsExplicitlyCompatibleWithVehicleType($vehicleType)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.loading, errorMessage: null),
    );

    try {
      final payloads = await _repository
          .getPayloadsExplicitlyCompatibleWithVehicleType(vehicleType);
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          payloads: payloads,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e(
        'loadPayloadsExplicitlyCompatibleWithVehicleType failed',
        error,
        stackTrace,
      );
      _emitFailure(error);
    }
  }

  Future<void> createPayload({
    String? payloadId,
    required String name,
    required PayloadCategory category,
    String? storageType,
    String? storageCapacity,
    PayloadStatus? status,
    required String performedBy,
    List<String> compatibleVehicleTypes = const [],
  }) async {
    _log.i('createPayload(id: $payloadId, category: ${category.name})');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.saving, errorMessage: null),
    );

    try {
      final id = await _repository.createPayload(
        payloadId: payloadId,
        name: name,
        category: category.name,
        storageType: storageType,
        storageCapacity: storageCapacity,
        status: status?.name,
        performedBy: performedBy,
        compatibleVehicleTypes: compatibleVehicleTypes,
      );
      _log.d('payload created: $id');
      final payload = await _repository.getPayloadById(id);
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          category: category,
          payloadStatus: status,
          selectedPayload: payload,
          compatibleVehicleTypes: compatibleVehicleTypes,
          successMessage: 'Payload saved.',
          errorMessage: null,
        ),
      );
      await loadPayloads();
    } catch (error, stackTrace) {
      _log.e('createPayload failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> updatePayload({
    required String payloadId,
    String? name,
    PayloadCategory? category,
    String? storageType,
    String? storageCapacity,
    PayloadStatus? status,
    required String performedBy,
  }) async {
    _log.i('updatePayload($payloadId, status: ${status?.name})');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.updatePayload(
        payloadId: payloadId,
        name: name,
        category: category?.name,
        storageType: storageType,
        storageCapacity: storageCapacity,
        status: status?.name,
        performedBy: performedBy,
      );
      await selectPayload(payloadId);
    } catch (error, stackTrace) {
      _log.e('updatePayload failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> retirePayload({
    required String payloadId,
    required String performedBy,
  }) async {
    _log.i('retirePayload($payloadId)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.retirePayload(
        payloadId: payloadId,
        performedBy: performedBy,
      );
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          successMessage: 'Payload retired.',
          errorMessage: null,
        ),
      );
      await loadPayloads();
    } catch (error, stackTrace) {
      _log.e('retirePayload failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> replaceCompatibility({
    required String payloadId,
    required List<String> compatibleVehicleTypes,
    required String performedBy,
  }) async {
    _log.i('replaceCompatibility($payloadId, $compatibleVehicleTypes)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.replacePayloadCompatibility(
        payloadId: payloadId,
        compatibleVehicleTypes: compatibleVehicleTypes,
        performedBy: performedBy,
      );
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          compatibleVehicleTypes: compatibleVehicleTypes,
          successMessage: 'Compatibility updated.',
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('replaceCompatibility failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> addCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  }) async {
    _log.i('addCompatibility($payloadId, $vehicleType)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.addPayloadCompatibility(
        payloadId: payloadId,
        vehicleType: vehicleType,
        performedBy: performedBy,
      );
      final compatibleVehicleTypes = await _repository
          .getCompatibleVehicleTypes(payloadId);
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          compatibleVehicleTypes: compatibleVehicleTypes,
          successMessage: 'Compatibility added.',
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('addCompatibility failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<void> removeCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  }) async {
    _log.i('removeCompatibility($payloadId, $vehicleType)');
    emit(
      state.copyWith(viewStatus: PayloadViewStatus.saving, errorMessage: null),
    );

    try {
      await _repository.removePayloadCompatibility(
        payloadId: payloadId,
        vehicleType: vehicleType,
        performedBy: performedBy,
      );
      final compatibleVehicleTypes = await _repository
          .getCompatibleVehicleTypes(payloadId);
      emit(
        state.copyWith(
          viewStatus: PayloadViewStatus.loaded,
          compatibleVehicleTypes: compatibleVehicleTypes,
          successMessage: 'Compatibility removed.',
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('removeCompatibility failed', error, stackTrace);
      _emitFailure(error);
    }
  }

  Future<bool> isPayloadCompatibleWithVehicleType({
    required String payloadId,
    required String vehicleType,
  }) {
    return _repository.isPayloadCompatibleWithVehicleType(
      payloadId: payloadId,
      vehicleType: vehicleType,
    );
  }

  void setSelectedPayload(PayloadEntity? payload) {
    emit(state.copyWith(selectedPayload: payload));
  }

  void _emitFailure(Object error) {
    emit(
      state.copyWith(
        viewStatus: PayloadViewStatus.failure,
        errorMessage: error.toString(),
      ),
    );
  }
}
