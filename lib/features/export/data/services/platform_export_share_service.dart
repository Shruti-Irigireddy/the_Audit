import 'package:flutter/services.dart';

import 'package:the_audit/features/export/domain/services/export_generation_service.dart';
import 'package:the_audit/features/export/domain/services/export_share_service.dart';

class PlatformExportShareService implements ExportShareService {
  static const MethodChannel _channel = MethodChannel('the_audit/export_share');

  const PlatformExportShareService();

  @override
  Future<void> shareExport(ExportArtifact artifact) {
    return _channel.invokeMethod<void>('shareExport', {
      'entityType': artifact.entityType,
      'entityId': artifact.entityId,
      'exportFormat': artifact.exportFormat,
      'filePath': artifact.filePath,
    });
  }
}
