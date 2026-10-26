import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/utils/app_themes.dart';
import 'package:vigilo/utils/constants.dart';
import 'package:vigilo/views/widgets/exam_card_widget.dart';
import 'package:vigilo/views/widgets/filtered_empty_state_widget.dart';
import 'package:vigilo/views/widgets/footer_widget.dart';
import 'package:vigilo/views/widgets/home_empty_state_widget.dart';
import 'package:vigilo/views/widgets/license_required_view.dart';
import 'package:vigilo/views/widgets/stat_chip_widget.dart';

void main() {
  group('Synchronized Smooth Theme Fade Tests', () {
    testWidgets('MaterialApp with kThemeFadeDuration smoothly animates theme changes', (tester) async {
      bool isDark = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: isDark ? darkTheme() : lightTheme(),
              themeAnimationDuration: kThemeFadeDuration,
              themeAnimationCurve: kThemeFadeCurve,
              home: Scaffold(
                body: Builder(
                  builder: (ctx) {
                    final currentTheme = Theme.of(ctx);
                    return Center(
                      child: Text(
                        currentTheme.brightness == Brightness.dark ? 'DARK' : 'LIGHT',
                      ),
                    );
                  },
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    setState(() => isDark = !isDark);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('LIGHT'), findsOneWidget);

      // Tap to toggle theme
      await tester.tap(find.byType(FloatingActionButton));
      // Pump initial frame of animation
      await tester.pump();
      // Pump half-way through the 250ms fade
      await tester.pump(const Duration(milliseconds: 125));
      // Pump completion of the 250ms fade
      await tester.pump(const Duration(milliseconds: 125));

      expect(find.text('DARK'), findsOneWidget);
    });

    testWidgets('ExamCard, StatChip, and FooterWidget all use unified kThemeFadeDuration and kThemeFadeCurve', (tester) async {
      final cardData = ExamCardData(
        recordId: '10',
        school: 'School',
        date: '12/10/2026',
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

      bool isDark = false;
      final testController = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 1));

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: isDark ? darkTheme() : lightTheme(),
              themeAnimationDuration: kThemeFadeDuration,
              themeAnimationCurve: kThemeFadeCurve,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      StatChip(
                        isArchiveView: false,
                        activeExams: 3,
                        invigilatorsOnDuty: 5,
                      ),
                      ExamCard(
                        data: cardData,
                        pulse: testController,
                        isExamCompleted: false,
                        isArchiveMode: false,
                        extraPulse: false,
                        tapScale: 1.0,
                        onSelect: () {},
                        onChevronTap: () {},
                        onEditDate: () {},
                        onEditStartTime: () {},
                        onEditDuration: () {},
                        onEditExtra: () {},
                        onTimeTap: () {},
                        onProgressChangeEnd: (_) {},
                        onProgressDragState: (_) {},
                        onUpdate: (_) {},
                      ),
                      FooterWidget(
                        onOfficerTools: () {},
                        onVibrate: () {},
                        onArchive: () {},
                        onBriefings: () {},
                        isVibrateOn: true,
                        isArchiveMode: false,
                      ),
                    ],
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => isDark = !isDark),
                ),
              ),
            );
          },
        ),
      );

      // Verify StatChip, ExamCard, and FooterWidget all contain AnimatedContainer
      final statChipContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(StatChip), matching: find.byType(AnimatedContainer)),
      );
      for (final container in statChipContainers) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      final examCardContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(ExamCard), matching: find.byType(AnimatedContainer)),
      );
      for (final container in examCardContainers) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      final footerContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(FooterWidget), matching: find.byType(AnimatedContainer)),
      );
      for (final container in footerContainers) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      // Toggle theme
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Verify that after toggle, every component still shares the exact same kThemeFadeDuration and curve
      for (final container in tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(StatChip), matching: find.byType(AnimatedContainer)),
      )) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      for (final container in tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(ExamCard), matching: find.byType(AnimatedContainer)),
      )) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      for (final container in tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(FooterWidget), matching: find.byType(AnimatedContainer)),
      )) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      // Finish the 250ms fade
      await tester.pump(kThemeFadeDuration);

      testController.dispose();
    });

    testWidgets('HomeEmptyStateWidget, FilteredEmptyStateWidget, and LicenseRequiredView use kThemeFadeDuration and kThemeFadeCurve', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const HomeEmptyStateWidget(dark: true),
                  FilteredEmptyStateWidget(onClear: () {}, dark: true),
                  const LicenseRequiredView(dark: true),
                ],
              ),
            ),
          ),
        ),
      );

      for (final container in tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(HomeEmptyStateWidget), matching: find.byType(AnimatedContainer)),
      )) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      for (final container in tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(FilteredEmptyStateWidget), matching: find.byType(AnimatedContainer)),
      )) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }

      for (final container in tester.widgetList<AnimatedContainer>(
        find.descendant(of: find.byType(LicenseRequiredView), matching: find.byType(AnimatedContainer)),
      )) {
        expect(container.duration, equals(kThemeFadeDuration));
        expect(container.curve, equals(kThemeFadeCurve));
      }
    });

    testWidgets('ExamCard is isolated with RepaintBoundary and synchronizes text styles with kThemeFadeDuration', (tester) async {
      final cardData = ExamCardData(
        recordId: '100',
        school: 'School',
        date: '12/10/2026',
        subject: 'Physics',
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

      final testController = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 1));

      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: kThemeFadeDuration,
          themeAnimationCurve: kThemeFadeCurve,
          home: Scaffold(
            body: ExamCard(
              data: cardData,
              pulse: testController,
              isExamCompleted: false,
              isArchiveMode: false,
              extraPulse: false,
              tapScale: 1.0,
              isDark: false,
              onChevronTap: () {},
              onEditDate: () {},
              onEditStartTime: () {},
              onEditDuration: () {},
              onEditExtra: () {},
              onUpdate: (_) {},
              onSelect: () {},
              onTimeTap: () {},
              onProgressChangeEnd: (_) {},
              onProgressDragState: (_) {},
            ),
          ),
        ),
      );

      // Verify that ExamCard root is a RepaintBoundary
      expect(
        find.descendant(of: find.byType(ExamCard), matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );

      // Verify AnimatedDefaultTextStyle is configured with kThemeFadeDuration
      final animatedTexts = tester.widgetList<AnimatedDefaultTextStyle>(
        find.descendant(of: find.byType(ExamCard), matching: find.byType(AnimatedDefaultTextStyle)),
      );
      expect(animatedTexts.isNotEmpty, isTrue);
      final fadeDurationTexts = animatedTexts.where((at) => at.duration == kThemeFadeDuration);
      expect(fadeDurationTexts.length, greaterThanOrEqualTo(5));
      for (final at in fadeDurationTexts) {
        expect(at.curve, equals(kThemeFadeCurve));
      }
    });
  });
}

