import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class ElapsedRemainingLine extends StatelessWidget {
  const ElapsedRemainingLine({
    super.key,
    required this.elapsedStr,
    required this.remainingStr,
    required this.isDark,
  });

  final String elapsedStr;
  final String remainingStr;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Elapsed',
          style: TextStyle(
            color: VigiloUiColors.textSoft(isDark),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          elapsedStr,
          style: TextStyle(
            color: VigiloUiColors.text(isDark),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '|',
            style: TextStyle(
              color: VigiloUiColors.textSoft(isDark),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          'Remaining',
          style: TextStyle(
            color: VigiloUiColors.textSoft(isDark),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          remainingStr,
          style: TextStyle(
            color: VigiloUiColors.text(isDark),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
