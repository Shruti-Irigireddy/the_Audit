class ChecklistOverrideEntity {
  final String id;
  final String flightId;
  final String itemId;
  final String checklistResponseId;
  final String overrideReason;
  final String overriddenBy;
  final DateTime createdAt;

  const ChecklistOverrideEntity({
    required this.id,
    required this.flightId,
    required this.itemId,
    required this.checklistResponseId,
    required this.overrideReason,
    required this.overriddenBy,
    required this.createdAt,
  });
}
