import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class StatChip extends StatefulWidget {
  final bool isArchiveView;
  final int activeExams;
  final int invigilatorsOnDuty;
  final bool? isDark;

  const StatChip({
    super.key,
    required this.isArchiveView,
    required this.activeExams,
    required this.invigilatorsOnDuty,
    this.isDark,
  });

  @override
  State<StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<StatChip> {
  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: _topStat(
                  dark,
                  Icons.play_circle_fill_rounded,
                  widget.isArchiveView ? 'Archived' : 'Active Exams',
                  '${widget.activeExams}',
                ),
              ),
              AnimatedContainer(
                duration: kThemeFadeDuration,
                curve: kThemeFadeCurve,
                width: 1,
                height: 30,
                color: dark
                    ? VigiloUiColors.line(dark).withValues(alpha: 0.52)
                    : VigiloUiColors.line(dark).withValues(alpha: 0.75),
              ),
              Expanded(
                child: _topStat(
                  dark,
                  Icons.groups_2_rounded,
                  'Invigilators',
                  '${widget.invigilatorsOnDuty}',
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          width: double.infinity,
          height: 0.75,
          color: VigiloUiColors.line(dark),
        ),
      ],
    );
  }

  Widget _topStat(bool dark, IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<Color?>(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          tween: ColorTween(end: VigiloUiColors.blue(dark)),
          builder: (context, iconColor, _) {
            return Icon(icon, color: iconColor, size: 26);
          },
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: AnimatedDefaultTextStyle(
            duration: kThemeFadeDuration,
            curve: kThemeFadeCurve,
            style: TextStyle(
              color: VigiloUiColors.text(dark),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
            child: Text(
              value,
              key: ValueKey(value),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedDefaultTextStyle(
              duration: kThemeFadeDuration,
              curve: kThemeFadeCurve,
              style: TextStyle(
                color: VigiloUiColors.textSoft(dark),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
              child: Text(
                label,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

