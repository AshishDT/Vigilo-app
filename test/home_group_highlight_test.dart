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
import 'package:vigilo/utils/id_generator.dart';
import 'package:vigilo/views/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen Group Highlight Tests', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp('vigilo_home_highlight_');
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

    ExamCardData buildExamCard(String date) {
      return ExamCardData(
        recordId: generateId(),
        school: 'Battersea Academy',
        centreNumber: '12345',
        date: date,
        subject: 'Maths (AQA)',
        start: '09:00',
        duration: '00:02',
        end: '09:03',
        normalStart: '09:00',
        normalDuration: '00:02',
        normalEnd: '09:02',
        extraTime: '00:01',
        totalDuration: '00:03',
        extraEnd: '09:03',
        autoStart: true,
      );
    }

    testWidgets(
      'renders group highlight decoration when jump to date is triggered',
      (tester) async {
        await tester.runAsync(() async {
          await activatePilotLicence();
          await sessionService.initialize();
          await sessionService.persistHomeState(
            cards: [buildExamCard('26/03/2026')],
            archiveCards: const [],
            lastUsed: const {
              'school': 'Battersea Academy',
            },
          );

          await pumpHomeScreen(tester);

          // Find the group column widget for date group '26/03/2026'
          final groupColumnFinder = find.byKey(const ValueKey('group_26/03/2026'));
          expect(groupColumnFinder, findsOneWidget);

          // Simulate selection of date by state helper
          final stateFinder = find.byType(HomeScreen);
          final state = tester.state(stateFinder) as dynamic;
          
          state.highlightDateForTest('26/03/2026');
          await tester.pump();

          // Verify the AnimatedContainer containing the cards gets the amber highlight border
          final groupColumn = tester.widget<Column>(groupColumnFinder);
          final groupAnimatedContainer = groupColumn.children[1] as AnimatedContainer;
          final decoration = groupAnimatedContainer.decoration as BoxDecoration;
          expect(decoration.border?.top.color, const Color(0xFFE59422)); // VigiloUiColors.amber(false) = Color(0xFFE59422)

          await disposeHomeScreen(tester);
        });
      },
    );
  });
}
