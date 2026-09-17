import 'package:the_audit/features/export/domain/entities/export_entity.dart';
import 'package:the_audit/features/export/domain/services/export_generation_service.dart';

enum ExportStatus { initial, loading, loaded, generating, sharing, failure }

class ExportState {
  final ExportStatus status;
  final List<ExportEntity> pendingExports;
  final List<ExportEntity> inProgressExports;
  final List<ExportEntity> failedExports;
  final List<ExportEntity> completedExports;
  final List<ExportEntity> entityExports;
  final ExportEntity? selectedExport;
  final ExportArtifact? latestArtifact;
  final int pendingCount;
  final int failedCount;
  final String? errorMessage;

  const ExportState({
    this.status = ExportStatus.initial,
    this.pendingExports = const [],
    this.inProgressExports = const [],
    this.failedExports = const [],
    this.completedExports = const [],
    this.entityExports = const [],
    this.selectedExport,
    this.latestArtifact,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.errorMessage,
  });

  bool get isBusy =>
      status == ExportStatus.loading ||
      status == ExportStatus.generating ||
      status == ExportStatus.sharing;

  ExportState copyWith({
    ExportStatus? status,
    List<ExportEntity>? pendingExports,
    List<ExportEntity>? inProgressExports,
    List<ExportEntity>? failedExports,
    List<ExportEntity>? completedExports,
    List<ExportEntity>? entityExports,
    ExportEntity? selectedExport,
    bool clearSelectedExport = false,
    ExportArtifact? latestArtifact,
    bool clearLatestArtifact = false,
    int? pendingCount,
    int? failedCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExportState(
      status: status ?? this.status,
      pendingExports: pendingExports ?? this.pendingExports,
      inProgressExports: inProgressExports ?? this.inProgressExports,
      failedExports: failedExports ?? this.failedExports,
      completedExports: completedExports ?? this.completedExports,
      entityExports: entityExports ?? this.entityExports,
      selectedExport: clearSelectedExport
          ? null
          : selectedExport ?? this.selectedExport,
      latestArtifact: clearLatestArtifact
          ? null
          : latestArtifact ?? this.latestArtifact,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
