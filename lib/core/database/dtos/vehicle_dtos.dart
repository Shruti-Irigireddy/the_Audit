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
