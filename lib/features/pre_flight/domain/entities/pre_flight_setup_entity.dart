import 'package:the_audit/features/pre_field/domain/entities/session_vehicle_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/vehicle_entity.dart';

import 'checklist_override_entity.dart';
import 'checklist_response_entity.dart';
import 'sortie_battery_entity.dart';
import 'sortie_entity.dart';
import 'sortie_payload_entity.dart';
import 'sortie_user_entity.dart';

class PreFlightSetupEntity {
  final SortieEntity sortie;
  final SessionVehicleEntity sessionVehicle;
  final VehicleEntity vehicle;
  final List<ChecklistItemEntity> checklistItems;
  final List<SortiePayloadWithPayloadEntity> payloads;
  final List<SortieBatteryWithBatteryEntity> batteries;
  final List<SortieUserWithUserEntity> crew;
  final List<ChecklistResponseWithItemEntity> responses;
  final List<ChecklistOverrideEntity> overrides;

  const PreFlightSetupEntity({
    required this.sortie,
    required this.sessionVehicle,
    required this.vehicle,
    required this.checklistItems,
    required this.payloads,
    required this.batteries,
    required this.crew,
    required this.responses,
    required this.overrides,
  });
}
