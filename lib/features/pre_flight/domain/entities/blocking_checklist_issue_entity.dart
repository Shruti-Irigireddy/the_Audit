import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';

class BlockingChecklistIssueEntity {
  final ChecklistItemEntity checklistItem;
  final ChecklistResponseEntity? checklistResponse;
  final bool hasOverride;
  final String reason;

  const BlockingChecklistIssueEntity ({
    required this.checklistItem,
    this.checklistResponse,
    required this.hasOverride,
    required this.reason,
  });
}
