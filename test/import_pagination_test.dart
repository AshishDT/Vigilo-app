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
}
