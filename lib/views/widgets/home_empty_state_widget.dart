import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class HomeEmptyStateWidget extends StatelessWidget {
  const HomeEmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        decoration: BoxDecoration(
          color: isDark ? VigiloUiColors.panel(isDark).withValues(alpha: 0.45) : VigiloUiColors.panel(isDark),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? VigiloUiColors.line(isDark).withValues(alpha: 0.45) : VigiloUiColors.line(isDark),
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
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: VigiloUiColors.blue(isDark).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: VigiloUiColors.blue(isDark).withValues(alpha: 0.42)),
                boxShadow: [
                  BoxShadow(
                    color: VigiloUiColors.blue(isDark).withValues(alpha: 0.10),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: VigiloUiColors.blueSoft(isDark),
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No exams yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VigiloUiColors.text(isDark),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Tap +Exam to create your first exam',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VigiloUiColors.textSoft(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
