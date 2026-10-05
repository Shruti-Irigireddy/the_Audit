class ChecklistItemEntity {
  final String id;
  final String templateId;
  final String section;
  final String label;
  final String responseType;
  final bool isRequired;
  final bool blocksArming;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistItemEntity ({
    required this.id,
    required this.templateId,
    required this.section,
    required this.label,
    required this.responseType,
    required this.isRequired,
    required this.blocksArming,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}
