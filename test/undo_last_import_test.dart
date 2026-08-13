import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/enums/exam_phase.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/incident.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/license_service.dart';
import 'package:vigilo/services/session_service.dart';
import 'package:vigilo/utils/id_generator.dart';
import 'package:vigilo/views/home_screen.dart';
import 'package:vigilo/views/widgets/session_manager_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Undo Last Import integration tests', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp(
        'vigilo_undo_import_',
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
      for (int i = 0; i < 30; i++) {
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

    List<ExamCardData> buildMockSessions(int count, {
      bool withRunning = false,
      bool withIncident = false,
      bool inPast = false,
    }) {
      final now = DateTime.now();
      final targetDate = inPast
          ? now.subtract(const Duration(days: 2))
          : now.add(const Duration(days: 10));
      final dateStr =
          "${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}";

      return List.generate(count, (i) {
        final isRunning = withRunning && i == 0;
        final hasIncident = withIncident && i == 1;
        final wasStarted = isRunning || hasIncident;

        return ExamCardData(
          recordId: 'record_mock_$i',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: dateStr,
          subject: 'Subject Mock $i',
          start: '09:00',
          duration: '01:30',
          end: '10:30',
          normalStart: '09:00',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
          running: isRunning,
          wasEverStarted: wasStarted,
          logs: hasIncident
              ? [
                  Incident(
                    'Mock Incident',
                    time: DateTime.now(),
                    eventType: 'incident',
                  ),
                ]
              : const [],
        );
      });
    }

    testWidgets(
      'performs undo action and leaves protected sessions intact',
      (tester) async {
        await tester.runAsync(() async {
          await activatePilotLicence();

          // 1. Create and import 8 sessions (so cards > 5 to display the tune icon)
          // 1 running (protected), 1 with incident (protected), 6 idle (unprotected)
          final mockSessions = buildMockSessions(
            8,
            withRunning: true,
            withIncident: true,
          );
          await sessionService.importSessions(mockSessions);

          // 2. Pump Home Screen
          await pumpHomeScreen(tester);

          // Verify all 8 are shown
          expect(find.textContaining('Subject Mock'), findsNWidgets(8));

          // 3. Open Session Manager by tapping tune icon
          final tuneIconFinder = find.byIcon(Icons.tune_rounded);
          expect(tuneIconFinder, findsOneWidget);
          await tester.tap(tuneIconFinder);
          await pumpMultiple(tester);

          // 4. Verify LAST IMPORT banner is visible
          expect(find.text('LAST IMPORT'), findsOneWidget);
          expect(
            find.text('8 sessions · 2 protected (started, archived, or has an incident)'),
            findsOneWidget,
          );
          expect(find.text('Undo 6 sessions'), findsOneWidget);

          // 5. Tap Undo button
          final undoBtnFinder = find.ancestor(
            of: find.byIcon(Icons.undo_rounded),
            matching: find.byType(GestureDetector),
          );
          expect(undoBtnFinder, findsOneWidget);
          await tester.tap(undoBtnFinder);
          await Future.delayed(const Duration(milliseconds: 300));
          await pumpMultiple(tester);

          // 6. Verify SnackBar and card removal
          expect(find.text('Reverted 6 sessions from the last import.'), findsOneWidget);

          // Verify that only the 2 protected sessions remain
          expect(find.textContaining('Subject Mock'), findsNWidgets(2));
          expect(find.text('Subject Mock 0'), findsOneWidget); // Running
          expect(find.text('Subject Mock 1'), findsOneWidget); // Incident

          // 7. Verify banner and Session Manager panel are now hidden
          expect(find.text('LAST IMPORT'), findsNothing);
          expect(find.byType(SessionManagerPanel), findsNothing);

          // 8. Dispose HomeScreen to cancel background timers
          await disposeHomeScreen(tester);
        });
      },
    );

    testWidgets(
      'shows disabled state when all sessions are protected in the batch',
      (tester) async {
        await tester.runAsync(() async {
          await activatePilotLicence();

          // 1. Create and import 6 sessions (all running/protected)
          final mockSessions = buildMockSessions(
            6,
            withRunning: true,
            withIncident: true,
          );
          // Make all of them running or with incidents
          final allProtected = mockSessions.map((s) => s.copyWith(running: true, wasEverStarted: true)).toList();
          await sessionService.importSessions(allProtected);

          // 2. Pump Home Screen
          await pumpHomeScreen(tester);

          // 3. Open Session Manager
          final tuneIconFinder = find.byIcon(Icons.tune_rounded);
          await tester.tap(tuneIconFinder);
          await pumpMultiple(tester);

          // 4. Verify LAST IMPORT banner is visible and showing disabled text
          expect(find.text('LAST IMPORT'), findsOneWidget);
          expect(
            find.text("Can't undo - all sessions protected"),
            findsOneWidget,
          );

          // Verify tap does nothing
          final disabledBtnFinder = find.text("Can't undo - all sessions protected");
          await tester.tap(disabledBtnFinder, warnIfMissed: false);
          await pumpMultiple(tester);

          // Verify all 6 sessions are still there
          expect(find.textContaining('Subject Mock'), findsNWidgets(6));

          // 5. Dispose HomeScreen to cancel background timers
          await disposeHomeScreen(tester);
        });
      },
    );

    testWidgets(
      'archived sessions are counted as protected in the banner and not reverted',
      (tester) async {
        await tester.runAsync(() async {
          await activatePilotLicence();

          // 1. Create and import 8 sessions (with past dates so they are archivable)
          final mockSessions = buildMockSessions(8, inPast: true);
          await sessionService.importSessions(mockSessions);

          // 2. Pump Home Screen
          await pumpHomeScreen(tester);

          // Verify all 8 are shown
          expect(find.textContaining('Subject Mock'), findsNWidgets(8));

          // State manipulation to archive 2 sessions
          final dynamic homeState = tester.state(find.byType(HomeScreen));
          final c0 = homeState.cardsForTesting[0].copyWith(autoStart: false);
          final c1 = homeState.cardsForTesting[1].copyWith(autoStart: false);
          
          homeState.cardsForTesting.removeRange(0, 2);
          homeState.archiveCardsForTesting.add(c0);
          homeState.archiveCardsForTesting.add(c1);

          // Save to database so refresh reads the updated archive state
          await sessionService.persistHomeState(
            cards: List<ExamCardData>.from(homeState.cardsForTesting),
            archiveCards: List<ExamCardData>.from(homeState.archiveCardsForTesting),
            lastUsed: const {},
          );


          // Trigger a state update and wait
          await tester.tap(find.byIcon(Icons.tune_rounded));
          await pumpMultiple(tester);

          // Verify only 6 active remain
          expect(find.textContaining('Subject Mock'), findsNWidgets(6));

          // 4. Verify LAST IMPORT banner counts the 2 archived sessions as protected
          expect(find.text('LAST IMPORT'), findsOneWidget);
          expect(
            find.text('8 sessions · 2 protected (started, archived, or has an incident)'),
            findsOneWidget,
          );
          expect(find.text('Undo 6 sessions'), findsOneWidget);

          // 5. Tap Undo button
          final undoBtnFinder = find.ancestor(
            of: find.byIcon(Icons.undo_rounded),
            matching: find.byType(GestureDetector),
          );
          await tester.tap(undoBtnFinder);
          // Wait for the async DB roundtrip (_undoLastImport → _refreshCards → setState)
          await Future.delayed(const Duration(milliseconds: 1500));
          await pumpMultiple(tester);

          // 6. Verify SnackBar and active cards are removed
          expect(find.text('Reverted 6 sessions from the last import.'), findsOneWidget);


          expect(find.textContaining('Subject Mock'), findsNothing);

          // 7. Dispose HomeScreen
          await disposeHomeScreen(tester);
        });
      },
    );
  });
}
