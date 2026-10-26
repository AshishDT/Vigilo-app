import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class HomeEmptyStateWidget extends StatelessWidget {
  const HomeEmptyStateWidget({super.key, this.dark});

  /// Optional explicit dark mode flag to ensure immediate, synchronous theme switching
  /// without Flutter's ThemeData.lerp thresholding delay.
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? (Theme.of(context).brightness == Brightness.dark);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: AnimatedContainer(
        duration: kThemeFadeDuration,
        curve: kThemeFadeCurve,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        decoration: BoxDecoration(
          color: isDark
              ? VigiloUiColors.panel(isDark).withValues(alpha: 0.45)
              : VigiloUiColors.panel(isDark),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark
                ? VigiloUiColors.line(isDark).withValues(alpha: 0.45)
                : VigiloUiColors.line(isDark),
            width: isDark ? 1.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: kThemeFadeDuration,
              curve: kThemeFadeCurve,
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: VigiloUiColors.blue(isDark).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: VigiloUiColors.blue(isDark).withValues(alpha: 0.42),
                ),
                boxShadow: [
                  BoxShadow(
                    color: VigiloUiColors.blue(isDark).withValues(alpha: 0.10),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: TweenAnimationBuilder<Color?>(
                duration: kThemeFadeDuration,
                curve: kThemeFadeCurve,
                tween: ColorTween(end: VigiloUiColors.blueSoft(isDark)),
                builder: (_, iconColor, _) => Icon(
                  Icons.assignment_outlined,
                  color: iconColor,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedDefaultTextStyle(
              duration: kThemeFadeDuration,
              curve: kThemeFadeCurve,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VigiloUiColors.text(isDark),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                fontFamily: textTheme.bodyMedium?.fontFamily,
              ),
              child: const Text('No exams yet'),
            ),
            const SizedBox(height: 9),
            AnimatedDefaultTextStyle(
              duration: kThemeFadeDuration,
              curve: kThemeFadeCurve,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VigiloUiColors.textSoft(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
                fontFamily: textTheme.bodyMedium?.fontFamily,
              ),
              child: const Text('Tap +Exam to create your first exam'),
            ),
          ],
        ),
      ),
    );
  }
}
