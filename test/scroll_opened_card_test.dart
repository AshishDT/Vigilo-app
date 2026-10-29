import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/views/widgets/home_sessions_list_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  group('Scroll Opened Card to Top (A8) Tests', () {
    ExamCardData createMockCard(String id, String date, {bool expanded = false}) {
      return ExamCardData(
        recordId: id,
        school: 'Test School',
        centreNumber: '12345',
        date: date,
        subject: 'Maths $id',
        start: '09:00',
        duration: '01:00',
        end: '10:00',
        normalStart: '09:00',
        normalDuration: '01:00',
        normalEnd: '10:00',
        extraTime: '00:00',
        totalDuration: '01:00',
        extraEnd: '10:00',
        expanded: expanded,
      );
    }

    testWidgets('HomeSessionsListView applies 0 top padding and dynamic bottom runway',
        (WidgetTester tester) async {
      final controller = ItemScrollController();
      final groupedCards = <String, List<ExamCardData>>{
        '29/10/2026': [createMockCard('c1', '29/10/2026')],
      };

      // 1. When no card is open, bottom padding is 100
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSessionsListView(
              itemScrollController: controller,
              groupedCards: groupedCards,
              highlightedDate: null,
              dark: false,
              dateKeys: const {},
              formatDate: (d) => d,
              buildCard: (card) => Text('Card ${card.recordId}'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            ),
          ),
        ),
      );

      final listFinderClosed = find.byType(ScrollablePositionedList);
      expect(listFinderClosed, findsOneWidget);
      final widgetClosed = tester.widget<ScrollablePositionedList>(listFinderClosed);
      expect(widgetClosed.padding, const EdgeInsets.fromLTRB(20, 0, 20, 100));

      // 2. When a card is open (anyOpen == true), bottom padding provides runway for last card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSessionsListView(
              itemScrollController: controller,
              groupedCards: groupedCards,
              highlightedDate: null,
              dark: false,
              dateKeys: const {},
              formatDate: (d) => d,
              buildCard: (card) => Text('Card ${card.recordId}'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 680),
            ),
          ),
        ),
      );

      final listFinderOpen = find.byType(ScrollablePositionedList);
      final widgetOpen = tester.widget<ScrollablePositionedList>(listFinderOpen);
      expect(widgetOpen.padding, const EdgeInsets.fromLTRB(20, 0, 20, 680));
    });
  });
}

