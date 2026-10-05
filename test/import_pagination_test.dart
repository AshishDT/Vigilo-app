import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/views/widgets/import_flow_sheet.dart';

void main() {
  testWidgets('ImportFlowSheet pagination works correctly for large imports', (WidgetTester tester) async {
    // 1. Pump the ImportFlowSheet
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

    // Find the state object
    final stateFinder = find.byType(ImportFlowSheet);
    expect(stateFinder, findsOneWidget);
    final dynamic state = tester.state(stateFinder);

    // 2. Set up mock parsed rows (17 rows with 6 unique dates to trigger 2 pages)
    final futureYear = DateTime.now().year + 1;
    final mockRows = List.generate(17, (i) => {
      'subject': 'Subject Row $i',
      'board': 'Edexcel',
      'date': '${20 + (i % 6)}/08/$futureYear', // 20/08 to 25/08 in future year (6 unique dates)
      'time': '09:00',
      'duration': '01:30',
      'room': 'Room A',
    });

    state.setParsedRowsForTesting(mockRows);
    await tester.pump();

    // Verify we are in the Preview step
    expect(state.stepForTesting, equals(2));
    expect(state.previewPageForTesting, equals(0));

    // 4. Verify summary counts (17 valid, 0 flagged)
    expect(find.text('17 valid'), findsOneWidget);
    expect(find.text('0 flagged'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);

    // Verify date headers on page 1 (first 5 unique dates: 20/08, 21/08, 22/08, 23/08, 24/08)
    expect(find.text('20/08/$futureYear'), findsOneWidget);
    expect(find.text('25/08/$futureYear'), findsNothing);

    // Verify sessions on page 1
    expect(find.text('Subject Row 0'), findsOneWidget); // 20/08
    expect(find.text('Subject Row 5'), findsNothing);    // 25/08 (on page 2)

    // 5. Verify Previous button is disabled
    final prevBtnFinder = find.text('Previous');
    expect(prevBtnFinder, findsOneWidget);
    await tester.tap(prevBtnFinder);
    await tester.pump();
    expect(state.previewPageForTesting, equals(0)); // still page 0

    // 6. Navigate to Page 2
    final nextBtnFinder = find.text('Next');
    expect(nextBtnFinder, findsOneWidget);
    await tester.tap(nextBtnFinder);
    await tester.pump();

    // Verify page changed
    expect(state.previewPageForTesting, equals(1));
    expect(find.text('Page 2 of 2'), findsOneWidget);

    // Verify date headers and sessions on page 2 (6th unique date: 25/08)
    expect(find.text('20/08/$futureYear'), findsNothing);
    expect(find.text('25/08/$futureYear'), findsOneWidget);
    expect(find.text('Subject Row 4'), findsNothing);
    expect(find.text('Subject Row 5'), findsOneWidget); // 25/08

    // 7. Verify Next button is now disabled
    await tester.tap(nextBtnFinder);
    await tester.pump();
    expect(state.previewPageForTesting, equals(1)); // still page 1

    // 8. Navigate back to Page 1
    await tester.tap(prevBtnFinder);
    await tester.pump();
    expect(state.previewPageForTesting, equals(0));
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.text('Subject Row 0'), findsOneWidget);
  });

  testWidgets('ImportFlowSheet pagination with 15+ pages keeps Previous and Next inside screen without overflow', (WidgetTester tester) async {
    // Set screen size accommodating Ahem font metrics
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    tester.takeException(); // Drain layout exceptions from Step 0 initial render if any

    final stateFinder = find.byType(ImportFlowSheet);
    final dynamic state = tester.state(stateFinder);

    // 75 unique dates = 15 pages (5 dates per page)
    final futureYear = DateTime.now().year + 1;
    final mockRows = List.generate(75, (i) {
      final day = (i % 28) + 1;
      final month = ((i ~/ 28) + 1).toString().padLeft(2, '0');
      final dayStr = day.toString().padLeft(2, '0');
      return {
        'subject': 'Exam $i',
        'board': 'AQA',
        'date': '$dayStr/$month/$futureYear',
        'time': '09:00',
        'duration': '01:30',
        'room': 'Hall',
      };
    });

    state.setParsedRowsForTesting(mockRows);
    await tester.pump();

    expect(state.stepForTesting, equals(2));
    expect(state.previewPageForTesting, equals(0));

    // Previous and Next buttons should both be present and inside screen bounds (0 <= dx <= 360)
    final prevFinder = find.text('Previous');
    final nextFinder = find.text('Next');
    expect(prevFinder, findsOneWidget);
    expect(nextFinder, findsOneWidget);

    final prevRect = tester.getRect(prevFinder);
    final nextRect = tester.getRect(nextFinder);

    // Previous is on the left
    expect(prevRect.left, greaterThanOrEqualTo(16.0));
    // Next is on the right, well within the 500px screen width
    expect(nextRect.right, lessThanOrEqualTo(500.0));
    // Verify no RenderFlex overflow error occurred
    expect(tester.takeException(), isNull);

    // Tap Next several times and verify it advances and stays bounded
    for (int p = 1; p <= 5; p++) {
      await tester.tap(nextFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.previewPageForTesting, equals(p));

      final currentNextRect = tester.getRect(nextFinder);
      expect(currentNextRect.right, lessThanOrEqualTo(500.0));
    }

    // Tap Previous several times and verify it decrements and stays bounded
    for (int p = 4; p >= 0; p--) {
      await tester.tap(prevFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.previewPageForTesting, equals(p));

      final currentNextRect = tester.getRect(nextFinder);
      expect(currentNextRect.right, lessThanOrEqualTo(500.0));
    }
  });
}
