class VehicleDraft {
  final String id;
  final String name;
  final String type;
  final String? frameMake;
  final String? frameModel;
  final int? motorCount;
  final String? frameStyle;
  final String? firmwareTarget;
  final String? defaultFailSafeProfile;
  final String? notes;

  const VehicleDraft({
    required this.id,
    required this.name,
    required this.type,
    this.frameMake,
    this.frameModel,
    this.motorCount,
    this.frameStyle,
    this.firmwareTarget,
    this.defaultFailSafeProfile,
    this.notes,
  });
}

class VehicleUpdateDraft {
  final String id;
  final String? name;
  final String? type;
  final String? frameMake;
  final String? frameModel;
  final int? motorCount;
  final String? frameStyle;
  final String? firmwareTarget;
  final String? defaultFailSafeProfile;
  final String? status;
  final String? notes;

  const VehicleUpdateDraft({
    required this.id,
    this.name,
    this.type,
    this.frameMake,
    this.frameModel,
    this.motorCount,
    this.frameStyle,
    this.firmwareTarget,
    this.defaultFailSafeProfile,
    this.status,
    this.notes,
  });
}

class ChecklistItemDraft {
  final String section;
  final String label;
  final String responseType;
  final bool isRequired;
  final bool blocksArming;

  const ChecklistItemDraft({
    required this.section,
    required this.label,
    required this.responseType,
    this.isRequired = true,
    this.blocksArming = false,
  });
}

class ChecklistItemUpdateDraft {
  final String id;
  final String? section;
  final String? label;
  final String? responseType;
  final bool? isRequired;
  final bool? blocksArming;
  final int? sortOrder;
  final bool? isActive;

  const ChecklistItemUpdateDraft({
    required this.id,
    this.section,
    this.label,
    this.responseType,
    this.isRequired,
    this.blocksArming,
    this.sortOrder,
    this.isActive,
  });
}

class VehicleChecklistTemplateDraft {
  final String vehicleId;
  final List<ChecklistItemDraft> items;

  const VehicleChecklistTemplateDraft({
    required this.vehicleId,
    required this.items,
  });
}
