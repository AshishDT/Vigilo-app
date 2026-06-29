import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class StatChip extends StatelessWidget {
  final bool isArchiveView;
  final int activeExams;
  final int invigilatorsOnDuty;

  const StatChip({
    super.key,
    required this.isArchiveView,
    required this.activeExams,
    required this.invigilatorsOnDuty,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 64,
      decoration: BoxDecoration(
        color: VigiloUiColors.panel(dark).withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VigiloUiColors.blue(dark).withOpacity(dark ? 0.30 : 0.26),
          width: dark ? 0.7 : 1.5,
        ),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: VigiloUiColors.blue(dark).withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: VigiloUiColors.blue(dark).withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _topStat(
              dark,
              Icons.play_circle_fill_rounded,
              isArchiveView ? 'Archived' : 'Active Exams',
              '$activeExams',
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: dark
                ? VigiloUiColors.line(dark).withOpacity(0.52)
                : VigiloUiColors.line(dark).withOpacity(0.75),
          ),
          Expanded(
            child: _topStat(
              dark,
              Icons.groups_2_rounded,
              'Invigilators',
              '$invigilatorsOnDuty',
            ),
          ),
        ],
      ),
    );
  }

  Widget _topStat(bool dark, IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: VigiloUiColors.blue(dark), size: 26),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            color: VigiloUiColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: VigiloUiColors.textSoft(dark),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

