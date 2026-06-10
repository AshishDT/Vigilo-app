import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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

  group('HomeScreen licence persistence', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp(
        'vigilo_home_license_',
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
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      sessionService = SessionService();

      final box = await Hive.openBox('vigilo_data');
      await box.clear();

      await AppDatabase().clearAllData();
    });

    Future<void> pumpHomeScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(dark: false, onToggleTheme: () {})),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }

    Future<void> restartHomeScreen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpHomeScreen(tester);
    }

    Future<void> disposeHomeScreen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    Future<String> activatePilotLicence() async {
      final issuedAt = DateTime(2026, 3, 26, 10, 0);
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

      return licenceKey;
    }

    Map<String, String?> buildLastUsed({
      String? school,
      String? centre,
      String? subject,
      String? board,
      String? start,
      String? duration,
      String? extra,
    }) {
      return {
        'school': school,
        'centre': centre,
        'subject': subject,
        'board': board,
        'start': start,
        'duration': duration,
        'extra': extra,
      };
    }

    ExamCardData buildExamCard() {
      return ExamCardData(
        recordId: generateId(),
        school: 'Battersea Academy',
        centreNumber: '12345',
        date: '26/03/2026',
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
      'seeds the organisation context from a stored licence and keeps it active after restart',
      (tester) async {
        await activatePilotLicence();

        await pumpHomeScreen(tester);

        expect(find.text('Licence Required'), findsNothing);

        final lastUsed = await sessionService.loadLastUsed();
        expect(lastUsed['school'], 'Battersea Academy');
        expect(lastUsed['centre'], isNull);

        await restartHomeScreen(tester);

        expect(find.text('Licence Required'), findsNothing);
        await disposeHomeScreen(tester);
      },
    );

    testWidgets(
      'keeps the stored licence active when persisted exams use centre numbers',
      (tester) async {
        await activatePilotLicence();
        await sessionService.initialize();
        await sessionService.persistHomeState(
          cards: [buildExamCard()],
          archiveCards: const [],
          lastUsed: buildLastUsed(
            school: 'Other Academy',
            centre: 'OA',
            subject: 'Maths',
            board: 'AQA',
            start: '09:00',
            duration: '00:02',
            extra: '00:01',
          ),
        );

        await pumpHomeScreen(tester);

        expect(find.text('Licence Required'), findsNothing);

        await restartHomeScreen(tester);

        expect(find.text('Licence Required'), findsNothing);
        await disposeHomeScreen(tester);
      },
    );
  });
}
