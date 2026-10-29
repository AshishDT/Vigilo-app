import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/enums/exam_phase.dart';
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

  testWidgets(
    'renders Level and Board together separated by dot when both are provided',
    (tester) async {
      final pulse = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(pulse.dispose);

      final card = ExamCardData(
        recordId: 'exam-2',
        school: 'Bramwell Academy',
        centreNumber: '68214',
        date: '30/08/2026',
        subject: 'Mathematics - Paper 1',
        examLevel: 'GCSE',
        examBoard: 'Edexcel',
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

      expect(find.textContaining('Mathematics - Paper 1'), findsOneWidget);
      expect(find.textContaining('GCSE'), findsOneWidget);
      expect(find.textContaining('·'), findsOneWidget);
      expect(find.textContaining('Edexcel'), findsOneWidget);
    },
  );

  testWidgets(
    'A2 Start Now button behavior: enabled for today, disabled for future, neither closes card on tap',
    (tester) async {
      final pulse = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(pulse.dispose);

      final now = DateTime.now();
      final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final futureDate = now.add(const Duration(days: 5));
      final futureStr = '${futureDate.day.toString().padLeft(2, '0')}/${futureDate.month.toString().padLeft(2, '0')}/${futureDate.year}';

      bool chevronTapped = false;
      bool updateCalled = false;

      // 1. Future Exam Card
      final futureCard = ExamCardData(
        recordId: 'exam-future',
        school: 'Northbridge College',
        centreNumber: 'NB12',
        date: futureStr,
        subject: 'Chemistry Paper 1',
        start: '09:00',
        normalStart: '09:00',
        duration: '01:30',
        normalDuration: '01:30',
        normalEnd: '10:30',
        end: '10:30',
        extraTime: '00:15',
        totalDuration: '01:45',
        extraEnd: '10:45',
        expanded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExamCard(
                data: futureCard,
                pulse: pulse,
                onChevronTap: () {
                  chevronTapped = true;
                },
                onEditDate: () {},
                onEditStartTime: () {},
                onEditDuration: () {},
                onEditExtra: () {},
                onUpdate: (_) {
                  updateCalled = true;
                },
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
        ),
      );

      // Verify "Start Now" is visible and has no "Scheduled" text
      expect(find.text('Start Now'), findsOneWidget);
      expect(find.text('Scheduled'), findsNothing);

      // Tapping disabled "Start Now" does NOT update card and does NOT close card
      chevronTapped = false;
      updateCalled = false;
      await tester.tap(find.text('Start Now'));
      await tester.pump();

      expect(updateCalled, isFalse);
      expect(chevronTapped, isFalse);

      // 2. Today Exam Card
      final todayCard = ExamCardData(
        recordId: 'exam-today',
        school: 'Northbridge College',
        centreNumber: 'NB12',
        date: todayStr,
        subject: 'Biology Paper 1',
        start: '09:00',
        normalStart: '09:00',
        duration: '01:30',
        normalDuration: '01:30',
        normalEnd: '10:30',
        end: '10:30',
        extraTime: '00:15',
        totalDuration: '01:45',
        extraEnd: '10:45',
        expanded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExamCard(
                data: todayCard,
                pulse: pulse,
                onChevronTap: () {
                  chevronTapped = true;
                },
                onEditDate: () {},
                onEditStartTime: () {},
                onEditDuration: () {},
                onEditExtra: () {},
                onUpdate: (_) {
                  updateCalled = true;
                },
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
        ),
      );

      // Tapping enabled "Start Now" invokes onUpdate and does NOT close card
      chevronTapped = false;
      updateCalled = false;
      await tester.tap(find.text('Start Now'));
      await tester.pump();

      expect(updateCalled, isTrue);
      expect(chevronTapped, isFalse);
    },
  );

  testWidgets(
    'Finished exam buttons and Finished pill do nothing and do not collapse card; tapping empty area collapses',
    (tester) async {
      final pulse = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(pulse.dispose);

      bool chevronTapped = false;
      bool dateTapped = false;
      bool startTapped = false;
      bool durationTapped = false;
      bool extraTapped = false;

      final finishedCard = ExamCardData(
        recordId: 'exam-fin',
        school: 'Northbridge College',
        centreNumber: 'NB12',
        date: '01/01/2026',
        subject: 'History Paper 1',
        start: '09:00',
        normalStart: '09:00',
        duration: '01:30',
        normalDuration: '01:30',
        normalEnd: '10:30',
        end: '10:30',
        extraTime: '00:15',
        totalDuration: '01:45',
        extraEnd: '10:45',
        running: false,
        phase: ExamPhase.finished,
        wasEverStarted: true,
        expanded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExamCard(
                data: finishedCard,
                pulse: pulse,
                onChevronTap: () {
                  chevronTapped = true;
                },
                onEditDate: () {
                  dateTapped = true;
                },
                onEditStartTime: () {
                  startTapped = true;
                },
                onEditDuration: () {
                  durationTapped = true;
                },
                onEditExtra: () {
                  extraTapped = true;
                },
                onUpdate: (_) {},
                isExamCompleted: true,
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
        ),
      );

      // Verify Finished button is present
      expect(find.text('Finished'), findsOneWidget);

      // Tap Finished button: should not tap callback and should NOT close card
      chevronTapped = false;
      await tester.tap(find.text('Finished'));
      await tester.pump();
      expect(chevronTapped, isFalse);

      // Tap Date button: should not fire onEditDate and should NOT close card
      chevronTapped = false;
      await tester.tap(find.text('Date').first);
      await tester.pump();
      expect(dateTapped, isFalse);
      expect(chevronTapped, isFalse);

      // Tap Start Time button: should not fire onEditStartTime and should NOT close card
      chevronTapped = false;
      await tester.tap(find.text('Start Time').first);
      await tester.pump();
      expect(startTapped, isFalse);
      expect(chevronTapped, isFalse);

      // Tap Duration button: should not fire onEditDuration and should NOT close card
      chevronTapped = false;
      await tester.tap(find.text('Duration').first);
      await tester.pump();
      expect(durationTapped, isFalse);
      expect(chevronTapped, isFalse);

      // Tap Extra Time button: should not fire onEditExtra and should NOT close card
      chevronTapped = false;
      await tester.tap(find.text('Extra Time').first);
      await tester.pump();
      expect(extraTapped, isFalse);
      expect(chevronTapped, isFalse);

      // Tap empty space on card (e.g. subject header text area): should close the card (call onChevronTap)
      chevronTapped = false;
      await tester.tap(find.text('History Paper 1'));
      await tester.pumpAndSettle();
      expect(chevronTapped, isTrue);
    },
  );

  testWidgets(
    'shows DATE PASSED pill for past unstarted exams and READY TO START pill for today exams whose start time has arrived',
    (tester) async {
      final pulse = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(pulse.dispose);

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}';
      final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final pastCard = ExamCardData(
        recordId: 'exam-past',
        school: 'Northbridge College',
        centreNumber: 'NB12',
        date: yesterdayStr,
        subject: 'Art and Design',
        start: '09:00',
        normalStart: '09:00',
        duration: '01:30',
        normalDuration: '01:30',
        normalEnd: '10:30',
        end: '10:30',
        extraTime: '00:15',
        totalDuration: '01:45',
        extraEnd: '10:45',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamCard(
              data: pastCard,
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

      expect(find.text('DATE PASSED'), findsOneWidget);
      expect(find.text('READY TO START'), findsNothing);

      // In Archive Mode, Date Passed cards show the selection checkbox
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamCard(
              data: pastCard,
              pulse: pulse,
              onChevronTap: () {},
              onEditDate: () {},
              onEditStartTime: () {},
              onEditDuration: () {},
              onEditExtra: () {},
              onUpdate: (_) {},
              isExamCompleted: false,
              isArchiveMode: true,
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

      // Checkbox is shown for Date Passed exam in archive mode
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      // If date is today and time has arrived, shows READY TO START
      final todayCard = pastCard.copyWith(
        date: todayStr,
        start: '00:01',
        normalStart: '00:01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamCard(
              data: todayCard,
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

      expect(find.text('READY TO START'), findsOneWidget);
      expect(find.text('DATE PASSED'), findsNothing);
    },
  );
}
