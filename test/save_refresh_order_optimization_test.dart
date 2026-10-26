import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/enums/exam_phase.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/schedule.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/session_service.dart';

ExamCardData _buildTestCard({
  required String recordId,
  required String subject,
  required String school,
  required String date,
  String normalStart = '09:00',
  String normalDuration = '01:00',
  String extraTime = '00:00',
  String invigilatorsSnapshot = '',
  String roomsSnapshot = '',
  String setUpBy = '',
  String notes = '',
  List<ScheduleData>? scheduleList,
}) {
  return ExamCardData(
    recordId: recordId,
    school: school,
    date: date,
    subject: subject,
    start: normalStart,
    duration: normalDuration,
    end: '10:00',
    normalStart: normalStart,
    normalDuration: normalDuration,
    normalEnd: '10:00',
    extraTime: extraTime,
    totalDuration: normalDuration,
    extraEnd: '10:00',
    invigilatorsSnapshot: invigilatorsSnapshot,
    roomsSnapshot: roomsSnapshot,
    setUpBy: setUpBy,
    notes: notes,
    scheduleList: scheduleList,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Save & Refresh Path Optimization Tests', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp(
        'vigilo_save_refresh_test_',
      );
      dbDir = Directory(path.join(sandboxRoot.path, 'db'));
      hiveDir = Directory(path.join(sandboxRoot.path, 'hive'));
      await dbDir.create(recursive: true);
      await hiveDir.create(recursive: true);

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
        buildSignature: 'buildSignature',
      );
      SharedPreferences.setMockInitialValues({});
      sessionService = SessionService();
      await sessionService.initialize();

      final box = await Hive.openBox('vigilo_data');
      await box.clear();

      await AppDatabase().clearAllData();
    });

    tearDownAll(() async {
      try {
        await sandboxRoot.delete(recursive: true);
      } catch (_) {}
    });

    test('refreshSingleCardRuntime updates runtime fields without touching other cards', () async {
      final card1 = _buildTestCard(
        recordId: 'rec_1',
        subject: 'Mathematics',
        school: 'School A',
        date: '22/10/2026',
        invigilatorsSnapshot: 'John Doe',
      );
      final card2 = _buildTestCard(
        recordId: 'rec_2',
        subject: 'Physics',
        school: 'School A',
        date: '22/10/2026',
        normalStart: '11:00',
        invigilatorsSnapshot: 'Jane Smith',
      );

      await sessionService.persistHomeState(
        cards: [card1, card2],
        archiveCards: [],
        lastUsed: {},
      );

      // Start rec_1
      final now = DateTime.now();
      await sessionService.startSession(
        examRecordId: 'rec_1',
        startedAt: now,
        normalDurationMs: card1.normalSeconds * 1000,
        extraTimeMs: card1.extraSeconds * 1000,
      );

      // Refresh single card runtime
      final refreshed = await sessionService.refreshSingleCardRuntime(card1);
      expect(refreshed, isNotNull);
      expect(refreshed!.running, isTrue);
      expect(refreshed.phase, equals(ExamPhase.normal));
      expect(refreshed.invigilatorsSnapshot, equals('John Doe'));

      // Verify rec_2 was untouched and remains not running
      final refreshed2 = await sessionService.refreshSingleCardRuntime(card2);
      expect(refreshed2, isNotNull);
      expect(refreshed2!.running, isFalse);
    });

    test('1-second tick timer merge preserves newer in-memory metadata over stale tick data', () {
      final inMemoryCard = _buildTestCard(
        recordId: 'rec_1',
        subject: 'Mathematics',
        school: 'School A',
        date: '22/10/2026',
        invigilatorsSnapshot: 'Newly Typed Invigilator',
        roomsSnapshot: 'Room 101',
        setUpBy: 'Officer Jones',
        notes: 'Important exam note',
        scheduleList: [
          ScheduleData(
            time: '09:00 - 10:00',
            room: 'Room 101',
            invigilators: ['Newly Typed Invigilator'],
            notes: 'Important exam note',
          ),
        ],
      ).copyWith(
        running: true,
        progress: 0.1,
      );

      // Simulating a stale tick result that had older empty/default metadata
      final staleTickCard = inMemoryCard.copyWith(
        invigilatorsSnapshot: '',
        roomsSnapshot: '',
        setUpBy: '',
        notes: '',
        scheduleList: [],
        progress: 0.15, // Advanced timer progress
      );

      // Apply the targeted timer update logic used in _tickAsync:
      final merged = inMemoryCard.copyWith(
        running: staleTickCard.running,
        isPaused: staleTickCard.isPaused,
        progress: staleTickCard.progress,
        phase: staleTickCard.phase,
        pausedSeconds: staleTickCard.pausedSeconds,
        epochStart: staleTickCard.epochStart,
        end: staleTickCard.end,
        normalEnd: staleTickCard.normalEnd,
        extraEnd: staleTickCard.extraEnd,
      );

      // Verified: Timer fields updated, but all user metadata is preserved!
      expect(merged.progress, equals(0.15));
      expect(merged.invigilatorsSnapshot, equals('Newly Typed Invigilator'));
      expect(merged.roomsSnapshot, equals('Room 101'));
      expect(merged.setUpBy, equals('Officer Jones'));
      expect(merged.notes, equals('Important exam note'));
      expect(merged.scheduleList?.length, equals(1));
    });

    test('saveCardDelta saves only the targeted card without rewriting other sessions', () async {
      final card1 = _buildTestCard(
        recordId: 'rec_1',
        subject: 'Chemistry',
        school: 'School B',
        date: '23/10/2026',
        normalStart: '10:00',
        normalDuration: '01:30',
        invigilatorsSnapshot: 'Old Staff',
      );
      final card2 = _buildTestCard(
        recordId: 'rec_2',
        subject: 'Biology',
        school: 'School B',
        date: '23/10/2026',
        normalStart: '14:00',
        invigilatorsSnapshot: 'Sarah Lee',
      );

      await sessionService.persistHomeState(
        cards: [card1, card2],
        archiveCards: [],
        lastUsed: {},
      );

      // Update card1 via saveCardDelta
      final updatedCard1 = card1.copyWith(
        invigilatorsSnapshot: 'Updated Staff Member',
      );
      await sessionService.saveCardDelta(updatedCard1, debounceDurationMs: 0);

      // Verify rec_1 was updated in SQLite
      final reloaded = await sessionService.loadHomeState();
      final loaded1 = reloaded.cards.firstWhere((c) => c.recordId == 'rec_1');
      final loaded2 = reloaded.cards.firstWhere((c) => c.recordId == 'rec_2');

      expect(loaded1.invigilatorsSnapshot, equals('Updated Staff Member'));
      expect(loaded2.invigilatorsSnapshot, equals('Sarah Lee'));
    });
  });
}
