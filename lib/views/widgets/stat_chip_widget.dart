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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? kDarkCard
            : kLightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBlue.withValues(alpha: 0.9), width: 1),
        boxShadow: [
          BoxShadow(
            color: kBlue.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Active Exams
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: kBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 6),
              _infoText(
                isArchiveView ? 'Archived Exams' : 'Active Exams',
                '$activeExams',
                color: kBlue,
              ),
            ],
          ),

          // Invigilators
          Row(
            children: [
              const Icon(Icons.people_alt, color: kBlue, size: 22),
              const SizedBox(width: 6),
              _infoText('Invigilators', '$invigilatorsOnDuty', color: kBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoText(String label, String value, {required Color color}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
