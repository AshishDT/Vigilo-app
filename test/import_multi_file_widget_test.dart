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
import 'package:vigilo/views/widgets/import_flow_sheet.dart';
import 'package:vigilo/views/widgets/exam_card_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen Multiple Imports Widget Tests', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp('vigilo_widget_multi_import_');
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

      final box = await Hive.openBox('vigilo_data');
      await box.clear();

      await AppDatabase().clearAllData();
    });

    tearDownAll(() async {
      await AppDatabase().close();
    });

    Future<void> activatePilotLicence() async {
      final issuedAt = DateTime.now();
      final encodedExpiry = LicenseService.fixedPilotExpiryFromIssueDate(issuedAt);
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

    testWidgets('Importing twice successfully keeps both sets of imported exams on the Home Screen', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await activatePilotLicence();

        // 1. Pump HomeScreen
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(dark: false, onToggleTheme: () {})),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Verify initial state has 0 cards
        expect(find.byType(Card), findsNothing);

        // 2. Open Speed Dial
        final fabFinder = find.byType(FloatingActionButton);
        expect(fabFinder, findsOneWidget);
        await tester.tap(fabFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 3. Tap Import Exam Sessions
        final importOptionFinder = find.text('Import Exam Sessions');
        expect(importOptionFinder, findsOneWidget);
        await tester.tap(importOptionFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify ImportFlowSheet is pushed
        final importSheetFinder = find.byType(ImportFlowSheet);
        expect(importSheetFinder, findsOneWidget);

        // Get the ImportFlowSheet widget
        final importSheet = tester.widget<ImportFlowSheet>(importSheetFinder);

        // 4. Simulate first import of 4 sessions
        final batch1 = List.generate(4, (i) => ExamCardData(
          recordId: 'batch1_session_$i',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '10/08/2026',
          subject: 'Subject Batch1 $i',
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
          roomsSnapshot: 'Room B1-$i',
          notes: '',
        ));

        await importSheet.onImportSessions(batch1);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Close the import flow sheet (simulate popping back)
        Navigator.of(tester.element(importSheetFinder)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify 4 cards are saved in DB
        var dbState = await sessionService.loadHomeState();
        expect(dbState.cards.length, equals(4));

        // 5. Open Speed Dial again
        await tester.tap(fabFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 6. Tap Import Exam Sessions again
        await tester.tap(importOptionFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(ImportFlowSheet), findsOneWidget);
        final importSheet2 = tester.widget<ImportFlowSheet>(find.byType(ImportFlowSheet));

        // 7. Simulate second import of 2 sessions
        final batch2 = List.generate(2, (i) => ExamCardData(
          recordId: 'batch2_session_$i',
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '11/08/2026',
          subject: 'Subject Batch2 $i',
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
          roomsSnapshot: 'Room B2-$i',
          notes: '',
        ));

        await importSheet2.onImportSessions(batch2);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Close import flow sheet again
        Navigator.of(tester.element(find.byType(ImportFlowSheet))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify all 6 cards are now saved in DB
        dbState = await sessionService.loadHomeState();
        expect(dbState.cards.length, equals(6));
      });
    });
  });
}
