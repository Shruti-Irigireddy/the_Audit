class ExportArtifact {
  final String entityType;
  final String entityId;
  final String exportFormat;
  final String filePath;
  final DateTime generatedAt;

  const ExportArtifact({
    required this.entityType,
    required this.entityId,
    required this.exportFormat,
    required this.filePath,
    required this.generatedAt,
  });
}

abstract class ExportGenerationService {
  Future<ExportArtifact> generateSessionExport({
    required String sessionId,
    required String exportFormat,
  });

  Future<ExportArtifact> generateFlightExport({
    required String flightId,
    required String exportFormat,
  });
}
