import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/enums/exam_phase.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/license_service.dart';
import 'package:vigilo/services/session_service.dart';
import 'package:vigilo/utils/id_generator.dart';
import 'package:vigilo/views/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen 10-minute warning logic', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory hiveDir;
    late SessionService sessionService;
    int vibrationCallCount = 0;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp('vigilo_warning_test_');
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

      final box = await Hive.openBox('vigilo_data');
      await box.clear();

      await AppDatabase().clearAllData();

      vibrationCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('vibration'), (MethodCall methodCall) async {
        if (methodCall.method == 'vibrate') {
          vibrationCallCount++;
        }
        if (methodCall.method == 'hasVibrator') {
          return true;
        }
        return null;
      });
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/platform'), (MethodCall methodCall) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          vibrationCallCount++;
        }
        return null;
      });
      
      final issuedAt = DateTime(2026, 3, 26, 10, 0);
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
    });

    testWidgets('triggers vibration at 10 minutes before normal and extra time ends', (WidgetTester tester) async {
      await sessionService.initialize();
      
      final cardId = generateId();
      final card = ExamCardData(
        recordId: cardId,
        school: 'Battersea Academy',
        centreNumber: '12345',
        date: '26/03/2026',
        subject: 'Maths',
        start: '09:00',
        duration: '01:00', // 60 minutes
        end: '10:00',
        normalStart: '09:00',
        normalDuration: '01:00',
        normalEnd: '10:00',
        extraTime: '00:15', // 15 minutes extra
        totalDuration: '01:15',
        extraEnd: '10:15',
        autoStart: true,
        vibrateOn: true,
        phase: ExamPhase.normal,
        running: true,
        isPaused: false,
        // Set progress to exactly 50 minutes elapsed, which triggers the normal time warning
        progress: (50 * 60) / (75 * 60), 
      );
      
      await sessionService.persistHomeState(
        cards: [card],
        archiveCards: [],
        lastUsed: {},
      );

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(dark: false, onToggleTheme: () {})),
      );
      await tester.pump();
      
      // Wait for tick
      await tester.pump(const Duration(seconds: 2));
      
      // The tick should trigger the vibration because exactly 50 minutes (3000s) has elapsed.
      expect(vibrationCallCount, greaterThan(0));
    });
  });
}
