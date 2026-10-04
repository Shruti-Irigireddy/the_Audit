/// One line of a session's equipment snapshot, built by Create session.
class SessionEquipmentDraft {
  /// Null = Tools.
  final String? sessionVehicleId;
  final String? templateItemId;
  final String category;
  final String name;
  final int? quantity;
  final int? spares;
  final bool isPacked;
  final int categoryOrder;
  final int sortOrder;

  const SessionEquipmentDraft({
    required this.sessionVehicleId,
    required this.templateItemId,
    required this.category,
    required this.name,
    required this.quantity,
    required this.spares,
    required this.isPacked,
    required this.categoryOrder,
    required this.sortOrder,
  });
}
