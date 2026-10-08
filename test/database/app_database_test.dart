import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/checklists/common_preflight.dart';
import 'package:the_audit/core/database/database_constants.dart';
import 'package:the_audit/core/database/dtos/equipment_dtos.dart';
import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/features/auth/data/current_user_repository.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_state.dart';
import 'package:the_audit/features/pre_field/data/repositories/session_setup_repository.dart';

const _fleet = ['Cerana', 'Dorsata', 'Kari', 'Striver'];

void main() {
  // Some Linux hosts only ship the versioned library name.
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  group('fresh database', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('contains the default fleet, authored by the system user', () async {
      final vehicles = await db.vehicleDao.getActiveVehicles();
      expect(vehicles.map((v) => v.name), _fleet);

      final byName = {for (final v in vehicles) v.name: v};
      expect(byName['Cerana']!.motorCount, 5);
      expect(byName['Striver']!.motorCount, 5);
      expect(byName['Dorsata']!.motorCount, 4);
      expect(byName['Kari']!.motorCount, 4);
      expect(byName['Striver']!.frameModel, 'Folding');
      for (final name in ['Cerana', 'Dorsata', 'Kari']) {
        expect(byName[name]!.frameModel, 'Fixed');
      }

      for (final vehicle in vehicles) {
        final template = await db.vehicleDao
            .getActiveChecklistTemplateForVehicle(vehicle.id);
        expect(template, isNotNull, reason: vehicle.name);
        expect(template!.version, 1);
        final items = await db.vehicleDao.getChecklistItemsForTemplate(
          template.id,
        );
        // SRS §5.1 common pre-flight checklist, [A] items block arming.
        // Common items, then the vehicle type's own (SRS §5.2–5.4).
        expect(
          items,
          hasLength(preflightChecklistFor(vehicle.type).length),
          reason: vehicle.name,
        );
        final typeItems = typePreflightChecklist(vehicle.type);
        expect(
          items
              .skip(commonPreflightChecklist.length)
              .take(typeItems.length)
              .map((i) => i.label),
          typeItems.map((i) => i.label),
          reason: vehicle.name,
        );
        // …and the Ready-to-Arm gate (SRS §5.5) last.
        expect(
          items
              .skip(items.length - readyToArmGateChecklist.length)
              .map((i) => i.section),
          everyElement(readyToArmSection),
          reason: vehicle.name,
        );
        final gcs = items.firstWhere((i) => i.label == 'GCS connected');
        expect(gcs.responseType, ChecklistResponseTypes.passFail);
        expect(gcs.blocksArming, isTrue);
        // Battery start voltage is entered as a number.
        expect(
          items
              .firstWhere(
                (i) =>
                    i.label ==
                    'Battery installed & secured; start voltage logged',
              )
              .responseType,
          ChecklistResponseTypes.number,
        );
        final geofence = items.firstWhere(
          (i) => i.label == 'Geofence set (if used)',
        );
        expect(geofence.responseType, ChecklistResponseTypes.passNa);
        expect(geofence.blocksArming, isFalse);
        expect(
          items.where((i) => i.blocksArming),
          hasLength(
            preflightChecklistFor(
              vehicle.type,
            ).where((i) => i.blocksArming).length,
          ),
        );

        final audits =
            await (db.select(db.auditEvents)..where(
                  (a) =>
                      a.entityId.equals(vehicle.id) &
                      a.entityType.equals(DbEntityTypes.vehicle),
                ))
                .get();
        expect(audits, hasLength(1), reason: vehicle.name);
        expect(audits.single.action, DbActions.create);
        expect(audits.single.performedBy, DbUsers.systemUserId);
      }

      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('contains the default payloads with their vehicle types', () async {
      final payloads = {
        for (final p in await db.payloadDao.getAllPayloads()) p.name: p,
      };
      expect(payloads.keys, hasLength(5));

      Future<Set<String>> types(String name) async =>
          (await db.payloadDao.getCompatibleVehicleTypes(
            payloads[name]!.payloadId,
          )).toSet();

      const all = {'MULTIROTOR', 'VTOL', 'FIXED_WING'};
      expect(await types('Jetson Orin Nano 8GB'), all);
      expect(await types('Pi 5 – 8GB'), all);
      expect(await types('FLIR Camera – USB'), all);
      expect(await types('Lucid Camera – Ethernet'), all);
      expect(await types('Motion Metrics IP – Ethernet'), {
        'MULTIROTOR',
        'VTOL',
      });

      // Motion Metrics IP is limited to Dorsata and Cerana (not Kari).
      final vehicles = {
        for (final v in await db.vehicleDao.getActiveVehicles()) v.name: v.id,
      };
      expect(
        (await db.payloadDao.getLimitedVehicleIds(
          payloads['Motion Metrics IP – Ethernet']!.payloadId,
        )).toSet(),
        {vehicles['Dorsata'], vehicles['Cerana']},
      );
      expect(
        await db.payloadDao.getLimitedVehicleIds(
          payloads['FLIR Camera – USB']!.payloadId,
        ),
        isEmpty,
      );

      expect(payloads['Jetson Orin Nano 8GB']!.category, 'Companion Computer');
      expect(payloads['Pi 5 – 8GB']!.storageCapacity, '64GB');
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('contains the default equipment lists from the sheets', () async {
      final vehicles = {
        for (final v in await db.vehicleDao.getActiveVehicles()) v.name: v,
      };
      final dao = db.equipmentDao;

      final tools = await dao.getTemplateItems();
      expect(tools, hasLength(27));
      expect(tools.map((t) => t.category).toSet(), {'Tools'});
      expect(
        tools.firstWhere((t) => t.name == 'Rubber Bands').quantity,
        isNull,
      );
      expect(tools.firstWhere((t) => t.name == 'Zip Ties Set').quantity, 3);

      final kari = await dao.getTemplateItems(vehicleId: vehicles['Kari']!.id);
      expect(kari.map((t) => t.category).toSet().toList(), [
        'Airframe',
        'Subsystems',
        'Communication Systems',
        'Power Systems',
      ]);
      final kariProps = kari.firstWhere((t) => t.name == 'Propellers');
      expect((kariProps.quantity, kariProps.spares), (4, 4));
      final kariGps = kari.firstWhere((t) => t.name == 'GPS');
      expect((kariGps.quantity, kariGps.spares), (1, 1));

      final cerana = await dao.getTemplateItems(
        vehicleId: vehicles['Cerana']!.id,
      );
      expect(cerana.firstWhere((t) => t.name == 'Motors').quantity, 5);
      final ceranaProps = cerana.firstWhere((t) => t.name == 'Propellers');
      expect((ceranaProps.quantity, ceranaProps.spares), (5, 5));
      expect(
        cerana.firstWhere((t) => t.name == 'Canopy Bolts').quantity,
        isNull,
      );

      final dorsata = await dao.getTemplateItems(
        vehicleId: vehicles['Dorsata']!.id,
      );
      expect(
        dorsata.where((t) => t.category == 'Communication Systems'),
        hasLength(10),
      );

      expect(
        await dao.getTemplateItems(vehicleId: vehicles['Striver']!.id),
        isEmpty,
      );
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('equipment items can be added, edited and removed', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );
      final striver = (await db.vehicleDao.getActiveVehicles()).firstWhere(
        (v) => v.name == 'Striver',
      );
      final dao = db.equipmentDao;

      final wingsId = await dao.addTemplateItem(
        vehicleId: striver.id,
        category: 'Airframe',
        name: 'Wings',
        quantity: 2,
        performedBy: 'u1',
      );
      final gpsId = await dao.addTemplateItem(
        vehicleId: striver.id,
        category: 'Subsystems',
        name: 'GPS',
        quantity: 1,
        spares: 1,
        performedBy: 'u1',
      );
      var items = await dao.getTemplateItems(vehicleId: striver.id);
      expect(items.map((t) => t.name), ['Wings', 'GPS']);
      expect(items.map((t) => t.categoryOrder), [0, 1]);

      await dao.updateTemplateItem(
        id: wingsId,
        quantity: 3,
        clearSpares: true,
        performedBy: 'u1',
      );
      await dao.deactivateTemplateItem(id: gpsId, performedBy: 'u1');

      items = await dao.getTemplateItems(vehicleId: striver.id);
      expect(items.single.name, 'Wings');
      expect(items.single.quantity, 3);
      expect(items.single.spares, isNull);
    });

    test('a session keeps its equipment snapshot after list edits', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );
      final dao = db.equipmentDao;
      final sessionId = await db.preFieldDao.createFieldSession(
        date: DateTime(2026, 10, 3),
        locationName: 'Test site',
        latitude: 12.97,
        longitude: 77.59,
        missionType: 'TESTING',
        sessionStatus: 'PLANNED',
        createdBy: 'u1',
      );
      final tweezers = (await dao.getTemplateItems()).first;

      await dao.saveSessionEquipment(
        sessionId: sessionId,
        items: [
          SessionEquipmentDraft(
            sessionVehicleId: null,
            templateItemId: tweezers.id,
            category: tweezers.category,
            name: tweezers.name,
            quantity: tweezers.quantity,
            spares: tweezers.spares,
            isPacked: true,
            categoryOrder: tweezers.categoryOrder,
            sortOrder: tweezers.sortOrder,
          ),
        ],
        performedBy: 'u1',
      );
      await dao.updateTemplateItem(
        id: tweezers.id,
        quantity: 9,
        performedBy: 'u1',
      );

      final saved = await dao.getSessionEquipmentItems(sessionId);
      expect(saved.single.name, 'Tweezers');
      expect(saved.single.quantity, 1);
      expect(saved.single.isPacked, isTrue);
      expect(saved.single.packedBy, 'u1');
    });

    test('hides the system user from people pickers', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );

      final users = await db.preFieldDao.getSelectableUsers();
      expect(users.map((u) => u.id), ['u1']);
    });

    test('stores each session vehicle with its quantity', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );
      final kari = (await db.vehicleDao.getActiveVehicles()).firstWhere(
        (v) => v.name == 'Kari',
      );

      final sessionId = await db.preFieldDao.createFieldSession(
        date: DateTime(2026, 10, 3),
        locationName: 'Test site',
        latitude: 12.97,
        longitude: 77.59,
        missionType: 'TESTING',
        sessionStatus: 'IN_PROGRESS',
        createdBy: 'u1',
      );
      await db.preFieldDao.addVehicleToSession(
        sessionId: sessionId,
        vehicleId: kari.id,
        quantity: 2,
        performedBy: 'u1',
      );

      final rows = await (db.select(
        db.sessionVehicles,
      )..where((v) => v.sessionId.equals(sessionId))).get();
      expect(rows.single.quantity, 2);
    });

    test(
      'two saves of the same checklist answer at once keep one row',
      () async {
        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                id: 'u1',
                name: 'Tester',
                role: 'PIC',
                email: 'tester@example.com',
              ),
            );
        final kari = (await db.vehicleDao.getActiveVehicles()).firstWhere(
          (v) => v.name == 'Kari',
        );
        final sessionId = await db.preFieldDao.createFieldSession(
          date: DateTime(2026, 10, 6),
          locationName: 'Test site',
          latitude: 12.97,
          longitude: 77.59,
          missionType: 'TESTING',
          sessionStatus: 'PLANNED',
          createdBy: 'u1',
        );
        final sessionVehicleId = await db.preFieldDao.addVehicleToSession(
          sessionId: sessionId,
          vehicleId: kari.id,
          performedBy: 'u1',
        );
        final flightId = await db.preFlightDao.createSortie(
          sessionId: sessionId,
          sessionVehicleId: sessionVehicleId,
          picUserId: 'u1',
          performedBy: 'u1',
        );
        final template = await db.vehicleDao
            .getActiveChecklistTemplateForVehicle(kari.id);
        final voltage = (await db.vehicleDao.getChecklistItemsForTemplate(
          template!.id,
        )).firstWhere((i) => i.responseType == ChecklistResponseTypes.value);

        // Like pressing Done and then leaving the field: both arrive together.
        Future<void> save() => db.preFlightDao.saveChecklistResponse(
          flightId: flightId,
          itemId: voltage.id,
          response: 'VALUE',
          valueText: '25.26',
          valueNumber: 25.26,
          createdBy: 'u1',
        );
        await Future.wait([save(), save()]);

        final rows = await (db.select(
          db.checklistResponses,
        )..where((r) => r.flightId.equals(flightId))).get();
        expect(rows, hasLength(1));
        expect(rows.single.valueNumber, 25.26);
      },
    );

    test('a session closes only when every sortie is closed', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );
      final kari = (await db.vehicleDao.getActiveVehicles()).firstWhere(
        (v) => v.name == 'Kari',
      );
      final sessionId = await db.preFieldDao.createFieldSession(
        date: DateTime(2026, 10, 7),
        locationName: 'Test site',
        latitude: 12.97,
        longitude: 77.59,
        missionType: 'TESTING',
        sessionStatus: 'PLANNED',
        createdBy: 'u1',
      );
      final sessionVehicleId = await db.preFieldDao.addVehicleToSession(
        sessionId: sessionId,
        vehicleId: kari.id,
        performedBy: 'u1',
      );
      final flightId = await db.preFlightDao.createSortie(
        sessionId: sessionId,
        sessionVehicleId: sessionVehicleId,
        picUserId: 'u1',
        performedBy: 'u1',
      );

      Future<void> close() => db.preFieldDao.closeFieldSession(
        sessionId: sessionId,
        closedBy: 'u1',
      );
      await expectLater(close(), throwsA(isA<AppFailure>()));

      await db.customStatement(
        "UPDATE sorties SET flight_status = 'CLOSED' WHERE flight_id = ?",
        [flightId],
      );
      await close();
      expect(
        (await db.recordDao.getSessionById(sessionId))!.sessionStatus,
        'CLOSED',
      );
    });

    test('first pre-flight moves a PLANNED session to IN_PROGRESS', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );
      final kari = (await db.vehicleDao.getActiveVehicles()).firstWhere(
        (v) => v.name == 'Kari',
      );
      final sessionId = await db.preFieldDao.createFieldSession(
        date: DateTime(2026, 10, 3),
        locationName: 'Test site',
        latitude: 12.97,
        longitude: 77.59,
        missionType: 'TESTING',
        sessionStatus: 'PLANNED',
        createdBy: 'u1',
      );
      final sessionVehicleId = await db.preFieldDao.addVehicleToSession(
        sessionId: sessionId,
        vehicleId: kari.id,
        performedBy: 'u1',
      );

      Future<String> status() async =>
          (await db.recordDao.getSessionById(sessionId))!.sessionStatus;

      expect(await status(), 'PLANNED');
      await db.preFlightDao.createSortie(
        sessionId: sessionId,
        sessionVehicleId: sessionVehicleId,
        picUserId: 'u1',
        performedBy: 'u1',
      );
      expect(await status(), 'IN_PROGRESS');
    });

    test('foreign keys are enforced: unknown users are rejected', () async {
      final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(pragma.data.values.single, 1);

      await expectLater(
        db.preFieldDao.createFieldSession(
          date: DateTime(2026, 10, 6),
          locationName: 'Test site',
          latitude: 12.97,
          longitude: 77.59,
          missionType: 'TESTING',
          sessionStatus: 'PLANNED',
          createdBy: 'unknown',
        ),
        throwsA(anything),
      );
      expect(await db.select(db.fieldSessions).get(), isEmpty);
    });

    test('the signed-in user is added once and used as performedBy', () async {
      final repo = CurrentUserRepository(db);
      const auth = AuthState(
        viewStatus: AuthViewStatus.authenticated,
        isLoggedIn: true,
        uid: 'firebase-uid',
        email: 'shruti.k@example.com',
        errorMessage: null,
      );

      expect(await repo.resolvePerformedBy(auth), 'firebase-uid');
      expect(await repo.resolvePerformedBy(auth), 'firebase-uid');

      final users = await (db.select(
        db.users,
      )..where((u) => u.id.equals('firebase-uid'))).get();
      expect(users.single.name, 'Shruti.k');
      expect(users.single.email, 'shruti.k@example.com');

      // Nobody signed in: nothing is attributed to a made-up user.
      await expectLater(
        repo.resolvePerformedBy(AuthState.initial()),
        throwsA(isA<NotSignedInException>()),
      );
    });

    test(
      'changing a vehicle type renews its checklist as a new version',
      () async {
        final setup = SessionSetupRepository(db);
        final kari = (await db.vehicleDao.getActiveVehicles()).firstWhere(
          (v) => v.name == 'Kari',
        );
        final before = await db.vehicleDao.getActiveChecklistTemplateForVehicle(
          kari.id,
        );

        await setup.editVehicle(
          before: kari,
          name: kari.name,
          type: 'VTOL',
          performedBy: DbUsers.systemUserId,
        );

        final after = await db.vehicleDao.getActiveChecklistTemplateForVehicle(
          kari.id,
        );
        expect(after!.version, before!.version + 1);
        expect(
          await db.vehicleDao.getChecklistItemsForTemplate(after.id),
          hasLength(preflightChecklistFor('VTOL').length),
        );
      },
    );

    test('payloads fit by vehicle limit first, then by type', () async {
      final catalog = await SessionSetupRepository(db).loadPayloadCatalog();
      final vehicles = await db.vehicleDao.getActiveVehicles();
      for (final vehicle in vehicles) {
        for (final payload in catalog.payloadsFor(vehicle)) {
          final limit = catalog.vehicleLimits[payload.payloadId];
          final types = catalog.types[payload.payloadId]!;
          expect(
            limit?.contains(vehicle.id) ??
                (types.isEmpty || types.contains(vehicle.type.toUpperCase())),
            isTrue,
            reason: '${payload.name} on ${vehicle.name}',
          );
        }
      }
      // A vehicle-limited payload is offered only to its vehicles.
      final limited = catalog.vehicleLimits.entries.first;
      for (final vehicle in vehicles) {
        final offered = catalog
            .payloadsFor(vehicle)
            .any((p) => p.payloadId == limited.key);
        expect(offered, limited.value.contains(vehicle.id));
      }
    });

    test('saving Go makes the sortie READY for post-flight', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );
      final kari = (await db.vehicleDao.getActiveVehicles()).firstWhere(
        (v) => v.name == 'Kari',
      );
      final sessionId = await db.preFieldDao.createFieldSession(
        date: DateTime(2026, 10, 7),
        locationName: 'Test site',
        latitude: 12.97,
        longitude: 77.59,
        missionType: 'TESTING',
        sessionStatus: 'PLANNED',
        createdBy: 'u1',
      );
      final sessionVehicleId = await db.preFieldDao.addVehicleToSession(
        sessionId: sessionId,
        vehicleId: kari.id,
        performedBy: 'u1',
      );
      final flightId = await db.preFlightDao.createSortie(
        sessionId: sessionId,
        sessionVehicleId: sessionVehicleId,
        picUserId: 'u1',
        performedBy: 'u1',
      );
      // Pass every blocking [A] item (numbers need a value).
      for (final item
          in await db.preFlightDao.loadBlockingChecklistItemsForSortie(
            flightId,
          )) {
        final isNumber = item.responseType == ChecklistResponseTypes.number;
        await db.preFlightDao.saveChecklistResponse(
          flightId: flightId,
          itemId: item.id,
          response: isNumber ? 'VALUE' : 'PASS',
          valueNumber: isNumber ? 25.2 : null,
          createdBy: 'u1',
        );
      }

      await db.preFlightDao.submitGoNoGoDecision(
        flightId: flightId,
        decision: 'GO',
        decisionBy: 'u1',
      );

      final sortie = await (db.select(
        db.sorties,
      )..where((s) => s.flightId.equals(flightId))).getSingle();
      expect(sortie.flightStatus, 'READY');
      // Post-flight accepts it with no take-off or landing times: only the
      // notes are still missing.
      expect(await db.postFlightDao.validatePostFlightCompletion(flightId), [
        'Post-flight note is required.',
      ]);

      // Save & close with stars, a typed duration and the landed battery.
      Future<void> saveNote(String notes) =>
          db.postFlightDao.savePostFlightNote(
            flightId: flightId,
            objectiveResult: 'YES',
            missionRating: '4',
            flightDurationSeconds: 12 * 60,
            landedBatteryVoltage: 22.4,
            landedBatteryPercent: 35,
            notes: notes,
            createdBy: 'u1',
          );
      await saveNote('All good');
      await db.postFlightDao.closeSortie(flightId: flightId, closedBy: 'u1');

      final closed = await (db.select(
        db.sorties,
      )..where((s) => s.flightId.equals(flightId))).getSingle();
      expect(closed.flightStatus, 'CLOSED');
      var note = (await db.postFlightDao.getPostFlightNoteForFlight(flightId))!;
      expect(note.missionRating, '4');
      expect(note.flightDurationSeconds, 12 * 60);
      expect(note.landedBatteryVoltage, 22.4);
      expect(note.landedBatteryPercent, 35);

      // Edited after close: saved, and logged as an amendment.
      await saveNote('All good; prop nick found later');
      note = (await db.postFlightDao.getPostFlightNoteForFlight(flightId))!;
      expect(note.notes, 'All good; prop nick found later');
      final amendments = await db.select(db.recordAmendments).get();
      expect(amendments.single.amendmentText, 'Edited after close: notes');
    });

    test('removing a session vehicle removes its packing snapshot', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              name: 'Tester',
              role: 'PIC',
              email: 'tester@example.com',
            ),
          );
      final kari = (await db.vehicleDao.getActiveVehicles()).firstWhere(
        (v) => v.name == 'Kari',
      );
      final sessionId = await db.preFieldDao.createFieldSession(
        date: DateTime(2026, 10, 6),
        locationName: 'Test site',
        latitude: 12.97,
        longitude: 77.59,
        missionType: 'TESTING',
        sessionStatus: 'PLANNED',
        createdBy: 'u1',
      );
      final sessionVehicleId = await db.preFieldDao.addVehicleToSession(
        sessionId: sessionId,
        vehicleId: kari.id,
        performedBy: 'u1',
      );
      await db.equipmentDao.saveSessionEquipment(
        sessionId: sessionId,
        items: [
          SessionEquipmentDraft(
            sessionVehicleId: sessionVehicleId,
            templateItemId: null,
            category: 'AIRFRAME',
            name: 'Propellers',
            quantity: 4,
            spares: 0,
            isPacked: false,
            categoryOrder: 0,
            sortOrder: 0,
          ),
        ],
        performedBy: 'u1',
      );

      await db.preFieldDao.removeVehicleFromSession(
        sessionVehicleId: sessionVehicleId,
        performedBy: 'u1',
      );

      expect(await db.select(db.sessionVehicles).get(), isEmpty);
      expect(await db.select(db.sessionEquipmentItems).get(), isEmpty);
    });
  });

  test('upgrading to v11 makes sorties with a saved Go READY', () async {
    final dir = await Directory.systemTemp.createTemp('the_audit_test');
    final file = File('${dir.path}/the_audit.db');
    addTearDown(() => dir.delete(recursive: true));

    // A v10 database: one sortie with Go saved (still PREFLIGHT, as v10
    // left it) and one still being checked.
    final v10 = AppDatabase.forTesting(NativeDatabase(file));
    await v10
        .into(v10.users)
        .insert(
          UsersCompanion.insert(
            id: 'u1',
            name: 'Tester',
            role: 'PIC',
            email: 'tester@example.com',
          ),
        );
    final kari = (await v10.vehicleDao.getActiveVehicles()).firstWhere(
      (v) => v.name == 'Kari',
    );
    final sessionId = await v10.preFieldDao.createFieldSession(
      date: DateTime(2026, 10, 7),
      locationName: 'Test site',
      latitude: 12.97,
      longitude: 77.59,
      missionType: 'TESTING',
      sessionStatus: 'PLANNED',
      createdBy: 'u1',
    );
    final sessionVehicleId = await v10.preFieldDao.addVehicleToSession(
      sessionId: sessionId,
      vehicleId: kari.id,
      quantity: 2,
      performedBy: 'u1',
    );
    Future<String> sortie() => v10.preFlightDao.createSortie(
      sessionId: sessionId,
      sessionVehicleId: sessionVehicleId,
      picUserId: 'u1',
      performedBy: 'u1',
    );
    final withGo = await sortie();
    final checking = await sortie();
    await v10.customStatement(
      "UPDATE sorties SET final_decision = 'GO' WHERE flight_id = ?",
      [withGo],
    );
    // v12 added the landed battery columns.
    await v10.customStatement(
      'ALTER TABLE post_flight_notes DROP COLUMN landed_battery_voltage',
    );
    await v10.customStatement(
      'ALTER TABLE post_flight_notes DROP COLUMN landed_battery_percent',
    );
    await v10.customStatement('PRAGMA user_version = 10');
    await v10.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    Future<String> status(String id) async => (await (db.select(
      db.sorties,
    )..where((s) => s.flightId.equals(id))).getSingle()).flightStatus;

    expect(await status(withGo), 'READY');
    expect(await status(checking), 'PREFLIGHT');
  });

  test(
    'upgrading from v2 adds quantity and only the missing defaults',
    () async {
      final dir = await Directory.systemTemp.createTemp('the_audit_test');
      final file = File('${dir.path}/the_audit.db');
      addTearDown(() => dir.delete(recursive: true));

      // Build a database with today's tables, then roll it back to the v2
      // shape: no session_vehicles.quantity, no default fleet, an existing
      // vehicle named "kari", user_version 2.
      final v2 = AppDatabase.forTesting(NativeDatabase(file));
      await v2.customSelect('SELECT 1').get(); // opens + creates
      // Old databases had no foreign key checks; rolling back needs them off.
      await v2.customStatement('PRAGMA foreign_keys = OFF');
      await v2.customStatement('DELETE FROM audit_events');
      await v2.customStatement('DELETE FROM payload_vehicle_compatibility');
      await v2.customStatement('DELETE FROM payloads');
      await v2.customStatement('DROP TABLE payload_vehicles');
      await v2.customStatement('DROP TABLE session_equipment_items');
      await v2.customStatement('DROP TABLE equipment_template_items');
      await v2.customStatement('DELETE FROM checklist_items');
      await v2.customStatement('DELETE FROM vehicle_checklist_templates');
      await v2.customStatement('DELETE FROM vehicles');
      await v2.customStatement(
        'ALTER TABLE session_vehicles DROP COLUMN quantity',
      );
      await v2.customStatement(
        "INSERT INTO vehicles (id, name, type) VALUES ('old-kari', 'kari', "
        "'MULTIROTOR')",
      );
      // Its old v1 checklist with the placeholder item.
      await v2.customStatement(
        "INSERT INTO vehicle_checklist_templates (id, vehicle_id, version) "
        "VALUES ('old-tpl', 'old-kari', 1)",
      );
      await v2.customStatement(
        "INSERT INTO checklist_items (id, template_id, section, label, "
        "response_type, sort_order) VALUES ('old-item', 'old-tpl', "
        "'General', 'Visual inspection complete', 'PASS_FAIL_NA', 0)",
      );
      // v12 added the landed battery columns.
      await v2.customStatement(
        'ALTER TABLE post_flight_notes DROP COLUMN landed_battery_voltage',
      );
      await v2.customStatement(
        'ALTER TABLE post_flight_notes DROP COLUMN landed_battery_percent',
      );
      await v2.customStatement('PRAGMA user_version = 2');
      await v2.close();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final names = (await db.vehicleDao.getActiveVehicles())
          .map((v) => v.name)
          .toList();
      // SQLite sorts case-sensitively, so compare as a set.
      expect(names, unorderedEquals(['Cerana', 'Dorsata', 'kari', 'Striver']));

      final columns = await db
          .customSelect('PRAGMA table_info(session_vehicles)')
          .get();
      expect(columns.map((c) => c.read<String>('name')), contains('quantity'));

      // The v4 data step adds the default payloads too.
      expect(await db.payloadDao.getAllPayloads(), hasLength(5));

      // The v7 step gives the older "kari" the common pre-flight checklist.
      final kariTemplate = await db.vehicleDao
          .getActiveChecklistTemplateForVehicle('old-kari');
      expect(kariTemplate, isNotNull);
      // v2 = common items (v7), v3 = + multirotor (v8), v4 = + gate (v9).
      expect(kariTemplate!.version, 4);
      final oldTemplate = await (db.select(
        db.vehicleChecklistTemplates,
      )..where((t) => t.id.equals('old-tpl'))).getSingle();
      expect(oldTemplate.isActive, isFalse);
      // Placeholder dropped: exactly common + multirotor + gate items.
      expect(
        await db.vehicleDao.getChecklistItemsForTemplate(kariTemplate.id),
        hasLength(preflightChecklistFor('MULTIROTOR').length),
      );

      // The v5 step creates the equipment tables and lists; the existing
      // "kari" gets Kari's list.
      expect(await db.equipmentDao.getTemplateItems(), hasLength(27));
      expect(
        await db.equipmentDao.getTemplateItems(vehicleId: 'old-kari'),
        isNotEmpty,
      );
    },
  );
}
