import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/features/pre_flight/domain/entities/pre_flight_setup_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/ready_to_arm_validation_result_entity.dart';
import 'package:the_audit/features/pre_flight/domain/repositories/pre_flight_repository.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_cubit.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_state.dart';

import 'checklist_progress_test.dart' show answer, item;

class _MockRepository extends Mock implements PreFlightRepository {}

class _FakeSetup extends Fake implements PreFlightSetupEntity {}

void main() {
  late _MockRepository repo;
  late PreFlightCubit cubit;
  final gps = item('gps');

  const ready = ReadyToArmValidationResultEntity(
    canProceed: true,
    missingItems: [],
    failedItems: [],
    overrides: [],
  );

  void stubSave({Object? error}) {
    final call = when(
      () => repo.saveChecklistResponse(
        flightId: any(named: 'flightId'),
        itemId: any(named: 'itemId'),
        response: any(named: 'response'),
        valueText: any(named: 'valueText'),
        valueNumber: any(named: 'valueNumber'),
        notes: any(named: 'notes'),
        createdBy: any(named: 'createdBy'),
      ),
    );
    if (error == null) {
      call.thenAnswer((_) async {});
    } else {
      call.thenThrow(error);
    }
  }

  Future<void> save(String response) => cubit.saveChecklistResponse(
    flightId: 'f',
    itemId: 'gps',
    response: response,
    createdBy: 'u',
  );

  setUp(() async {
    repo = _MockRepository();
    when(() => repo.getSortieById('f')).thenAnswer((_) async => null);
    when(
      () => repo.getPreFlightSetup('f'),
    ).thenAnswer((_) async => _FakeSetup());
    when(() => repo.getSortieUsers('f')).thenAnswer((_) async => []);
    when(() => repo.getSortiePayloads('f')).thenAnswer((_) async => []);
    when(() => repo.getSortieBatteries('f')).thenAnswer((_) async => []);
    when(() => repo.loadChecklistForSortie('f')).thenAnswer((_) async => [gps]);
    when(
      () => repo.getChecklistResponsesForFlight('f'),
    ).thenAnswer((_) async => []);
    when(() => repo.getOverridesForFlight('f')).thenAnswer((_) async => []);
    when(() => repo.validateReadyToArm('f')).thenAnswer((_) async => ready);
    when(
      () => repo.validatePreflightCompletion('f'),
    ).thenAnswer((_) async => []);

    cubit = PreFlightCubit(repo);
    await cubit.loadSetup('f');
  });

  tearDown(() => cubit.close());

  test('an answer updates in place, with no loading or saving state', () async {
    stubSave();
    when(
      () => repo.getChecklistResponsesForFlight('f'),
    ).thenAnswer((_) async => [answer(gps, 'PASS')]);

    final states = <PreFlightState>[];
    final sub = cubit.stream.listen(states.add);
    await save('PASS');
    // Let the stream deliver the last state before stopping.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    // Shown at once (optimistic), then confirmed with the arming check.
    expect(states, hasLength(2));
    expect(states.first.checklistResponses.single.checklistResponse.response,
        'PASS');
    expect(
      states.map((s) => s.viewStatus),
      everyElement(
        isNot(anyOf(PreFlightViewStatus.loading, PreFlightViewStatus.saving)),
      ),
    );
    expect(cubit.state.readyToArmValidation?.canProceed, isTrue);
    // No full reload of the sortie after the answer.
    verify(() => repo.getSortieUsers('f')).called(1);
  });

  test('a failed save puts the answer back and shows a friendly error', () async {
    stubSave(error: const AppFailure('Sortie is not editable.'));

    await save('PASS');

    expect(cubit.state.checklistResponses, isEmpty);
    expect(cubit.state.errorMessage, 'Sortie is not editable.');
  });
}
