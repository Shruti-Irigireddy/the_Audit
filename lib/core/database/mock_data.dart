import 'package:drift/drift.dart';

import 'app_database.dart';

class MockIds {
  static const adminUser = 'mock-user-admin';
  static const picUser = 'mock-user-pic';
  static const voUser = 'mock-user-vo';
  static const crewUser = 'mock-user-crew';

  static const multirotor = 'mock-vehicle-multirotor';
  static const fixedWing = 'mock-vehicle-fixed-wing';
  static const vtol = 'mock-vehicle-vtol';

  static const rgbPayload = 'mock-payload-rgb';
  static const thermalPayload = 'mock-payload-thermal';
  static const lidarPayload = 'mock-payload-lidar';

  static const battery6sOne = 'mock-battery-6s-001';
  static const battery6sTwo = 'mock-battery-6s-002';
  static const battery4sOne = 'mock-battery-4s-001';

  static const activeSession = 'mock-session-active';
  static const closedSession = 'mock-session-closed';
  static const sessionVehicle = 'mock-session-vehicle-001';
  static const sessionBatteryOne = 'mock-session-battery-001';
  static const sessionBatteryTwo = 'mock-session-battery-002';

  static const checklistTemplate = 'mock-checklist-template-001';
  static const checklistItemAirframe = 'mock-checklist-item-airframe';
  static const checklistItemBattery = 'mock-checklist-item-battery';
  static const checklistItemGps = 'mock-checklist-item-gps';
  static const checklistItemFailsafe = 'mock-checklist-item-failsafe';

  static const sortie = 'mock-sortie-001';
}

Future<void> seedMockData(AppDatabase database) async {
  final existingAdmin = await (database.select(
    database.users,
  )..where((user) => user.id.equals(MockIds.adminUser))).getSingleOrNull();

  if (existingAdmin != null) {
    return;
  }

  final now = DateTime(2026, 8, 6, 9);
  final yesterday = DateTime(2026, 8, 5, 8, 30);

  await database.transaction(() async {
    await _seedUsers(database, now);
    await _seedVehicles(database, now);
    await _seedVehicleChecklist(database, now);
    await _seedPayloads(database, now);
    await _seedBatteries(database, now);
    await _seedEquipment(database, now);
    await _seedSessions(database, now, yesterday);
    await _seedSortie(database, now);
  });
}

Future<void> _seedUsers(AppDatabase database, DateTime now) async {
  final users = [
    UsersCompanion.insert(
      id: MockIds.adminUser,
      name: 'Saishruti',
      role: 'ADMIN',
      defaultPic: const Value(true),
      email: 'saishruti05@gmail.com',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    UsersCompanion.insert(
      id: MockIds.picUser,
      name: 'Arjun Menon',
      role: 'PIC',
      defaultPic: const Value(true),
      email: 'arjun.menon@theaudit.local',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    UsersCompanion.insert(
      id: MockIds.voUser,
      name: 'Meera Rao',
      role: 'VO',
      email: 'meera.rao@theaudit.local',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    UsersCompanion.insert(
      id: MockIds.crewUser,
      name: 'Nikhil Shah',
      role: 'CREW',
      email: 'nikhil.shah@theaudit.local',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  ];

  for (final user in users) {
    await database
        .into(database.users)
        .insert(user, mode: InsertMode.insertOrIgnore);
  }
}

Future<void> _seedVehicles(AppDatabase database, DateTime now) async {
  final vehicles = [
    VehiclesCompanion.insert(
      id: MockIds.multirotor,
      name: 'Aquila M600',
      type: 'MULTIROTOR',
      frameMake: const Value('DJI'),
      frameModel: const Value('Matrice 600 Pro'),
      motorCount: const Value(6),
      frameStyle: const Value('Hexacopter'),
      firmwareTarget: const Value('PX4'),
      defaultFailSafeProfile: const Value('Return to Launch at 60 m'),
      notes: const Value('Primary mapping platform.'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    VehiclesCompanion.insert(
      id: MockIds.fixedWing,
      name: 'Surveyor FX',
      type: 'FIXED_WING',
      frameMake: const Value('Quantum Systems'),
      frameModel: const Value('Trinity F90+'),
      motorCount: const Value(3),
      frameStyle: const Value('Fixed wing VTOL assist'),
      firmwareTarget: const Value('ArduPilot'),
      defaultFailSafeProfile: const Value('Loiter, then RTL'),
      notes: const Value('Long corridor survey vehicle.'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    VehiclesCompanion.insert(
      id: MockIds.vtol,
      name: 'Falcon VTOL',
      type: 'VTOL',
      frameMake: const Value('Wingtra'),
      frameModel: const Value('WingtraOne Gen II'),
      motorCount: const Value(4),
      frameStyle: const Value('Tailsitter VTOL'),
      firmwareTarget: const Value('PX4'),
      defaultFailSafeProfile: const Value('Hold, then RTL'),
      notes: const Value('High accuracy photogrammetry.'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  ];

  for (final vehicle in vehicles) {
    await database
        .into(database.vehicles)
        .insert(vehicle, mode: InsertMode.insertOrIgnore);
  }
}

Future<void> _seedVehicleChecklist(AppDatabase database, DateTime now) async {
  await database
      .into(database.vehicleChecklistTemplates)
      .insert(
        VehicleChecklistTemplatesCompanion.insert(
          id: MockIds.checklistTemplate,
          vehicleId: MockIds.multirotor,
          version: 1,
          isActive: const Value(true),
          createdBy: const Value(MockIds.adminUser),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  final items = [
    ChecklistItemsCompanion.insert(
      id: MockIds.checklistItemAirframe,
      templateId: MockIds.checklistTemplate,
      section: 'Airframe',
      label: 'Frame, arms, landing gear, and propellers inspected',
      responseType: 'PASS_FAIL_NA',
      blocksArming: const Value(true),
      sortOrder: 1,
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    ChecklistItemsCompanion.insert(
      id: MockIds.checklistItemBattery,
      templateId: MockIds.checklistTemplate,
      section: 'Power',
      label: 'Battery seated, locked, and voltage within range',
      responseType: 'PASS_FAIL_NA',
      blocksArming: const Value(true),
      sortOrder: 2,
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    ChecklistItemsCompanion.insert(
      id: MockIds.checklistItemGps,
      templateId: MockIds.checklistTemplate,
      section: 'Navigation',
      label: 'GPS lock and home point confirmed',
      responseType: 'PASS_FAIL_NA',
      blocksArming: const Value(true),
      sortOrder: 3,
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    ChecklistItemsCompanion.insert(
      id: MockIds.checklistItemFailsafe,
      templateId: MockIds.checklistTemplate,
      section: 'Ready to Arm',
      label: 'Failsafe mode and geofence verified',
      responseType: 'PASS_FAIL_NA',
      blocksArming: const Value(true),
      sortOrder: 4,
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  ];

  for (final item in items) {
    await database
        .into(database.checklistItems)
        .insert(item, mode: InsertMode.insertOrIgnore);
  }
}

Future<void> _seedPayloads(AppDatabase database, DateTime now) async {
  final payloads = [
    PayloadsCompanion.insert(
      payloadId: MockIds.rgbPayload,
      name: 'Sony A7R IV RGB',
      category: 'RGB',
      storageType: const Value('SD'),
      storageCapacity: const Value('128 GB'),
      status: const Value('ACTIVE'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    PayloadsCompanion.insert(
      payloadId: MockIds.thermalPayload,
      name: 'FLIR Vue TZ20-R',
      category: 'THERMAL',
      storageType: const Value('microSD'),
      storageCapacity: const Value('64 GB'),
      status: const Value('ACTIVE'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    PayloadsCompanion.insert(
      payloadId: MockIds.lidarPayload,
      name: 'Zenmuse L2 LiDAR',
      category: 'LIDAR',
      storageType: const Value('Internal SSD'),
      storageCapacity: const Value('256 GB'),
      status: const Value('MAINTENANCE'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  ];

  for (final payload in payloads) {
    await database
        .into(database.payloads)
        .insert(payload, mode: InsertMode.insertOrIgnore);
  }

  final compatibility = [
    (
      id: 'mock-payload-rgb-multirotor',
      payloadId: MockIds.rgbPayload,
      type: 'MULTIROTOR',
    ),
    (
      id: 'mock-payload-rgb-fixed-wing',
      payloadId: MockIds.rgbPayload,
      type: 'FIXED_WING',
    ),
    (
      id: 'mock-payload-thermal-multirotor',
      payloadId: MockIds.thermalPayload,
      type: 'MULTIROTOR',
    ),
    (
      id: 'mock-payload-lidar-vtol',
      payloadId: MockIds.lidarPayload,
      type: 'VTOL',
    ),
  ];

  for (final rule in compatibility) {
    await database
        .into(database.payloadVehicleCompatibility)
        .insert(
          PayloadVehicleCompatibilityCompanion.insert(
            id: rule.id,
            payloadId: rule.payloadId,
            vehicleType: rule.type,
            createdAt: Value(now),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

Future<void> _seedBatteries(AppDatabase database, DateTime now) async {
  final batteries = [
    BatteriesCompanion.insert(
      batteryId: MockIds.battery6sOne,
      config: '6S',
      capacity: const Value(22000),
      voltage: const Value(25.1),
      cycleCount: const Value(18),
      status: const Value('ACTIVE'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    BatteriesCompanion.insert(
      batteryId: MockIds.battery6sTwo,
      config: '6S',
      capacity: const Value(22000),
      voltage: const Value(24.8),
      cycleCount: const Value(22),
      status: const Value('ACTIVE'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    BatteriesCompanion.insert(
      batteryId: MockIds.battery4sOne,
      config: '4S',
      capacity: const Value(10000),
      voltage: const Value(16.3),
      cycleCount: const Value(41),
      status: const Value('MAINTENANCE'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  ];

  for (final battery in batteries) {
    await database
        .into(database.batteries)
        .insert(battery, mode: InsertMode.insertOrIgnore);
  }
}

Future<void> _seedEquipment(AppDatabase database, DateTime now) async {
  final equipment = [
    (id: 'mock-equipment-props', name: 'Spare propellers', category: 'Tools'),
    (id: 'mock-equipment-charger', name: 'Field charger', category: 'Charger'),
    (id: 'mock-equipment-gcs', name: 'Ground control station', category: 'GCS'),
    (id: 'mock-equipment-radio', name: 'Telemetry radio', category: 'Comms'),
    (id: 'mock-equipment-laptop', name: 'Mission laptop', category: 'GCS'),
  ];

  for (final item in equipment) {
    await database
        .into(database.equipmentLists)
        .insert(
          EquipmentListsCompanion.insert(
            id: item.id,
            name: item.name,
            category: item.category,
            createdAt: Value(now),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

Future<void> _seedSessions(
  AppDatabase database,
  DateTime now,
  DateTime yesterday,
) async {
  await database
      .into(database.fieldSessions)
      .insert(
        FieldSessionsCompanion.insert(
          sessionId: MockIds.activeSession,
          date: now,
          locationName: 'Hebbal Lake Survey Block A',
          latitude: 13.0432,
          longitude: 77.5913,
          missionType: 'DATA_COLLECTION',
          sessionStatus: 'IN_PROGRESS',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  await database
      .into(database.fieldSessions)
      .insert(
        FieldSessionsCompanion.insert(
          sessionId: MockIds.closedSession,
          date: yesterday,
          locationName: 'Jakkur Practice Field',
          latitude: 13.0767,
          longitude: 77.5976,
          missionType: 'PRACTICE',
          sessionStatus: 'CLOSED',
          createdAt: Value(yesterday),
          updatedAt: Value(yesterday.add(const Duration(hours: 2))),
          closedAt: Value(yesterday.add(const Duration(hours: 2))),
          closedBy: const Value(MockIds.adminUser),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  final sessionUsers = [
    (id: 'mock-session-user-pic', userId: MockIds.picUser, role: 'PIC'),
    (id: 'mock-session-user-vo', userId: MockIds.voUser, role: 'VO'),
    (id: 'mock-session-user-crew', userId: MockIds.crewUser, role: 'CREW'),
  ];

  for (final member in sessionUsers) {
    await database
        .into(database.sessionUsers)
        .insert(
          SessionUsersCompanion.insert(
            id: member.id,
            sessionId: MockIds.activeSession,
            userId: member.userId,
            role: member.role,
            createdAt: Value(now),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  await database
      .into(database.sessionVehicles)
      .insert(
        SessionVehiclesCompanion.insert(
          id: MockIds.sessionVehicle,
          sessionId: MockIds.activeSession,
          vehicleId: MockIds.multirotor,
          objective: const Value(
            'Map shoreline and capture thermal reference points',
          ),
          createdAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  await database
      .into(database.sessionVehiclePayload)
      .insert(
        SessionVehiclePayloadCompanion.insert(
          id: 'mock-session-vehicle-payload-rgb',
          sessionVehicleId: MockIds.sessionVehicle,
          payloadId: MockIds.rgbPayload,
          createdAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  await database
      .into(database.sessionBatteries)
      .insert(
        SessionBatteriesCompanion.insert(
          id: MockIds.sessionBatteryOne,
          sessionId: MockIds.activeSession,
          batteryId: MockIds.battery6sOne,
          createdAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  await database
      .into(database.sessionBatteries)
      .insert(
        SessionBatteriesCompanion.insert(
          id: MockIds.sessionBatteryTwo,
          sessionId: MockIds.activeSession,
          batteryId: MockIds.battery6sTwo,
          createdAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> _seedSortie(AppDatabase database, DateTime now) async {
  await database
      .into(database.sorties)
      .insert(
        SortiesCompanion.insert(
          flightId: MockIds.sortie,
          sessionId: MockIds.activeSession,
          sequenceNo: 1,
          sessionVehicleId: MockIds.sessionVehicle,
          picUserId: MockIds.picUser,
          objective: const Value('Low altitude overlap check over Block A'),
          checklistTemplateId: MockIds.checklistTemplate,
          checklistTemplateVersion: 1,
          takeoffAt: Value(now.add(const Duration(minutes: 20))),
          landingAt: Value(now.add(const Duration(minutes: 34))),
          flightStatus: const Value('CLOSED'),
          closedAt: Value(now.add(const Duration(minutes: 40))),
          closedBy: const Value(MockIds.picUser),
          finalDecision: const Value('GO'),
          decisionReason: const Value('Checklist passed and airspace clear.'),
          decisionBy: const Value(MockIds.picUser),
          decisionAt: Value(now.add(const Duration(minutes: 15))),
          createdAt: Value(now),
          updatedAt: Value(now.add(const Duration(minutes: 40))),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  await database
      .into(database.sortiePayloads)
      .insert(
        SortiePayloadsCompanion.insert(
          id: 'mock-sortie-payload-rgb',
          flightId: MockIds.sortie,
          payloadId: MockIds.rgbPayload,
          createdAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  await database
      .into(database.sortieBatteries)
      .insert(
        SortieBatteriesCompanion.insert(
          id: 'mock-sortie-battery-001',
          flightId: MockIds.sortie,
          batteryId: MockIds.battery6sOne,
          voltageStart: const Value(25.1),
          voltageEnd: const Value(23.2),
          percentStart: const Value(96),
          percentEnd: const Value(42),
          createdAt: Value(now),
          updatedAt: Value(now.add(const Duration(minutes: 40))),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  await database
      .into(database.sortieUsers)
      .insert(
        SortieUsersCompanion.insert(
          id: 'mock-sortie-user-vo',
          flightId: MockIds.sortie,
          userId: MockIds.voUser,
          role: 'VO',
          createdAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  final responses = [
    (id: 'mock-response-airframe', itemId: MockIds.checklistItemAirframe),
    (id: 'mock-response-battery', itemId: MockIds.checklistItemBattery),
    (id: 'mock-response-gps', itemId: MockIds.checklistItemGps),
    (id: 'mock-response-failsafe', itemId: MockIds.checklistItemFailsafe),
  ];

  for (final response in responses) {
    await database
        .into(database.checklistResponses)
        .insert(
          ChecklistResponsesCompanion.insert(
            id: response.id,
            flightId: MockIds.sortie,
            itemId: response.itemId,
            response: 'PASS',
            notes: const Value('Mock checklist pass.'),
            createdBy: MockIds.picUser,
            responseAt: Value(now.add(const Duration(minutes: 10))),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  await database
      .into(database.postFlightNotes)
      .insert(
        PostFlightNotesCompanion.insert(
          id: 'mock-post-flight-note-001',
          flightId: MockIds.sortie,
          objectiveResult: 'YES',
          objectiveNotes: const Value(
            'Coverage complete with clear image overlap.',
          ),
          missionRating: const Value('4.5'),
          issuesEncountered: const Value(
            'Minor wind gusts near the north edge.',
          ),
          logStoredAt: const Value('LOCAL'),
          logLocation: const Value('/logs/2026-08-06/mock-sortie-001'),
          logNotes: const Value('Telemetry and payload logs verified.'),
          flightDurationSeconds: const Value(840),
          followUpRequired: const Value(true),
          followUpNotes: const Value(
            'Review thermal alignment before next flight.',
          ),
          followUpAssignedTo: const Value(MockIds.voUser),
          followUpStatus: const Value('PENDING'),
          notes: const Value('Mock post-flight notes for UI testing.'),
          createdBy: MockIds.picUser,
          createdAt: Value(now.add(const Duration(minutes: 45))),
          updatedAt: Value(now.add(const Duration(minutes: 45))),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}
