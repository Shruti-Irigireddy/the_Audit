class RecordAmendmentDraft {
  final String id;
  final String entityType;
  final String entityId;
  final String amendmentText;
  final String createdBy;

  const RecordAmendmentDraft({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.amendmentText,
    required this.createdBy,
  });
}
