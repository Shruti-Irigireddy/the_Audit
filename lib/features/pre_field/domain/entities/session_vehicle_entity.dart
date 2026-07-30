import 'package:the_audit/features/vehicle/domain/entities/vehicle_entity.dart';

class SessionVehicleEntity {
  final String id;
  final String sessionId;
  final String vehicleId;
  final String? objective;
  final DateTime createdAt;

  const SessionVehicleEntity({
    required this.id,
    required this.sessionId,
    required this.vehicleId,
    required this.createdAt,
    this.objective,
  });
}

class SessionVehicleWithVehicleEntity {
  final SessionVehicleEntity sessionVehicle;
  final VehicleEntity vehicle;

  const SessionVehicleWithVehicleEntity({
    required this.sessionVehicle,
    required this.vehicle,
  });
}
