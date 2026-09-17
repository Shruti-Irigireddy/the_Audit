import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/shared_dtos.dart';

class BatteryEndStateDraft {
  final String batteryId;
  final double? voltageEnd;
  final int? percentEnd;

  const BatteryEndStateDraft({
    required this.batteryId,
    this.voltageEnd,
    this.percentEnd,
  });
}

class PostFlightSetupData {
  final Sorty sortie;
  final PostFlightNote? postFlightNote;
  final List<SortieBatteryWithBattery> batteries;
  final List<SortiePayloadWithPayload> payloads;

  const PostFlightSetupData({
    required this.sortie,
    required this.postFlightNote,
    required this.batteries,
    required this.payloads,
  });
}
