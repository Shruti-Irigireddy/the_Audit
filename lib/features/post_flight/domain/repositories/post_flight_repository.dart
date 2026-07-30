import 'package:the_audit/features/post_flight/domain/dtos/post_flight_dtos.dart';
import 'package:the_audit/features/post_flight/domain/entities/post_flight_note_entity.dart';
import 'package:the_audit/features/post_flight/domain/entities/post_flight_setup_entity.dart';

import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';

abstract class PostFlightRepository {
  Future<PostFlightSetupEntity> getPostFlightSetup(String flightId);

  Future<PostFlightNoteEntity> getPostFlightNoteForFlight(String flightId);

  Future<List<SortieEntity>> getPostFlightPendingSorties({
    String sessionId,
    int limit
    });

  Future<List<SortieEntity>> getClosedSorties({
    String sessionId,
    int limit
  });

  Future<List<SortieBatteryEntity>> getSortieBatteries (String flightId);

  Future<List<SortiePayloadEntity>> getSortiePayloads (String flightId);

  Future<void> savePostFlightNote({
    String? id,
    required String flightId,
    required String objectiveResult,
    String? objectiveNotes,
    String? missionRating,
    String? issueEncountered,
    String? logStoredAt,
    String? logLocation,
    String? logNotes,
    String? flightDurationSeconds,
    bool followUpRequired,
    String? followUpNotes,
    String? followUpAssignedTo,
    DateTime? followUpDueDate,
    String? followUpStatus,
    String? notes,
    required String createdBy,
  });

  Future<void> updateObjectiveResult({
    required String flightId,
    required String objectiveResult,
    String? objectiveNotes,
    required String performedBy,
  });
  Future<void> updateMissionRating({
    required String flightId,
    String missionRating,
    required String performedBy
  });
  Future<void> updateLogDetails({
    required String flightId,
    String? logStoredAt,
    String? logLocation,
    String? logNotes,
    required String performedBy,
  });

  Future<void> updateIssuesEncountered({
    required String flightId,
    String? issueEncountered,
    String? notes,
    required String performedBy,
  });

  Future<void> updateFollowUpStatus({
    required String flightId,
    required String followUpStatus,
    bool? followUpRequired,
    String? followUpNotes,
    String? followUpAssignedTo,
    DateTime? followUpDueDate,
    required String performedBy,
  });

  Future<void> saveBatteryEndState({
    required String flightId,
    required String batteryId,
    double? voltageEnd,
    int? percentEnd,
    required String performedBy,
  });

  Future<void> saveBatteryEndStates ({
    required String flightId,
    required List<BatteryEndStateDraft> batteries,
    required String performedBy,
  });

  Future<int> countBatteriesWithoutEndState(String flightId);

  Future<bool> allBatteriesHaveEndState(String flightId);

  Future<List<String>> validatePostFlightCompletion(String flightId);

  Future<void> closeSortie({
    required String flightId,
    required String closedBy
  });
}

