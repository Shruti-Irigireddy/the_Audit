import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/vehicle/vehicle_dao.dart';
import 'daos/payload/payload_dao.dart';
import 'daos/battery/battery_dao.dart';
import 'daos/pre_field/pre_field_dao.dart';
import 'daos/pre_flight/pre_flight_dao.dart';
import 'daos/post_flight/post_flight_dao.dart';
import 'daos/records/record_dao.dart';
import 'daos/sync/sync_dao.dart';
import 'daos/export/export_dao.dart';

part 'app_database.g.dart';

  class Users extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get name => text()();
    TextColumn get role => text()(); // ADMIN, PIC, VO, crew
    BoolColumn get defaultPic => boolean().withDefault(const Constant(false))();
    TextColumn get email => text().unique()();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  }

  class Vehicles extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get name => text()();
    TextColumn get type => text()();  // MULTIROTOR, FIXED_WING, VTOL
    TextColumn get frameMake => text().nullable()();
    TextColumn get frameModel => text().nullable()();
    IntColumn get motorCount => integer().nullable()();
    TextColumn get frameStyle => text().nullable()();
    TextColumn get firmwareTarget => text().nullable()();
    TextColumn get defaultFailSafeProfile => text().nullable()();
    TextColumn get status => text().withDefault(const Constant('ACTIVE'))(); // ACTIVE, MAINTENANCE, RETIRED
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
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
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
      {vehicleId, version}
    ];
  }

  class ChecklistItems extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get templateId => text().references(VehicleChecklistTemplates, #id)();
    TextColumn get section => text()(); // Airframe, Comms, Ready to Arm
    TextColumn get label => text()();
    TextColumn get responseType => text()(); // PASS/FAIL/NA, VALUE, CHECKBOX, TEXT
    BoolColumn get isRequired => boolean().withDefault(const Constant(true))();
    BoolColumn get blocksArming => boolean().withDefault(const Constant(false))();
    IntColumn get sortOrder => integer()();
    BoolColumn get isActive => boolean().withDefault(const Constant(true))();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

    @override
    List<Set<Column>> get uniqueKeys => [
      {templateId, sortOrder}
    ];
  }

  class FieldSessions extends Table {
    TextColumn get sessionId => text().customConstraint('PRIMARY KEY')();
    DateTimeColumn get date => dateTime()();
    TextColumn get locationName => text()();
    RealColumn get latitude => real()();
    RealColumn get longitude => real()();
    TextColumn get missionType => text()();
    // Team members - list of userIds (multi-enum)
    // Vehicle taken - list of vehicleIds (multi-enum)
    // Pre-flight checklist - embedded table with checklist items (multi-enum)
    // Flights - list of flightIds (multi-enum)
    TextColumn get sessionStatus => text()(); // PLANNED, IN_PROGRESS, CLOSED
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get closedAt => dateTime().nullable()();
    TextColumn get closedBy => text().references(Users, #id).nullable()();
  }

  // Team members - list of userIds (multi-enum) 
  @TableIndex(name: 'idx_session_users_session_id', columns: {#sessionId})
  class SessionUsers extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
    TextColumn get userId => text().references(Users, #id)();
    TextColumn get role => text()(); // PIC, VO, Crew
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  }

  // Vehicle taken - list of vehicleIds (multi-enum)
  @TableIndex(name: 'idx_session_vehicles_session_id', columns: {#sessionId})
  class SessionVehicles extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
    TextColumn get vehicleId => text().references(Vehicles, #id)();
    TextColumn get objective => text().nullable()();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

    @override
    List<Set<Column>> get uniqueKeys => [
          {sessionId, vehicleId},
        ];
  }

  class SessionVehiclePayload extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get sessionVehicleId => text().references(SessionVehicles, #id)();
    TextColumn get payloadId => text().references(Payloads, #payloadId)();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

    @override
    List<Set<Column>> get uniqueKeys => [
      {sessionVehicleId, payloadId}
    ];
  }

  class Batteries extends Table {
    TextColumn get batteryId => text().customConstraint('PRIMARY KEY')();
    TextColumn get config => text()(); // 4S, 6S, 8S, 12S
    IntColumn get capacity => integer().nullable()(); // mAh
    RealColumn get voltage => real().nullable()(); // V
    IntColumn get cycleCount => integer().withDefault(const Constant(0)).nullable()();
    TextColumn get status => text().withDefault(const Constant('ACTIVE'))(); // ACTIVE, RETIRED
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  }

  @TableIndex(name: 'idx_session_batteries_session_id', columns: {#sessionId})
  class SessionBatteries extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
    TextColumn get batteryId => text().references(Batteries, #batteryId)();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

    @override
    List<Set<Column>> get uniqueKeys => [
          {sessionId, batteryId},
        ];
  }

  class Payloads extends Table {
    TextColumn get payloadId => text().customConstraint('PRIMARY KEY')();
    TextColumn get name => text()();
    TextColumn get category => text()(); // RGB/ Thermal, LiDAR, Multispectral, Hyperspectral, Mapping, Other
    TextColumn get storageType => text().nullable()();
    TextColumn get storageCapacity => text().nullable()(); // SD/ internal
    // Compatible vehicle Types - list of vehicleIds (multi-enum)
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  }

  // Compatible vehicle Types - list of vehicleIds (multi-enum)

  @TableIndex(name: 'idx_payload_vehicle_compatibility_payload_id', columns: {#payloadId})
  @TableIndex(name: 'idx_payload_vehicle_compatibility_vehicle_type', columns: {#vehicleType})
  class PayloadVehicleCompatibility extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get payloadId => text().references(Payloads, #payloadId)();
    TextColumn get vehicleType => text()(); // MULTIROTOR, FIXED_WING, VTOL
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

    @override
    List<Set<Column>> get uniqueKeys => [
      {payloadId, vehicleType}
    ];
  }

  class EquipmentLists extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get name => text()(); // Batteries, Charger, RC, GCS, Telemetry Radio, Tools, Props, Laptop
    TextColumn get category => text()(); // Batteries, Charger, RC, GCS, Telemetry Radio, Tools, Props, Laptop
    BoolColumn get isActive => boolean().withDefault(const Constant(true))();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  }

  @TableIndex(name: 'idx_session_equipment_checks_session_id', columns: {#sessionId})
  class SessionEquipmentChecks extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
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
      {sessionId, equipmentId}
    ];
  }

  @TableIndex(name: 'idx_sorties_session_id', columns: {#sessionId})
  @TableIndex(name: 'idx_sorties_flight_status', columns: {#flightStatus})
  class Sorties extends Table {
    TextColumn get flightId => text().customConstraint('PRIMARY KEY')();
    TextColumn get sessionId => text().references(FieldSessions, #sessionId)();
    IntColumn get sequenceNo => integer()(); // Sequence number of the flight in the session - more than one flight can be conducted in a single session (Auto-incremented within a session)
    TextColumn get sessionVehicleId => text().references(SessionVehicles, #id)();
    // Payloads - list of payloadIds (multi-enum)
    // Batteries - list of batteryIds (multi-enum)
    TextColumn get picUserId => text().references(Users, #id)();
    // VO (users) - list of userIds (multi-enum)
    TextColumn get objective => text().nullable()();
    // Pre-flight checklist - embedded table with checklist items (multi-enum)
    TextColumn get checklistTemplateId => text().references(VehicleChecklistTemplates, #id)();
    IntColumn get checklistTemplateVersion => integer()();
    DateTimeColumn get takeoffAt => dateTime().nullable()();
    DateTimeColumn get landingAt => dateTime().nullable()();
    // Post-flight notes - embedded table with checklist items (multi-enum)
    TextColumn get flightStatus => text().withDefault(const Constant('PREFLIGHT'))(); // PREFLIGHT, IN_PROGRESS, CLOSED, ABORTED
    DateTimeColumn get closedAt => dateTime().nullable()();
    TextColumn get closedBy => text().references(Users, #id).nullable()();
    TextColumn get finalDecision => text().nullable()(); // GO, NO_GO
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
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
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
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
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
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get flightId => text().references(Sorties, #flightId)();
    TextColumn get userId => text().references(Users, #id)();
    TextColumn get role => text()(); // PIC, VO, Crew
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

    @override
    List<Set<Column>> get uniqueKeys => [
      {flightId, userId, role}
    ];
  }

  @TableIndex(name: 'idx_checklist_responses_flight_id', columns: {#flightId})
  class ChecklistResponses extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get flightId => text().references(Sorties, #flightId)();
    TextColumn get itemId => text().references(ChecklistItems, #id)();
    TextColumn get response => text()(); // PASS/FAIL/NA, VALUE, CHECKBOX, TEXT
    TextColumn get valueText => text().nullable()();
    RealColumn get valueNumber => real().nullable()();
    TextColumn get notes => text().nullable()();
    TextColumn get createdBy => text().references(Users, #id)();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

    @override
    List<Set<Column>> get uniqueKeys => [
          {flightId, itemId},
        ];  
  }

  @TableIndex(name: 'idx_post_flight_notes_flight_id', columns: {#flightId})
  class PostFlightNotes extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get flightId => text().references(Sorties, #flightId).unique()();
    TextColumn get objectiveResult => text()(); // Yes/No/Partial
    TextColumn get objectiveNotes => text().nullable()();
    TextColumn get missionRating => text().nullable()(); // Excellent, Good, Average, Poor
    TextColumn get issuesEncountered => text().nullable()();
    TextColumn get logStoredAt => text().nullable()(); // Local, Cloud, Both
    TextColumn get logLocation => text().nullable()(); // Path or URL
    TextColumn get logNotes => text().nullable()();
    IntColumn get flightDurationSeconds => integer().nullable()();
    BoolColumn get followUpRequired => boolean().withDefault(const Constant(false))();
    TextColumn get followUpNotes => text().nullable()();
    TextColumn get followUpAssignedTo => text().references(Users, #id).nullable()();
    DateTimeColumn get followUpDueDate => dateTime().nullable()();
    TextColumn get followUpStatus => text().withDefault(const Constant('PENDING'))();
    TextColumn get notes => text().nullable()();
    TextColumn get createdBy => text().references(Users, #id)();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  }

  @TableIndex(name: 'idx_checklist_overrides_flight_id', columns: {#flightId})
  class ChecklistOverrides extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get flightId => text().references(Sorties, #flightId)();
    TextColumn get itemId => text().references(ChecklistItems, #id)();
    TextColumn get checklistResponseId => text().references(ChecklistResponses, #id).nullable()();
    TextColumn get overrideReason => text()();
    TextColumn get overriddenBy => text().references(Users, #id)();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  }

  @TableIndex(name: 'idx_audit_events_entity', columns: {#entityType, #entityId})
  class AuditEvents extends Table {
    IntColumn get id => integer().customConstraint('PRIMARY KEY').autoIncrement()();
    TextColumn get entityType => text()(); // User, Vehicle, Flight, Battery, Payload
    TextColumn get entityId => text()(); // userId, vehicleId, flightId, batteryId, payloadId
    TextColumn get action => text()(); // CREATE, UPDATE, DELETE
    TextColumn get description => text().nullable()(); // JSON or string representation of the changes made
    TextColumn get performedBy => text().references(Users, #id)();
    DateTimeColumn get performedAt => dateTime().withDefault(currentDateAndTime)();
  }

  @TableIndex(name: 'idx_record_amendments_entity', columns: {#entityType, #entityId})
  class RecordAmendments extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
    TextColumn get entityType => text()(); // SORTIE, POST_FLIGHT_NOTES, CHECKLIST_RESPONSE
    TextColumn get entityId => text()();
    TextColumn get amendmentText => text()();
    TextColumn get createdBy => text().references(Users, #id)();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  }
  
  //ObjectiveTags
  //SessionVehicleObjectiveTags

  @TableIndex(name: 'idx_export_records_status', columns: {#exportStatus})
  @TableIndex(name: 'idx_export_records_entity', columns: {#entityType, #entityId})
  class ExportRecords extends Table {
    IntColumn get id => integer().customConstraint('PRIMARY KEY').autoIncrement()();
    TextColumn get entityType => text()(); // User, Vehicle, Flight, Battery, Payload
    TextColumn get entityId => text()(); // userId, vehicleId, flightId, batteryId, payloadId
    TextColumn get exportFormat => text()(); // CSV, JSON, PDF
    TextColumn get exportLocation => text().nullable()(); // Path or URL
    TextColumn get exportStatus => text().withDefault(const Constant('PENDING'))(); // PENDING, IN_PROGRESS, COMPLETED, FAILED
    TextColumn get generatedBy => text().references(Users, #id)();
    IntColumn get retryCount => integer().withDefault(const Constant(0))();
    DateTimeColumn get lastAttemptAt => dateTime().nullable()();
    TextColumn get errorMessage => text().nullable()();
    DateTimeColumn get generatedAt => dateTime().withDefault(currentDateAndTime)();
  }

  @TableIndex(name: 'idx_sync_queue_status', columns: {#syncStatus})
  @TableIndex(name: 'idx_sync_queue_entity', columns: {#entityType, #entityId})
  class SyncQueue extends Table {
    IntColumn get id => integer().customConstraint('PRIMARY KEY').autoIncrement()();
    TextColumn get entityType => text()();
    TextColumn get entityId => text()();
    TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
    TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))(); // PENDING, IN_PROGRESS, COMPLETED, FAILED
    IntColumn get retryCount => integer().withDefault(const Constant(0))();
    DateTimeColumn get lastAttemptAt => dateTime().nullable()();
    DateTimeColumn get syncedAt => dateTime().nullable()();
    TextColumn get errorMessage => text().nullable()();
    DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
    DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  }

  class LocalAuthSessions extends Table {
    TextColumn get id => text().customConstraint('PRIMARY KEY')();
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
      SessionEquipmentChecks,
      EquipmentLists,
      RecordAmendments,
      LocalAuthSessions
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
    ],
  )

  class AppDatabase extends _$AppDatabase {
    AppDatabase()
        : super(
            driftDatabase(
              name: 'the_audit.db',
              // logStatements: true,
            ),
          );

    @override
    int get schemaVersion => 1;
  }
