import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/license_service.dart';
import 'package:vigilo/services/session_service.dart';
import 'package:vigilo/views/home_screen.dart';
import 'package:vigilo/views/widgets/add_exam_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoStart Behavior Integration Tests', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp(
        'vigilo_autostart_behavior_tests_',
      );
      dbDir = Directory(path.join(sandboxRoot.path, 'db'));
      hiveDir = Directory(path.join(sandboxRoot.path, 'hive'));
      await dbDir.create(recursive: true);
      await hiveDir.create(recursive: true);

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(dbDir.path);
      Hive.init(hiveDir.path);

      final databaseFile = File(path.join(dbDir.path, 'vigilo_exam_logger.db'));
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
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
      await SharedPreferences.getInstance();
      sessionService = SessionService();
      await sessionService.initialize();

      final box = await Hive.openBox('vigilo_data');
      await box.clear();

      await AppDatabase().clearAllData();
    });

    tearDownAll(() async {
      await AppDatabase().close();
    });

    Future<void> pumpHomeScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(dark: false, onToggleTheme: () {})),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }

    Future<void> disposeHomeScreen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    Future<void> pumpMultiple(WidgetTester tester) async {
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> activatePilotLicence() async {
      final issuedAt = DateTime.now();
      final encodedExpiry = LicenseService.fixedPilotExpiryFromIssueDate(
        issuedAt,
      );
      final licenceKey = LicenseService.generateLicenceKey(
        organizationCode: 'BA',
        expiryYear: encodedExpiry.year,
        licenceType: LicenseService.pilotLicenceType,
        now: issuedAt,
      );

      await LicenseService.activate(
        'Battersea Academy',
        'BA',
        licenceKey,
        now: issuedAt,
      );
    }

    testWidgets('Manually created past exams show READY TO START and save correctly', (tester) async {
      await tester.runAsync(() async {
        await activatePilotLicence();
        await pumpHomeScreen(tester);

        final dynamic homeState = tester.state(find.byType(HomeScreen));
        expect(homeState.cardsForTesting, isEmpty);

        // Open manual creation dialog
        final fabFinder = find.byType(FloatingActionButton);
        expect(fabFinder, findsOneWidget);
        await tester.tap(fabFinder);
        await pumpMultiple(tester);

        // Tap the 'Create Single Exam' option
        final createOptionFinder = find.text('Create Single Exam');
        expect(createOptionFinder, findsOneWidget);
        await tester.tap(createOptionFinder);
        await pumpMultiple(tester);

        // Retrieve AddExamSheet widget to call its onSave callback directly
        final sheetFinder = find.byType(AddExamSheet);
        expect(sheetFinder, findsOneWidget);
        final addExamSheet = tester.widget<AddExamSheet>(sheetFinder);

        // Execute save for a past date
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await addExamSheet.onSave(
          school: 'Battersea Academy',
          centre: '12345',
          subject: 'Physics',
          board: 'AQA',
          date: yesterday,
          startTime: '09:00',
          duration: '01:30',
          extraTime: '00:15',
        );

        await pumpMultiple(tester);

        // Verify the card was added to the state
        expect(homeState.cardsForTesting.length, 1);
        final createdCard = homeState.cardsForTesting.first as ExamCardData;

        // Verify default fields
        expect(createdCard.autoStart, isFalse);
        expect(createdCard.importedAsPast, isFalse);
        expect(createdCard.isLocked, isFalse); // Normal manual exams are never locked

        // Verify READY TO START pill is shown on screen
        expect(find.text('READY TO START'), findsOneWidget);
        expect(find.text('DATE PASSED'), findsNothing);

        // Reload state from database and verify persistence
        final persistedState = await sessionService.loadHomeState();
        expect(persistedState.cards.length, 1);
        expect(persistedState.cards.first.autoStart, isFalse);
        expect(persistedState.cards.first.importedAsPast, isFalse);
        expect(persistedState.cards.first.isLocked, isFalse);

        await disposeHomeScreen(tester);
      });
    });

    testWidgets('Imported past exams show DATE PASSED and save correctly', (tester) async {
      await tester.runAsync(() async {
        await activatePilotLicence();
        await pumpHomeScreen(tester);

        // Construct a card representing a past-dated import
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

        final importedCard = ExamCardData(
          recordId: 'record_import_past_1',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: yesterdayStr,
          subject: 'Maths (Edexcel)',
          start: '09:00',
          duration: '01:30',
          end: '10:30',
          normalStart: '09:00',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
          importedAsPast: true, // set as past-dated import
          autoStart: false,
        );

        // Import the sessions into the DB
        await sessionService.importSessions([importedCard]);

        // Persist the home state metadata as well
        await sessionService.persistHomeState(
          cards: [importedCard],
          archiveCards: [],
          lastUsed: {},
        );

        // Reload the HomeScreen completely to read the fresh DB entries
        await disposeHomeScreen(tester);
        await pumpHomeScreen(tester);

        final dynamic freshHomeState = tester.state(find.byType(HomeScreen));

        // Verify cards list in home state
        expect(freshHomeState.cardsForTesting.length, 1);
        final cardInState = freshHomeState.cardsForTesting.first as ExamCardData;
        expect(cardInState.autoStart, isFalse);
        expect(cardInState.importedAsPast, isTrue);
        expect(cardInState.isLocked, isTrue); // Backdated imports are locked/disabled

        // Verify DATE PASSED pill is shown
        expect(find.text('DATE PASSED'), findsOneWidget);
        expect(find.text('READY TO START'), findsNothing);

        await disposeHomeScreen(tester);
      });
    });

    testWidgets('Imported future exams that pass later show READY TO START', (tester) async {
      await tester.runAsync(() async {
        await activatePilotLicence();
        await pumpHomeScreen(tester);

        // Construct a card representing a session that is past now,
        // but was imported with future date (importedAsPast: false)
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

        final importedCard = ExamCardData(
          recordId: 'record_import_future_matured',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: yesterdayStr,
          subject: 'Chemistry (OCR)',
          start: '09:00',
          duration: '01:30',
          end: '10:30',
          normalStart: '09:00',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
          importedAsPast: false, // future at import time
          autoStart: false,
        );

        await sessionService.importSessions([importedCard]);
        await sessionService.persistHomeState(
          cards: [importedCard],
          archiveCards: [],
          lastUsed: {},
        );

        await disposeHomeScreen(tester);
        await pumpHomeScreen(tester);

        final dynamic freshHomeState = tester.state(find.byType(HomeScreen));
        expect(freshHomeState.cardsForTesting.length, 1);
        final cardInState = freshHomeState.cardsForTesting.first as ExamCardData;
        expect(cardInState.isLocked, isFalse); // Matured future imports are accessible

        // Verify READY TO START pill is shown
        expect(find.text('READY TO START'), findsOneWidget);
        expect(find.text('DATE PASSED'), findsNothing);

        await disposeHomeScreen(tester);
      });
    });

    testWidgets('Auto-start enabled exams that failed to start show DATE PASSED', (tester) async {
      await tester.runAsync(() async {
        await activatePilotLicence();
        await pumpHomeScreen(tester);

        // Construct a card representing a past session with autoStart enabled but not started (progress = 0)
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

        final card = ExamCardData(
          recordId: 'failed_autostart',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: yesterdayStr,
          subject: 'Biology (AQA)',
          start: '09:00',
          duration: '01:30',
          end: '10:30',
          normalStart: '09:00',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
          importedAsPast: false,
          autoStart: true, // autoStart toggled ON
          progress: 0.0,
        );

        await sessionService.importSessions([card]);
        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: [],
          lastUsed: {},
        );

        await disposeHomeScreen(tester);
        await pumpHomeScreen(tester);

        final dynamic freshHomeState = tester.state(find.byType(HomeScreen));
        expect(freshHomeState.cardsForTesting.length, 1);
        final cardInState = freshHomeState.cardsForTesting.first as ExamCardData;
        expect(cardInState.isLocked, isTrue); // Failed auto-starts are locked

        // Verify DATE PASSED pill is shown
        expect(find.text('DATE PASSED'), findsOneWidget);
        expect(find.text('READY TO START'), findsNothing);

        await disposeHomeScreen(tester);
      });
    });

    testWidgets('Toggling autoStart update state and saves it correctly', (tester) async {
      await tester.runAsync(() async {
        await activatePilotLicence();
        await pumpHomeScreen(tester);

        final dynamic homeState = tester.state(find.byType(HomeScreen));

        // Let's manually inject a card into the state
        final initialCard = ExamCardData(
          recordId: 'record_toggle_1',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '26/03/2026',
          subject: 'Maths (Edexcel)',
          start: '09:00',
          duration: '01:30',
          end: '10:30',
          normalStart: '09:00',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
          autoStart: false,
          autoStartUserModified: false,
        );

        await sessionService.importSessions([initialCard]);
        await sessionService.persistHomeState(
          cards: [initialCard],
          archiveCards: [],
          lastUsed: {},
        );

        await disposeHomeScreen(tester);
        await pumpHomeScreen(tester);

        final dynamic currentHomeState = tester.state(find.byType(HomeScreen));

        expect(currentHomeState.cardsForTesting.length, 1);
        expect(currentHomeState.cardsForTesting.first.autoStart, isFalse);
        expect(currentHomeState.cardsForTesting.first.autoStartUserModified, isFalse);

        // Simulate a toggle change and persist directly
        final updatedCard = currentHomeState.cardsForTesting.first.copyWith(
          autoStart: true,
          autoStartUserModified: true,
        );
        await sessionService.persistHomeState(
          cards: [updatedCard],
          archiveCards: [],
          lastUsed: {},
        );

        // Verify database reflects modified toggled state
        final persistedState = await sessionService.loadHomeState();
        expect(persistedState.cards.length, 1);
        expect(persistedState.cards.first.autoStart, isTrue);
        expect(persistedState.cards.first.autoStartUserModified, isTrue);

        await disposeHomeScreen(tester);
      });
    });
  });
}
