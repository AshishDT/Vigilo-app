import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/enums/exam_phase.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/session_service.dart';

ExamCardData _buildTestCard({
  required String recordId,
  required String subject,
  required String school,
  required String date,
  String normalStart = '10:00',
  String normalDuration = '01:00',
  String extraTime = '00:00',
}) {
  return ExamCardData(
    recordId: recordId,
    school: school,
    date: date,
    subject: subject,
    start: normalStart,
    duration: normalDuration,
    end: '11:00',
    normalStart: normalStart,
    normalDuration: normalDuration,
    normalEnd: '11:00',
    extraTime: extraTime,
    totalDuration: normalDuration,
    extraEnd: '11:00',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Resume Session Sync Tests (Item 7)', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp('resume_test_');
      dbDir = Directory(path.join(sandboxRoot.path, 'db'))..createSync(recursive: true);
      hiveDir = Directory(path.join(sandboxRoot.path, 'hive'))..createSync(recursive: true);

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(dbDir.path);
      Hive.init(hiveDir.path);
    });

    setUp(() async {
      PackageInfo.setMockInitialValues(
        appName: 'vigilo',
        packageName: 'com.example.vigilo',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      SharedPreferences.setMockInitialValues({});
      sessionService = SessionService();
      await sessionService.initialize();

      final box = await Hive.openBox('vigilo_data');
      await box.clear();
      await AppDatabase().clearAllData();
    });

    tearDownAll(() async {
      await Hive.close();
      if (sandboxRoot.existsSync()) {
        sandboxRoot.deleteSync(recursive: true);
      }
    });

    test('refreshActiveCardsOnly updates in-memory running cards when SQLite session has ended', () async {
      final card = _buildTestCard(
        recordId: 'exam_resumed_1',
        subject: 'Mathematics',
        school: 'St Andrews',
        date: '22/10/2026',
        normalDuration: '01:00',
      );

      // Persist the card and start session 2 hours in the past
      await sessionService.persistHomeState(
        cards: [card],
        archiveCards: [],
        lastUsed: {},
      );

      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      await sessionService.startSession(
        examRecordId: card.recordId!,
        startedAt: twoHoursAgo,
        normalDurationMs: 60 * 60 * 1000,
        extraTimeMs: 0,
      );

      // Simulate the auto-end that occurred while the phone was locked/sleeping
      final ended = await sessionService.autoEndIfNeeded();
      expect(ended, isTrue, reason: 'Session duration expired, should auto-end');

      // Now create the in-memory representation that was in memory before lock
      final inMemoryRunningCard = card.copyWith(
        running: true,
        phase: ExamPhase.normal,
        progress: 0.1,
      );

      // Verify that refreshActiveCardsOnly recognizes that the SQLite session ended
      // and returns the card updated to finished
      final updated = await sessionService.refreshActiveCardsOnly([inMemoryRunningCard]);

      expect(updated.length, 1);
      final refreshed = updated.first;
      expect(refreshed.recordId, 'exam_resumed_1');
      expect(refreshed.running, isFalse);
      expect(refreshed.isPaused, isFalse);
      expect(refreshed.phase, ExamPhase.finished);
    });

    test('autoEndIfNeeded followed by loadHomeState renders finished state immediately', () async {
      final card = _buildTestCard(
        recordId: 'exam_resumed_2',
        subject: 'History',
        school: 'St Andrews',
        date: '22/10/2026',
        normalDuration: '00:30',
      );

      await sessionService.persistHomeState(
        cards: [card],
        archiveCards: [],
        lastUsed: {},
      );

      final oneHourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      await sessionService.startSession(
        examRecordId: card.recordId!,
        startedAt: oneHourAgo,
        normalDurationMs: 30 * 60 * 1000,
        extraTimeMs: 0,
      );

      // Trigger auto-end as happens on resume
      await sessionService.autoEndIfNeeded();

      final homeState = await sessionService.loadHomeState();
      final loadedCard = homeState.cards.firstWhere((c) => c.recordId == 'exam_resumed_2');

      expect(loadedCard.running, isFalse);
      expect(loadedCard.phase, ExamPhase.finished);
    });

    test('startSession updates normalStart to actual start time instead of keeping scheduled time', () async {
      final card = _buildTestCard(
        recordId: 'exam_actual_start_1',
        subject: 'Design & Technology',
        school: 'St Andrews',
        date: '17/10/2026',
        normalStart: '10:00',
        normalDuration: '01:30',
      );

      await sessionService.persistHomeState(
        cards: [card],
        archiveCards: [],
        lastUsed: {},
      );

      // Start at 10:01:05 local
      final actualStart = DateTime(2026, 10, 17, 10, 1, 5);
      await sessionService.startSession(
        examRecordId: card.recordId!,
        startedAt: actualStart,
        normalDurationMs: 90 * 60 * 1000,
        extraTimeMs: 0,
      );

      final homeState = await sessionService.loadHomeState();
      final loadedCard = homeState.cards.firstWhere((c) => c.recordId == 'exam_actual_start_1');

      // The normalStart must be 10:01, matching the actual start time
      expect(loadedCard.normalStart, '10:01');
    });
  });
}
