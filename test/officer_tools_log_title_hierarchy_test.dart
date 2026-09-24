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
  group('Log tab officer tools screen title hierarchy', () {
    testWidgets('Medical incident renders title at w600 and candidate reference at w400', (tester) async {
      final medicalIncident = Incident(
        'Medical incident',
        eventType: 'incident',
        incidentType: 'medical_incident',
        studentID: 'FR973',
        room: 'Room 101',
        detail: 'Fainted during exam',
        action: 'First aid given',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [medicalIncident]),
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

      final textFinder = find.text('Medical Incident\nFR973');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.textSpan, isNotNull);

      final rootSpan = textWidget.textSpan as TextSpan;
      final titleSpan = rootSpan.children![0] as TextSpan;
      final newlineSpan = rootSpan.children![1] as TextSpan;
      final candidateSpan = rootSpan.children![2] as TextSpan;

      expect(titleSpan.text, equals('Medical Incident'));
      expect(titleSpan.style?.fontWeight, equals(FontWeight.w600));

      expect(newlineSpan.text, equals('\n'));

      expect(candidateSpan.text, equals('FR973'));
      expect(candidateSpan.style?.fontWeight, equals(FontWeight.w400));
    });

    testWidgets('Log item without candidate reference renders title at w600 as standard Text', (tester) async {
      final logItem = Incident(
        'Invigilator list updated',
        eventType: 'incident',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [logItem]),
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

      final textFinder = find.text('Invigilator list updated');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.data, equals('Invigilator list updated'));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w600));
    });
  });
}
