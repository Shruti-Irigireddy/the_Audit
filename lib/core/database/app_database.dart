import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:the_audit/core/database/seed/checklists.dart';
import 'package:the_audit/core/database/seed/default_equipment.dart';
import 'package:the_audit/core/database/seed/default_fleet.dart';
import 'package:the_audit/core/database/seed/default_payloads.dart';
import 'package:the_audit/core/database/dao_write_helpers.dart';
import 'package:the_audit/core/database/database_constants.dart';
import 'package:the_audit/core/database/sql_log_interceptor.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

import 'daos/vehicle/vehicle_dao.dart';
import 'daos/payload/payload_dao.dart';
import 'daos/battery/battery_dao.dart';
import 'daos/pre_field/pre_field_dao.dart';
import 'daos/pre_flight/pre_flight_dao.dart';
import 'daos/post_flight/post_flight_dao.dart';
import 'daos/records/record_dao.dart';
import 'daos/sync/sync_dao.dart';
import 'daos/export/export_dao.dart';
import 'daos/equipment/equipment_dao.dart';

part 'app_database.g.dart';

class Users extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get name => text()();
  TextColumn get role => text()(); // ADMIN, PIC, VO, crew
  BoolColumn get defaultPic => boolean().withDefault(const Constant(false))();
  TextColumn get email => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Vehicles extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get name => text()();
  TextColumn get type => text()(); // MULTIROTOR, FIXED_WING, VTOL
  TextColumn get frameMake => text().nullable()();
  TextColumn get frameModel => text().nullable()();
  // Total motors; a VTOL with 4 lift + 1 pusher is stored as 5.
  IntColumn get motorCount => integer().nullable()();
  TextColumn get frameStyle => text().nullable()();
  TextColumn get firmwareTarget => text().nullable()();
  TextColumn get defaultFailSafeProfile => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('ACTIVE'),
  )(); // ACTIVE, MAINTENANCE, RETIRED
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// @TableIndex.sql(
//   'CREATE UNIQUE INDEX unique_active_vehicle_template '
//   'ON vehicle_check_list_template (vehicle_id) '
//   'WHERE is_active = 1',
// )

class VehicleChecklistTemplates extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get vehicleId => text().references(Vehicles, #id)();
  IntColumn get version => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdBy => text().references(Users, #id).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deactivatedAt => dateTime().nullable()();
  TextColumn get deactivatedBy => text().references(Users, #id).nullable()();
  TextColumn get deactivationReason => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {vehicleId, version},
  ];
}

class ChecklistItems extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get templateId =>
      text().references(VehicleChecklistTemplates, #id)();
  TextColumn get section => text()(); // Airframe, Comms, Ready to Arm
  TextColumn get label => text()();
  TextColumn get responseType =>
      text()(); // PASS/FAIL/NA, VALUE, CHECKBOX, TEXT
  BoolColumn get isRequired => boolean().withDefault(const Constant(true))();
  BoolColumn get blocksArming => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {templateId, sortOrder},
  ];
}

class FieldSessions extends Table {
  TextColumn get sessionId => text()();

  @override
  Set<Column> get primaryKey => {sessionId};

  DateTimeColumn get date => dateTime()();
  TextColumn get locationName => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get missionType => text()();
  // Team members - list of userIds (multi-enum)
  // Vehicle taken - list of vehicleIds (multi-enum)
  // Pre-flight checklist - embedded table with checklist items (multi-enum)
  // Flights - list of flightIds (multi-enum)
  TextColumn get sessionStatus =>
      text().check(sessionStatus.isIn(SessionStatus.all))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get closedBy => text().references(Users, #id).nullable()();
}

// Team members - list of userIds (multi-enum)
@TableIndex(name: 'idx_session_users_session_id', columns: {#sessionId})
class SessionUsers extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get role => text()(); // PIC, VO, Crew
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Vehicle taken - list of vehicleIds (multi-enum)
@TableIndex(name: 'idx_session_vehicles_session_id', columns: {#sessionId})
class SessionVehicles extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  TextColumn get objective => text().nullable()();
  // How many units of this vehicle are taken to the field.
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, vehicleId},
  ];
}

class SessionVehiclePayload extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get sessionVehicleId => text().references(SessionVehicles, #id)();
  TextColumn get payloadId => text().references(Payloads, #payloadId)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionVehicleId, payloadId},
  ];
}

class Batteries extends Table {
  TextColumn get batteryId => text()();

  @override
  Set<Column> get primaryKey => {batteryId};

  TextColumn get config => text()(); // 4S, 6S, 8S, 12S
  IntColumn get capacity => integer().nullable()(); // mAh
  RealColumn get voltage => real().nullable()(); // V
  IntColumn get cycleCount =>
      integer().withDefault(const Constant(0)).nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('ACTIVE'))(); // ACTIVE, RETIRED
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_session_batteries_session_id', columns: {#sessionId})
class SessionBatteries extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
  TextColumn get batteryId => text().references(Batteries, #batteryId)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, batteryId},
  ];
}

class Payloads extends Table {
  TextColumn get payloadId => text()();

  @override
  Set<Column> get primaryKey => {payloadId};

  TextColumn get name => text()();
  TextColumn get category =>
      text()(); // RGB/ Thermal, LiDAR, Multispectral, Hyperspectral, Mapping, Other
  TextColumn get storageType => text().nullable()();
  TextColumn get storageCapacity => text().nullable()(); // SD/ internal
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  // Compatible vehicle Types - list of vehicleIds (multi-enum)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Compatible vehicle Types - list of vehicleIds (multi-enum)

@TableIndex(
  name: 'idx_payload_vehicle_compatibility_payload_id',
  columns: {#payloadId},
)
@TableIndex(
  name: 'idx_payload_vehicle_compatibility_vehicle_type',
  columns: {#vehicleType},
)
class PayloadVehicleCompatibility extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get payloadId => text().references(Payloads, #payloadId)();
  TextColumn get vehicleType => text()(); // MULTIROTOR, FIXED_WING, VTOL
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {payloadId, vehicleType},
  ];
}

/// Specific vehicles a payload is limited to. When a payload has rows here,
/// only these vehicles may carry it; otherwise its vehicle-type rules apply.
class PayloadVehicles extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get payloadId => text().references(Payloads, #payloadId)();
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {payloadId, vehicleId},
  ];
}

class EquipmentLists extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get name =>
      text()(); // Batteries, Charger, RC, GCS, Telemetry Radio, Tools, Props, Laptop
  TextColumn get category =>
      text()(); // Batteries, Charger, RC, GCS, Telemetry Radio, Tools, Props, Laptop
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(
  name: 'idx_session_equipment_checks_session_id',
  columns: {#sessionId},
)
class SessionEquipmentChecks extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
  TextColumn get equipmentId => text().references(EquipmentLists, #id)();
  BoolColumn get isPacked => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get checkedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get checkedBy => text().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, equipmentId},
  ];
}

/// Standard "equipment to bring" lists: one per vehicle, plus the Tools list
/// (vehicleId null) that every session takes.
@TableIndex(
  name: 'idx_equipment_template_items_vehicle_id',
  columns: {#vehicleId},
)
class EquipmentTemplateItems extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  // Null = the Tools list.
  TextColumn get vehicleId => text().references(Vehicles, #id).nullable()();
  TextColumn get category => text()(); // Airframe, Subsystems, ..., Tools
  TextColumn get name => text()();
  IntColumn get quantity => integer().nullable()();
  IntColumn get spares => integer().nullable()();
  IntColumn get categoryOrder => integer()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// What a session takes: a snapshot of the lists at save time, with packing.
@TableIndex(
  name: 'idx_session_equipment_items_session_id',
  columns: {#sessionId},
)
class SessionEquipmentItems extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
  // Null = Tools.
  TextColumn get sessionVehicleId =>
      text().references(SessionVehicles, #id).nullable()();
  TextColumn get templateItemId =>
      text().references(EquipmentTemplateItems, #id).nullable()();
  TextColumn get category => text()();
  TextColumn get name => text()();
  IntColumn get quantity => integer().nullable()();
  IntColumn get spares => integer().nullable()();
  BoolColumn get isPacked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get packedAt => dateTime().nullable()();
  TextColumn get packedBy => text().references(Users, #id).nullable()();
  IntColumn get categoryOrder => integer()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_sorties_session_id', columns: {#sessionId})
@TableIndex(name: 'idx_sorties_flight_status', columns: {#flightStatus})
class Sorties extends Table {
  TextColumn get flightId => text()();

  @override
  Set<Column> get primaryKey => {flightId};

  TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
  IntColumn get sequenceNo =>
      integer()(); // Sequence number of the flight in the session - more than one flight can be conducted in a single session (Auto-incremented within a session)
  TextColumn get sessionVehicleId => text().references(SessionVehicles, #id)();
  // Payloads - list of payloadIds (multi-enum)
  // Batteries - list of batteryIds (multi-enum)
  TextColumn get picUserId => text().references(Users, #id)();
  // VO (users) - list of userIds (multi-enum)
  TextColumn get objective => text().nullable()();
  // Pre-flight checklist - embedded table with checklist items (multi-enum)
  TextColumn get checklistTemplateId =>
      text().references(VehicleChecklistTemplates, #id)();
  IntColumn get checklistTemplateVersion => integer()();
  DateTimeColumn get takeoffAt => dateTime().nullable()();
  DateTimeColumn get landingAt => dateTime().nullable()();
  // Post-flight notes - embedded table with checklist items (multi-enum)
  TextColumn get flightStatus => text()
      .withDefault(const Constant(FlightStatus.preflight))
      .check(flightStatus.isIn(FlightStatus.all))();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get closedBy => text().references(Users, #id).nullable()();
  TextColumn get finalDecision =>
      text().nullable().check(finalDecision.isIn(FinalDecision.all))();
  TextColumn get decisionReason => text().nullable()();
  TextColumn get decisionBy => text().references(Users, #id).nullable()();
  DateTimeColumn get decisionAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, sequenceNo},
  ];
}

@TableIndex(name: 'idx_sortie_payloads_flight_id', columns: {#flightId})
class SortiePayloads extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get flightId => text().references(Sorties, #flightId)();
  TextColumn get payloadId => text().references(Payloads, #payloadId)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {flightId, payloadId},
  ];
}

@TableIndex(name: 'idx_sortie_batteries_flight_id', columns: {#flightId})
class SortieBatteries extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get flightId => text().references(Sorties, #flightId)();
  TextColumn get batteryId => text().references(Batteries, #batteryId)();
  RealColumn get voltageStart => real().nullable()();
  RealColumn get voltageEnd => real().nullable()();
  IntColumn get percentStart => integer().nullable()();
  IntColumn get percentEnd => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {flightId, batteryId},
  ];
}

@TableIndex(name: 'idx_sortie_users_flight_id', columns: {#flightId})
class SortieUsers extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get flightId => text().references(Sorties, #flightId)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get role => text()(); // PIC, VO, Crew
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {flightId, userId, role},
  ];
}

@TableIndex(name: 'idx_checklist_responses_flight_id', columns: {#flightId})
class ChecklistResponses extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get flightId => text().references(Sorties, #flightId)();
  TextColumn get itemId => text().references(ChecklistItems, #id)();
  TextColumn get response => text()(); // PASS/FAIL/NA, VALUE, CHECKBOX, TEXT
  TextColumn get valueText => text().nullable()();
  RealColumn get valueNumber => real().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().references(Users, #id)();
  DateTimeColumn get responseAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {flightId, itemId},
  ];
}

@TableIndex(name: 'idx_post_flight_notes_flight_id', columns: {#flightId})
class PostFlightNotes extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get flightId => text().references(Sorties, #flightId).unique()();
  TextColumn get objectiveResult => text()(); // Yes/No/Partial
  TextColumn get objectiveNotes => text().nullable()();
  TextColumn get missionRating =>
      text().nullable()(); // Excellent, Good, Average, Poor
  TextColumn get issuesEncountered => text().nullable()();
  TextColumn get logStoredAt => text().nullable()(); // Local, Cloud, Both
  TextColumn get logLocation => text().nullable()(); // Path or URL
  TextColumn get logNotes => text().nullable()();
  IntColumn get flightDurationSeconds => integer().nullable()();
  // Landed battery state (FR-POST-02); batteries aren't picked per sortie.
  RealColumn get landedBatteryVoltage => real().nullable()();
  IntColumn get landedBatteryPercent => integer().nullable()();
  BoolColumn get followUpRequired =>
      boolean().withDefault(const Constant(false))();
  TextColumn get followUpNotes => text().nullable()();
  TextColumn get followUpAssignedTo =>
      text().references(Users, #id).nullable()();
  DateTimeColumn get followUpDueDate => dateTime().nullable()();
  TextColumn get followUpStatus => text()
      .withDefault(const Constant(FollowUpStatus.pending))
      .check(followUpStatus.isIn(FollowUpStatus.all))();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_checklist_overrides_flight_id', columns: {#flightId})
class ChecklistOverrides extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get flightId => text().references(Sorties, #flightId)();
  TextColumn get itemId => text().references(ChecklistItems, #id)();
  TextColumn get checklistResponseId =>
      text().references(ChecklistResponses, #id).nullable()();
  TextColumn get overrideReason => text()();
  TextColumn get overriddenBy => text().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_audit_events_entity', columns: {#entityType, #entityId})
@TableIndex(name: 'idx_audit_events_session_id', columns: {#sessionId})
@TableIndex(name: 'idx_audit_events_flight_id', columns: {#flightId})
class AuditEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType =>
      text()(); // User, Vehicle, Flight, Battery, Payload
  TextColumn get entityId =>
      text()(); // userId, vehicleId, flightId, batteryId, payloadId
  TextColumn get action => text()(); // CREATE, UPDATE, DELETE
  TextColumn get description =>
      text().nullable()(); // JSON or string representation of the changes made
  TextColumn get performedBy => text().references(Users, #id)();
  DateTimeColumn get performedAt =>
      dateTime().withDefault(currentDateAndTime)();
  // The session / sortie an event belongs to, so a record's audit trail is
  // one indexed query. Null for fleet-wide events (vehicles, payloads...).
  TextColumn get sessionId => text().nullable()();
  TextColumn get flightId => text().nullable()();
}

@TableIndex(
  name: 'idx_record_amendments_entity',
  columns: {#entityType, #entityId},
)
class RecordAmendments extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get entityType =>
      text()(); // SORTIE, POST_FLIGHT_NOTES, CHECKLIST_RESPONSE
  TextColumn get entityId => text()();
  TextColumn get amendmentText => text()();
  TextColumn get createdBy => text().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

//ObjectiveTags
//SessionVehicleObjectiveTags

@TableIndex(name: 'idx_export_records_status', columns: {#exportStatus})
@TableIndex(
  name: 'idx_export_records_entity',
  columns: {#entityType, #entityId},
)
class ExportRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType =>
      text()(); // User, Vehicle, Flight, Battery, Payload
  TextColumn get entityId =>
      text()(); // userId, vehicleId, flightId, batteryId, payloadId
  TextColumn get exportFormat => text()(); // CSV, JSON, PDF
  TextColumn get exportLocation => text().nullable()(); // Path or URL
  TextColumn get exportStatus => text().withDefault(
    const Constant('PENDING'),
  )(); // PENDING, IN_PROGRESS, COMPLETED, FAILED
  TextColumn get generatedBy => text().references(Users, #id)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get generatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_sync_queue_status', columns: {#syncStatus})
@TableIndex(name: 'idx_sync_queue_entity', columns: {#entityType, #entityId})
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
  TextColumn get syncStatus => text().withDefault(
    const Constant('PENDING'),
  )(); // PENDING, IN_PROGRESS, COMPLETED, FAILED
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class LocalAuthSessions extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get userId => text().references(Users, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get loginAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get logoutAt => dateTime().nullable()();
}

@DriftDatabase(
  tables: [
    Users,
    Vehicles,
    VehicleChecklistTemplates,
    ChecklistItems,
    FieldSessions,
    SessionUsers,
    SessionVehicles,
    SessionBatteries,
    Payloads,
    Batteries,
    Sorties,
    SortiePayloads,
    SortieBatteries,
    SortieUsers,
    ChecklistResponses,
    SyncQueue,
    PostFlightNotes,
    ChecklistOverrides,
    AuditEvents,
    ExportRecords,
    SessionVehiclePayload,
    PayloadVehicleCompatibility,
    PayloadVehicles,
    SessionEquipmentChecks,
    EquipmentLists,
    EquipmentTemplateItems,
    SessionEquipmentItems,
    RecordAmendments,
    LocalAuthSessions,
  ],
  daos: [
    VehicleDao,
    PayloadDao,
    BatteryDao,
    PreFieldDao,
    PreFlightDao,
    PostFlightDao,
    ExportDao,
    RecordDao,
    SyncDao,
    EquipmentDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Namespace for the ids of data the app creates itself.
  static const _seedNamespace = '6f1c2a54-3b9e-5d7a-8c41-2e9f0b7d5a13';

  /// The same id on every install for the same default record (the
  /// "Cerana" vehicle, its v1 checklist, ...), so records from several
  /// phones can be merged once sync exists. [key] names the record.
  static String _seedId(String key) => const Uuid().v5(_seedNamespace, key);

  static const _log = AppLogger('AppDatabase');

  AppDatabase() : super(_openConnection());

  /// For tests: runs against the given executor (e.g. an in-memory DB).
  AppDatabase.forTesting(super.executor);

  /// With app logging on, every SQL statement is logged (SqlLogInterceptor).
  static QueryExecutor _openConnection() {
    final executor = driftDatabase(name: 'the_audit.db');
    return AppLogger.enabled
        ? executor.interceptWith(SqlLogInterceptor())
        : executor;
  }

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _insertDefaultFleet();
        await _insertDefaultPayloads();
        await _insertDefaultEquipmentLists();
        await _insertDefaultPayloadVehicleLimits();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(payloads, payloads.status);
          await m.addColumn(checklistResponses, checklistResponses.responseAt);
        }
        if (from < 3) {
          await m.addColumn(sessionVehicles, sessionVehicles.quantity);
          await _insertDefaultFleet();
        }
        if (from < 4) {
          // Data only: the team's standard payloads.
          await _insertDefaultPayloads();
        }
        if (from < 5) {
          await m.createTable(equipmentTemplateItems);
          await m.createTable(sessionEquipmentItems);
          await _insertDefaultEquipmentLists();
        }
        if (from < 6) {
          await m.createTable(payloadVehicles);
          await _insertDefaultPayloadVehicleLimits();
        }
        if (from < 7) {
          // Data only: give every vehicle the common pre-flight checklist.
          await _upgradeToCommonPreflight();
        }
        if (from < 8) {
          // Data only: add each vehicle's type-specific pre-flight items.
          await _upgradeToTypePreflight();
        }
        if (from < 9) {
          // Data only: add the Ready-to-Arm gate as every checklist's end.
          await _appendItemsAsNewChecklistVersion(
            itemsFor: (_) => readyToArmGateChecklist,
            reason: 'Ready-to-Arm gate added',
          );
        }
        if (from < 10) {
          // Data only: the battery start voltage is a number (decimals
          // allowed). Same question, so existing items are updated in place.
          await customStatement(
            "UPDATE checklist_items SET response_type = 'NUMBER' "
            "WHERE label = 'Battery installed & secured; start voltage logged' "
            "AND response_type = 'VALUE'",
          );
        }
        if (from < 11) {
          // Data only: a saved Go now makes a sortie READY for post-flight
          // (take-off and landing are no longer recorded).
          await customStatement(
            "UPDATE sorties SET flight_status = 'READY' "
            "WHERE flight_status = 'PREFLIGHT' AND final_decision = 'GO'",
          );
        }
        if (from < 12) {
          await m.addColumn(postFlightNotes, postFlightNotes.landedBatteryVoltage);
          await m.addColumn(postFlightNotes, postFlightNotes.landedBatteryPercent);
        }
        if (from < 13) {
          // Statuses become fixed lists (CHECK constraints). Map leftovers
          // first: the old landing flow wrote LANDED for a flown sortie.
          await customStatement(
            "UPDATE sorties SET flight_status = 'FLOWN' "
            "WHERE flight_status = 'LANDED'",
          );
          // SQLite can't add a CHECK to a table: rebuild these three.
          await m.alterTable(TableMigration(sorties));
          await m.alterTable(TableMigration(fieldSessions));
          await m.alterTable(TableMigration(postFlightNotes));

          await m.addColumn(auditEvents, auditEvents.sessionId);
          await m.addColumn(auditEvents, auditEvents.flightId);
          await m.createIndex(idxAuditEventsSessionId);
          await m.createIndex(idxAuditEventsFlightId);
          await _backfillAuditScope();
        }
        if (from < 14) {
          // Data only: default equipment lists added since (Striver's).
          // Lists that already exist are left as they are.
          await _insertDefaultEquipmentLists();
        }
      },
      // SQLite ignores `references(...)` unless this is on for each
      // connection. It runs after migrations, so seeding isn't affected.
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        if (AppLogger.enabled) await _logForeignKeyProblems();
      },
    );
  }

  /// Tags existing audit events with their session / sortie (v13), using
  /// the same lookups as new events.
  Future<void> _backfillAuditScope() async {
    for (final MapEntry(key: type, value: sql) in auditFlightScopeSql.entries) {
      await customStatement(
        'UPDATE audit_events SET flight_id = '
        '(${sql.replaceFirst('?', 'audit_events.entity_id')}) '
        "WHERE entity_type = '$type' AND flight_id IS NULL",
      );
    }
    // Older answers / batteries were audited as "flightId:itemId".
    await customStatement(
      'UPDATE audit_events SET flight_id = '
      "substr(entity_id, 1, instr(entity_id, ':') - 1) "
      "WHERE entity_type IN ('CHECKLIST_RESPONSE', 'SORTIE_BATTERY') "
      "AND flight_id IS NULL AND instr(entity_id, ':') > 0",
    );
    await customStatement(
      'UPDATE audit_events SET session_id = '
      '(SELECT session_id FROM sorties '
      'WHERE sorties.flight_id = audit_events.flight_id) '
      'WHERE flight_id IS NOT NULL AND session_id IS NULL',
    );
    for (final MapEntry(key: type, value: sql)
        in auditSessionScopeSql.entries) {
      await customStatement(
        'UPDATE audit_events SET session_id = '
        '(${sql.replaceFirst('?', 'audit_events.entity_id')}) '
        "WHERE entity_type = '$type' AND session_id IS NULL",
      );
    }
  }

  /// Debug logs only: rows written before foreign keys were enforced that
  /// point at a missing parent. They stay readable; only new writes are
  /// checked.
  Future<void> _logForeignKeyProblems() async {
    final rows = await customSelect('PRAGMA foreign_key_check').get();
    if (rows.isEmpty) return;
    final byTable = <String, int>{};
    for (final row in rows) {
      final table = row.data['table'] as String? ?? '?';
      byTable[table] = (byTable[table] ?? 0) + 1;
    }
    _log.w('rows with a missing parent (before foreign keys): $byTable');
  }

  /// Adds the SRS §5.1 common pre-flight items to [templateId], from
  /// [startOrder]. Returns the next free sort order.
  Future<int> _insertCommonPreflightItems(
    String templateId,
    Uuid uuid, {
    int startOrder = 0,
  }) => _insertPreflightItems(
    templateId,
    uuid,
    commonPreflightChecklist,
    startOrder: startOrder,
  );

  /// Adds [items] to [templateId] from [startOrder]; returns the next free
  /// sort order.
  Future<int> _insertPreflightItems(
    String templateId,
    Uuid uuid,
    List<PreflightItem> items, {
    int startOrder = 0,
  }) async {
    var order = startOrder;
    for (final item in items) {
      await into(checklistItems).insert(
        ChecklistItemsCompanion.insert(
          id: _seedId('item:$templateId:${item.section}:${item.label}'),
          templateId: templateId,
          section: item.section,
          label: item.label,
          responseType: item.responseType,
          blocksArming: Value(item.blocksArming),
          sortOrder: order++,
        ),
      );
    }
    return order;
  }

  /// For each vehicle whose active checklist lacks the common pre-flight
  /// items: create the next template version (common items, then the
  /// vehicle's own items except the old "Visual inspection complete"
  /// placeholder) and retire the old version. Flights keep the version they
  /// were run against (FR-ADM-03).
  Future<void> _upgradeToCommonPreflight() async {
    const uuid = Uuid();
    await _ensureSystemUser();
    final marker = commonPreflightChecklist[7].label; // 'GCS connected'

    var upgraded = 0;
    for (final vehicle in await select(vehicles).get()) {
      final active =
          await (select(vehicleChecklistTemplates)
                ..where(
                  (t) =>
                      t.vehicleId.equals(vehicle.id) & t.isActive.equals(true),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.version)])
                ..limit(1))
              .getSingleOrNull();
      final oldItems = active == null
          ? <ChecklistItem>[]
          : await (select(checklistItems)
                  ..where((i) => i.templateId.equals(active.id))
                  ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
                .get();
      if (oldItems.any((item) => item.label == marker)) continue;

      final versions = await (select(
        vehicleChecklistTemplates,
      )..where((t) => t.vehicleId.equals(vehicle.id))).get();
      final nextVersion =
          versions.fold<int>(0, (max, t) => t.version > max ? t.version : max) +
          1;
      final templateId = _seedId('template:${vehicle.id}:v$nextVersion');
      final now = DateTime.now();

      if (active != null) {
        await (update(
          vehicleChecklistTemplates,
        )..where((t) => t.id.equals(active.id))).write(
          VehicleChecklistTemplatesCompanion(
            isActive: const Value(false),
            deactivatedAt: Value(now),
            deactivatedBy: const Value(DbUsers.systemUserId),
            deactivationReason: const Value(
              'Replaced by the common pre-flight checklist',
            ),
            updatedAt: Value(now),
          ),
        );
      }
      await into(vehicleChecklistTemplates).insert(
        VehicleChecklistTemplatesCompanion.insert(
          id: templateId,
          vehicleId: vehicle.id,
          version: nextVersion,
          createdBy: const Value(DbUsers.systemUserId),
        ),
      );
      var order = await _insertCommonPreflightItems(templateId, uuid);
      for (final item in oldItems) {
        if (item.label == 'Visual inspection complete') continue;
        await into(checklistItems).insert(
          ChecklistItemsCompanion.insert(
            id: _seedId('item:$templateId:${item.section}:${item.label}'),
            templateId: templateId,
            section: item.section,
            label: item.label,
            responseType: item.responseType,
            isRequired: Value(item.isRequired),
            blocksArming: Value(item.blocksArming),
            sortOrder: order++,
          ),
        );
      }
      await into(auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: DbEntityTypes.vehicle,
          entityId: vehicle.id,
          action: DbActions.update,
          description: Value(
            'Checklist v$nextVersion: common pre-flight items added',
          ),
          performedBy: DbUsers.systemUserId,
        ),
      );
      upgraded++;
    }
    const AppLogger(
      'AppDatabase',
    ).i('common pre-flight checklist: $upgraded vehicles upgraded');
  }

  /// For each vehicle whose active checklist lacks its type's items (SRS
  /// §5.2–5.4): create the next template version with the current items
  /// plus the type items, and retire the old version. Flights keep the
  /// version they were run against.
  Future<void> _upgradeToTypePreflight() async {
    const uuid = Uuid();
    await _ensureSystemUser();

    var upgraded = 0;
    for (final vehicle in await select(vehicles).get()) {
      final typeItems = typePreflightChecklist(vehicle.type);
      if (typeItems.isEmpty) continue;

      final active =
          await (select(vehicleChecklistTemplates)
                ..where(
                  (t) =>
                      t.vehicleId.equals(vehicle.id) & t.isActive.equals(true),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.version)])
                ..limit(1))
              .getSingleOrNull();
      if (active == null) continue;
      final oldItems =
          await (select(checklistItems)
                ..where((i) => i.templateId.equals(active.id))
                ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
              .get();
      if (oldItems.any((item) => item.label == typeItems.first.label)) continue;

      final versions = await (select(
        vehicleChecklistTemplates,
      )..where((t) => t.vehicleId.equals(vehicle.id))).get();
      final nextVersion =
          versions.fold<int>(0, (max, t) => t.version > max ? t.version : max) +
          1;
      final templateId = _seedId('template:${vehicle.id}:v$nextVersion');
      final now = DateTime.now();

      await (update(
        vehicleChecklistTemplates,
      )..where((t) => t.id.equals(active.id))).write(
        VehicleChecklistTemplatesCompanion(
          isActive: const Value(false),
          deactivatedAt: Value(now),
          deactivatedBy: const Value(DbUsers.systemUserId),
          deactivationReason: const Value('Replaced: type checklist added'),
          updatedAt: Value(now),
        ),
      );
      await into(vehicleChecklistTemplates).insert(
        VehicleChecklistTemplatesCompanion.insert(
          id: templateId,
          vehicleId: vehicle.id,
          version: nextVersion,
          createdBy: const Value(DbUsers.systemUserId),
        ),
      );
      var order = 0;
      for (final item in oldItems) {
        await into(checklistItems).insert(
          ChecklistItemsCompanion.insert(
            id: _seedId('item:$templateId:${item.section}:${item.label}'),
            templateId: templateId,
            section: item.section,
            label: item.label,
            responseType: item.responseType,
            isRequired: Value(item.isRequired),
            blocksArming: Value(item.blocksArming),
            sortOrder: order++,
          ),
        );
      }
      await _insertPreflightItems(
        templateId,
        uuid,
        typeItems,
        startOrder: order,
      );
      await into(auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: DbEntityTypes.vehicle,
          entityId: vehicle.id,
          action: DbActions.update,
          description: Value(
            'Checklist v$nextVersion: ${vehicle.type} items added',
          ),
          performedBy: DbUsers.systemUserId,
        ),
      );
      upgraded++;
    }
    const AppLogger(
      'AppDatabase',
    ).i('type pre-flight checklist: $upgraded vehicles upgraded');
  }

  /// For each vehicle whose active checklist lacks `itemsFor(vehicle)`
  /// (checked by its first label): create the next template version with
  /// the current items plus those items at the end, and retire the old
  /// version. Flights keep the version they were run against.
  Future<void> _appendItemsAsNewChecklistVersion({
    required List<PreflightItem> Function(Vehicle vehicle) itemsFor,
    required String reason,
  }) async {
    const uuid = Uuid();
    await _ensureSystemUser();

    var upgraded = 0;
    for (final vehicle in await select(vehicles).get()) {
      final newItems = itemsFor(vehicle);
      if (newItems.isEmpty) continue;

      final active =
          await (select(vehicleChecklistTemplates)
                ..where(
                  (t) =>
                      t.vehicleId.equals(vehicle.id) & t.isActive.equals(true),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.version)])
                ..limit(1))
              .getSingleOrNull();
      if (active == null) continue;
      final oldItems =
          await (select(checklistItems)
                ..where((i) => i.templateId.equals(active.id))
                ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
              .get();
      if (oldItems.any((item) => item.label == newItems.first.label)) continue;

      final versions = await (select(
        vehicleChecklistTemplates,
      )..where((t) => t.vehicleId.equals(vehicle.id))).get();
      final nextVersion =
          versions.fold<int>(0, (max, t) => t.version > max ? t.version : max) +
          1;
      final templateId = _seedId('template:${vehicle.id}:v$nextVersion');
      final now = DateTime.now();

      await (update(
        vehicleChecklistTemplates,
      )..where((t) => t.id.equals(active.id))).write(
        VehicleChecklistTemplatesCompanion(
          isActive: const Value(false),
          deactivatedAt: Value(now),
          deactivatedBy: const Value(DbUsers.systemUserId),
          deactivationReason: Value('Replaced: $reason'),
          updatedAt: Value(now),
        ),
      );
      await into(vehicleChecklistTemplates).insert(
        VehicleChecklistTemplatesCompanion.insert(
          id: templateId,
          vehicleId: vehicle.id,
          version: nextVersion,
          createdBy: const Value(DbUsers.systemUserId),
        ),
      );
      var order = 0;
      for (final item in oldItems) {
        await into(checklistItems).insert(
          ChecklistItemsCompanion.insert(
            id: _seedId('item:$templateId:${item.section}:${item.label}'),
            templateId: templateId,
            section: item.section,
            label: item.label,
            responseType: item.responseType,
            isRequired: Value(item.isRequired),
            blocksArming: Value(item.blocksArming),
            sortOrder: order++,
          ),
        );
      }
      await _insertPreflightItems(
        templateId,
        uuid,
        newItems,
        startOrder: order,
      );
      await into(auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: DbEntityTypes.vehicle,
          entityId: vehicle.id,
          action: DbActions.update,
          description: Value('Checklist v$nextVersion: $reason'),
          performedBy: DbUsers.systemUserId,
        ),
      );
      upgraded++;
    }
    const AppLogger('AppDatabase').i('$reason: $upgraded vehicles upgraded');
  }

  /// The reserved author of data the app creates itself.
  Future<void> _ensureSystemUser() {
    return into(users).insert(
      UsersCompanion.insert(
        id: DbUsers.systemUserId,
        name: 'System',
        role: 'ADMIN',
        email: 'system@the-audit.local',
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Limits payloads to specific fleet vehicles where `seedPayloads` says
  /// so. Skips a payload that already has limits, and vehicles/payloads
  /// that don't exist.
  Future<void> _insertDefaultPayloadVehicleLimits() async {
    final payloadsByName = {
      for (final payload in await select(payloads).get())
        payload.name.trim().toLowerCase(): payload,
    };
    final vehiclesByName = {
      for (final vehicle in await select(vehicles).get())
        vehicle.name.trim().toLowerCase(): vehicle,
    };

    var added = 0;
    for (final seed in seedPayloads.where((p) => p.onlyVehicles.isNotEmpty)) {
      final payload = payloadsByName[seed.name.toLowerCase()];
      if (payload == null) continue;
      final existing = await (select(
        payloadVehicles,
      )..where((t) => t.payloadId.equals(payload.payloadId))).get();
      if (existing.isNotEmpty) continue;

      for (final vehicleKey in seed.onlyVehicles) {
        final vehicle = vehiclesByName[_seedVehicleName(vehicleKey)];
        if (vehicle == null) continue;
        await into(payloadVehicles).insert(
          PayloadVehiclesCompanion.insert(
            id: _seedId('payload-vehicle:${payload.payloadId}:${vehicle.id}'),
            payloadId: payload.payloadId,
            vehicleId: vehicle.id,
          ),
        );
        added++;
      }
    }
    const AppLogger('AppDatabase').i('payload vehicle limits: $added added');
  }

  /// The (lower-case) name of the fleet vehicle with seed [key].
  static String _seedVehicleName(String key) =>
      seedFleet.firstWhere((v) => v.key == key).name.toLowerCase();

  /// Writes the standard equipment lists (`seed/default_equipment.dart`):
  /// Tools, plus each fleet vehicle's list. A list is skipped if its vehicle
  /// is missing or it already has items. Runs only from migrations.
  Future<void> _insertDefaultEquipmentLists() async {
    await _ensureSystemUser();

    Future<bool> hasItems(String? vehicleId) async {
      final query = select(equipmentTemplateItems)
        ..where(
          (t) => vehicleId == null
              ? t.vehicleId.isNull()
              : t.vehicleId.equals(vehicleId),
        )
        ..limit(1);
      return (await query.get()).isNotEmpty;
    }

    Future<void> writeList(
      String listKey,
      String? vehicleId,
      List<SeedEquipmentCategory> categories,
    ) async {
      for (var c = 0; c < categories.length; c++) {
        final (category, items) = categories[c];
        for (var i = 0; i < items.length; i++) {
          final (name, quantity, spares) = items[i];
          await into(equipmentTemplateItems).insert(
            EquipmentTemplateItemsCompanion.insert(
              // By name, not position: reordering the seed keeps ids.
              id: _seedId('equipment:$listKey:$category:$name'),
              vehicleId: Value(vehicleId),
              category: category,
              name: name,
              quantity: Value(quantity),
              spares: Value(spares),
              categoryOrder: c,
              sortOrder: i,
            ),
          );
        }
      }
      // No sync_queue row: every install creates these lists itself.
      await into(auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: 'EQUIPMENT_LIST',
          entityId: vehicleId ?? 'TOOLS',
          action: DbActions.create,
          description: const Value('Default equipment list'),
          performedBy: DbUsers.systemUserId,
        ),
      );
    }

    var written = 0;
    if (!await hasItems(null)) {
      await writeList('tools', null, [('Tools', seedTools)]);
      written++;
    }

    final vehiclesByName = {
      for (final vehicle in await select(vehicles).get())
        vehicle.name.trim().toLowerCase(): vehicle,
    };
    for (final MapEntry(key: vehicleKey, value: categories)
        in seedVehicleEquipment.entries) {
      final vehicle = vehiclesByName[_seedVehicleName(vehicleKey)];
      if (vehicle == null || await hasItems(vehicle.id)) continue;
      await writeList(vehicleKey, vehicle.id, categories);
      written++;
    }
    const AppLogger('AppDatabase').i('default equipment lists: $written added');
  }

  /// Writes the standard payloads (`seed/default_payloads.dart`) and the
  /// vehicle types each fits. Runs only from migrations and skips names
  /// that already exist (any status).
  Future<void> _insertDefaultPayloads() async {
    await _ensureSystemUser();

    final existingNames = {
      for (final payload in await select(payloads).get())
        payload.name.trim().toLowerCase(),
    };

    var added = 0;
    for (final payload in seedPayloads) {
      if (existingNames.contains(payload.name.toLowerCase())) continue;

      final payloadId = _seedId('payload:${payload.key}');
      await into(payloads).insert(
        PayloadsCompanion.insert(
          payloadId: payloadId,
          name: payload.name,
          category: payload.category,
          storageType: Value(payload.storageType),
          storageCapacity: Value(payload.storageCapacity),
        ),
      );
      for (final type in payload.vehicleTypes) {
        await into(payloadVehicleCompatibility).insert(
          PayloadVehicleCompatibilityCompanion.insert(
            id: _seedId('payload-type:$payloadId:$type'),
            payloadId: payloadId,
            vehicleType: type,
          ),
        );
      }
      // No sync_queue row: every install creates these payloads itself.
      await into(auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: DbEntityTypes.payload,
          entityId: payloadId,
          action: DbActions.create,
          description: const Value('Default payload'),
          performedBy: DbUsers.systemUserId,
        ),
      );
      added++;
    }
    const AppLogger('AppDatabase').i('default payloads: $added added');
  }

  /// Writes the standard fleet (`seed/default_fleet.dart`), each vehicle
  /// with its type's checklist. Runs only from migrations (first creation /
  /// upgrade); afterwards vehicles are edited in the `vehicles` table.
  Future<void> _insertDefaultFleet() async {
    const uuid = Uuid();

    await _ensureSystemUser();

    // Match by name in any status, so a retired/renamed vehicle isn't re-added.
    final existingNames = {
      for (final vehicle in await select(vehicles).get())
        vehicle.name.trim().toLowerCase(),
    };

    var added = 0;
    for (final vehicle in seedFleet) {
      if (existingNames.contains(vehicle.name.toLowerCase())) continue;

      final vehicleId = _seedId('vehicle:${vehicle.key}');
      final templateId = _seedId('template:$vehicleId:v1');
      await into(vehicles).insert(
        VehiclesCompanion.insert(
          id: vehicleId,
          name: vehicle.name,
          type: vehicle.type,
          motorCount: Value(vehicle.motorCount),
          frameMake: Value(vehicle.frameMake),
          frameModel: Value(vehicle.frameModel),
        ),
      );
      await into(vehicleChecklistTemplates).insert(
        VehicleChecklistTemplatesCompanion.insert(
          id: templateId,
          vehicleId: vehicleId,
          version: 1,
          createdBy: const Value(DbUsers.systemUserId),
        ),
      );
      await _insertPreflightItems(
        templateId,
        uuid,
        preflightChecklistFor(vehicle.type),
      );
      // No sync_queue row: every install creates these vehicles itself.
      await into(auditEvents).insert(
        AuditEventsCompanion.insert(
          entityType: DbEntityTypes.vehicle,
          entityId: vehicleId,
          action: DbActions.create,
          description: const Value('Default fleet vehicle'),
          performedBy: DbUsers.systemUserId,
        ),
      );
      added++;
    }
    const AppLogger('AppDatabase').i('default fleet: $added vehicles added');
  }
}
