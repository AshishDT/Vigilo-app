import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/services/import_service.dart';
import 'package:vigilo/views/widgets/import_flow_sheet.dart';

void main() {
  group('ImportService Duration Normalization & Conversion Tests', () {
    test('normalizeDuration - valid formats', () {
      expect(ImportService.normalizeDuration('01:30'), '01:30');
      expect(ImportService.normalizeDuration('90'), '01:30');
      expect(ImportService.normalizeDuration('1.5'), '00:02'); // double tryParse mins -> 2 mins
      expect(ImportService.normalizeDuration(''), isNull);
      expect(ImportService.normalizeDuration(null), isNull);
    });

    test('normalizeDuration - negative formats', () {
      expect(ImportService.normalizeDuration('-01:00'), '-01:00');
      expect(ImportService.normalizeDuration('-60'), '-01:00');
      expect(ImportService.normalizeDuration('-1.5'), '-00:02');
    });

    test('durationToMinutes - conversion', () {
      expect(ImportService.durationToMinutes('01:30'), 90);
      expect(ImportService.durationToMinutes('00:00'), 0);
      expect(ImportService.durationToMinutes('-01:00'), -60);
      expect(ImportService.durationToMinutes('-00:30'), -30);
      expect(ImportService.durationToMinutes('00:-30'), -30);
    });
  });

  group('ImportFlowSheet Past-Date Validation Tests', () {
    testWidgets('rejects past-dated rows and flags reason in preview', (WidgetTester tester) async {
      List<dynamic> imported = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportFlowSheet(
              dark: false,
              onToggleTheme: () {},
              initialCentreNumber: '12345',
              onImportSessions: (sessions) async {
                imported = sessions;
              },
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final stateFinder = find.byType(ImportFlowSheet);
      final dynamic state = tester.state(stateFinder);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

      final futureDay = DateTime.now().add(const Duration(days: 10));
      final futureDayStr = "${futureDay.day.toString().padLeft(2, '0')}/${futureDay.month.toString().padLeft(2, '0')}/${futureDay.year}";

      final mockRows = [
        {
          'subject': 'Past Exam Maths',
          'board': 'Edexcel',
          'date': yesterdayStr,
          'time': '09:00',
          'duration': '01:30',
          'room': 'Hall A',
        },
        {
          'subject': 'Future Exam English',
          'board': 'AQA',
          'date': futureDayStr,
          'time': '09:00',
          'duration': '01:30',
          'room': 'Hall B',
        },
      ];

      state.setParsedRowsForTesting(mockRows);
      await tester.pump();

      // Check preview step
      expect(state.stepForTesting, equals(2));

      // 1 valid (future), 1 flagged (past)
      expect(find.text('1 valid'), findsOneWidget);
      expect(find.text('1 flagged'), findsOneWidget);
      expect(find.text('1 sessions to create'), findsOneWidget);

      // Verify the past date error message is rendered in preview
      expect(find.textContaining('Scheduled date is in the past'), findsOneWidget);
      expect(find.text('Past Exam Maths'), findsOneWidget);
      expect(find.text('Future Exam English'), findsOneWidget);
    });

    testWidgets('rejects today rows with past start time', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportFlowSheet(
              dark: false,
              onToggleTheme: () {},
              initialCentreNumber: '12345',
              onImportSessions: (sessions) async {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final stateFinder = find.byType(ImportFlowSheet);
      final dynamic state = tester.state(stateFinder);

      final now = DateTime.now();
      final todayStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

      // If current time is after 00:05, test an earlier time today
      if (now.hour > 0 || now.minute > 10) {
        final pastTime = "00:01";
        final mockRows = [
          {
            'subject': 'Past Time Today',
            'board': 'OCR',
            'date': todayStr,
            'time': pastTime,
            'duration': '01:00',
            'room': 'Gym',
          },
        ];

        state.setParsedRowsForTesting(mockRows);
        await tester.pump();

        expect(find.text('0 valid'), findsOneWidget);
        expect(find.text('1 flagged'), findsOneWidget);
        expect(find.textContaining('Scheduled time is in the past'), findsOneWidget);
      }
    });

    testWidgets('renders long error text, long notes, and long rooms without RenderFlex overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportFlowSheet(
              dark: false,
              onToggleTheme: () {},
              initialCentreNumber: '12345',
              onImportSessions: (sessions) async {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final stateFinder = find.byType(ImportFlowSheet);
      final dynamic state = tester.state(stateFinder);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

      final mockRows = [
        {
          'subject': 'Very Long Subject Name For An Advanced Qualification Examination 2026',
          'board': 'Cambridge International Examinations Board UK',
          'date': yesterdayStr,
          'time': '09:00',
          'duration': '01:30',
          'room': 'Extraordinarily Long Main Examination Sports Hall Complex Block C Room 102',
          'notes': 'This is an extremely long note containing detailed instructions for invigilators and candidates regarding examination conduct and special arrangements.',
        },
      ];

      state.setParsedRowsForTesting(mockRows);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('1 flagged'), findsOneWidget);
      expect(find.textContaining('Scheduled date is in the past'), findsOneWidget);
    });

    testWidgets('shows clean Missing and Invalid messages for Date and Start Time', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportFlowSheet(
              dark: false,
              onToggleTheme: () {},
              initialCentreNumber: '12345',
              onImportSessions: (sessions) async {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final stateFinder = find.byType(ImportFlowSheet);
      final dynamic state = tester.state(stateFinder);

      final mockRows = [
        {
          'subject': 'Exam Missing Both',
          'board': 'Edexcel',
          'date': '',
          'time': '',
          'duration': '01:30',
        },
        {
          'subject': 'Exam Invalid Both',
          'board': 'AQA',
          'date': 'InvalidDate',
          'time': 'InvalidTime',
          'duration': '01:30',
        },
      ];

      state.setParsedRowsForTesting(mockRows);
      await tester.pump();

      expect(find.text('Missing Date'), findsOneWidget);
      expect(find.text('Missing Start Time'), findsOneWidget);
      expect(find.text('Invalid Date ("InvalidDate")'), findsOneWidget);
      expect(find.text('Invalid Start Time ("InvalidTime")'), findsOneWidget);
    });

    testWidgets('accepts YYYY-MM-DD dates without flagging Invalid Date', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportFlowSheet(
              dark: false,
              onToggleTheme: () {},
              initialCentreNumber: '12345',
              onImportSessions: (sessions) async {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final stateFinder = find.byType(ImportFlowSheet);
      final dynamic state = tester.state(stateFinder);

      final nextYear = DateTime.now().year + 1;
      final mockRows = [
        {
          'subject': 'Biology Paper 1',
          'level': 'GCSE',
          'board': 'AQA',
          'date': '$nextYear-05-12',
          'time': '09:00',
          'duration': '01:30',
        },
      ];

      state.setParsedRowsForTesting(mockRows);
      await tester.pump();

      expect(find.textContaining('Invalid Date'), findsNothing);
    });
  });

  group('ImportService Date Normalization Tests', () {
    test('normalizeDate - accepts ISO YYYY-MM-DD formats', () {
      expect(ImportService.normalizeDate('2026-05-12'), '12/05/2026');
      expect(ImportService.normalizeDate('2026-5-2'), '02/05/2026');
      expect(ImportService.normalizeDate('2024-02-29'), '29/02/2024'); // leap year
    });

    test('normalizeDate - accepts DD/MM/YYYY and DD-MM-YYYY formats', () {
      expect(ImportService.normalizeDate('12/05/2026'), '12/05/2026');
      expect(ImportService.normalizeDate('2/5/2026'), '02/05/2026');
      expect(ImportService.normalizeDate('12/05/26'), '12/05/2026');
      expect(ImportService.normalizeDate('12-05-2026'), '12/05/2026');
      expect(ImportService.normalizeDate('2-5-2026'), '02/05/2026');
    });

    test('normalizeDate - accepts D MMM YYYY format', () {
      expect(ImportService.normalizeDate('12 May 2026'), '12/05/2026');
      expect(ImportService.normalizeDate('2 Jan 2026'), '02/01/2026');
      expect(ImportService.normalizeDate('15 October 2026'), '15/10/2026');
    });

    test('normalizeDate - rejects invalid dates', () {
      expect(ImportService.normalizeDate(''), isNull);
      expect(ImportService.normalizeDate('   '), isNull);
      expect(ImportService.normalizeDate('InvalidDate'), isNull);
      expect(ImportService.normalizeDate('2026-02-31'), isNull); // Feb 31 does not exist
      expect(ImportService.normalizeDate('2026-13-01'), isNull); // Month 13 invalid
      expect(ImportService.normalizeDate('31/02/2026'), isNull); // Feb 31 does not exist in DMY
      expect(ImportService.normalizeDate('00/05/2026'), isNull); // Day 0 invalid
    });
  });
}
