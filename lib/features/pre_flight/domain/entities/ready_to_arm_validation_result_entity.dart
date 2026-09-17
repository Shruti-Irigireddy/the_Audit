import 'blocking_checklist_issue_entity.dart';
import 'checklist_override_entity.dart';

class ReadyToArmValidationResultEntity {
  final bool canProceed;
  final List<BlockingChecklistIssueEntity> missingItems;
  final List<BlockingChecklistIssueEntity> failedItems;
  final List<ChecklistOverrideEntity> overrides;

  const ReadyToArmValidationResultEntity ({
    required this.canProceed,
    required this.missingItems,
    required this.failedItems,
    required this.overrides,
  });
}