import 'package:flutter/material.dart';

class _EmptyStateColors {
  final BuildContext context;
  _EmptyStateColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get panel =>
      isDark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);
  Color get line => isDark ? const Color(0xFF294867) : const Color(0xFFCBD5E1);
  Color get text => isDark ? const Color(0xFFF3F7FC) : const Color(0xFF0B253A);
  Color get textSoft =>
      isDark ? const Color(0xFFB6C7D8) : const Color(0xFF475569);
  Color get blue => isDark ? const Color(0xFF4B86F8) : const Color(0xFF2563EB);
  Color get blueSoft => isDark ? const Color(0xFF8FD4FF) : const Color(0xFF3B82F6);
}

class HomeEmptyStateWidget extends StatelessWidget {
  const HomeEmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _EmptyStateColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        decoration: BoxDecoration(
          color: colors.isDark ? colors.panel.withValues(alpha: 0.45) : colors.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: colors.isDark ? colors.line.withValues(alpha: 0.45) : colors.line,
            width: colors.isDark ? 1.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: colors.isDark ? 0.18 : 0.06),
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
                color: colors.blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: colors.blue.withValues(alpha: 0.42)),
                boxShadow: [
                  BoxShadow(
                    color: colors.blue.withValues(alpha: 0.10),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: colors.blueSoft,
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No exams yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
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
                color: colors.textSoft,
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
