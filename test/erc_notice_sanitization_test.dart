import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/views/widgets/erc_notice.dart';

void main() {
  group('ERCNotice sanitization tests', () {
    testWidgets('sanitizes persisted to saved', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ERCNotice(
              icon: Icons.info,
              title: 'Exam persisted successfully',
              subtitle: 'The data has been persisted to disk',
            ),
          ),
        ),
      );

      expect(find.text('Exam saved successfully'), findsOneWidget);
      expect(find.text('The data has been saved to disk'), findsOneWidget);
    });

    testWidgets('sanitizes file paths to filenames', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ERCNotice(
              icon: Icons.info,
              title: 'Saved file',
              subtitle: 'Output stored at /Users/dt/Documents/logs/export.csv',
            ),
          ),
        ),
      );

      expect(find.text('Saved file'), findsOneWidget);
      expect(find.text('Output stored at export.csv'), findsOneWidget);
    });

    testWidgets('sanitizes exception details and patterns', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ERCNotice(
              icon: Icons.info,
              title: 'Error occurred',
              subtitle: 'Exception: SqliteException: unique constraint failed',
            ),
          ),
        ),
      );

      expect(find.text('Error occurred'), findsOneWidget);
      expect(find.text('An unexpected error occurred'), findsOneWidget);
    });
  });
}
