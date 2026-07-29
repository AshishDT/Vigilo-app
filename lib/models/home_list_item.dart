import 'exam_card_data.dart';

class HomeListItem {
  final String? dateHeader;
  final ExamCardData? card;
  final int? cardIndex;

  HomeListItem({
    this.dateHeader,
    this.card,
    this.cardIndex,
  });
}
