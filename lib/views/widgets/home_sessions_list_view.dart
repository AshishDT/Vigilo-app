import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../models/exam_card_data.dart';
import '../../models/home_list_item.dart';
import '../../utils/constants.dart';

class HomeSessionsListView extends StatelessWidget {
  const HomeSessionsListView({
    super.key,
    required this.itemScrollController,
    this.itemPositionsListener,
    this.scrollOffsetListener,
    required this.groupedCards,
    required this.highlightedDate,
    required this.dark,
    required this.dateKeys,
    required this.formatDate,
    required this.buildCard,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 380),
  });

  final ItemScrollController itemScrollController;
  final ItemPositionsListener? itemPositionsListener;
  final ScrollOffsetListener? scrollOffsetListener;
  final Map<String, List<ExamCardData>> groupedCards;
  final String? highlightedDate;
  final bool dark;
  final Map<String, GlobalKey> dateKeys;
  final String Function(String date) formatDate;
  final Widget Function(ExamCardData card) buildCard;
  final EdgeInsets padding;

  /// Flattens grouped cards into linear items (headers + cards)
  /// so that Flutter can virtualise individual cards lazily.
  static List<HomeListItem> buildFlattenedItems(
    Map<String, List<ExamCardData>> groupedCards,
  ) {
    final items = <HomeListItem>[];
    for (final entry in groupedCards.entries) {
      final date = entry.key;
      final sessions = entry.value;
      items.add(HomeListItem.dateHeader(
        date: date,
        sessionsCount: sessions.length,
      ));
      for (int i = 0; i < sessions.length; i++) {
        items.add(HomeListItem.examCard(
          date: date,
          card: sessions[i],
          cardIndex: i,
          isFirstInGroup: i == 0,
          isLastInGroup: i == sessions.length - 1,
        ));
      }
    }
    return items;
  }

  /// Calculates the exact index of the target date header in the flattened list.
  static int findDateHeaderIndex({
    required List<HomeListItem> items,
    required String targetDate,
  }) {
    return items.indexWhere(
      (it) => it.isHeader && it.date == targetDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = groupedCards.keys.toList();

    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      scrollOffsetListener: scrollOffsetListener,
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: padding,
      minCacheExtent: 1200,
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final sessions = groupedCards[date] ?? const [];
        final isHighlighted = highlightedDate == date;
        debugPrint(
          '[JumpToDate] itemBuilder: index=$index, date=$date, sessions=${sessions.length}, isHighlighted=$isHighlighted',
        );

        return Column(
          key: ValueKey('group_$date'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              child: Padding(
                key: ValueKey('header_$date'),
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: kThemeFadeDuration,
                      curve: kThemeFadeCurve,
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: VigiloUiColors.blueSoft(dark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: kThemeFadeDuration,
                      curve: kThemeFadeCurve,
                      style: TextStyle(
                        color: VigiloUiColors.blueSoft(dark),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                      child: Text(
                        formatDate(date),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: kThemeFadeDuration,
                      curve: kThemeFadeCurve,
                      style: TextStyle(
                        color: VigiloUiColors.textFaint(dark),
                        fontSize: 11,
                      ),
                      child: Text(
                        '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedContainer(
              duration: kThemeFadeDuration,
              curve: kThemeFadeCurve,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isHighlighted
                      ? VigiloUiColors.blue(dark)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: sessions.map((c) {
                  final isLast = c == sessions.last;
                  return Padding(
                    key: ValueKey('card_${c.recordId}'),
                    padding: EdgeInsets.only(
                      bottom: isLast ? 0 : 16,
                    ),
                    child: RepaintBoundary(
                      child: buildCard(c),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
