import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/views/widgets/session_manager_panel.dart';
import 'package:vigilo/views/widgets/speed_dial_option.dart';

void main() {
  group('SessionManagerPanel Widget Tests', () {
    testWidgets('renders filter options correctly', (WidgetTester tester) async {
      String selectedStatus = 'All';
      String selectedDate = 'All';
      bool clearCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionManagerPanel(
              dark: false,
              statusFilter: selectedStatus,
              dateFilter: selectedDate,
              onStatusFilterChanged: (val) => selectedStatus = val,
              onDateFilterChanged: (val) => selectedDate = val,
              onClear: () => clearCalled = true,
              onJumpToDateTap: () {},
              lastImportSessions: const [],
              onUndoLastImport: () {},
            ),
          ),
        ),
      );

      // Verify header title
      expect(find.text('Session Manager'), findsOneWidget);

      // Verify Status Chips
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('Not Started'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);

      // Verify Date Chips
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);

      // Tap on a status chip and verify callback triggers
      await tester.tap(find.text('Running'));
      expect(selectedStatus, equals('Running'));

      // Tap on a date chip and verify callback triggers
      await tester.tap(find.text('Today'));
      expect(selectedDate, equals('Today'));
    });

    testWidgets('Jump to date option is rendered and fires callback', (WidgetTester tester) async {
      bool jumpToDateCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionManagerPanel(
              dark: false,
              statusFilter: 'All',
              dateFilter: 'All',
              onStatusFilterChanged: (_) {},
              onDateFilterChanged: (_) {},
              onClear: () {},
              onJumpToDateTap: () => jumpToDateCalled = true,
              lastImportSessions: const [],
              onUndoLastImport: () {},
            ),
          ),
        ),
      );

      // Verify Jump to date button is rendered by finding its calendar icon
      final jumpButton = find.byIcon(Icons.calendar_today_rounded);
      expect(jumpButton, findsOneWidget);

      // Tap on it and verify callback triggers
      await tester.tap(jumpButton);
      expect(jumpToDateCalled, isTrue);
    });
  });

  group('SpeedDialOption Widget Tests', () {
    testWidgets('renders SpeedDialOption correctly', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeedDialOption(
              icon: Icons.edit_outlined,
              label: 'Create Single Exam',
              dark: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Create Single Exam'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      await tester.tap(find.text('Create Single Exam'));
      expect(tapped, isTrue);
    });
  });
}
