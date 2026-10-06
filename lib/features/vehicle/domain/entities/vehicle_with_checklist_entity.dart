import 'vehicle_entity.dart';
import 'vehicle_checklist_template_entity.dart';
import 'checklist_item_entity.dart';

class VehicleWithChecklistEntity {
  final VehicleEntity vehicle;
  final VehicleChecklistTemplateEntity? activeTemplate;
  final List<ChecklistItemEntity> checklistItems;

  const VehicleWithChecklistEntity({
    required this.vehicle,
    required this.activeTemplate,
    required this.checklistItems,
  });
}
