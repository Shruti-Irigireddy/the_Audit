class PreFieldEquipmentEntity {
  final String id;
  final String name;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreFieldEquipmentEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}
