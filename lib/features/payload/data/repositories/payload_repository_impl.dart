import 'package:the_audit/core/database/daos/payload/payload_dao.dart';

import 'package:the_audit/features/payload/data/mappers/payload_mapper.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_vehicle_compatibility_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_with_compatibility_entity.dart';
import 'package:the_audit/features/payload/domain/repositories/payload_repository.dart';

class PayloadRepositoryImpl implements PayloadRepository {
  final PayloadDao _payloadDao;

  const PayloadRepositoryImpl({
    required PayloadDao payloadDao,
  }) : _payloadDao = payloadDao;

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
    final payload = await _payloadDao.getPayloadById(payloadId);
    return payload?.toEntity();
  }

  @override
  Future<PayloadWithCompatibilityEntity?> getPayloadWithCompatibility(
    String payloadId,
  ) async {
    final payload = await _payloadDao.getPayloadById(payloadId);

    if (payload == null) {
      return null;
    }

    final compatibilityRules =
        await _payloadDao.getCompatibilityRulesForPayload(payloadId);

    return PayloadWithCompatibilityEntity(
      payload: payload.toEntity(),
      compatibilityRules: compatibilityRules
          .map((compatibility) => compatibility.toEntity())
          .toList(),
    );
  }

  @override
  Future<List<PayloadEntity>> getAllPayloads() async {
    final payloads = await _payloadDao.getAllPayloads();
    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<List<PayloadEntity>> searchPayload(String query) async {
    final payloads = await _payloadDao.searchPayloads(query);
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
    return _payloadDao.retirePayload(
      payloadId: payloadId,
      performedBy: performedBy,
    );
  }

  @override
  Future<List<PayloadVehicleCompatibilityEntity>>
      getCompatibilityRulesForPayload(String payloadId) async {
    final rules = await _payloadDao.getCompatibilityRulesForPayload(payloadId);

    return rules.map((rule) => rule.toEntity()).toList();
  }

  @override
  Future<List<String>> getCompatibleVehicleTypes(String payloadId) {
    return _payloadDao.getCompatibleVehicleTypes(payloadId);
  }

  @override
  Future<bool> isPayloadCompatibleWithVehicleType({
    required String payloadId,
    required String vehicleType,
  }) {
    return _payloadDao.isPayloadCompatibleWithVehicleType(
      payloadId: payloadId,
      vehicleType: vehicleType,
    );
  }

  @override
  Future<List<PayloadEntity>> getPayloadsCompatibleWithVehicleType(
    String vehicleType,
  ) async {
    final payloads =
        await _payloadDao.getPayloadsCompatibleWithVehicleType(vehicleType);

    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<List<PayloadEntity>> getPayloadsExplicitlyCompatibleWithVehicleType(
    String vehicleType,
  ) async {
    final payloads = await _payloadDao
        .getPayloadsExplicitlyCompatibleWithVehicleType(vehicleType);

    return payloads.map((payload) => payload.toEntity()).toList();
  }

  @override
  Future<void> replacePayloadCompatibility({
    required String payloadId,
    required List<String> compatibleVehicleTypes,
    required String performedBy,
  }) {
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
    return _payloadDao.removePayloadCompatibility(
      payloadId: payloadId,
      vehicleType: vehicleType,
      performedBy: performedBy,
    );
  }
}
