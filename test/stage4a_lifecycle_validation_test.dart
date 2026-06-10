import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/enums/exam_phase.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/session_event.dart';
import 'package:vigilo/models/session_snapshot.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/session_service.dart';
import 'package:vigilo/utils/id_generator.dart';

const String _auditInvigilatorUpdateMessage = 'Invigilator list updated';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 4A lifecycle validation', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late SessionService service;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp(
        'vigilo_stage4a_lifecycle_',
      );
      dbDir = Directory(path.join(sandboxRoot.path, 'db'));
      await dbDir.create(recursive: true);

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(dbDir.path);

      final databaseFile = File(path.join(dbDir.path, 'vigilo_exam_logger.db'));
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
    });

    setUp(() async {
      service = SessionService();
      await AppDatabase().clearAllData();
    });

    test('1) Normal time only (no pause)', () async {
      final recordId = await _createScenarioExam(
        service,
        normalDuration: '00:01',
        extraTime: '00:00',
      );

      await service.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
      );

      final startedCard = await _loadCard(service, recordId);
      expect(startedCard.phase, ExamPhase.normal);

      await _setStartedAtUtc(
        recordId,
        DateTime.now().toUtc().subtract(const Duration(seconds: 70)),
      );
      final endedAny = await service.autoEndIfNeeded();
      expect(endedAny, isTrue);

      final finishedCard = await _loadCard(service, recordId);
      expect(finishedCard.phase, ExamPhase.finished);

      final events = await service.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.start), 1);
      expect(_count(events, SessionEventType.pause), 0);
      expect(_count(events, SessionEventType.resume), 0);
      expect(_count(events, SessionEventType.end), 0);
      expect(_count(events, SessionEventType.recoveryAutoEnd), 1);
      expect(_count(events, SessionEventType.startExtraTime), 0);
      _assertNoContradictoryLifecycleEvents(events);
      _assertChronologicalExportOrder(events);
    });

    test('2) Normal -> Extra transition (no pause)', () async {
      final recordId = await _createScenarioExam(
        service,
        normalDuration: '00:01',
        extraTime: '00:01',
      );

      await service.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 70)),
      );

      final crossedBoundary = await service.autoEndIfNeeded();
      expect(crossedBoundary, isFalse);

      final extraCard = await _loadCard(service, recordId);
      expect(extraCard.phase, ExamPhase.extra);

      var events = await service.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.endNormalTime), 1);
      expect(_count(events, SessionEventType.startExtraTime), 1);
      expect(_terminationCount(events), 0);

      await _setStartedAtUtc(
        recordId,
        DateTime.now().toUtc().subtract(const Duration(seconds: 130)),
      );
      final endedAny = await service.autoEndIfNeeded();
      expect(endedAny, isTrue);

      final finishedCard = await _loadCard(service, recordId);
      expect(finishedCard.phase, ExamPhase.finished);

      events = await service.getEventsForRecord(recordId);
      expect(_terminationCount(events), 1);
      _assertNoContradictoryLifecycleEvents(events);
      _assertChronologicalExportOrder(events);
    });

    test(
      '3) Pause during normal -> Resume -> Normal -> Extra -> End',
      () async {
        final recordId = await _createScenarioExam(
          service,
          normalDuration: '00:01',
          extraTime: '00:01',
        );

        await service.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 30),
          ),
        );

        await service.pauseSession(recordId);
        var pausedSnapshot = await service.getSnapshotForRecord(recordId);
        expect(pausedSnapshot?.sessionStatus, SessionStatus.paused);

        var events = await service.getEventsForRecord(recordId);
        expect(_count(events, SessionEventType.pause), 1);
        expect(_terminationCount(events), 0);
        expect(_count(events, SessionEventType.endNormalTime), 0);

        await service.resumeSession(recordId);
        var runningSnapshot = await service.getSnapshotForRecord(recordId);
        expect(runningSnapshot?.sessionStatus, SessionStatus.running);

        final resumedCard = await _loadCard(service, recordId);
        expect(resumedCard.phase, ExamPhase.normal);

        await _setStartedAtUtc(
          recordId,
          DateTime.now().toUtc().subtract(const Duration(seconds: 70)),
        );
        final crossedBoundary = await service.autoEndIfNeeded();
        expect(crossedBoundary, isFalse);

        final extraCard = await _loadCard(service, recordId);
        expect(extraCard.phase, ExamPhase.extra);

        events = await service.getEventsForRecord(recordId);
        expect(_count(events, SessionEventType.pause), 1);
        expect(_count(events, SessionEventType.resume), 1);
        expect(_count(events, SessionEventType.endNormalTime), 1);
        expect(_count(events, SessionEventType.startExtraTime), 1);
        expect(_terminationCount(events), 0);

        await _setStartedAtUtc(
          recordId,
          DateTime.now().toUtc().subtract(const Duration(seconds: 130)),
        );
        final endedAny = await service.autoEndIfNeeded();
        expect(endedAny, isTrue);

        final finishedCard = await _loadCard(service, recordId);
        expect(finishedCard.phase, ExamPhase.finished);

        events = await service.getEventsForRecord(recordId);
        expect(_terminationCount(events), 1);
        _assertNoContradictoryLifecycleEvents(events);
        _assertChronologicalExportOrder(events);
      },
    );

    test('4) Pause during extra time -> Resume -> End', () async {
      final recordId = await _createScenarioExam(
        service,
        normalDuration: '00:01',
        extraTime: '00:01',
      );

      await service.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 70)),
      );
      await service.autoEndIfNeeded();

      final extraCard = await _loadCard(service, recordId);
      expect(extraCard.phase, ExamPhase.extra);

      await service.pauseSession(recordId);
      var pausedSnapshot = await service.getSnapshotForRecord(recordId);
      expect(pausedSnapshot?.sessionStatus, SessionStatus.paused);

      await service.resumeSession(recordId);
      var runningSnapshot = await service.getSnapshotForRecord(recordId);
      expect(runningSnapshot?.sessionStatus, SessionStatus.running);

      var events = await service.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.pause), 1);
      expect(_count(events, SessionEventType.resume), 1);
      expect(_terminationCount(events), 0);

      await _setStartedAtUtc(
        recordId,
        DateTime.now().toUtc().subtract(const Duration(seconds: 130)),
      );
      final endedAny = await service.autoEndIfNeeded();
      expect(endedAny, isTrue);

      final finishedCard = await _loadCard(service, recordId);
      expect(finishedCard.phase, ExamPhase.finished);

      events = await service.getEventsForRecord(recordId);
      expect(_terminationCount(events), 1);
      _assertNoContradictoryLifecycleEvents(events);
      _assertChronologicalExportOrder(events);
    });

    test('5) Pause near the normal -> extra boundary', () async {
      final recordId = await _createScenarioExam(
        service,
        normalDuration: '00:01',
        extraTime: '00:01',
      );

      await service.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 59)),
      );
      await service.pauseSession(recordId);

      final pausedCard = await _loadCard(service, recordId);
      expect(pausedCard.phase, ExamPhase.normal);

      await service.autoEndIfNeeded();
      var events = await service.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.endNormalTime), 0);
      expect(_count(events, SessionEventType.startExtraTime), 0);
      expect(_terminationCount(events), 0);

      await service.resumeSession(recordId);
      await _setStartedAtUtc(
        recordId,
        DateTime.now().toUtc().subtract(const Duration(seconds: 70)),
      );
      final crossedBoundary = await service.autoEndIfNeeded();
      expect(crossedBoundary, isFalse);

      final extraCard = await _loadCard(service, recordId);
      expect(extraCard.phase, ExamPhase.extra);

      events = await service.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.endNormalTime), 1);
      expect(_count(events, SessionEventType.startExtraTime), 1);
      expect(_terminationCount(events), 0);

      await _setStartedAtUtc(
        recordId,
        DateTime.now().toUtc().subtract(const Duration(seconds: 130)),
      );
      final endedAny = await service.autoEndIfNeeded();
      expect(endedAny, isTrue);

      final finishedCard = await _loadCard(service, recordId);
      expect(finishedCard.phase, ExamPhase.finished);

      events = await service.getEventsForRecord(recordId);
      expect(_terminationCount(events), 1);
      _assertNoContradictoryLifecycleEvents(events);
      _assertChronologicalExportOrder(events);
    });

    test('6) App restart during normal time', () async {
      final recordId = await _createScenarioExam(
        service,
        normalDuration: '00:01',
        extraTime: '00:01',
      );

      await service.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
      );

      final restartService = SessionService();
      await restartService.recoverActiveSession();

      final recoveredCard = await _loadCard(restartService, recordId);
      expect(recoveredCard.phase, ExamPhase.normal);

      final snapshot = await restartService.getSnapshotForRecord(recordId);
      expect(snapshot?.sessionStatus, SessionStatus.running);

      final events = await restartService.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.recoveredAfterTermination), 1);
      expect(_terminationCount(events), 0);
      _assertNoContradictoryLifecycleEvents(events);
      _assertChronologicalExportOrder(events);
    });

    test('7) App restart during pause', () async {
      final recordId = await _createScenarioExam(
        service,
        normalDuration: '00:01',
        extraTime: '00:01',
      );

      await service.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
      );
      await service.pauseSession(recordId);

      final restartService = SessionService();
      await restartService.recoverActiveSession();

      final snapshot = await restartService.getSnapshotForRecord(recordId);
      expect(snapshot?.sessionStatus, SessionStatus.paused);

      final card = await _loadCard(restartService, recordId);
      expect(card.phase, ExamPhase.normal);

      final events = await restartService.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.pause), 1);
      expect(_count(events, SessionEventType.recoveredAfterTermination), 1);
      expect(_terminationCount(events), 0);
      _assertNoContradictoryLifecycleEvents(events);
      _assertChronologicalExportOrder(events);
    });

    test('8) App restart during extra time', () async {
      final recordId = await _createScenarioExam(
        service,
        normalDuration: '00:01',
        extraTime: '00:01',
      );

      await service.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 70)),
      );

      final restartService = SessionService();
      await restartService.recoverActiveSession();

      final extraCard = await _loadCard(restartService, recordId);
      expect(extraCard.phase, ExamPhase.extra);

      var events = await restartService.getEventsForRecord(recordId);
      expect(_count(events, SessionEventType.endNormalTime), 1);
      expect(_count(events, SessionEventType.startExtraTime), 1);
      expect(_count(events, SessionEventType.recoveredAfterTermination), 1);
      expect(_terminationCount(events), 0);

      await _setStartedAtUtc(
        recordId,
        DateTime.now().toUtc().subtract(const Duration(seconds: 130)),
      );
      final endedAny = await restartService.autoEndIfNeeded();
      expect(endedAny, isTrue);

      final finishedCard = await _loadCard(restartService, recordId);
      expect(finishedCard.phase, ExamPhase.finished);

      events = await restartService.getEventsForRecord(recordId);
      expect(_terminationCount(events), 1);
      _assertNoContradictoryLifecycleEvents(events);
      _assertChronologicalExportOrder(events);
    });

    test(
      '9) Late auto-end preserves full extra-time interval in lifecycle log',
      () async {
        final recordId = await _createScenarioExam(
          service,
          normalDuration: '00:01',
          extraTime: '00:01',
        );

        final startedAtUtc = DateTime.now().toUtc().subtract(
          const Duration(seconds: 130),
        );
        await service.startSession(
          examRecordId: recordId,
          startedAt: startedAtUtc,
        );

        final endedAny = await service.autoEndIfNeeded();
        expect(endedAny, isTrue);

        final events = await service.getEventsForRecord(recordId);
        final normalEnd = _singleEvent(events, SessionEventType.endNormalTime);
        final extraStart = _singleEvent(
          events,
          SessionEventType.startExtraTime,
        );
        final examEnd = _singleTerminationEvent(events);

        expect(
          extraStart.occurredAtUtc.isAfter(normalEnd.occurredAtUtc),
          isTrue,
        );
        final extraPhaseMs = examEnd.occurredAtUtc
            .difference(extraStart.occurredAtUtc)
            .inMilliseconds;
        expect(
          extraPhaseMs,
          greaterThanOrEqualTo(59999),
          reason: 'Extra phase collapsed unexpectedly before termination',
        );
        expect(
          extraPhaseMs,
          lessThanOrEqualTo(60050),
          reason: 'Unexpected drift in computed extra-time interval',
        );
      },
    );

    test(
      '10) Manual end during normal time does not backfill extra markers',
      () async {
        final recordId = await _createScenarioExam(
          service,
          normalDuration: '00:01',
          extraTime: '00:01',
        );

        await service.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 20),
          ),
        );
        await service.endSession(recordId, manual: true, reason: 'manual_end');

        final events = await service.getEventsForRecord(recordId);
        expect(_count(events, SessionEventType.endNormalTime), 0);
        expect(_count(events, SessionEventType.startExtraTime), 0);
        expect(_count(events, SessionEventType.end), 1);
        expect(_count(events, SessionEventType.recoveryAutoEnd), 0);
      },
    );

    test(
      '11) Planned overnight boundaries stay anchored to the original start after an early termination event',
      () async {
        final startLocal = DateTime(2026, 3, 31, 21, 31);
        final recordId = await _createScenarioExam(
          service,
          normalStart: '21:31',
          normalDuration: '03:00',
          extraTime: '00:50',
          date: '31/03/2026',
        );

        await _seedEndedLifecycle(
          recordId: recordId,
          startedAtUtc: startLocal.toUtc(),
          endedAtUtc: startLocal.add(const Duration(minutes: 22)).toUtc(),
          plannedDurationMs: const Duration(
            hours: 3,
            minutes: 50,
          ).inMilliseconds,
        );

        final finishedCard = await _loadCard(service, recordId);
        expect(
          finishedCard.normalEnd,
          _localHms(startLocal.add(const Duration(hours: 3))),
        );
        expect(
          finishedCard.extraEnd,
          _localHms(startLocal.add(const Duration(hours: 3, minutes: 50))),
        );
        expect(finishedCard.phase, ExamPhase.finished);
      },
    );

    test(
      '12) Recovery realigns stale active snapshot durations with saved exam timings before auto-end decisions',
      () async {
        final recordId = await _createScenarioExam(
          service,
          normalDuration: '00:30',
          extraTime: '00:15',
        );

        await service.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
        );

        await _setPlannedDurationMs(
          recordId,
          const Duration(minutes: 4, seconds: 18).inMilliseconds,
        );

        final staleSnapshot = await service.getSnapshotForRecord(recordId);
        expect(
          staleSnapshot?.plannedDurationMs,
          const Duration(minutes: 4, seconds: 18).inMilliseconds,
        );

        final recoveredService = SessionService();
        await recoveredService.initialize();

        final recoveredSnapshot = await recoveredService.getSnapshotForRecord(
          recordId,
        );
        expect(
          recoveredSnapshot?.plannedDurationMs,
          const Duration(minutes: 45).inMilliseconds,
        );

        final endedAny = await recoveredService.autoEndIfNeeded();
        expect(endedAny, isFalse);

        final runningCard = await _loadCard(recoveredService, recordId);
        expect(runningCard.running, isTrue);
        expect(runningCard.phase, ExamPhase.normal);
        expect(runningCard.progress, lessThan(1.0));

        final events = await recoveredService.getEventsForRecord(recordId);
        expect(_terminationCount(events), 0);
      },
    );

    test(
      '13) Start realigns stale planned duration before countdown begins',
      () async {
        final recordId = await _createScenarioExam(
          service,
          normalDuration: '00:10',
          extraTime: '00:07',
        );

        await _setPlannedDurationMs(
          recordId,
          const Duration(minutes: 7).inMilliseconds,
        );

        final staleSnapshot = await service.getSnapshotForRecord(recordId);
        expect(
          staleSnapshot?.plannedDurationMs,
          const Duration(minutes: 7).inMilliseconds,
        );

        await service.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 8),
          ),
        );

        final runningSnapshot = await service.getSnapshotForRecord(recordId);
        expect(
          runningSnapshot?.plannedDurationMs,
          const Duration(minutes: 17).inMilliseconds,
        );

        final endedAny = await service.autoEndIfNeeded();
        expect(endedAny, isFalse);

        final runningCard = await _loadCard(service, recordId);
        expect(runningCard.running, isTrue);
        expect(runningCard.phase, ExamPhase.normal);

        final events = await service.getEventsForRecord(recordId);
        expect(_terminationCount(events), 0);
      },
    );
  });
}

Future<String> _createScenarioExam(
  SessionService service, {
  String normalStart = '09:00',
  required String normalDuration,
  required String extraTime,
  String? date,
}) async {
  final card = _buildCard(
    normalStart: normalStart,
    normalDuration: normalDuration,
    extraTime: extraTime,
    date: date,
  );
  final state = await service.persistHomeState(
    cards: [card],
    archiveCards: const [],
    lastUsed: const {
      'school': null,
      'centre': null,
      'subject': null,
      'board': null,
      'start': null,
      'duration': null,
      'extra': null,
    },
  );
  final recordId = state.cards.single.recordId;
  expect(recordId, isNotNull);
  return recordId!;
}

ExamCardData _buildCard({
  required String normalStart,
  required String normalDuration,
  required String extraTime,
  String? date,
}) {
  final now = DateTime.now();
  final resolvedDate =
      date ??
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  final startMin = _hhmmToMinutes(normalStart);
  final normalMin = _hhmmToMinutes(normalDuration);
  final extraMin = _hhmmToMinutes(extraTime);
  final normalEnd = _minutesToHhmm(startMin + normalMin);
  final totalDuration = _minutesToHhmm(normalMin + extraMin);
  final extraEnd = _minutesToHhmm(startMin + normalMin + extraMin);

  return ExamCardData(
    recordId: generateId(),
    school: 'Lifecycle Test School',
    date: resolvedDate,
    subject: 'Lifecycle Stage 4A',
    start: normalStart,
    duration: normalDuration,
    end: normalEnd,
    normalStart: normalStart,
    normalDuration: normalDuration,
    normalEnd: normalEnd,
    extraTime: extraTime,
    totalDuration: totalDuration,
    extraEnd: extraEnd,
    autoStart: false,
  );
}

Future<ExamCardData> _loadCard(SessionService service, String recordId) async {
  final state = await service.loadHomeState();
  for (final card in state.cards) {
    if (card.recordId == recordId) return card;
  }
  for (final card in state.archiveCards) {
    if (card.recordId == recordId) return card;
  }
  fail('Expected exam card with recordId=$recordId to exist');
}

Future<void> _setStartedAtUtc(String recordId, DateTime startedAtUtc) async {
  final db = await AppDatabase().database;
  final nowUtc = DateTime.now().toUtc().toIso8601String();
  await db.update(
    'session_snapshot',
    {
      'started_at_utc': startedAtUtc.toIso8601String(),
      'last_known_now_utc': nowUtc,
      'last_checkpoint_at_utc': nowUtc,
    },
    where: 'exam_record_id = ?',
    whereArgs: [recordId],
  );
}

Future<void> _setPlannedDurationMs(
  String recordId,
  int plannedDurationMs,
) async {
  final db = await AppDatabase().database;
  await db.update(
    'session_snapshot',
    {'planned_duration_ms': plannedDurationMs},
    where: 'exam_record_id = ?',
    whereArgs: [recordId],
  );
}

Future<void> _seedEndedLifecycle({
  required String recordId,
  required DateTime startedAtUtc,
  required DateTime endedAtUtc,
  required int plannedDurationMs,
}) async {
  final db = await AppDatabase().database;
  final endedIso = endedAtUtc.toIso8601String();

  await db.update(
    'session_snapshot',
    {
      'session_status': SessionStatus.ended.code,
      'started_at_utc': startedAtUtc.toIso8601String(),
      'pause_started_at_utc': null,
      'total_paused_ms': 0,
      'planned_duration_ms': plannedDurationMs,
      'ended_at_utc': endedIso,
      'last_known_now_utc': endedIso,
      'last_checkpoint_at_utc': endedIso,
      'integrity_flag': null,
    },
    where: 'exam_record_id = ?',
    whereArgs: [recordId],
  );

  await db.update(
    'exam_record',
    {'closed_at_utc': endedIso, 'record_status': 'closed'},
    where: 'exam_record_id = ?',
    whereArgs: [recordId],
  );

  await db.delete(
    'session_event',
    where: 'exam_record_id = ?',
    whereArgs: [recordId],
  );

  await db.insert('session_event', {
    'event_id': generateId(),
    'exam_record_id': recordId,
    'seq_no': 1,
    'type': SessionEventType.start.code,
    'occurred_at_utc': startedAtUtc.toIso8601String(),
    'payload_json': jsonEncode({'seeded': true}),
    'persisted_at_utc': startedAtUtc.toIso8601String(),
  });

  await db.insert('session_event', {
    'event_id': generateId(),
    'exam_record_id': recordId,
    'seq_no': 2,
    'type': SessionEventType.end.code,
    'occurred_at_utc': endedIso,
    'payload_json': jsonEncode({'reason': 'seeded_early_end'}),
    'persisted_at_utc': endedIso,
  });
}

int _hhmmToMinutes(String hhmm) {
  final parts = hhmm.split(':');
  final hh = int.tryParse(parts[0]) ?? 0;
  final mm = int.tryParse(parts[1]) ?? 0;
  return hh * 60 + mm;
}

String _minutesToHhmm(int totalMinutes) {
  final wrapped = totalMinutes % (24 * 60);
  final hh = (wrapped ~/ 60).toString().padLeft(2, '0');
  final mm = (wrapped % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _localHms(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  final ss = value.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

int _count(List<SessionEvent> events, SessionEventType type) {
  return events.where((event) => event.type == type).length;
}

int _terminationCount(List<SessionEvent> events) {
  return _count(events, SessionEventType.end) +
      _count(events, SessionEventType.recoveryAutoEnd);
}

SessionEvent _singleEvent(List<SessionEvent> events, SessionEventType type) {
  final matches = events.where((event) => event.type == type).toList();
  expect(matches.length, 1, reason: 'Expected exactly one ${type.code} event');
  return matches.single;
}

SessionEvent _singleTerminationEvent(List<SessionEvent> events) {
  final matches = events
      .where(
        (event) =>
            event.type == SessionEventType.end ||
            event.type == SessionEventType.recoveryAutoEnd,
      )
      .toList();
  expect(matches.length, 1, reason: 'Expected exactly one termination event');
  return matches.single;
}

void _assertNoContradictoryLifecycleEvents(List<SessionEvent> events) {
  expect(
    _count(events, SessionEventType.start),
    lessThanOrEqualTo(1),
    reason: 'Duplicate start events detected',
  );
  expect(
    _count(events, SessionEventType.endNormalTime),
    lessThanOrEqualTo(1),
    reason: 'Duplicate end-of-normal-time events detected',
  );
  expect(
    _count(events, SessionEventType.startExtraTime),
    lessThanOrEqualTo(1),
    reason: 'Duplicate start-extra-time events detected',
  );

  final manualEndCount = _count(events, SessionEventType.end);
  final autoEndCount = _count(events, SessionEventType.recoveryAutoEnd);
  expect(
    manualEndCount + autoEndCount,
    lessThanOrEqualTo(1),
    reason: 'Conflicting termination events detected',
  );
}

void _assertChronologicalExportOrder(List<SessionEvent> events) {
  final ordered = _meaningfulExportEvents(events);
  for (var i = 1; i < ordered.length; i++) {
    final previous = ordered[i - 1];
    final current = ordered[i];

    expect(
      current.occurredAtUtc.isBefore(previous.occurredAtUtc),
      isFalse,
      reason:
          'Export order is not chronological: ${previous.type.code} -> ${current.type.code}',
    );

    if (current.occurredAtUtc.isAtSameMomentAs(previous.occurredAtUtc)) {
      expect(
        current.seqNo > previous.seqNo,
        isTrue,
        reason:
            'Export order has unstable sequence for same timestamp: seq ${previous.seqNo} then ${current.seqNo}',
      );
    }
  }
}

List<SessionEvent> _meaningfulExportEvents(List<SessionEvent> events) {
  final sorted = [...events]
    ..sort((a, b) {
      final byOccurred = a.occurredAtUtc.compareTo(b.occurredAtUtc);
      if (byOccurred != 0) return byOccurred;
      return a.seqNo.compareTo(b.seqNo);
    });

  SessionEvent? firstStart;
  for (final event in sorted) {
    if (event.type == SessionEventType.start) {
      firstStart = event;
      break;
    }
  }
  if (firstStart == null) {
    return const <SessionEvent>[];
  }
  final recordedStartUtc = firstStart.occurredAtUtc;

  SessionEvent? manualEnd;
  SessionEvent? recoveryEnd;
  for (final event in sorted) {
    if (!_isTerminationEvent(event.type)) continue;
    if (event.occurredAtUtc.isBefore(recordedStartUtc)) continue;
    if (event.type == SessionEventType.end) {
      manualEnd ??= event;
    } else {
      recoveryEnd ??= event;
    }
  }
  final chosenTermination = manualEnd ?? recoveryEnd;

  final filtered = <SessionEvent>[];
  var keptStart = false;
  var keptNormalBoundary = false;
  var keptExtraBoundary = false;
  var keptTermination = false;

  for (final event in sorted) {
    final payload = _decodePayload(event.payloadJson);
    if (_isInternalAuditEvent(event.type)) continue;
    if (_isInvigilatorUpdatePayload(payload)) continue;
    if (event.occurredAtUtc.isBefore(recordedStartUtc)) continue;
    if (chosenTermination != null &&
        event.occurredAtUtc.isAfter(chosenTermination.occurredAtUtc)) {
      continue;
    }

    switch (event.type) {
      case SessionEventType.start:
        if (event.id != firstStart.id || keptStart) continue;
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
        if (!keptStart) continue;
        filtered.add(event);
        continue;
    }
  }

  return filtered;
}

Map<String, dynamic> _decodePayload(String? payloadJson) {
  if (payloadJson == null || payloadJson.isEmpty) {
    return const <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {}
  return const <String, dynamic>{};
}

bool _isTerminationEvent(SessionEventType type) {
  return type == SessionEventType.end ||
      type == SessionEventType.recoveryAutoEnd;
}

bool _isInternalAuditEvent(SessionEventType type) {
  return type == SessionEventType.checkpoint ||
      type == SessionEventType.recoveredAfterTermination;
}

String _payloadMessage(Map<String, dynamic> payload) {
  if (payload['incident'] is Map) {
    final incidentMap = (payload['incident'] as Map).cast<String, dynamic>();
    final incidentMessage = incidentMap['message'];
    if (incidentMessage is String) return incidentMessage;
  }
  final message = payload['message'];
  return message is String ? message : '';
}

bool _isInvigilatorUpdatePayload(Map<String, dynamic> payload) {
  final message = _payloadMessage(payload).trim().toLowerCase();
  if (message.isEmpty) return false;
  return message == _auditInvigilatorUpdateMessage.toLowerCase();
}
