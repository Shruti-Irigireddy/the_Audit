import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/sync/domain/entities/sync_queue_entity.dart';

extension SyncQueueDbMapper on SyncQueueData {
  SyncQueueEntity toEntity() {
    return SyncQueueEntity(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      syncStatus: syncStatus,
      retryCount: retryCount,
      lastAttemptAt: lastAttemptAt,
      syncedAt: syncedAt,
      errorMessage: errorMessage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}