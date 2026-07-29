import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/enums/exam_phase.dart';
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

  group('Past-Date AutoStart Suppression Tests', () {
    bool isPastExam(String dateStr, String startStr) {
      try {
        final dateParts = dateStr.split('/');
        final timeParts = startStr.split(':');
        if (dateParts.length == 3 && timeParts.length == 2) {
          final d = int.parse(dateParts[0]);
          final m = int.parse(dateParts[1]);
          final y = int.parse(dateParts[2]);
          final hh = int.parse(timeParts[0]);
          final mm = int.parse(timeParts[1]);
          final scheduled = DateTime(y, m, d, hh, mm);
          return scheduled.isBefore(DateTime.now());
        }
      } catch (_) {}
      return false;
    }

    test('should identify past-dated exams correctly', () {
      final now = DateTime.now();
      
      // An exam scheduled 1 day ago
      final pastDate = now.subtract(const Duration(days: 1));
      final pastDateStr = "${pastDate.day.toString().padLeft(2, '0')}/${pastDate.month.toString().padLeft(2, '0')}/${pastDate.year}";
      final pastStartStr = "${pastDate.hour.toString().padLeft(2, '0')}:${pastDate.minute.toString().padLeft(2, '0')}";
      expect(isPastExam(pastDateStr, pastStartStr), isTrue);

      // An exam scheduled 1 day in the future
      final futureDate = now.add(const Duration(days: 1));
      final futureDateStr = "${futureDate.day.toString().padLeft(2, '0')}/${futureDate.month.toString().padLeft(2, '0')}/${futureDate.year}";
      final futureStartStr = "${futureDate.hour.toString().padLeft(2, '0')}:${futureDate.minute.toString().padLeft(2, '0')}";
      expect(isPastExam(futureDateStr, futureStartStr), isFalse);
    });
  });
}
