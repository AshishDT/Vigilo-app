import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/schedule.dart';
import 'package:vigilo/views/officer_tools_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ExamCardData buildExamCardData() {
    return ExamCardData(
      school: 'Test School',
      date: '2026-03-19',
      subject: 'Mathematics',
      start: '09:00',
      duration: '02:00',
      end: '11:00',
      normalStart: '09:00',
      normalDuration: '02:00',
      normalEnd: '11:00',
      extraTime: '00:00',
      totalDuration: '02:00',
      extraEnd: '11:00',
      scheduleList: [
        ScheduleData(
          time: '09:00 - 11:00',
          room: 'Hall A',
          invigilators: ['Alice'],
          notes: '',
        ),
      ],
    );
  }

  Finder messageField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Type a message',
    );
  }

  testWidgets(
    'Messages tab removes Pro banner and still sends without a Pro licence',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      var updatedData = buildExamCardData();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfficerToolsSheet(
              isExamCompleted: false,
              data: updatedData,
              initialTabIndex: 2,
              onLog: (_) {},
              onReStart: () {},
              onPause: () {},
              onEnd: () {},
              onExportCopy: () {},
              onExportCsvDownload: () {},
              onExportCsvShare: () {},
              onToggleAutoStart: (_) {},
              onDeleteData: () {},
              onUpdateData: (value) => updatedData = value,
              onSaveData: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Messages is a Pro feature. Core users can view this tab, but sending messages, briefings sharing and preset management requires a Pro licence.',
        ),
        findsNothing,
      );

      await tester.tap(find.text('No Invigilators selected'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final fieldFinder = messageField();
      await tester.ensureVisible(fieldFinder);
      await tester.enterText(fieldFinder, 'Status check');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.send_rounded);
      await tester.ensureVisible(sendButtonFinder);
      await tester.tap(sendButtonFinder);
      await tester.pumpAndSettle();

      expect(updatedData.messages, isNotNull);
      expect(updatedData.messages, hasLength(1));
      expect(updatedData.messages!.single.message, 'to Alice: Status check');
      expect(find.text('To: Alice'), findsWidgets);
      expect(find.text('Status check'), findsOneWidget);
    },
  );

  testWidgets('Incidents tab uses malpractice wording', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficerToolsSheet(
            isExamCompleted: false,
            data: buildExamCardData(),
            initialTabIndex: 3,
            onLog: (_) {},
            onReStart: () {},
            onPause: () {},
            onEnd: () {},
            onExportCopy: () {},
            onExportCsvDownload: () {},
            onExportCsvShare: () {},
            onToggleAutoStart: (_) {},
            onDeleteData: () {},
            onUpdateData: (_) {},
            onSaveData: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Malpractice'), findsOneWidget);
    expect(find.text('Cheating'), findsNothing);

    await tester.tap(find.text('Malpractice'));
    await tester.pumpAndSettle();

    expect(find.text('Record a malpractice concern'), findsOneWidget);
    expect(find.text('Suspected cheating'), findsNothing);
  });
}
