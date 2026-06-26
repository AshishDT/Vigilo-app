import 'package:flutter/material.dart';
import 'exam_card_widget.dart';

class ElapsedRemainingLine extends StatelessWidget {
  const ElapsedRemainingLine({
    super.key,
    required this.elapsedStr,
    required this.remainingStr,
    required this.vColors,
  });

  final String elapsedStr;
  final String remainingStr;
  final VigiloColors vColors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Elapsed',
                style: TextStyle(
                  color: vColors.textSoft,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                elapsedStr,
                style: TextStyle(
                  color: vColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '|',
                  style: TextStyle(
                    color: vColors.textSoft,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Remaining',
                style: TextStyle(
                  color: vColors.textSoft,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                remainingStr,
                style: TextStyle(
                  color: vColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
