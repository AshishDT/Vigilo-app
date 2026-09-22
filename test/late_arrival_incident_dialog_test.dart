import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/incident.dart';
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
      expect(find.text('ADMITTED TO SIT THE EXAM?'), findsOneWidget);

      // Finish time and warning should not be visible before Admitted is selected
      expect(find.text('CANDIDATE ACTUAL FINISH TIME'), findsNothing);
      expect(find.text('CANDIDATE WARNED SCRIPT MAY NOT BE ACCEPTED?'), findsNothing);

      // Tap Admitted
      await tester.tap(find.text('Admitted'));
      await tester.pumpAndSettle();

      // Now both fields appear
      expect(find.text('CANDIDATE ACTUAL START TIME'), findsOneWidget);
      expect(find.text('CANDIDATE ACTUAL FINISH TIME'), findsOneWidget);
      expect(find.text('CANDIDATE WARNED SCRIPT MAY NOT BE ACCEPTED?'), findsOneWidget);
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
  });
}
