import 'export_generation_service.dart';

abstract class ExportShareService {
  Future<void> shareExport(ExportArtifact artifact);
}
