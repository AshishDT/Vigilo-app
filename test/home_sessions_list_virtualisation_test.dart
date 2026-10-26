import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/views/widgets/home_sessions_list_view.dart';

void main() {
  group('HomeSessionsListView Virtualisation Tests', () {
    ExamCardData createMockCard(String id, String date) {
      return ExamCardData(
        recordId: id,
        school: 'Test School',
        centreNumber: '12345',
        date: date,
        subject: 'Maths',
        start: '09:00',
        duration: '01:00',
        end: '10:00',
        normalStart: '09:00',
        normalDuration: '01:00',
        normalEnd: '10:00',
        extraTime: '00:00',
        totalDuration: '01:00',
        extraEnd: '10:00',
      );
    }

    testWidgets('renders visible date groups lazily via ScrollablePositionedList',
        (WidgetTester tester) async {
      final controller = ItemScrollController();
      final dateKeys = <String, GlobalKey>{};
      final groupedCards = <String, List<ExamCardData>>{
        '10/10/2026': [createMockCard('c1', '10/10/2026')],
        '11/10/2026': [createMockCard('c2', '11/10/2026')],
        '12/10/2026': [createMockCard('c3', '12/10/2026')],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSessionsListView(
              itemScrollController: controller,
              groupedCards: groupedCards,
              highlightedDate: null,
              dark: false,
              dateKeys: dateKeys,
              formatDate: (d) => 'Date: $d',
              buildCard: (card) => Text('Card: ${card.recordId}'),
            ),
          ),
        ),
      );

      // Verify ScrollablePositionedList is rendered
      expect(find.byType(ScrollablePositionedList), findsOneWidget);

      // Verify date group columns are rendered
      expect(find.byKey(const ValueKey('group_10/10/2026')), findsOneWidget);
      expect(find.text('Date: 10/10/2026'), findsOneWidget);
      expect(find.text('Card: c1'), findsOneWidget);
    });

    testWidgets('virtualises date groups lazily when timetable contains multiple dates',
        (WidgetTester tester) async {
      final controller = ItemScrollController();
      final dateKeys = <String, GlobalKey>{};
      final groupedCards = <String, List<ExamCardData>>{};
      for (int d = 1; d <= 30; d++) {
        final dateStr = '${d.toString().padLeft(2, '0')}/10/2026';
        groupedCards[dateStr] = [createMockCard('c_$d', dateStr)];
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: HomeSessionsListView(
                itemScrollController: controller,
                groupedCards: groupedCards,
                highlightedDate: null,
                dark: false,
                dateKeys: dateKeys,
                formatDate: (d) => 'Date: $d',
                buildCard: (card) => SizedBox(
                  height: 200,
                  child: Text('Card: ${card.recordId}'),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify that out of 30 dates, only visible dates are built
      final builtCardsCount = find.textContaining('Card: c_').evaluate().length;
      expect(builtCardsCount, lessThan(10));
      expect(builtCardsCount, greaterThan(0));
    });
  });
}
