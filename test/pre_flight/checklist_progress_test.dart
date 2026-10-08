import 'package:flutter_test/flutter_test.dart';
import 'package:the_audit/core/database/seed/checklists.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/pre_flight/presentation/pre-flight.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';

ChecklistItemEntity item(
  String id, {
  String type = ChecklistResponseTypes.passFail,
  bool blocks = true,
}) => ChecklistItemEntity(
  id: id,
  templateId: 't',
  section: 'S',
  label: id,
  responseType: type,
  isRequired: true,
  blocksArming: blocks,
  sortOrder: 0,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ChecklistResponseWithItemEntity answer(
  ChecklistItemEntity item,
  String response, {
  String? valueText,
  double? valueNumber,
}) => ChecklistResponseWithItemEntity(
  checklistItem: item,
  checklistResponse: ChecklistResponseEntity(
    id: 'r-${item.id}',
    flightId: 'f',
    itemId: item.id,
    response: response,
    valueText: valueText,
    valueNumber: valueNumber,
    createdBy: 'u',
    responseAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

void main() {
  test('Pass clears a blocking item; Fail and N/A keep it blocked', () {
    final pass = item('pass');
    final fail = item('fail');
    final na = item('na', type: ChecklistResponseTypes.passNa);
    final open = item('open');
    final progress = ChecklistProgress([
      answer(pass, 'PASS'),
      answer(fail, 'FAIL'),
      answer(na, 'NA'),
    ], {});

    expect(progress.isBlocking(pass), isFalse);
    expect(progress.isBlocking(fail), isTrue);
    expect(progress.isBlocking(na), isTrue);
    expect(progress.isBlocking(open), isTrue);
    expect(progress.isAnswered(open), isFalse);
  });

  test('items that do not block arming never count as blocking', () {
    final optional = item('optional', blocks: false);
    final progress = ChecklistProgress([answer(optional, 'FAIL')], {});
    expect(progress.isBlocking(optional), isFalse);
    expect(progress.isAnswered(optional), isTrue);
  });

  test('a number item follows what is typed before it is saved', () {
    final voltage = item('voltage', type: ChecklistResponseTypes.number);
    final typed = <String, String>{};
    final progress = ChecklistProgress([], typed);

    expect(progress.isBlocking(voltage), isTrue);
    typed['voltage'] = '25.2';
    expect(progress.isBlocking(voltage), isFalse);
    expect(progress.isAnswered(voltage), isTrue);
    typed['voltage'] = '';
    expect(progress.isBlocking(voltage), isTrue);
  });

  test('saved numbers show without a trailing .0', () {
    final voltage = item('voltage', type: ChecklistResponseTypes.number);
    final rssi = item('rssi', type: ChecklistResponseTypes.number);
    final progress = ChecklistProgress([
      answer(voltage, 'VALUE', valueNumber: 12),
      answer(rssi, 'VALUE', valueNumber: 25.2),
    ], {});
    expect(progress.savedValue('voltage'), '12');
    expect(progress.savedValue('rssi'), '25.2');
  });
}
