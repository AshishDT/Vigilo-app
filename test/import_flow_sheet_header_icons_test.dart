import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/views/widgets/import_flow_sheet.dart';

void main() {
  testWidgets('ImportFlowSheet header close and theme icons match Home Screen dimensions', (WidgetTester tester) async {
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

    // Verify close_rounded icon has size 23
    final closeIconFinder = find.byIcon(Icons.close_rounded);
    expect(closeIconFinder, findsOneWidget);
    final closeIcon = tester.widget<Icon>(closeIconFinder);
    expect(closeIcon.size, equals(23));

    // Verify theme icon (dark_mode_outlined or wb_sunny_outlined) has size 23
    final themeIconFinder = find.byWidgetPredicate(
      (widget) => widget is Icon && (widget.icon == Icons.dark_mode_outlined || widget.icon == Icons.wb_sunny_outlined),
    );
    expect(themeIconFinder, findsOneWidget);
    final themeIcon = tester.widget<Icon>(themeIconFinder);
    expect(themeIcon.size, equals(23));

    // Verify 44x44 container dimensions
    final containerFinder = find.byWidgetPredicate(
      (widget) => widget is Container && widget.constraints?.minWidth == 44 && widget.constraints?.minHeight == 44,
    );
    expect(containerFinder, findsNWidgets(2));
  });
}
