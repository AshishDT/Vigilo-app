import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class FilteredEmptyStateWidget extends StatelessWidget {
  final VoidCallback onClear;

  const FilteredEmptyStateWidget({
    super.key,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
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
            Container(
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
              child: Icon(
                Icons.filter_alt_off_outlined,
                color: VigiloUiColors.blueSoft(isDark),
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No exams match these filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VigiloUiColors.text(isDark),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Try adjusting Status or Date',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VigiloUiColors.textSoft(isDark),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: VigiloUiColors.blue(isDark),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: VigiloUiColors.blue(isDark).withValues(
                        alpha: isDark ? 0.3 : 0.2,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Clear Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
