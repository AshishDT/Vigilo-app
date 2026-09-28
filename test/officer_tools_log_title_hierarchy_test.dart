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
    testWidgets('Medical incident renders title at w700 and candidate reference at w400', (tester) async {
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

      final textFinder = find.text('Medical Incident\nStudent: FR973');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.textSpan, isNotNull);

      final rootSpan = textWidget.textSpan as TextSpan;
      final titleSpan = rootSpan.children![0] as TextSpan;
      final newlineSpan = rootSpan.children![1] as TextSpan;
      final candidateSpan = rootSpan.children![2] as TextSpan;

      expect(titleSpan.text, equals('Medical Incident'));
      expect(titleSpan.style?.fontWeight, equals(FontWeight.w700));

      expect(newlineSpan.text, equals('\n'));

      expect(candidateSpan.text, equals('Student: FR973'));
      expect(candidateSpan.style?.fontWeight, equals(FontWeight.w400));
    });

    testWidgets('Log item without candidate reference renders title at w700 as standard Text', (tester) async {
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
      expect(textWidget.style?.fontWeight, equals(FontWeight.w700));
    });

    testWidgets('Late arrival renders inline title "Late Arrival (Admitted)" and "Student: [code]" on line two', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lateArrivalIncident = Incident(
        'Late arrival',
        eventType: 'incident',
        incidentType: 'late_arrival',
        studentID: 'FT543',
        action: 'Admitted',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [lateArrivalIncident]),
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

      final textFinder = find.text('Late Arrival (Admitted)\nStudent: FT543');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.textSpan, isNotNull);

      final rootSpan = textWidget.textSpan as TextSpan;
      final titleSpan = rootSpan.children![0] as TextSpan;
      final newlineSpan = rootSpan.children![1] as TextSpan;
      final candidateSpan = rootSpan.children![2] as TextSpan;

      expect(titleSpan.text, equals('Late Arrival (Admitted)'));
      expect(titleSpan.style?.fontWeight, equals(FontWeight.w700));
      expect(newlineSpan.text, equals('\n'));
      expect(candidateSpan.text, equals('Student: FT543'));
      expect(candidateSpan.style?.fontWeight, equals(FontWeight.w400));
    });

    testWidgets('Toilet visit renders "Toilet Visit (Approved)" and "Student: [code]" on line two', (tester) async {
      final toiletIncident = Incident(
        'Toilet break',
        eventType: 'incident',
        incidentType: 'toilet_visit',
        studentID: 'FT543',
        action: 'Approved',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [toiletIncident]),
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

      final textFinder = find.text('Toilet Visit (Approved)\nStudent: FT543');
      expect(textFinder, findsOneWidget);
    });

    testWidgets('Sanitizes redundant "Students :" or "Student:" prefixes in studentID', (tester) async {
      final incident = Incident(
        'Medical incident',
        eventType: 'incident',
        incidentType: 'medical',
        studentID: 'Students : Ertff',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: _createExamData(logs: [incident]),
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

      // Verifies it does NOT render "Student: Students : Ertff"
      final textFinder = find.text('Medical Incident\nStudent: Ertff');
      expect(textFinder, findsOneWidget);
    });
  });
}

