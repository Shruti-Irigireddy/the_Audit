/// Reserved users that are not real people.
class DbUsers {
  /// Author of data the app creates itself (e.g. the default fleet). Never
  /// shown in people pickers.
  static const systemUserId = 'system';
}

class DbEntityTypes {
  static const auditEvent = 'AUDIT_EVENT';
  static const battery = 'BATTERY';
  static const checklistOverride = 'CHECKLIST_OVERRIDE';
  static const checklistResponse = 'CHECKLIST_RESPONSE';
  static const exportRecord = 'EXPORT_RECORD';
  static const fieldSession = 'FIELD_SESSION';
  static const payload = 'PAYLOAD';
  static const postFlightNote = 'POST_FLIGHT_NOTE';
  static const sessionBattery = 'SESSION_BATTERY';
  static const sessionEquipmentCheck = 'SESSION_EQUIPMENT_CHECK';
  static const sessionUser = 'SESSION_USER';
  static const sessionVehicle = 'SESSION_VEHICLE';
  static const sortie = 'SORTIE';
  static const sortieBattery = 'SORTIE_BATTERY';
  static const sortiePayload = 'SORTIE_PAYLOAD';
  static const sortieUser = 'SORTIE_USER';
  static const vehicle = 'VEHICLE';
}

class DbActions {
  static const abort = 'ABORT';
  static const close = 'CLOSE';
  static const create = 'CREATE';
  static const delete = 'DELETE';
  static const insert = 'INSERT';
  static const replace = 'REPLACE';
  static const retire = 'RETIRE';
  static const update = 'UPDATE';
}

class DbStatuses {
  static const aborted = 'ABORTED';
  static const active = 'ACTIVE';
  static const closed = 'CLOSED';
  static const completed = 'COMPLETED';
  static const failed = 'FAILED';
  static const flown = 'FLOWN';
  static const inProgress = 'IN_PROGRESS';
  static const maintenance = 'MAINTENANCE';
  static const pending = 'PENDING';
  static const preflight = 'PREFLIGHT';
  /// Go saved: the sortie waits for its post-flight notes.
  static const ready = 'READY';
  static const retired = 'RETIRED';
}

class DbSyncOperations {
  static const insert = 'INSERT';
  static const update = 'UPDATE';
  static const delete = 'DELETE';
}

/// A sortie's life: PREFLIGHT -> READY (Go saved) -> CLOSED (post-flight),
/// or ABORTED (No-Go). IN_PROGRESS and FLOWN come from the earlier
/// take-off / landing flow and stay valid for older records.
class FlightStatus {
  static const preflight = 'PREFLIGHT';
  static const ready = 'READY';
  static const inProgress = 'IN_PROGRESS';
  static const flown = 'FLOWN';
  static const aborted = 'ABORTED';
  static const closed = 'CLOSED';

  static const all = [preflight, ready, inProgress, flown, aborted, closed];

  /// Finished: the session can close once every sortie is one of these.
  static const finished = [closed, aborted];
}

class SessionStatus {
  static const planned = 'PLANNED';
  static const inProgress = 'IN_PROGRESS';
  static const closed = 'CLOSED';

  static const all = [planned, inProgress, closed];
}

class FinalDecision {
  static const go = 'GO';
  static const noGo = 'NO_GO';

  static const all = [go, noGo];
}

class FollowUpStatus {
  static const pending = 'PENDING';
  static const inProgress = 'IN_PROGRESS';
  static const done = 'DONE';
  static const cancelled = 'CANCELLED';

  static const all = [pending, inProgress, done, cancelled];
}
