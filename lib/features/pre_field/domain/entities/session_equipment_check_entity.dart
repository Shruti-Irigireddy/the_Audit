import 'pre_field_equipment_entity.dart';

class SessionEquipmentCheckEntity {
  final String id;
  final String sessionId;
  final String equipmentId;
  final bool isPacked;
  final String? notes;
  final DateTime checkedAt;
  final String checkedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionEquipmentCheckEntity({
    required this.id,
    required this.sessionId,
    required this.equipmentId,
    required this.isPacked,
    required this.checkedAt,
    required this.checkedBy,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });
}

class SessionEquipmentCheckWithItemEntity {
  final SessionEquipmentCheckEntity sessionEquipmentCheck;
  final PreFieldEquipmentEntity equipmentList;

  const SessionEquipmentCheckWithItemEntity({
    required this.sessionEquipmentCheck,
    required this.equipmentList,
  });
}
