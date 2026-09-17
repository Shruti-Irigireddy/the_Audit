import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_vehicle_compatibility_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_with_compatibility_entity.dart';

abstract class PayloadRepository {

  Future<String> createPayload ({
    String? payloadId,
    required String name,
    required String category,
    String? storageType,
    String? storageCapacity,
    String? status,
    required String performedBy,
    List<String> compatibleVehicleTypes = const [],
  });

  Future<PayloadEntity?> getPayloadById(String payloadId);

  Future<PayloadWithCompatibilityEntity?> getPayloadWithCompatibility(String payloadId);

  Future<List<PayloadEntity>> getAllPayloads();

  Future<List<PayloadEntity>> searchPayload(String query);

  Future<void> updatePayload({
    required String payloadId,
    String? name,
    String? category,
    String? storageType,
    String? storageCapacity,
    String? status,
    required String performedBy,
  });

  // Future<void> deletePayload({
  //   required String payloadId,
  //   required String performedBy,
  // });

  Future<void> retirePayload({
    required String payloadId,
    required String performedBy,
  });

  Future<List<PayloadVehicleCompatibilityEntity>> getCompatibilityRulesForPayload(String payloadId);

  Future<List<String>> getCompatibleVehicleTypes(String payloadId);

  Future<bool> isPayloadCompatibleWithVehicleType({
    required String payloadId,
    required String vehicleType,
  });

  Future<List<PayloadEntity>> getPayloadsCompatibleWithVehicleType(String vehicleType);

  Future<List<PayloadEntity>> getPayloadsExplicitlyCompatibleWithVehicleType(String vehicleType);

  Future<void> replacePayloadCompatibility ({
    required String payloadId,
    required List<String> compatibleVehicleTypes,
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
