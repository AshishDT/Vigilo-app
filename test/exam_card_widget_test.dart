import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/views/widgets/exam_card_widget.dart';

void main() {
  testWidgets(
    'renders subject, date, and organisation name in the requested order',
    (tester) async {
      final pulse = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(pulse.dispose);

      final card = ExamCardData(
        recordId: 'exam-1',
        school: 'Northbridge College',
        centreNumber: 'NB12',
        date: '06/03/2026',
        subject: 'Physics GCSE (AQA)',
        start: '09:00',
        duration: '01:30',
        end: '10:30',
        normalStart: '09:00',
        normalDuration: '01:30',
        normalEnd: '10:30',
        extraTime: '00:15',
        totalDuration: '01:45',
        extraEnd: '10:45',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamCard(
              data: card,
              pulse: pulse,
              onChevronTap: () {},
              onEditDate: () {},
              onEditStartTime: () {},
              onEditDuration: () {},
              onEditExtra: () {},
              onUpdate: (_) {},
              isExamCompleted: false,
              isArchiveMode: false,
              onSelect: () {},
              extraPulse: false,
              tapScale: 1.0,
              onTimeTap: () {},
              onProgressChangeEnd: (_) {},
              onProgressDragState: (_) {},
            ),
          ),
        ),
      );

      final subjectFinder = find.text('Physics GCSE');
      final dateFinder = find.text('06/03/2026');
      final organizationFinder = find.text('Northbridge College (NB12)');

      expect(subjectFinder, findsOneWidget);
      expect(dateFinder, findsOneWidget);
      expect(organizationFinder, findsOneWidget);
      expect(find.text('Physics GCSE (AQA)'), findsNothing);

      final subjectY = tester.getTopLeft(subjectFinder).dy;
      final dateY = tester.getTopLeft(dateFinder).dy;
      final organizationY = tester.getTopLeft(organizationFinder).dy;

      expect(subjectY, lessThan(dateY));
      expect(dateY, lessThan(organizationY));

      final subjectText = tester.widget<Text>(subjectFinder);
      final dateText = tester.widget<Text>(dateFinder);
      final organizationText = tester.widget<Text>(organizationFinder);
      final textTheme = Theme.of(tester.element(subjectFinder)).textTheme;

      expect(
        subjectText.style?.fontSize,
        (textTheme.titleMedium?.fontSize ?? 16) + 2,
      );
      expect(
        dateText.style?.fontSize,
        (textTheme.bodySmall?.fontSize ?? 12) + 1,
      );
      expect(
        organizationText.style?.fontSize,
        (textTheme.bodyMedium?.fontSize ?? 14) + 1,
      );
    },
  );
}
