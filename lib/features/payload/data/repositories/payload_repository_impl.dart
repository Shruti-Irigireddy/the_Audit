import 'package:the_audit/core/database/daos/payload/payload_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';

import 'package:the_audit/features/payload/data/mappers/payload_mapper.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_vehicle_compatibility_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_with_compatibility_entity.dart';
import 'package:the_audit/features/payload/domain/repositories/payload_repository.dart';

class PayloadRepositoryImpl implements PayloadRepository {
  static const _log = AppLogger('PayloadRepositoryImpl');

  final PayloadDao _payloadDao;

  const PayloadRepositoryImpl({required PayloadDao payloadDao})
    : _payloadDao = payloadDao;

  @override
  Future<String> createPayload({
    String? payloadId,
    required String name,
    required String category,
    String? storageType,
    String? storageCapacity,
    String? status,
    required String performedBy,
    List<String> compatibleVehicleTypes = const [],
  }) {
    _log.t('createPayload(payloadId: $payloadId, status: $status)');
    return _payloadDao.createPayload(
      payloadId: payloadId,
      name: name,
      category: category,
      storageType: storageType,
      storageCapacity: storageCapacity,
      status: status,
      performedBy: performedBy,
      compatibleVehicleTypes: compatibleVehicleTypes,
    );
  }

  @override
  Future<PayloadEntity?> getPayloadById(String payloadId) async {
    _log.t('getPayloadById(payloadId: $payloadId)');
    final payload = await _payloadDao.getPayloadById(payloadId);
    return payload?.toEntity();
  }

  @override
  Future<PayloadWithCompatibilityEntity?> getPayloadWithCompatibility(
    String payloadId,
  ) async {
    _log.t('getPayloadWithCompatibility(payloadId: $payloadId)');
    final payload = await _payloadDao.getPayloadById(payloadId);

    if (payload == null) {
      return null;
    }

    final compatibilityRules = await _payloadDao
        .getCompatibilityRulesForPayload(payloadId);

    return PayloadWithCompatibilityEntity(
      payload: payload.toEntity(),
      compatibilityRules: compatibilityRules
          .map((compatibility) => compatibility.toEntity())
          .toList(),
    );
  }

  @override
  Future<List<PayloadEntity>> getAllPayloads() async {
    _log.t('getAllPayloads()');
    final payloads = await _payloadDao.getAllPayloads();
    _log.d('getAllPayloads: ${payloads.length} items');
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<List<PayloadEntity>> searchPayload(String query) async {
    _log.t('searchPayload(query: $query)');
    final payloads = await _payloadDao.searchPayloads(query);
    _log.d('searchPayload: ${payloads.length} items');
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<void> updatePayload({
    required String payloadId,
    String? name,
    String? category,
    String? storageType,
    String? storageCapacity,
    String? status,
    required String performedBy,
  }) {
    _log.t('updatePayload(payloadId: $payloadId, status: $status)');
    return _payloadDao.updatePayload(
      payloadId: payloadId,
      name: name,
      category: category,
      storageType: storageType,
      storageCapacity: storageCapacity,
      status: status,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> retirePayload({
    required String payloadId,
    required String performedBy,
  }) {
    _log.t('retirePayload(payloadId: $payloadId)');
    return _payloadDao.retirePayload(
      payloadId: payloadId,
      performedBy: performedBy,
    );
  }

  @override
  Future<List<PayloadVehicleCompatibilityEntity>>
  getCompatibilityRulesForPayload(String payloadId) async {
    _log.t('getCompatibilityRulesForPayload(payloadId: $payloadId)');
    final rules = await _payloadDao.getCompatibilityRulesForPayload(payloadId);

    _log.d('getCompatibilityRulesForPayload: ${rules.length} items');
    return rules.map((rule) => rule.toEntity()).toList();
  }

  @override
  Future<List<String>> getCompatibleVehicleTypes(String payloadId) {
    _log.t('getCompatibleVehicleTypes(payloadId: $payloadId)');
    return _payloadDao.getCompatibleVehicleTypes(payloadId);
  }

  @override
  Future<bool> isPayloadCompatibleWithVehicleType({
    required String payloadId,
    required String vehicleType,
  }) {
    _log.t(
      'isPayloadCompatibleWithVehicleType(payloadId: $payloadId, vehicleType: $vehicleType)',
    );
    return _payloadDao.isPayloadCompatibleWithVehicleType(
      payloadId: payloadId,
      vehicleType: vehicleType,
    );
  }

  @override
  Future<List<PayloadEntity>> getPayloadsCompatibleWithVehicleType(
    String vehicleType,
  ) async {
    _log.t('getPayloadsCompatibleWithVehicleType(vehicleType: $vehicleType)');
    final payloads = await _payloadDao.getPayloadsCompatibleWithVehicleType(
      vehicleType,
    );

    _log.d('getPayloadsCompatibleWithVehicleType: ${payloads.length} items');
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<List<PayloadEntity>> getPayloadsExplicitlyCompatibleWithVehicleType(
    String vehicleType,
  ) async {
    _log.t(
      'getPayloadsExplicitlyCompatibleWithVehicleType(vehicleType: $vehicleType)',
    );
    final payloads = await _payloadDao
        .getPayloadsExplicitlyCompatibleWithVehicleType(vehicleType);

    _log.d(
      'getPayloadsExplicitlyCompatibleWithVehicleType: ${payloads.length} items',
    );
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<void> replacePayloadCompatibility({
    required String payloadId,
    required List<String> compatibleVehicleTypes,
    required String performedBy,
  }) {
    _log.t('replacePayloadCompatibility(payloadId: $payloadId)');
    return _payloadDao.replacePayloadCompatibility(
      payloadId: payloadId,
      compatibleVehicleTypes: compatibleVehicleTypes,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> addPayloadCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  }) {
    _log.t(
      'addPayloadCompatibility(payloadId: $payloadId, vehicleType: $vehicleType)',
    );
    return _payloadDao.addPayloadCompatibility(
      payloadId: payloadId,
      vehicleType: vehicleType,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> removePayloadCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  }) {
    _log.t(
      'removePayloadCompatibility(payloadId: $payloadId, vehicleType: $vehicleType)',
    );
    return _payloadDao.removePayloadCompatibility(
      payloadId: payloadId,
      vehicleType: vehicleType,
      performedBy: performedBy,
    );
  }
}
