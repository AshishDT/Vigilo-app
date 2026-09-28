import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/incident.dart';
import 'package:vigilo/views/officer_tools_screen.dart';

ExamCardData _createExamData({List<Incident>? logs}) {
  return ExamCardData(
    school: 'Test School',
    date: '2026-09-24',
    subject: 'Mathematics',
    start: '09:00 AM',
    duration: '01:30',
    end: '10:30 AM',
    normalStart: '09:00 AM',
    normalDuration: '01:30',
    normalEnd: '10:30 AM',
    extraTime: '00:00',
    totalDuration: '01:30',
    extraEnd: '10:30 AM',
    logs: logs ?? [],
  );
}

void main() {
  group('Malpractice Incident Features', () {
    testWidgets('Malpractice dialog has shortened details placeholder without multi-candidate statement text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(),
              onLog: (_) {},
              onReStart: () async {},
              onPause: () {},
              onEnd: () async {},
              onExportCopy: () {},
              onExportCsvDownload: () {},
              onExportCsvShare: () {},
              onToggleAutoStart: (_) {},
              onDeleteData: () {},
              onUpdateData: (_) {},
              onSaveData: () {},
              isExamCompleted: false,
              initialTabIndex: 3, // Incidents tab
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Malpractice action button
      await tester.tap(find.text('Malpractice'));
      await tester.pumpAndSettle();

      // Verify shortened hint is present
      expect(
        find.text(
          'Describe the observed behaviour factually.\n\n'
          'e.g. Mobile phone rang from Candidate A\'s bag at 10:42.',
        ),
        findsOneWidget,
      );

      // Verify the dropped multi-candidate statement text is NOT present
      expect(
        find.textContaining('Statements taken from Candidates A, B and C'),
        findsNothing,
      );
    });

    testWidgets('Incidents tab card displays "Students: GY876, HL332, FT333, DV987" for multi-candidate', (tester) async {
      final multiIncident = Incident(
        'Malpractice',
        eventType: 'incident',
        incidentType: 'malpractice',
        studentID: 'GY876\nHL332\nFT333\nDV987',
        room: 'Main Hall',
        detail: 'Talking during exam',
        action: 'Reported to supervisor',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [multiIncident]),
              onLog: (_) {},
              onReStart: () async {},
              onPause: () {},
              onEnd: () async {},
              onExportCopy: () {},
              onExportCsvDownload: () {},
              onExportCsvShare: () {},
              onToggleAutoStart: (_) {},
              onDeleteData: () {},
              onUpdateData: (_) {},
              onSaveData: () {},
              isExamCompleted: false,
              initialTabIndex: 3, // Incidents tab
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Plural label and comma-separated candidates
      expect(find.text('Students: GY876, HL332, FT333, DV987'), findsOneWidget);
      // Singular label should not be displayed
      expect(find.text('Student: GY876, HL332, FT333, DV987'), findsNothing);
    });

    testWidgets('Incidents tab card displays "Student: VG987" for single candidate', (tester) async {
      final singleIncident = Incident(
        'Malpractice',
        eventType: 'incident',
        incidentType: 'malpractice',
        studentID: 'VG987',
        room: 'Main Hall',
        detail: 'Unauthorized notes',
        action: 'Notes confiscated',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [singleIncident]),
              onLog: (_) {},
              onReStart: () async {},
              onPause: () {},
              onEnd: () async {},
              onExportCopy: () {},
              onExportCsvDownload: () {},
              onExportCsvShare: () {},
              onToggleAutoStart: (_) {},
              onDeleteData: () {},
              onUpdateData: (_) {},
              onSaveData: () {},
              isExamCompleted: false,
              initialTabIndex: 3, // Incidents tab
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student: VG987'), findsOneWidget);
    });

    testWidgets('Log tab summary row and expanded detail format candidates comma-separated with dynamic label', (tester) async {
      final multiIncident = Incident(
        'Malpractice',
        eventType: 'incident',
        incidentType: 'malpractice',
        studentID: 'GY876\nHL332\nFT333\nDV987',
        room: 'Main Hall',
        detail: 'Phone rang',
        action: 'Phone confiscated',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [multiIncident]),
              onLog: (_) {},
              onReStart: () async {},
              onPause: () {},
              onEnd: () async {},
              onExportCopy: () {},
              onExportCsvDownload: () {},
              onExportCsvShare: () {},
              onToggleAutoStart: (_) {},
              onDeleteData: () {},
              onUpdateData: (_) {},
              onSaveData: () {},
              isExamCompleted: false,
              initialTabIndex: 4, // Log tab
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Summary row shows title and comma-separated candidates on second line
      expect(find.text('Malpractice\nStudents: GY876, HL332, FT333, DV987'), findsOneWidget);

      // Tap the row to expand details
      await tester.tap(find.text('Malpractice\nStudents: GY876, HL332, FT333, DV987'));
      await tester.pumpAndSettle();

      // Candidates are shown ONLY in the summary header row, not duplicated in the expanded drawer.
      // The expanded detail must NOT contain a standalone Students: / Student ID: row.
      expect(find.text('Students: GY876, HL332, FT333, DV987'), findsNothing);
      expect(find.text('Student ID: GY876, HL332, FT333, DV987'), findsNothing);

      // Expanded drawer does show the non-candidate detail fields
      expect(find.text('Details: Phone rang'), findsOneWidget);
      expect(find.text('Action taken: Phone confiscated'), findsOneWidget);
    });
  });
}
