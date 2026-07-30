import 'payload_entity.dart';
import 'payload_vehicle_compatibility_entity.dart';

class PayloadWithCompatibilityEntity {
  final PayloadEntity payload;
  final List<PayloadVehicleCompatibilityEntity> compatibilityRules;

  const PayloadWithCompatibilityEntity ({
    required this.payload,
    required this.compatibilityRules,
  });

  bool get isUniversal {
    return compatibilityRules.isEmpty;
  }

  List<String> get compatibleVehicleTypes {
    return compatibilityRules.map((rule) => rule.vehicleType).toList();
  }
}