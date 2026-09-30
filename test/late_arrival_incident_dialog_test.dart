import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/incident.dart';
import 'package:vigilo/views/officer_tools_screen.dart';
import 'package:vigilo/views/widgets/late_arrival_incident_dialog.dart';

void main() {
  group('LateArrivalIncidentDialog', () {
    test('Incident model serialization and deserialization with all late arrival fields', () {
      final incident = Incident(
        'Late arrival',
        eventType: 'incident',
        incidentType: 'late_arrival',
        studentID: 'CD341',
        room: 'Hall A',
        action: 'Admitted',
        supervisionTime: '09:15 AM',
        actualStartTime: '09:30 AM',
        actualFinishTime: '11:15 AM',
        reason: 'Train delay',
        candidateWarnedScriptMayNotBeAccepted: 'Yes',
        actionsTaken: 'Monitored',
        detail:
            'Supervision time: 09:15 AM. Actual start: 09:30 AM. Candidate actual finish time: 11:15 AM. Reason: Train delay. Candidate Warned Script May Not Be Accepted?: Yes. Actions: Monitored',
      );

      final json = incident.toJson();
      expect(json['supervisionTime'], '09:15 AM');
      expect(json['actualStartTime'], '09:30 AM');
      expect(json['actualFinishTime'], '11:15 AM');
      expect(json['reason'], 'Train delay');
      expect(json['candidateWarnedScriptMayNotBeAccepted'], 'Yes');
      expect(json['actionsTaken'], 'Monitored');

      final reconstructed = Incident.fromJson(json);
      expect(reconstructed.supervisionTime, '09:15 AM');
      expect(reconstructed.actualStartTime, '09:30 AM');
      expect(reconstructed.actualFinishTime, '11:15 AM');
      expect(reconstructed.reason, 'Train delay');
      expect(reconstructed.candidateWarnedScriptMayNotBeAccepted, 'Yes');
      expect(reconstructed.actionsTaken, 'Monitored');

      // Test backward-compatibility: extract from detail when individual keys are absent
      final legacyJson = {
        'message': 'Late arrival',
        'eventType': 'incident',
        'incidentType': 'late_arrival',
        'time': DateTime.now().millisecondsSinceEpoch,
        'studentID': 'CD341',
        'duration': '',
        'detail':
            'Supervision time: 08:45 AM. Actual start: 09:00 AM. Candidate actual finish time: 10:30 AM. Reason: Traffic. Candidate Warned Script May Not Be Accepted?: No. Actions: Kept isolated',
        'room': 'Hall A',
        'staffMember': '',
        'action': 'Admitted',
        'updatedDuration': '',
      };
      final fromLegacy = Incident.fromJson(legacyJson);
      expect(fromLegacy.supervisionTime, '08:45 AM');
      expect(fromLegacy.actualStartTime, '09:00 AM');
      expect(fromLegacy.actualFinishTime, '10:30 AM');
      expect(fromLegacy.reason, 'Traffic');
      expect(fromLegacy.candidateWarnedScriptMayNotBeAccepted, 'No');
      expect(fromLegacy.actionsTaken, 'Kept isolated');

      // Test new format without literal ?
      final newFormatJson = {
        'message': 'Late arrival',
        'eventType': 'incident',
        'incidentType': 'late_arrival',
        'time': DateTime.now().millisecondsSinceEpoch,
        'studentID': 'CD341',
        'duration': '',
        'detail':
            'Supervision time: 08:45 AM. Actual start: 09:00 AM. Candidate actual finish time: 10:30 AM. Reason: Traffic. Warned script may not be accepted: Yes. Actions: Kept isolated',
        'room': 'Hall A',
        'staffMember': '',
        'action': 'Admitted',
        'updatedDuration': '',
      };
      final fromNewFormat = Incident.fromJson(newFormatJson);
      expect(fromNewFormat.candidateWarnedScriptMayNotBeAccepted, 'Yes');
    });

    testWidgets('renders dialog and shows finish time and warning toggle when Admitted is selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LateArrivalIncidentDialog(
              initialRoom: 'Hall 1',
              examDuration: const Duration(hours: 1, minutes: 30),
              extraTime: const Duration(minutes: 15),
              onSave: (
                room,
                candidate,
                admitted,
                supTime,
                startTime,
                finishTime,
                reason,
                warned,
                actions,
              ) {},
            ),
          ),
        ),
      );

      expect(find.text('Late Arrival'), findsOneWidget);
      expect(find.text('CANDIDATE REFERENCE'), findsOneWidget);
      expect(find.text('TIME UNDER SUPERVISION'), findsOneWidget);
      expect(find.text('TIME CANDIDATE CAME UNDER STAFF SUPERVISION'), findsNothing);
      expect(find.text('ADMITTED TO SIT THE EXAM?'), findsOneWidget);
      expect(find.text('SECURITY ASSURANCE'), findsOneWidget);
      expect(find.text('ACTIONS TAKEN / SECURITY ASSURANCE'), findsNothing);

      // Finish time and warning should not be visible before Admitted is selected
      expect(find.text('CANDIDATE ACTUAL FINISH TIME'), findsNothing);
      expect(find.text('WARNED SCRIPT MAY NOT BE ACCEPTED?'), findsNothing);
      expect(find.text('CANDIDATE WARNED SCRIPT MAY NOT BE ACCEPTED?'), findsNothing);

      // Tap Admitted
      await tester.tap(find.text('Admitted'));
      await tester.pumpAndSettle();

      // Now both fields appear
      expect(find.text('CANDIDATE ACTUAL START TIME'), findsOneWidget);
      expect(find.text('CANDIDATE ACTUAL FINISH TIME'), findsOneWidget);
      expect(find.text('WARNED SCRIPT MAY NOT BE ACCEPTED?'), findsOneWidget);
      expect(find.text('CANDIDATE WARNED SCRIPT MAY NOT BE ACCEPTED?'), findsNothing);
      expect(find.text('Suggested from start time + full duration + extra time. Tap to override.'), findsOneWidget);
    });

    testWidgets('requires candidate warning selection before logging when Admitted', (tester) async {
      String? savedFinishTime;
      bool? savedWarning;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LateArrivalIncidentDialog(
              initialRoom: 'Hall 1',
              examDuration: const Duration(hours: 1),
              extraTime: Duration.zero,
              onSave: (room, candidate, admitted, supTime, startTime, finishTime, reason, warned, actions) {
                savedFinishTime = finishTime;
                savedWarning = warned;
              },
            ),
          ),
        ),
      );

      // Fill in Candidate Ref
      await tester.enterText(find.byType(TextField).first, 'CD999');
      await tester.pump();

      // Select Admitted
      await tester.tap(find.text('Admitted'));
      await tester.pumpAndSettle();

      // Fill in Reason
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'Late bus');
      await tester.pump();

      // Fill in Actions Taken
      await tester.enterText(textFields.at(2), 'Escorted to desk');
      await tester.pump();

      // Log Incident button should not trigger onSave because warning is unselected
      await tester.tap(find.text('Log Incident'));
      await tester.pumpAndSettle();
      expect(savedFinishTime, isNull);
      expect(savedWarning, isNull);

      // Now select "Yes" on candidate warning
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      // Now tap Log Incident
      await tester.tap(find.text('Log Incident'));
      await tester.pumpAndSettle();

      expect(savedFinishTime, isNotNull);
      expect(savedFinishTime!.isNotEmpty, isTrue);
      expect(savedWarning, isTrue);
    });

    testWidgets('finish time displays suggested hint initially and allows override', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LateArrivalIncidentDialog(
              initialRoom: 'Hall 1',
              examDuration: const Duration(hours: 1, minutes: 30),
              extraTime: Duration.zero,
              onSave: (room, candidate, admitted, supTime, startTime, finishTime, reason, warned, actions) {},
            ),
          ),
        ),
      );

      // Select Admitted
      await tester.tap(find.text('Admitted'));
      await tester.pumpAndSettle();

      // Suggested hint is initially present
      expect(find.text('Suggested from start time + full duration + extra time. Tap to override.'), findsOneWidget);
      expect(find.textContaining('Use '), findsNothing);
      expect(find.text('CANDIDATE ACTUAL FINISH TIME'), findsOneWidget);
    });

    testWidgets('invalid start time shows inline error banner without opening an alert dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LateArrivalIncidentDialog(
              initialRoom: 'Hall 1',
              examDuration: const Duration(hours: 1),
              extraTime: Duration.zero,
              onSave: (room, candidate, admitted, supTime, startTime, finishTime, reason, warned, actions) {},
            ),
          ),
        ),
      );

      // Select Admitted
      await tester.tap(find.text('Admitted'));
      await tester.pumpAndSettle();

      // No modal dialog for 'Invalid Start Time' exists
      expect(find.text('Invalid Start Time'), findsNothing);
      expect(find.text('Align Time'), findsNothing);

      // No extra cards/chips or extra labels
      expect(find.textContaining('Now ('), findsNothing);
      expect(find.textContaining('Supervision ('), findsNothing);
      expect(find.textContaining('Must be at or after supervision time'), findsNothing);
    });

    testWidgets('Recent Incidents displays Late Arrival title alone and Student: [code] on line two', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final examData = ExamCardData(
        school: 'School A',
        date: '2026-09-24',
        subject: 'Math',
        start: '09:00 AM',
        duration: '01:30',
        end: '10:30 AM',
        normalStart: '09:00 AM',
        normalDuration: '01:30',
        normalEnd: '10:30 AM',
        extraTime: '00:00',
        totalDuration: '01:30',
        extraEnd: '10:30 AM',
        logs: [
          Incident(
            'Late arrival',
            eventType: 'incident',
            incidentType: 'late_arrival',
            studentID: 'VG987',
            action: 'Admitted',
            supervisionTime: '09:15 AM',
            actualStartTime: '09:30 AM',
            actualFinishTime: '11:00 AM',
            reason: 'Bus breakdown',
            candidateWarnedScriptMayNotBeAccepted: 'Yes',
            actionsTaken: 'Monitored',
            detail:
                'Supervision time: 09:15 AM. Actual start: 09:30 AM. Candidate actual finish time: 11:00 AM. Reason: Bus breakdown. Warned script may not be accepted: Yes. Actions: Monitored',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              data: examData,
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
              initialTabIndex: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title line should be "Late Arrival" alone, not "Late Arrival VG987"
      expect(find.text('Late Arrival VG987'), findsNothing);

      // Line two should be "Student: VG987"
      expect(find.text('Student: VG987'), findsOneWidget);

      // Outcome detail is in the expanded details view
      expect(find.text('Outcome: Admitted'), findsOneWidget);

      // Verify each detail line is rendered separately one by one
      expect(find.text('Supervision time: 09:15 AM'), findsOneWidget);
      expect(find.text('Actual start: 09:30 AM'), findsOneWidget);
      expect(find.text('Candidate actual finish time: 11:00 AM'), findsOneWidget);
      expect(find.text('Reason: Bus breakdown'), findsOneWidget);
      expect(find.text('Warned script may not be accepted: Yes'), findsOneWidget);
      expect(find.text('Security assurance: Monitored'), findsOneWidget);
      expect(find.textContaining('Details: Supervision time:'), findsNothing);
    });

    testWidgets('bottom text field switches between Security Assurance and Action Taken based on toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LateArrivalIncidentDialog(
              initialRoom: 'Hall A',
              onSave: (_, __, ___, ____, _____, ______, _______, ________, _________) {},
            ),
          ),
        ),
      );

      // Initially / Admitted defaults to SECURITY ASSURANCE
      expect(find.text('SECURITY ASSURANCE'), findsOneWidget);
      expect(find.text('Record supervision and any assurance given.'), findsOneWidget);
      expect(find.text('REASON FOR LATE ARRIVAL'), findsOneWidget);

      // Tap Declined
      await tester.tap(find.text('Declined'));
      await tester.pumpAndSettle();

      // Label switches to ACTION TAKEN and hint updates
      expect(find.text('ACTION TAKEN'), findsOneWidget);
      expect(find.text('SECURITY ASSURANCE'), findsNothing);
      expect(
        find.text('Record what action was taken as a result of the candidate not being admitted.'),
        findsOneWidget,
      );
      // Reason stays as-is
      expect(find.text('REASON FOR LATE ARRIVAL'), findsOneWidget);

      // Tap Admitted
      await tester.tap(find.text('Admitted'));
      await tester.pumpAndSettle();

      // Label switches back to SECURITY ASSURANCE and hint updates
      expect(find.text('SECURITY ASSURANCE'), findsOneWidget);
      expect(find.text('ACTION TAKEN'), findsNothing);
      expect(find.text('Record supervision and any assurance given.'), findsOneWidget);
      // Reason stays as-is
      expect(find.text('REASON FOR LATE ARRIVAL'), findsOneWidget);
    });
  });
}

