import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/session_event.dart';
import 'package:vigilo/models/session_snapshot.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/license_service.dart';
import 'package:vigilo/services/session_service.dart';
import 'package:vigilo/views/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Start Now Reproduction Test', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp(
        'vigilo_start_now_test_',
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

    testWidgets('Tap Start Now on Mathematics Paper 2', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.runAsync(() async {
        await activatePilotLicence();

        final now = DateTime.now();
        final todayStr =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');

        final card = ExamCardData(
          recordId: 'math_paper_2',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: todayStr,
          subject: 'Mathematics Paper 2',
          start: '$hh:$mm',
          duration: '01:30',
          end: '23:59',
          normalStart: '$hh:$mm',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
          importedAsPast: false,
          autoStart: false,
          progress: 0.0,
          running: false,
        );

        await sessionService.importSessions([card]);
        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: [],
          lastUsed: {},
        );

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(dark: false, onToggleTheme: () {})),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Find the card and expand it if needed
        expect(find.text('Mathematics Paper 2'), findsOneWidget);

        // Tap on card to expand
        await tester.tap(find.text('Mathematics Paper 2'));
        await tester.pump(const Duration(milliseconds: 500));

        // Check if Start Now button is present
        final startNowBtn = find.text('Start Now');
        print('startNowBtn found: ${startNowBtn.evaluate().isNotEmpty}');
        expect(startNowBtn, findsOneWidget);
        await tester.ensureVisible(startNowBtn);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Start Now
        await tester.tap(startNowBtn);
        await tester.pump();
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump();

        final dynamic homeState = tester.state(find.byType(HomeScreen));
        final ExamCardData currentCard = homeState.cardsForTesting.first;

        final events = await AppDatabase().getEvents('math_paper_2');
        final hasStartEvent = events.any((e) => e.type == SessionEventType.start);
        expect(hasStartEvent, isTrue, reason: 'Must contain SessionEventType.start event');
        expect(currentCard.running, isTrue);
        expect(currentCard.progress, greaterThan(0.0));
      });
    });

    testWidgets('Tap Start Now on Future-Scheduled Exam sets running, start event, and advances progress', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.runAsync(() async {
        await activatePilotLicence();

        final now = DateTime.now();
        final futureTime = now.add(const Duration(hours: 3));
        final todayStr =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
        final hh = futureTime.hour.toString().padLeft(2, '0');
        final mm = futureTime.minute.toString().padLeft(2, '0');

        final card = ExamCardData(
          recordId: 'physics_paper_1',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: todayStr,
          subject: 'Physics Paper 1',
          start: '$hh:$mm',
          duration: '01:30',
          end: '23:59',
          normalStart: '$hh:$mm',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
          importedAsPast: false,
          autoStart: false,
          progress: 0.0,
          running: false,
        );

        await sessionService.importSessions([card]);
        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: [],
          lastUsed: {},
        );

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(dark: false, onToggleTheme: () {})),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Physics Paper 1'), findsOneWidget);

        // Tap card to expand
        await tester.tap(find.text('Physics Paper 1'));
        await tester.pump(const Duration(milliseconds: 500));

        final startNowBtn = find.text('Start Now');
        expect(startNowBtn, findsOneWidget);
        await tester.ensureVisible(startNowBtn);
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Start Now
        await tester.tap(startNowBtn);
        await tester.pump();
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump();

        final dynamic homeState = tester.state(find.byType(HomeScreen));
        final ExamCardData currentCard = homeState.cardsForTesting.first;

        final events = await AppDatabase().getEvents('physics_paper_1');
        final hasStartEvent = events.any((e) => e.type == SessionEventType.start);
        expect(hasStartEvent, isTrue, reason: 'Start Now on future exam must create SessionEventType.start');
        expect(currentCard.running, isTrue);
        expect(currentCard.progress, greaterThan(0.0), reason: 'Progress must immediately advance after Start Now');
      });
    });
  });
}
