import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite3/open.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_state.dart';
import 'package:the_audit/features/pre_flight/presentation/pre-flight.dart';

class _MockAuthCubit extends Mock implements AuthCubit {}

void main() {
  // Some Linux hosts only ship the versioned library name.
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  late AppDatabase db;
  late String flightId;
  final auth = _MockAuthCubit();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
    flightId = await db.preFlightDao.createSortie(
      sessionId: sessionId,
      sessionVehicleId: sessionVehicleId,
      picUserId: 'u1',
      performedBy: 'u1',
    );
    when(() => auth.state).thenReturn(
      const AuthState(
        viewStatus: AuthViewStatus.authenticated,
        isLoggedIn: true,
        uid: 'u1',
        email: 'tester@example.com',
        errorMessage: null,
      ),
    );
  });

  tearDown(() => db.close());

  int stillBlocked(WidgetTester tester) {
    final text = tester
        .widgetList<Text>(find.textContaining('Arming blocked:'))
        .single
        .data!;
    return int.parse(RegExp(r'Arming blocked: (\d+) of').firstMatch(text)![1]!);
  }

  testWidgets('answering a blocking item updates the arming count', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: PreFlightChecklistPage(
            database: db,
            authCubit: auth,
            flightId: flightId,
          ),
        ),
      );
      // Let the checklist load from the database.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final before = stillBlocked(tester);
    expect(before, greaterThan(0));

    // Documentation opens first: "Airspace & permissions OK" is a blocking
    // Pass-only item.
    final airspace = find.ancestor(
      of: find.text('Airspace & permissions OK for site'),
      matching: find.byType(Card),
    );
    final pass = find.descendant(of: airspace, matching: find.text('Pass'));
    await tester.ensureVisible(pass);
    await tester.pump();
    await tester.tap(pass);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    // Back to the top, where the arming bar is.
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pump();
    expect(stillBlocked(tester), before - 1);
    final saved = await tester.runAsync(
      () => db.preFlightDao.getChecklistResponsesForFlight(flightId),
    );
    expect(saved!.single.response.response, 'PASS');
  });
}
