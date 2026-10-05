import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';

import 'post_flight_note_entity.dart';

class PostFlightSetupEntity {
  final SortieEntity sortie;
  final PostFlightNoteEntity? postFlightNote;
  final List<SortieBatteryWithBatteryEntity> batteries;
  final List<SortiePayloadWithPayloadEntity> payloads;

  const PostFlightSetupEntity ({
    required this.sortie,
    this.postFlightNote,
    required this.batteries,
    required this.payloads,
  });
}
