import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/export/domain/entities/export_entity.dart';

extension ExportDbMapper on ExportRecord {
  ExportEntity toEntity() {
    return ExportEntity(
      id: id,
      entityType: entityType,
      entityId: entityId,
      exportFormat: exportFormat,
      exportLocation: exportLocation,
      exportStatus: exportStatus,
      generatedBy: generatedBy,
      retryCount: retryCount,
      lastAttemptAt: lastAttemptAt,
      errorMessage: errorMessage,
      generatedAt: generatedAt,
    );
  }
}
