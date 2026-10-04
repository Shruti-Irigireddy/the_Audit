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
  static const retired = 'RETIRED';
}

class DbSyncOperations {
  static const insert = 'INSERT';
  static const update = 'UPDATE';
  static const delete = 'DELETE';
}
