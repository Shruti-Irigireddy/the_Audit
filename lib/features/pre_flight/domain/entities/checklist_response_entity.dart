import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';

class ChecklistResponseEntity {
  final String id;
  final String flightId;
  final String itemId;
  final String response;
  final String? valueText;
  final double? valueNumber;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistResponseEntity ({
    required this.id,
    required this.flightId,
    required this.itemId,
    required this.response,
    this.valueText,
    this.valueNumber,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt
  });
}

class ChecklistResponseWithItemEntity {
  final ChecklistResponseEntity checklistResponse;
  final ChecklistItemEntity checklistItem;

  const ChecklistResponseWithItemEntity ({
    required this.checklistResponse,
    required this.checklistItem,
  });
}