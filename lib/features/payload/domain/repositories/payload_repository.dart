import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_vehicle_compatibility_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_with_compatibility_entity.dart';

abstract class PayloadRepository {
  Future<String> createPayload ({
    required String payloadId,
    required String name,
    required String category,
    String? storageType,
    String? storageCapacity,
    required DateTime createdAt,
    required DateTime updatedAt,
    List<String> compatibleVehicleTypes = const [],
  });

  Future<PayloadEntity?> getPayloadById(String payloadId);

  Future<PayloadWithCompatibilityEntity> getPayloadWithCompatibility(String payloadId);

  Future<List<PayloadEntity>> getAllPayloads();

  Future<List<PayloadEntity>> searchPayload(String query);

  Future<void> updatePayload({
    required String payloadId,
    String? name,
    String? category,
    String? storageType,
    String? storageCapacity,
    required String performedBy,
  });

  Future<void> deletePayload({
    required String payloadId,
    required String performedBy,
  });

  Future<List<PayloadVehicleCompatibilityEntity>> getCompatibityRulesForPayload(String payloadId);

  Future<List<String>> getCompatibleVehicleTypes(String payloadId);

  Future<bool> isPayloadCompatibleWthVehicleType({
    required String payloadId,
    required String vehicleType,
  });

  Future<List<PayloadEntity>> getPayloadsCompatibleWithVehicleType(String vehicleId);

  Future<List<PayloadEntity>> getPayloadsExplicitlyCompatibleWithVehicleType(String payloadId);

  Future<void> replacePayloadCompatibility ({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  });

  Future<void> addPayloadCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  });

    Future<void> removePayloadCompatibility({
    required String payloadId,
    required String vehicleType,
    required String performedBy,
  });
}