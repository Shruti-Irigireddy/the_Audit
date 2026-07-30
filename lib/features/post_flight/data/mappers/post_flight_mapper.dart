import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/dtos/post_flight_dtos.dart'as db_post_flight;

import 'package:the_audit/features/post_flight/domain/entities/post_flight_note_entity.dart';
import 'package:the_audit/features/post_flight/domain/entities/post_flight_setup_entity.dart';

import 'package:the_audit/features/pre_flight/data/mappers/pre_flight_mapper.dart';

extension PostFlightNotesDbMapper on PostFlightNote {
  PostFlightNoteEntity toEntity(){
    return PostFlightNoteEntity(
      id: id,
      flightId: flightId,
      objectiveNotes: objectiveNotes,
      objectiveResult: objectiveResult,
      missionRating: missionRating,
      issueEncountered: issuesEncountered,
      logStoredAt: logStoredAt,
      logLocation: logLocation,
      logNotes: logNotes,
      flightDurationSeconds: flightDurationSeconds,
      followUpRequired: followUpRequired,
      followUpNotes: followUpNotes,
      followUpAssignedTo: followUpAssignedTo,
      followUpDueDate: followUpDueDate,
      followUpStatus: followUpStatus,
      notes: notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    );
  }
}

extension PostFlightSetupDataDbMapper on db_post_flight.PostFlightSetupData {
  PostFlightSetupEntity toEntity() {
    return PostFlightSetupEntity(
      sortie: sortie.toEntity(),
      postFlightNote: postFlightNote?.toEntity(),
      batteries: batteries.map((item) => item.toEntity()).toList(),
      payloads: payloads.map((item) => item.toEntity()).toList(),
    );  
  }
}
