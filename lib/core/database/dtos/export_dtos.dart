class ExportRequestDraft {
  final String entityType;
  final String entityId;
  final String exportFormat;
  final String generatedBy;

  const ExportRequestDraft({
    required this.entityType,
    required this.entityId,
    required this.exportFormat,
    required this.generatedBy,
  });
}

class ExportCompletionDraft {
  final int exportId;
  final String exportLocation;
  final String performedBy;

  const ExportCompletionDraft({
    required this.exportId,
    required this.exportLocation,
    required this.performedBy,
  });
}

class ExportFailureDraft {
  final int exportId;
  final String errorMessage;

  const ExportFailureDraft({
    required this.exportId,
    required this.errorMessage,
  });
}
