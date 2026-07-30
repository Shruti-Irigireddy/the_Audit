import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_vehicle_compatibility_entity.dart';

extension PayloadDbMapper on Payload {
  PayloadEntity toEntity() {
    return PayloadEntity(
      payloadId: payloadId,
      name: name,
      category: category,
      storageType: storageType,
      storageCapacity: storageCapacity,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension PayloadVehicleCompatibilityDbMapper on PayloadVehicleCompatibilityData {
  PayloadVehicleCompatibilityEntity toEntity() {
    return PayloadVehicleCompatibilityEntity(
      id: id,
      payloadId: payloadId,
      vehicleType: vehicleType,
      createdAt: createdAt,
    );
  }
}