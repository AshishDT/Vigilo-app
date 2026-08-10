import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Import Multiple Files / Persistent State Tests', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late SessionService service;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp('vigilo_multi_import_test_');
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

    test('Importing a second batch of sessions does not delete the first batch', () async {
      // 1. Simulate first import of 4 sessions
      final initialCards = List.generate(4, (i) => ExamCardData(
        recordId: 'initial_session_$i',
        school: 'Test School',
        centreNumber: '12345',
        date: '10/08/2026',
        subject: 'Subject $i',
        examLevel: 'GCSE',
        start: '09:00',
        duration: '01:30',
        end: '10:30',
        normalStart: '09:00',
        normalDuration: '01:30',
        normalEnd: '10:30',
        extraTime: '00:00',
        totalDuration: '01:30',
        extraEnd: '10:30',
        roomsSnapshot: 'Gym',
        notes: '',
      ));

      var state = await service.persistHomeState(
        cards: initialCards,
        archiveCards: const [],
        lastUsed: const {},
      );

      expect(state.cards.length, equals(4));

      // Load to verify they are in the DB
      var loadedState = await service.loadHomeState();
      expect(loadedState.cards.length, equals(4));

      // 2. Simulate second import of 2 sessions
      final newCards = List.generate(2, (i) => ExamCardData(
        recordId: 'new_session_$i',
        school: 'Test School',
        centreNumber: '12345',
        date: '11/08/2026',
        subject: 'New Subject $i',
        examLevel: 'A Level',
        start: '14:00',
        duration: '02:00',
        end: '16:00',
        normalStart: '14:00',
        normalDuration: '02:00',
        normalEnd: '16:00',
        extraTime: '00:00',
        totalDuration: '02:00',
        extraEnd: '16:00',
        roomsSnapshot: 'Hall',
        notes: '',
      ));

      // Combine them just like HomeScreen does: _cards.insertAll(0, newSessions);
      final combinedCards = <ExamCardData>[...newCards, ...loadedState.cards];

      state = await service.persistHomeState(
        cards: combinedCards,
        archiveCards: const [],
        lastUsed: const {},
      );

      expect(state.cards.length, equals(6));

      loadedState = await service.loadHomeState();
      expect(loadedState.cards.length, equals(6));
    });
  });
}
