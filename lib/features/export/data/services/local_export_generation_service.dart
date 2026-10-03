import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/export/domain/services/export_generation_service.dart';
import 'package:the_audit/features/records/domain/entities/record_entity.dart';
import 'package:the_audit/features/records/domain/repositories/records_repository.dart';

class LocalExportGenerationService implements ExportGenerationService {
  static const _log = AppLogger('LocalExportGenerationService');

  final RecordRepository _recordRepository;

  const LocalExportGenerationService(this._recordRepository);

  @override
  Future<ExportArtifact> generateSessionExport({
    required String sessionId,
    required String exportFormat,
  }) {
    return _log.trace('generateSessionExport', () async {
      final format = _normalizeFormat(exportFormat);
      final record = await _recordRepository.getSessionRecordView(sessionId);
      _log.d(
        'session $sessionId: ${record.sorties.length} sorties, '
        '${record.auditTrail.length} audit events',
      );
      final content = switch (format) {
        'CSV' => utf8.encode(_buildSessionCsv(record)),
        'PDF' => _buildSimplePdf(_buildSessionReportText(record)),
        _ => throw Exception('Unsupported export format: $exportFormat'),
      };

      final filePath = await _writeExportFile(
        fileName: 'session_$sessionId.${format.toLowerCase()}',
        content: content,
      );
      _log.i(
        'session export $format written: $filePath (${content.length} bytes)',
      );

      return ExportArtifact(
        entityType: 'FIELD_SESSION',
        entityId: sessionId,
        exportFormat: format,
        filePath: filePath,
        generatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<ExportArtifact> generateFlightExport({
    required String flightId,
    required String exportFormat,
  }) {
    return _log.trace('generateFlightExport', () async {
      final format = _normalizeFormat(exportFormat);
      final sortie = await _recordRepository.getSortieById(flightId);

      if (sortie == null) {
        throw Exception('Flight not found: $flightId');
      }

      final responses = await _recordRepository.getChecklistResponsesForFlight(
        flightId,
      );
      final overrides = await _recordRepository.getOverridesForFlight(flightId);
      final note = await _recordRepository.getPostFlightNoteForFlight(flightId);
      final batteries = await _recordRepository.getSortieBatteries(flightId);
      final payloads = await _recordRepository.getSortiePayloads(flightId);
      final users = await _recordRepository.getSortieUsers(flightId);
      _log.d(
        'flight $flightId: ${responses.length} responses, '
        '${overrides.length} overrides, ${batteries.length} batteries, '
        '${payloads.length} payloads, ${users.length} users',
      );

      final content = switch (format) {
        'CSV' => utf8.encode(
          _buildFlightCsv(
            sortie: sortie,
            users: users,
            payloads: payloads,
            batteries: batteries,
            responses: responses,
            overrides: overrides,
            note: note,
          ),
        ),
        'PDF' => _buildSimplePdf(
          _buildFlightReportText(
            sortie: sortie,
            users: users,
            payloads: payloads,
            batteries: batteries,
            responses: responses,
            overrides: overrides,
            note: note,
          ),
        ),
        _ => throw Exception('Unsupported export format: $exportFormat'),
      };

      final filePath = await _writeExportFile(
        fileName: 'flight_$flightId.${format.toLowerCase()}',
        content: content,
      );
      _log.i(
        'flight export $format written: $filePath (${content.length} bytes)',
      );

      return ExportArtifact(
        entityType: 'SORTIE',
        entityId: flightId,
        exportFormat: format,
        filePath: filePath,
        generatedAt: DateTime.now(),
      );
    });
  }

  String _buildSessionCsv(SessionRecordViewEntity record) {
    final rows = <List<Object?>>[
      ['section', 'id', 'field', 'value'],
      ['session', record.session.sessionId, 'date', record.session.date],
      [
        'session',
        record.session.sessionId,
        'location',
        record.session.locationName,
      ],
      [
        'session',
        record.session.sessionId,
        'missionType',
        record.session.missionType,
      ],
      [
        'session',
        record.session.sessionId,
        'status',
        record.session.sessionStatus,
      ],
      for (final user in record.sessionUsers)
        ['sessionUser', user.id, 'role', user.role],
      for (final vehicle in record.sessionVehicles)
        ['sessionVehicle', vehicle.id, 'vehicle', vehicle.vehicle.name],
      for (final battery in record.sessionBatteries)
        ['sessionBattery', battery.id, 'battery', battery.battery.batteryId],
      for (final sortie in record.sorties)
        ['sortie', sortie.flightId, 'status', sortie.flightStatus],
      for (final event in record.auditTrail)
        ['audit', event.id, event.action, event.performedAt],
    ];

    return rows.map(_csvRow).join('\n');
  }

  String _buildFlightCsv({
    required SortieEntity sortie,
    required List<SortieUserWithUserEntity> users,
    required List<SortiePayloadWithPayloadEntity> payloads,
    required List<SortieBatteryWithBatteryEntity> batteries,
    required List<ChecklistResponseWithItemEntity> responses,
    required List<ChecklistOverrideEntity> overrides,
    required PostFlightNoteEntity? note,
  }) {
    final rows = <List<Object?>>[
      ['section', 'id', 'field', 'value'],
      ['sortie', sortie.flightId, 'sessionId', sortie.sessionId],
      ['sortie', sortie.flightId, 'status', sortie.flightStatus],
      ['sortie', sortie.flightId, 'objective', sortie.objective],
      for (final user in users) ['user', user.id, user.role, user.user.name],
      for (final payload in payloads)
        ['payload', payload.id, 'payload', payload.payload.name],
      for (final battery in batteries)
        ['battery', battery.id, 'battery', battery.battery.batteryId],
      for (final response in responses)
        ['checklist', response.id, response.item.label, response.response],
      for (final override in overrides)
        ['override', override.id, override.itemId, override.overrideReason],
      if (note != null)
        ['postFlight', note.id, 'objectiveResult', note.objectiveResult],
      if (note != null) ['postFlight', note.id, 'notes', note.notes],
    ];

    return rows.map(_csvRow).join('\n');
  }

  String _buildSessionReportText(SessionRecordViewEntity record) {
    return [
      'The Audit - Session Report',
      'Session: ${record.session.sessionId}',
      'Date: ${record.session.date}',
      'Location: ${record.session.locationName}',
      'Mission: ${record.session.missionType}',
      'Status: ${record.session.sessionStatus}',
      '',
      'Vehicles: ${record.sessionVehicles.length}',
      'Batteries: ${record.sessionBatteries.length}',
      'Sorties: ${record.sorties.length}',
      'Audit events: ${record.auditTrail.length}',
    ].join('\n');
  }

  String _buildFlightReportText({
    required SortieEntity sortie,
    required List<SortieUserWithUserEntity> users,
    required List<SortiePayloadWithPayloadEntity> payloads,
    required List<SortieBatteryWithBatteryEntity> batteries,
    required List<ChecklistResponseWithItemEntity> responses,
    required List<ChecklistOverrideEntity> overrides,
    required PostFlightNoteEntity? note,
  }) {
    return [
      'The Audit - Flight Report',
      'Flight: ${sortie.flightId}',
      'Session: ${sortie.sessionId}',
      'Status: ${sortie.flightStatus}',
      'Objective: ${sortie.objective ?? ''}',
      '',
      'Crew: ${users.length}',
      'Payloads: ${payloads.length}',
      'Batteries: ${batteries.length}',
      'Checklist responses: ${responses.length}',
      'Overrides: ${overrides.length}',
      'Post-flight result: ${note?.objectiveResult ?? ''}',
    ].join('\n');
  }

  Future<String> _writeExportFile({
    required String fileName,
    required List<int> content,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(content, flush: true);
    return file.path;
  }

  String _normalizeFormat(String exportFormat) {
    final value = exportFormat.trim().toUpperCase();

    if (value != 'PDF' && value != 'CSV') {
      throw Exception('Export format must be PDF or CSV.');
    }

    return value;
  }

  String _csvRow(List<Object?> values) {
    return values.map(_csvCell).join(',');
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  List<int> _buildSimplePdf(String text) {
    final safeLines = text
        .split('\n')
        .map(
          (line) => line
              .replaceAll('\\', r'\\')
              .replaceAll('(', r'\(')
              .replaceAll(')', r'\)'),
        )
        .toList();
    final content = StringBuffer('BT /F1 12 Tf 50 780 Td ');

    for (var i = 0; i < safeLines.length; i++) {
      if (i > 0) {
        content.write('0 -16 Td ');
      }
      content.write('(${safeLines[i]}) Tj ');
    }

    content.write('ET');
    final stream = content.toString();
    final objects = <String>[
      '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n',
      '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n',
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj\n',
      '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n',
      '5 0 obj << /Length ${stream.length} >> stream\n$stream\nendstream endobj\n',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];

    for (final object in objects) {
      offsets.add(buffer.length);
      buffer.write(object);
    }

    final xrefOffset = buffer.length;
    buffer.write('xref\n0 ${objects.length + 1}\n');
    buffer.write('0000000000 65535 f \n');

    for (final offset in offsets.skip(1)) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }

    buffer.write('trailer << /Size ${objects.length + 1} /Root 1 0 R >>\n');
    buffer.write('startxref\n$xrefOffset\n%%EOF');

    return ascii.encode(buffer.toString());
  }
}
