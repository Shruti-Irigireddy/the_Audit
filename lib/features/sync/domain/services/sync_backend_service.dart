import 'package:the_audit/features/sync/domain/entities/sync_queue_entity.dart';

class SyncConflict {
  final String entityType;
  final String entityId;
  final String localVersion;
  final String remoteVersion;
  final String message;

  const SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.localVersion,
    required this.remoteVersion,
    required this.message,
  });
}

class RegistryUpdateBatch {
  final List<Map<String, Object?>> users;
  final List<Map<String, Object?>> vehicles;
  final List<Map<String, Object?>> payloads;
  final List<Map<String, Object?>> batteries;
  final List<Map<String, Object?>> checklistTemplates;
  final List<Map<String, Object?>> checklistItems;

  const RegistryUpdateBatch({
    this.users = const [],
    this.vehicles = const [],
    this.payloads = const [],
    this.batteries = const [],
    this.checklistTemplates = const [],
    this.checklistItems = const [],
  });
}

abstract class SyncBackendService {
  Future<void> pushSyncItem(SyncQueueEntity item);

  Future<List<Map<String, Object?>>> pullRemoteChanges({
    DateTime? changedAfter,
  });

  Future<List<SyncConflict>> detectConflicts({
    required List<SyncQueueEntity> localItems,
  });

  Future<void> resolveConflict({
    required SyncConflict conflict,
    required String resolution,
  });

  Future<RegistryUpdateBatch> downloadRegistryAndTemplateUpdates({
    DateTime? changedAfter,
  });
}
