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
        AnimatedDefaultTextStyle(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          style: TextStyle(
            color: VigiloUiColors.textSoft(isDark),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          child: const Text('Elapsed'),
        ),
        const SizedBox(width: 6),
        AnimatedDefaultTextStyle(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          style: TextStyle(
            color: VigiloUiColors.text(isDark),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
          child: Text(elapsedStr),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedDefaultTextStyle(
            duration: kThemeFadeDuration,
            curve: kThemeFadeCurve,
            style: TextStyle(
              color: VigiloUiColors.textSoft(isDark),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            child: const Text('|'),
          ),
        ),
        AnimatedDefaultTextStyle(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          style: TextStyle(
            color: VigiloUiColors.textSoft(isDark),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          child: const Text('Remaining'),
        ),
        const SizedBox(width: 6),
        AnimatedDefaultTextStyle(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          style: TextStyle(
            color: VigiloUiColors.text(isDark),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
          child: Text(remainingStr),
        ),
      ],
    );
  }
}
