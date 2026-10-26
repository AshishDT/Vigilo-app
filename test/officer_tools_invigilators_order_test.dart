import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/schedule.dart';
import 'package:vigilo/views/officer_tools_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Invigilator names preserve user-entered order and format to comma-separated single line on save', (
    WidgetTester tester,
  ) async {
    ExamCardData currentData = ExamCardData(
      school: 'School 1',
      centreNumber: '12345',
      subject: 'Mathematics',
      date: '16 Oct 2026',
      start: '10:00:00',
      duration: '01:30',
      end: '11:30:00',
      normalStart: '10:00',
      normalDuration: '01:30',
      normalEnd: '11:30',
      extraTime: '00:00',
      totalDuration: '01:30',
      extraEnd: '11:30',
      roomsSnapshot: 'Main Hall',
      invigilatorsSnapshot: '',
      scheduleList: [
        ScheduleData(
          time: '10:00 - 11:30',
          room: 'Main Hall',
          invigilators: const [],
          notes: '',
        ),
      ],
    );

    ExamCardData? savedData;
    bool saveCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficerToolsSheet(
            data: currentData,
            initialTabIndex: 0, // Setup tab
            onLog: (_) {},
            onReStart: () async {},
            onPause: () {},
            onEnd: () async {},
            onExportCopy: () {},
            onExportCsvDownload: () {},
            onExportCsvShare: () {},
            onToggleAutoStart: (_) {},
            onDeleteData: () {},
            onUpdateData: (updated) {
              currentData = updated;
              savedData = updated;
            },
            onSaveData: () {
              saveCalled = true;
            },
            isExamCompleted: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find the Invigilators text field (has hintText 'Add invigilator names')
    final invigilatorField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Add invigilator names',
    );
    expect(invigilatorField, findsOneWidget);

    // Enter non-alphabetically sorted names with newlines (Enter key between each)
    const typedNames = "James Bond\nDonald Duck\nMickey Mouse";
    await tester.enterText(invigilatorField, typedNames);
    await tester.pump();

    // Verify it contains the raw multiline input prior to tapping save
    final textFieldBeforeSave = tester.widget<TextField>(invigilatorField);
    expect(textFieldBeforeSave.controller?.text, equals(typedNames));

    // Tap "Save Changes" button
    final saveButton = find.text('Save Changes');
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(saveCalled, isTrue);
    expect(savedData, isNotNull);

    // 1. Text field must immediately format to a single comma-separated line
    final textFieldAfterSave = tester.widget<TextField>(invigilatorField);
    expect(
      textFieldAfterSave.controller?.text,
      equals('James Bond, Donald Duck, Mickey Mouse'),
    );

    // 2. Saved data must strictly preserve typed order, NOT sorted alphabetically
    expect(
      savedData!.invigilatorsSnapshot,
      equals('James Bond, Donald Duck, Mickey Mouse'),
    );
    expect(
      savedData!.scheduleList!.first.invigilators,
      equals(['James Bond', 'Donald Duck', 'Mickey Mouse']),
    );

    // 3. Re-open sheet with savedData to simulate returning to Officer Tools
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficerToolsSheet(
            data: savedData!,
            initialTabIndex: 0, // Setup tab
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reloadedField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.controller?.text == 'James Bond, Donald Duck, Mickey Mouse',
    );
    expect(reloadedField, findsOneWidget);
    final reloadedTextField = tester.widget<TextField>(reloadedField);
    expect(
      reloadedTextField.controller?.text,
      equals('James Bond, Donald Duck, Mickey Mouse'),
    );
  });
}
