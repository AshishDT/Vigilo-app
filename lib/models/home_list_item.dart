import 'exam_card_data.dart';

enum HomeListItemType {
  dateHeader,
  examCard,
}

class HomeListItem {
  final HomeListItemType type;
  final String date;
  final int sessionsCount;
  final ExamCardData? card;
  final int? cardIndex;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const HomeListItem.dateHeader({
    required this.date,
    required this.sessionsCount,
  })  : type = HomeListItemType.dateHeader,
        card = null,
        cardIndex = null,
        isFirstInGroup = false,
        isLastInGroup = false;

  const HomeListItem.examCard({
    required this.date,
    required this.card,
    this.cardIndex,
    this.isFirstInGroup = false,
    this.isLastInGroup = false,
  })  : type = HomeListItemType.examCard,
        sessionsCount = 0;

  bool get isHeader => type == HomeListItemType.dateHeader;
  bool get isCard => type == HomeListItemType.examCard;
}
