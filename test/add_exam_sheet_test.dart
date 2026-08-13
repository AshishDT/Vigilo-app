import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/views/widgets/add_exam_sheet.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(size: Size(800, 1200)),
          child: SizedBox(
            height: 1200,
            width: 800,
            child: child,
          ),
        ),
      ),
    );
  }

  group('AddExamSheet Exam Level Tests', () {
    testWidgets('shows custom level field only when "Other" is selected and passes custom level on save', (WidgetTester tester) async {
      String? savedLevel;

      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Physics',
            lastBoard: 'AQA',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {
              savedLevel = level;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom level text field is not visible initially
      expect(find.text('Specify Exam Level'), findsNothing);

      final dropdownFinder = find.byType(DropdownButton<String>).first;
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Select 'Other' from dropdown menu items
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Verify custom level text field is now displayed
      expect(find.text('Specify Exam Level'), findsOneWidget);
      expect(find.text('Enter custom exam level'), findsOneWidget);

      // Enter a custom level
      final customFieldFinder = find.widgetWithText(TextField, 'Enter custom exam level');
      await tester.ensureVisible(customFieldFinder);
      await tester.enterText(customFieldFinder, 'BTEC Higher');
      await tester.pumpAndSettle();

      // Tap Save button
      final saveFinder = find.text('Save');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(savedLevel, equals('BTEC Higher'));
    });

    testWidgets('passes null on save when "Other" is selected but nothing is entered', (WidgetTester tester) async {
      String? savedLevel = 'initial_sentinel';

      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Physics',
            lastBoard: 'AQA',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {
              savedLevel = level;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButton<String>).first;
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Select 'Other' from dropdown menu items but leave input empty
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Tap Save button
      final saveFinder = find.text('Save');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(savedLevel, isNull);
    });

    testWidgets('clears custom level text field when dropdown level changes away from "Other"', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Physics',
            lastBoard: 'AQA',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButton<String>).first;
      await tester.ensureVisible(dropdownFinder);

      // Open dropdown and select 'Other'
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Type custom level
      final customFieldFinder = find.widgetWithText(TextField, 'Enter custom exam level');
      await tester.ensureVisible(customFieldFinder);
      await tester.enterText(customFieldFinder, 'BTEC');
      await tester.pumpAndSettle();

      // Unfocus before opening dropdown again
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Open dropdown again and select 'A Level'
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A Level').last);
      await tester.pumpAndSettle();

      // Custom level input field should disappear
      expect(find.text('Specify Exam Level'), findsNothing);

      // Open dropdown again and select 'Other'
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Custom input field should be empty (cleared)
      final textField = tester.widget<TextField>(find.widgetWithText(TextField, 'Enter custom exam level'));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('pre-populates custom level when lastLevel is a non-standard level string', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Computer Science',
            lastBoard: 'OCR',
            lastLevel: 'IB Diploma',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom level field is visible and pre-populated with 'IB Diploma'
      expect(find.text('Specify Exam Level'), findsOneWidget);
      expect(find.text('IB Diploma'), findsOneWidget);
    });
  });

  group('AddExamSheet Exam Board Tests', () {
    testWidgets('shows custom board field only when "Other" is selected and passes custom board on save', (WidgetTester tester) async {
      String? savedBoard;

      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Physics',
            lastBoard: '',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {
              savedBoard = board;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom board text field is not visible initially
      expect(find.text('Specify Exam Board'), findsNothing);

      // Find the second dropdown (first is Exam Level, second is Exam Board)
      final dropdownFinders = find.byType(DropdownButton<String>);
      expect(dropdownFinders, findsNWidgets(2));
      
      // Tap the second dropdown (Exam Board)
      await tester.ensureVisible(dropdownFinders.at(1));
      await tester.tap(dropdownFinders.at(1), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Select 'Other' from dropdown menu items
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Verify custom board text field is now displayed
      expect(find.text('Specify Exam Board'), findsOneWidget);
      expect(find.text('Enter custom exam board'), findsOneWidget);

      // Enter a custom board
      final customFieldFinder = find.widgetWithText(TextField, 'Enter custom exam board');
      await tester.ensureVisible(customFieldFinder);
      await tester.enterText(customFieldFinder, 'WJEC');
      await tester.pumpAndSettle();

      // Tap Save button
      final saveFinder = find.text('Save');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(savedBoard, equals('WJEC'));
    });

    testWidgets('validation prevents saving when dropdown is set to "Other" but custom board text field is empty', (WidgetTester tester) async {
      bool onSaveCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Physics',
            lastBoard: '',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {
              onSaveCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownFinders = find.byType(DropdownButton<String>);
      await tester.ensureVisible(dropdownFinders.at(1));
      await tester.tap(dropdownFinders.at(1), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Select 'Other' from dropdown menu items but leave input empty
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Tap Save button
      final saveFinder = find.text('Save');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(onSaveCalled, isFalse);
    });

    testWidgets('clears custom board text field when dropdown board changes away from "Other"', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Physics',
            lastBoard: '',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownFinders = find.byType(DropdownButton<String>);
      
      // Open dropdown and select 'Other'
      await tester.ensureVisible(dropdownFinders.at(1));
      await tester.tap(dropdownFinders.at(1), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Type custom board
      final customFieldFinder = find.widgetWithText(TextField, 'Enter custom exam board');
      await tester.ensureVisible(customFieldFinder);
      await tester.enterText(customFieldFinder, 'WJEC');
      await tester.pumpAndSettle();

      // Unfocus before opening dropdown again
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Open dropdown again and select 'AQA'
      await tester.ensureVisible(dropdownFinders.at(1));
      await tester.tap(dropdownFinders.at(1), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AQA').last);
      await tester.pumpAndSettle();

      // Custom board input field should disappear
      expect(find.text('Specify Exam Board'), findsNothing);

      // Open dropdown again and select 'Other'
      await tester.ensureVisible(dropdownFinders.at(1));
      await tester.tap(dropdownFinders.at(1), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      // Custom input field should be empty (cleared)
      final textField = tester.widget<TextField>(find.widgetWithText(TextField, 'Enter custom exam board'));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('pre-populates custom board when lastBoard is a non-standard board string', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AddExamSheet(
            lastSchool: 'Northbridge Academy',
            lastCentre: '12345',
            lastSubject: 'Computer Science',
            lastBoard: 'CIE',
            onSave: ({
              required school,
              required centre,
              required subject,
              required board,
              level,
              required date,
              required startTime,
              required duration,
              required extraTime,
            }) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom board field is visible and pre-populated with 'CIE'
      expect(find.text('Specify Exam Board'), findsOneWidget);
      expect(find.text('CIE'), findsOneWidget);
    });
  });
}
