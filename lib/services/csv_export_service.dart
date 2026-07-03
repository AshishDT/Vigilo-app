import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../enums/brief_type.dart';
import '../models/exam_card_data.dart';
import '../models/exam_record.dart';
import '../models/export_artifact.dart';
import '../models/session_event.dart';
import '../models/session_snapshot.dart';
import '../persistence/database.dart';
import '../utils/id_generator.dart';
import 'license_service.dart';

const String _auditExamStartedMessage = 'Exam started';
const String _auditExamEndedMessage = 'Exam ended';
const String _auditInvigilatorUpdateMessage = 'Invigilator list updated';
const String _noneValue = 'None';
const String _naValue = 'N/A';
const String _exportLogFormat = 'ERC-LOG-V1';
const String _exportGenerator = 'Vigilo ERC';
const String _exportAppVersion = '1.0';

class CsvExportService {
  final AppDatabase _db = AppDatabase();

  Future<File> exportRecordToCsv({required String examRecordId}) async {
    final snapshot = await _loadExportSnapshot(examRecordId: examRecordId);
    final record = snapshot.record;
    final events = snapshot.events;
    final exportedAtUtc = DateTime.now().toUtc();
    final logContent = _buildCsvText(
      snapshot,
      exportedAtLocal: exportedAtUtc.toLocal(),
    );
    final sessionId = _examSessionId(
      record: record,
      card: snapshot.card,
      fallbackLocal: snapshot.fallbackStartLocal,
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'erc_log_${_safeFileToken(sessionId)}_${_compactTimestamp(exportedAtUtc.toLocal())}.txt';
    final file = File('${directory.path}/$fileName');
    final logWithBom = '\uFEFF$logContent';
    await file.writeAsString(logWithBom, encoding: utf8);

    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    final artifact = ExportArtifact(
      id: generateId(),
      examRecordId: record.id,
      format: _exportLogFormat,
      fileName: fileName,
      fileHash: hash,
      eventCountAtExport: events.length,
      exportedAtUtc: exportedAtUtc,
    );

    final db = await _db.database;
    await db.transaction((txn) async {
      await _db.insertExportArtifact(txn, artifact);

      if (record.recordStatus == RecordStatus.closed) {
        final updatedRecord = record.copyWith(
          recordStatus: RecordStatus.exported,
        );
        await _db.updateExamRecord(txn, updatedRecord);
      }
    });

    return file;
  }

  Future<String> buildRecordCsvText({
    required String examRecordId,
    bool includeBom = false,
  }) async {
    final snapshot = await _loadExportSnapshot(examRecordId: examRecordId);
    final text = _buildCsvText(
      snapshot,
      exportedAtLocal: DateTime.now().toLocal(),
    );
    return includeBom ? '\uFEFF$text' : text;
  }

  Future<_ExportSnapshot> _loadExportSnapshot({
    required String examRecordId,
  }) async {
    final record = await _db.getRecord(examRecordId);
    if (record == null) {
      throw Exception('Exam record not found');
    }
    final sessionSnapshot = await _db.getSnapshot(examRecordId);
    if (sessionSnapshot == null) {
      throw Exception('Session snapshot not found');
    }

    final metadata = await _db.getMetadata(examRecordId);
    final metadataPayload = metadata?['payload_json'] as String?;
    final card = _decodeCardFromMetadata(metadataPayload);
    final events = _filteredExportEvents(await _db.getEvents(examRecordId));
    final startEvent = events.isNotEmpty ? events.first : null;
    final fallbackStartLocal =
        (startEvent?.occurredAtUtc ?? record.createdAtUtc).toLocal();
    final activeLicenseCode = LicenseService.sanitizeOrganizationCode(
      (await LicenseService.getSnapshot()).organizationCode ?? '',
    );

    return _ExportSnapshot(
      record: record,
      card: card,
      sessionSnapshot: sessionSnapshot,
      events: events,
      fallbackStartLocal: fallbackStartLocal,
      activeLicenseCode: activeLicenseCode,
    );
  }

  String _buildCsvText(
    _ExportSnapshot snapshot, {
    required DateTime exportedAtLocal,
  }) {
    final record = snapshot.record;
    final card = snapshot.card;
    final sessionSnapshot = snapshot.sessionSnapshot;
    final events = snapshot.events;
    final fallbackStartLocal = snapshot.fallbackStartLocal;
    SessionEvent? activeStartEvent;
    for (final event in events) {
      if (event.type == SessionEventType.start) {
        activeStartEvent = event;
      }
    }
    final primaryStartEvent = activeStartEvent ?? (events.isNotEmpty ? events.first : null);
    final activeStartUtc = primaryStartEvent?.occurredAtUtc;

    final normalEndEvent = activeStartUtc == null
        ? null
        : _firstEventByTypeAfter(events, SessionEventType.endNormalTime, activeStartUtc);
    final extraStartEvent = activeStartUtc == null
        ? null
        : _firstEventByTypeAfter(events, SessionEventType.startExtraTime, activeStartUtc);
    final examEndEvent = activeStartUtc == null
        ? null
        : _firstTerminationEventAfter(events, activeStartUtc);

    final organization = _organizationInfo(
      record,
      card,
      activeLicenseCode: snapshot.activeLicenseCode,
    );
    final sessionId = _examSessionId(
      record: record,
      card: card,
      fallbackLocal: fallbackStartLocal,
    );
    final exportReference = _buildExportReference(
      examSessionId: sessionId,
      exportedAtLocal: exportedAtLocal,
    );
    final actualStartLocal = (primaryStartEvent?.occurredAtUtc ?? record.createdAtUtc)
        .toLocal();
    final startType = _startType(primaryStartEvent);
    final logRows = _buildExportLogRows(snapshot);
    final actualEndLocal =
        (examEndEvent?.occurredAtUtc ?? sessionSnapshot.endedAtUtc)?.toLocal();
    final totalLoggedEvents = logRows.length;
    final totalIncidents = logRows
        .where((row) => row.category == 'Incident')
        .length;
    final totalControlActions = logRows
        .where((row) => row.category == 'Control')
        .length;
    final setUpRole = normalizeSetUpRole(card?.setUpRole);
    final exportedBy = _exportedBy(record: record, card: card);
    final userRole = setUpRole.isEmpty ? _noneValue : setUpRole;
    final normalTimeEnded = normalEndEvent == null
        ? _noneValue
        : _formatHms(normalEndEvent.occurredAtUtc.toLocal());
    final extraTimeStarted = extraStartEvent == null
        ? _naValue
        : _formatHms(extraStartEvent.occurredAtUtc.toLocal());
    final examEnded = actualEndLocal == null
        ? _noneValue
        : _formatHms(actualEndLocal);

    final buffer = StringBuffer();
    buffer.writeln('Vigilo ERC – Exam Session Export Log');
    buffer.writeln();
    buffer.writeln('Log Format: $_exportLogFormat');
    buffer.writeln('Generated by: $_exportGenerator');
    buffer.writeln('App Version: $_exportAppVersion');
    buffer.writeln();
    buffer.writeln('Export Reference: $exportReference');
    buffer.writeln('Export Time: ${_formatIsoDateTime(exportedAtLocal)}');
    buffer.writeln();
    buffer.writeln(
      'Exported By: ${_exportedByWithRole(exportedBy: exportedBy, userRole: userRole)}',
    );
    buffer.writeln();
    buffer.writeln('Organisation');
    buffer.writeln();
    buffer.writeln('Organisation Name: ${_noneIfBlank(organization.name)}');
    buffer.writeln('Centre Number: ${_noneIfBlank(organization.code)}');
    buffer.writeln();
    buffer.writeln('Exam Session');
    buffer.writeln();
    buffer.writeln('Exam Session ID: $sessionId');
    buffer.writeln('Exam Name: ${_noneIfBlank(_examName(record, card))}');
    buffer.writeln('Exam Board: ${_noneIfBlank(_examBoard(record, card))}');
    buffer.writeln(
      'Exam Date: ${_noneIfBlank(_examDate(card: card, fallbackLocal: fallbackStartLocal))}',
    );
    buffer.writeln();
    buffer.writeln('Room(s): ${_noneIfBlank(_rooms(card))}');
    buffer.writeln('Invigilator(s): ${_noneIfBlank(_invigilators(card))}');
    buffer.writeln();
    buffer.writeln('Set Up By: ${_noneIfBlank((card?.setUpBy ?? '').trim())}');
    buffer.writeln(
      'Set Up Role: ${setUpRole.isEmpty ? _noneValue : setUpRole}',
    );
    buffer.writeln();
    buffer.writeln(
      'Pre-Exam Briefings Issued: ${_noneIfBlank(_briefings(card))}',
    );
    buffer.writeln();
    buffer.writeln('Timing');
    buffer.writeln();
    buffer.writeln(
      'Scheduled Start Time: ${_noneIfBlank(_scheduledStartTime(card: card, fallbackLocal: fallbackStartLocal))}',
    );
    buffer.writeln(
      'Actual Start Time: ${_noneIfBlank(_formatHms(actualStartLocal))}',
    );
    buffer.writeln('Start Type: $startType');
    buffer.writeln(
      'Normal Time Duration: ${_noneIfBlank(_durationHms(card?.normalDuration))}',
    );
    buffer.writeln(
      'Extra Time Duration: ${_noneIfBlank(_durationHms(card?.extraTime))}',
    );
    buffer.writeln();
    buffer.writeln(
      'Actual End Time: ${actualEndLocal == null ? _noneValue : _formatHms(actualEndLocal)}',
    );
    buffer.writeln();
    buffer.writeln('Session Summary');
    buffer.writeln();
    buffer.writeln('Session Status: ${_sessionStatus(snapshot: snapshot)}');
    buffer.writeln();
    buffer.writeln('Total Logged Events: $totalLoggedEvents');
    buffer.writeln('Total Incidents: $totalIncidents');
    buffer.writeln('Total Control Actions: $totalControlActions');
    buffer.writeln();
    buffer.writeln('Normal Time Ended: $normalTimeEnded');
    buffer.writeln('Extra Time Started: $extraTimeStarted');
    buffer.writeln('Exam Ended: $examEnded');
    buffer.writeln();
    buffer.writeln('Event Log');
    buffer.writeln();
    buffer.writeln(
      'Date/Time,Category,Phase,Description,Room,Student ID,Invigilator(s),Details',
    );

    for (final row in logRows) {
      buffer.writeln(
        _csvLine([
          row.dateTime,
          row.category,
          row.phase,
          row.description,
          row.room,
          row.studentId,
          row.staffMember,
          row.details,
        ]),
      );
    }

    buffer.writeln();
    buffer.writeln('Export Integrity');
    buffer.writeln();
    buffer.writeln('Export Location: Generated locally by Vigilo ERC');
    buffer.writeln('Record Type: Exam session event log');
    buffer.writeln('Integrity Status: Complete local audit record');
    buffer.writeln();
    buffer.writeln('Note:');
    buffer.writeln(
      'This record reflects the complete event log captured during the exam session.',
    );

    return buffer.toString();
  }

  ExamCardData? _decodeCardFromMetadata(String? payloadJson) {
    if (payloadJson == null || payloadJson.trim().isEmpty) return null;
    final payload = _decodePayload(payloadJson);
    if (payload.isEmpty) return null;
    try {
      return ExamCardData.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  String _examName(ExamRecord record, ExamCardData? card) {
    final source = (card?.subject ?? record.examName).trim();
    return _subjectNameOnly(source);
  }

  String _examBoard(ExamRecord record, ExamCardData? card) {
    final source = (card?.subject ?? record.examName).trim();
    return _subjectBoardOnly(source);
  }

  String _examDate({
    required ExamCardData? card,
    required DateTime fallbackLocal,
  }) {
    final raw = (card?.date ?? '').trim();
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(raw)) {
      final parts = raw.split('/');
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return _formatIsoDate(fallbackLocal);
  }

  String _scheduledStartTime({
    required ExamCardData? card,
    required DateTime fallbackLocal,
  }) {
    final candidates = <String>[
      (card?.normalStart ?? '').trim(),
      (card?.start ?? '').trim(),
    ];
    for (final candidate in candidates) {
      final normalized = _normalizeClock(candidate);
      if (normalized != null) {
        return normalized;
      }
    }
    return _formatHms(fallbackLocal);
  }

  String _durationHms(String? value) {
    final raw = (value ?? '').trim();
    final parts = raw.split(':');
    if (parts.length < 2 || parts.length > 3) return '';
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    final ss = parts.length == 3 ? int.tryParse(parts[2]) : 0;
    if (hh == null || mm == null || ss == null) return '';
    if (hh < 0 || mm < 0 || mm > 59 || ss < 0 || ss > 59) return '';
    final hhText = hh.toString().padLeft(2, '0');
    final mmText = mm.toString().padLeft(2, '0');
    final ssText = ss.toString().padLeft(2, '0');
    return '$hhText:$mmText:$ssText';
  }

  String _rooms(ExamCardData? card) {
    if (card == null) return '';
    if (card.roomsSnapshot.trim().isNotEmpty) return card.roomsSnapshot.trim();

    final rooms = <String>{
      for (final schedule in card.scheduleList ?? const [])
        if (schedule.room.trim().isNotEmpty) schedule.room.trim(),
    }.toList()..sort();
    return rooms.join(', ');
  }

  String _invigilators(ExamCardData? card) {
    if (card == null) return '';
    if (card.invigilatorsSnapshot.trim().isNotEmpty) {
      return card.invigilatorsSnapshot.trim();
    }

    final invigilators = <String>{
      for (final schedule in card.scheduleList ?? const [])
        for (final invigilator in schedule.invigilators)
          if (invigilator.trim().isNotEmpty) invigilator.trim(),
    }.toList()..sort();
    return invigilators.join(', ');
  }

  String _briefings(ExamCardData? card) {
    if (card == null) return '';
    final briefings = card.briefings;
    if (briefings == null || briefings.isEmpty) return '';

    final entries = <String>[];
    for (final briefing in briefings) {
      final title = briefing.title.trim();
      if (title.isEmpty) continue;
      final typeLabel = briefing.type == BriefType.pdf ? 'PDF' : 'Photo';
      entries.add('$title ($typeLabel)');
    }
    return entries.join(', ');
  }

  _OrganizationInfo _organizationInfo(
    ExamRecord record,
    ExamCardData? card, {
    required String activeLicenseCode,
  }) {
    final source = (card?.school ?? record.examCenter ?? '').trim();
    final legacy = _splitTrailingMetadata(source);
    final name = card == null
        ? legacy.$1
        : _readText(card.organizationName).isEmpty
        ? legacy.$1
        : card.organizationName;
    String code = card?.resolvedCentreNumber.trim() ?? legacy.$2;

    if ((card?.centreNumber.trim().isEmpty ?? true) &&
        _matchesActiveLicenseCode(
          candidate: code,
          activeLicenseCode: activeLicenseCode,
        )) {
      code = '';
    }

    return _OrganizationInfo(name: name.trim(), code: code.trim());
  }

  String _examSessionId({
    required ExamRecord record,
    required ExamCardData? card,
    required DateTime fallbackLocal,
  }) {
    final dateToken = _examDate(
      card: card,
      fallbackLocal: fallbackLocal,
    ).replaceAll('-', '');
    final roomToken = _primaryRoomToken(card);
    final digest = sha256.convert(utf8.encode(record.id)).bytes;
    final sequenceValue = ((digest[0] << 8) + digest[1]) % 1000 + 1;
    final sequence = sequenceValue.toString().padLeft(3, '0');
    if (roomToken == null) {
      return 'ERC-$dateToken-$sequence';
    }
    return 'ERC-$dateToken-$roomToken-$sequence';
  }

  String? _primaryRoomToken(ExamCardData? card) {
    final roomSource = _rooms(card);
    if (roomSource.trim().isEmpty) return null;
    final firstRoom = roomSource.split(',').first.trim().toUpperCase();
    final token = firstRoom
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return token.isEmpty ? null : token;
  }

  String _buildExportReference({
    required String examSessionId,
    required DateTime exportedAtLocal,
  }) {
    return 'EXP-$examSessionId-${_compactDate(exportedAtLocal)}-${_compactClock(exportedAtLocal)}';
  }

  String _safeFileToken(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'export_log' : normalized;
  }

  String _compactTimestamp(DateTime local) {
    return '${_compactDate(local)}_${_compactClock(local)}';
  }

  String _compactDate(DateTime local) {
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  String _compactClock(DateTime local) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh$mm$ss';
  }

  String _startType(SessionEvent? startEvent) {
    final payload = _decodePayload(startEvent?.payloadJson);
    return payload['autoStart'] == true ? 'Auto' : 'Manual';
  }

  List<_ExportLogRow> _buildExportLogRows(_ExportSnapshot snapshot) {
    final events = snapshot.events;
    if (events.isEmpty) return const <_ExportLogRow>[];

    final startEvent = events.isNotEmpty ? events.first : null;
    final extraStartEvent = _firstEventByType(
      events,
      SessionEventType.startExtraTime,
    );
    final startUtc = startEvent?.occurredAtUtc;
    final extraStartUtc = extraStartEvent?.occurredAtUtc;
    final fallbackRoom = _rooms(snapshot.card);
    final fallbackStaff = _invigilators(snapshot.card).replaceAll(', ', ' / ');

    final rows = <_ExportLogRow>[];
    for (final event in events) {
      final payload = _decodePayload(event.payloadJson);
      final incidentMap = _incidentPayload(payload);
      final incidentDetails = incidentMap == null
          ? ''
          : _incidentDetails(incidentMap);
      final staffMember = incidentMap == null
          ? (event.type == SessionEventType.start ? fallbackStaff : '')
          : _readText(incidentMap['staffMember']);

      rows.add(
        _ExportLogRow(
          dateTime: _formatIsoDateTime(event.occurredAtUtc.toLocal()),
          category: _eventCategoryLabel(event),
          phase: _eventPhaseLabel(
            event: event,
            startUtc: startUtc,
            extraStartUtc: extraStartUtc,
          ),
          description: _eventLogDescription(event, payload),
          room: incidentMap == null
              ? fallbackRoom
              : _readText(incidentMap['room']).isEmpty
              ? fallbackRoom
              : _readText(incidentMap['room']),
          studentId: incidentMap == null
              ? ''
              : _readText(incidentMap['studentID']),
          staffMember: staffMember,
          details: incidentDetails.isNotEmpty
              ? incidentDetails
              : _eventLogDetail(event, payload),
        ),
      );
    }

    return rows;
  }

  String _eventCategoryLabel(SessionEvent event) {
    switch (event.type) {
      case SessionEventType.start:
      case SessionEventType.endNormalTime:
      case SessionEventType.startExtraTime:
      case SessionEventType.end:
      case SessionEventType.recoveryAutoEnd:
        return 'Core';
      case SessionEventType.pause:
      case SessionEventType.resume:
      case SessionEventType.controlAction:
      case SessionEventType.checkpoint:
      case SessionEventType.recoveredAfterTermination:
        return 'Control';
      case SessionEventType.incident:
        return 'Incident';
    }
  }

  String _eventPhaseLabel({
    required SessionEvent event,
    required DateTime? startUtc,
    required DateTime? extraStartUtc,
  }) {
    if (event.type == SessionEventType.startExtraTime) {
      return 'Extra Time';
    }
    if (event.type == SessionEventType.endNormalTime) {
      return 'Normal Time';
    }
    if (startUtc == null || event.occurredAtUtc.isBefore(startUtc)) {
      return 'System';
    }
    if (extraStartUtc != null && !event.occurredAtUtc.isBefore(extraStartUtc)) {
      return 'Extra Time';
    }
    return 'Normal Time';
  }

  String _eventLogDescription(
    SessionEvent event,
    Map<String, dynamic> payload,
  ) {
    switch (event.type) {
      case SessionEventType.start:
        return _auditExamStartedMessage;
      case SessionEventType.endNormalTime:
        return 'Normal time ended';
      case SessionEventType.startExtraTime:
        return 'Extra time started';
      case SessionEventType.pause:
        return 'Exam paused';
      case SessionEventType.resume:
        return 'Exam resumed';
      case SessionEventType.end:
      case SessionEventType.recoveryAutoEnd:
        return _auditExamEndedMessage;
      case SessionEventType.incident:
        final incidentMap = _incidentPayload(payload);
        if (incidentMap == null) return 'Incident detected';
        return _incidentDescription(
          incidentType: _readText(incidentMap['incidentType']),
          message: _readText(incidentMap['message']),
          fallback: 'Incident detected',
        );
      case SessionEventType.controlAction:
        return _controlActionFields(payload).$1;
      case SessionEventType.recoveredAfterTermination:
      case SessionEventType.checkpoint:
        return '';
    }
  }

  String _eventLogDetail(SessionEvent event, Map<String, dynamic> payload) {
    switch (event.type) {
      case SessionEventType.controlAction:
        return _controlActionFields(payload).$2;
      case SessionEventType.incident:
        final detail = _readText(payload['detail']);
        if (detail.isNotEmpty) return detail;
        return '';
      default:
        return '';
    }
  }

  SessionEvent? _firstEventByType(
    List<SessionEvent> events,
    SessionEventType type,
  ) {
    for (final event in events) {
      if (event.type == type) return event;
    }
    return null;
  }

  SessionEvent? _firstTerminationEvent(List<SessionEvent> events) {
    for (final event in events) {
      if (_isTerminationEvent(event.type)) {
        return event;
      }
    }
    return null;
  }

  String _exportedBy({
    required ExamRecord record,
    required ExamCardData? card,
  }) {
    final setUpBy = (card?.setUpBy ?? '').trim();
    if (setUpBy.isNotEmpty) return setUpBy;
    final createdBy = (record.createdBy ?? '').trim();
    if (createdBy.isNotEmpty) return createdBy;
    return _noneValue;
  }

  String _exportedByWithRole({
    required String exportedBy,
    required String userRole,
  }) {
    if (userRole.trim().isEmpty || userRole == _noneValue) {
      return exportedBy;
    }
    return '$exportedBy ($userRole)';
  }

  String _sessionStatus({required _ExportSnapshot snapshot}) {
    final sessionSnapshot = snapshot.sessionSnapshot;
    return sessionSnapshot.sessionStatus == SessionStatus.ended
        ? 'Completed'
        : 'Incomplete';
  }

  (String, String) _controlActionFields(Map<String, dynamic> payload) {
    final message = _payloadMessage(payload);
    final payloadDetail = _normalizeControlActionDetail(
      _readText(payload['detail']),
    );
    if (message.isEmpty) {
      return ('Control action', payloadDetail);
    }
    if (payloadDetail.isNotEmpty) {
      return (message, payloadDetail);
    }

    final split = _splitInlineDetail(message);
    if (split.$1.isNotEmpty && split.$2.isNotEmpty) {
      return (split.$1, _normalizeControlActionDetail(split.$2));
    }

    return (message, '');
  }

  (String, String) _splitInlineDetail(String value) {
    final separatorIndex = value.indexOf(' - ');
    if (separatorIndex <= 0 || separatorIndex >= value.length - 3) {
      return (value.trim(), '');
    }
    return (
      value.substring(0, separatorIndex).trim(),
      value.substring(separatorIndex + 3).trim(),
    );
  }

  String _formatIsoDateTime(DateTime local) {
    return '${_formatIsoDate(local)} ${_formatHms(local)}';
  }

  String _formatIsoDate(DateTime local) {
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _formatHms(DateTime local) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String? _normalizeClock(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    final ss = parts.length == 3 ? int.tryParse(parts[2]) : 0;
    if (hh == null || mm == null || ss == null) return null;
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59 || ss < 0 || ss > 59) {
      return null;
    }
    final hhText = hh.toString().padLeft(2, '0');
    final mmText = mm.toString().padLeft(2, '0');
    final ssText = ss.toString().padLeft(2, '0');
    return '$hhText:$mmText:$ssText';
  }

  String _csvLine(List<String> values) {
    return values.map(_csvCell).join(',');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _readText(dynamic value) {
    if (value is! String) return '';
    return value.trim();
  }

  String _noneIfBlank(String value) {
    final text = value.trim();
    return text.isEmpty ? _noneValue : text;
  }

  String _subjectNameOnly(String value) {
    final trimmed = value.trim();
    final start = trimmed.lastIndexOf('(');
    final end = trimmed.lastIndexOf(')');
    if (start > 0 && end == trimmed.length - 1 && start < end) {
      return trimmed.substring(0, start).trim();
    }
    return trimmed;
  }

  String _subjectBoardOnly(String value) {
    final trimmed = value.trim();
    final start = trimmed.lastIndexOf('(');
    final end = trimmed.lastIndexOf(')');
    if (start >= 0 && end == trimmed.length - 1 && start < end) {
      return trimmed.substring(start + 1, end).trim();
    }
    return '';
  }

  String _normalizeControlActionDetail(String detail) {
    if (detail.trim().isEmpty) return '';

    switch (_normalizeAuditMessage(detail)) {
      case 'adjustment entered before start of extra time':
        return 'Adjustment entered before extra time';
      case 'adjustment entered after start of extra time':
        return 'Adjustment entered during extra time';
      default:
        return detail.trim();
    }
  }

  (String, String) _splitTrailingMetadata(String value) {
    final trimmed = value.trim();
    final start = trimmed.lastIndexOf('(');
    final end = trimmed.lastIndexOf(')');
    if (start > 0 && end == trimmed.length - 1 && start < end) {
      return (
        trimmed.substring(0, start).trim(),
        trimmed.substring(start + 1, end).trim(),
      );
    }
    return (trimmed, '');
  }

  bool _matchesActiveLicenseCode({
    required String candidate,
    required String activeLicenseCode,
  }) {
    if (candidate.trim().isEmpty || activeLicenseCode.trim().isEmpty) {
      return false;
    }

    final normalizedCandidate = LicenseService.sanitizeOrganizationCode(
      candidate,
    );
    final normalizedLicenseCode = LicenseService.sanitizeOrganizationCode(
      activeLicenseCode,
    );
    if (normalizedCandidate.isEmpty ||
        normalizedCandidate != normalizedLicenseCode) {
      return false;
    }

    return !RegExp(r'\d').hasMatch(candidate);
  }

  Map<String, dynamic>? _incidentPayload(Map<String, dynamic> payload) {
    final incident = payload['incident'];
    if (incident is Map<String, dynamic>) {
      return incident;
    }
    if (incident is Map) {
      return incident.cast<String, dynamic>();
    }
    return null;
  }

  String _incidentDescription({
    required String incidentType,
    required String message,
    required String fallback,
  }) {
    switch (_normalizeAuditMessage(incidentType)) {
      case 'toilet':
        return 'Toilet visit';
      case 'malpractice':
      case 'cheating':
        return 'Malpractice';
      case 'medical':
        return 'Medical incident';
    }

    final normalizedMessage = _normalizeAuditMessage(message);
    if (normalizedMessage == 'toilet break') return 'Toilet visit';
    if (normalizedMessage == 'malpractice' ||
        normalizedMessage == 'malpractice concern' ||
        normalizedMessage == 'suspected malpractice' ||
        normalizedMessage == 'cheating concern' ||
        normalizedMessage == 'suspected cheating') {
      return 'Malpractice';
    }
    if (normalizedMessage == 'medical incident') return 'Medical incident';
    if (message.trim().isNotEmpty) return message.trim();
    return fallback;
  }

  String _incidentDetails(Map<String, dynamic> incidentMap) {
    final duration = _readText(incidentMap['duration']);
    final detail = _readText(incidentMap['detail']);
    final action = _readText(incidentMap['action']);

    if (duration.isNotEmpty) {
      final normalizedDuration = _normalizeAuditMessage(duration);
      final durationText = normalizedDuration.contains('minute')
          ? duration
          : '$duration minutes';
      return 'Duration: $durationText';
    }

    if (detail.isNotEmpty && action.isNotEmpty) {
      final detailEndsSentence = RegExp(r'[.!?]$').hasMatch(detail);
      return detailEndsSentence ? '$detail $action' : '$detail. $action';
    }
    if (detail.isNotEmpty) return detail;
    if (action.isNotEmpty) return action;
    return '';
  }

  Map<String, dynamic> _decodePayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  List<SessionEvent> _filteredExportEvents(List<SessionEvent> events) {
    final sorted = [...events]
      ..sort((a, b) {
        final byOccurred = a.occurredAtUtc.compareTo(b.occurredAtUtc);
        if (byOccurred != 0) return byOccurred;
        return a.seqNo.compareTo(b.seqNo);
      });
    SessionEvent? anchor;
    for (final event in sorted) {
      final payload = event.payloadJson == null
          ? const <String, dynamic>{}
          : _decodePayload(event.payloadJson);
      if (event.type == SessionEventType.start || _isRestartPayload(payload)) {
        anchor = event;
        break;
      }
    }
    if (anchor == null) {
      return const <SessionEvent>[];
    }
    final recordedStartUtc = anchor.occurredAtUtc;

    SessionEvent? lastSessionStart;
    for (final event in sorted) {
      final payloadData = event.payloadJson == null
          ? const <String, dynamic>{}
          : _decodePayload(event.payloadJson);
      if (event.type == SessionEventType.start ||
          _isRestartPayload(payloadData)) {
        lastSessionStart = event;
      }
    }

    SessionEvent? manualEnd;
    SessionEvent? recoveryEnd;
    for (final event in sorted) {
      if (!_isTerminationEvent(event.type)) continue;
      if (event.occurredAtUtc.isBefore(recordedStartUtc)) continue;

      if (lastSessionStart != null &&
          event.occurredAtUtc.isBefore(lastSessionStart.occurredAtUtc)) {
        continue;
      }

      if (event.type == SessionEventType.end) {
        manualEnd ??= event;
      } else {
        recoveryEnd ??= event;
      }
    }
    final chosenTermination = manualEnd ?? recoveryEnd;

    final filtered = <SessionEvent>[];
    bool keptStart = false;
    bool keptNormalBoundary = false;
    bool keptExtraBoundary = false;
    bool keptTermination = false;

    for (final event in sorted) {
      final payload = event.payloadJson == null
          ? const <String, dynamic>{}
          : _decodePayload(event.payloadJson);

      if (_isInternalAuditEvent(event.type)) continue;
      if (_isInvigilatorUpdatePayload(payload)) continue;

      if (event.occurredAtUtc.isBefore(recordedStartUtc)) continue;
      if (chosenTermination != null &&
          event.occurredAtUtc.isAfter(chosenTermination.occurredAtUtc)) {
        continue;
      }

      switch (event.type) {
        case SessionEventType.start:
          final isRestart = payload['restart'] == true;
          if (keptStart && !isRestart) continue;
          keptStart = true;
          filtered.add(event);
          continue;
        case SessionEventType.endNormalTime:
          if (!keptStart || keptNormalBoundary) continue;
          keptNormalBoundary = true;
          filtered.add(event);
          continue;
        case SessionEventType.startExtraTime:
          if (!keptStart || !keptNormalBoundary || keptExtraBoundary) continue;
          keptExtraBoundary = true;
          filtered.add(event);
          continue;
        case SessionEventType.end:
        case SessionEventType.recoveryAutoEnd:
          if (!keptStart || keptTermination) continue;
          if (chosenTermination == null || event.id != chosenTermination.id) {
            continue;
          }
          keptTermination = true;
          filtered.add(event);
          continue;
        default:
          final isRestart = _isRestartPayload(payload);
          if (!keptStart && !isRestart) continue;
          filtered.add(event);
          if (isRestart) {
            keptStart = true;
            keptNormalBoundary = false;
            keptExtraBoundary = false;
            keptTermination = false;
          }
          continue;
      }
    }

    return filtered;
  }

  String _normalizeAuditMessage(String message) {
    return message.trim().toLowerCase();
  }

  bool _isTerminationEvent(SessionEventType type) {
    return type == SessionEventType.end ||
        type == SessionEventType.recoveryAutoEnd;
  }

  bool _isInternalAuditEvent(SessionEventType type) {
    return type == SessionEventType.checkpoint ||
        type == SessionEventType.recoveredAfterTermination;
  }

  String _formatMinutesDescription(int minutes) {
    final absMinutes = minutes.abs();
    if (absMinutes == 0) return '0 minutes';
    final hours = absMinutes ~/ 60;
    final remainingMinutes = absMinutes % 60;

    String hoursStr = '';
    if (hours > 0) {
      hoursStr = '$hours ${hours == 1 ? "hour" : "hours"}';
    }

    String minsStr = '';
    if (remainingMinutes > 0) {
      minsStr = '$remainingMinutes ${remainingMinutes == 1 ? "minute" : "minutes"}';
    }

    if (hoursStr.isNotEmpty && minsStr.isNotEmpty) {
      return '$hoursStr and $minsStr';
    } else if (hoursStr.isNotEmpty) {
      return hoursStr;
    } else {
      return minsStr;
    }
  }

  String _formatDurationWording(String message) {
    final normalMatch = RegExp(r'Normal Time Updated \(([+-]?\d+)m\)', caseSensitive: false).firstMatch(message);
    if (normalMatch != null) {
      final diff = int.tryParse(normalMatch.group(1) ?? '0') ?? 0;
      final durationText = _formatMinutesDescription(diff);
      if (diff >= 0) {
        return 'Normal Time increased by $durationText';
      } else {
        return 'Normal Time reduced by $durationText';
      }
    }
    final extraMatch = RegExp(
      r'Extra\s+Time\s+updated\s*\((?:.*\s*,\s*)?([+-]?\d+)m\)',
      caseSensitive: false,
    ).firstMatch(message);
    if (extraMatch != null) {
      final diff = int.tryParse(extraMatch.group(1) ?? '0') ?? 0;
      final durationText = _formatMinutesDescription(diff);
      if (diff >= 0) {
        return 'Extra Time increased by $durationText';
      } else {
        return 'Extra Time reduced by $durationText';
      }
    }
    return message;
  }

  String _payloadMessage(Map<String, dynamic> payload) {
    String msg = '';
    if (payload['incident'] is Map) {
      final incidentMap = (payload['incident'] as Map).cast<String, dynamic>();
      final incidentMessage = incidentMap['message'];
      if (incidentMessage is String) msg = incidentMessage;
    } else {
      final message = payload['message'];
      if (message is String) msg = message;
    }
    return _formatDurationWording(msg);
  }

  bool _isRestartPayload(Map<String, dynamic> payload) {
    final message = _payloadMessage(payload);
    if (message.isEmpty) return false;
    return _normalizeAuditMessage(message) ==
        _normalizeAuditMessage('Exam restarted');
  }

  bool _isInvigilatorUpdatePayload(Map<String, dynamic> payload) {
    final message = _payloadMessage(payload);
    if (message.isEmpty) return false;
    return _normalizeAuditMessage(message) ==
        _normalizeAuditMessage(_auditInvigilatorUpdateMessage);
  }

  SessionEvent? _firstEventByTypeAfter(
    List<SessionEvent> events,
    SessionEventType type,
    DateTime afterUtc,
  ) {
    for (final event in events) {
      if (event.type == type && !event.occurredAtUtc.isBefore(afterUtc)) {
        return event;
      }
    }
    return null;
  }

  SessionEvent? _firstTerminationEventAfter(
    List<SessionEvent> events,
    DateTime afterUtc,
  ) {
    for (final event in events) {
      if (_isTerminationEvent(event.type) && !event.occurredAtUtc.isBefore(afterUtc)) {
        return event;
      }
    }
    return null;
  }
}

class _ExportLogRow {
  final String dateTime;
  final String category;
  final String phase;
  final String description;
  final String room;
  final String studentId;
  final String staffMember;
  final String details;

  const _ExportLogRow({
    required this.dateTime,
    required this.category,
    required this.phase,
    required this.description,
    required this.room,
    required this.studentId,
    required this.staffMember,
    required this.details,
  });
}

class _OrganizationInfo {
  final String name;
  final String code;

  const _OrganizationInfo({required this.name, required this.code});
}

extension on ExamRecord {
  ExamRecord copyWith({
    String? examName,
    String? examCenter,
    String? createdBy,
    DateTime? createdAtUtc,
    DateTime? closedAtUtc,
    RecordStatus? recordStatus,
    int? schemaVersion,
  }) {
    return ExamRecord(
      id: id,
      examName: examName ?? this.examName,
      examCenter: examCenter ?? this.examCenter,
      createdBy: createdBy ?? this.createdBy,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      closedAtUtc: closedAtUtc ?? this.closedAtUtc,
      recordStatus: recordStatus ?? this.recordStatus,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

class _ExportSnapshot {
  final ExamRecord record;
  final ExamCardData? card;
  final SessionSnapshot sessionSnapshot;
  final List<SessionEvent> events;
  final DateTime fallbackStartLocal;
  final String activeLicenseCode;

  const _ExportSnapshot({
    required this.record,
    required this.card,
    required this.sessionSnapshot,
    required this.events,
    required this.fallbackStartLocal,
    required this.activeLicenseCode,
  });
}
