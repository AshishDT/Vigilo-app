import 'animated_scale_on_press.dart';
import 'package:flutter/material.dart';

Widget confirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String okTitle,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
  bool shouldNotRestart = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final panelBg = isDark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);
  final lineBorder = isDark ? const Color(0xFF294867) : const Color(0xFFD0D7DE);
  final textMain = isDark ? const Color(0xFFF3F7FC) : const Color(0xFF0B253A);
  final textMuted = isDark ? const Color(0xFFB6C7D8) : const Color(0xFF475569);
  final buttonOutlineText = isDark
      ? const Color(0xFF4B86F8)
      : const Color(0xFF2563EB);
  final buttonDangerBg = isDark
      ? const Color(0xFFE05D74)
      : const Color(0xFFDC2626);

  final resolvedIcon = title.toLowerCase().contains('delete')
      ? Icons.delete_outline_rounded
      : title.toLowerCase().contains('end')
      ? Icons.stop_circle_outlined
      : Icons.info_outline_rounded;

  return AlertDialog(
    backgroundColor: panelBg,
    constraints: BoxConstraints(minWidth: double.infinity),
    insetPadding: EdgeInsets.symmetric(horizontal: 24).copyWith(top: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: lineBorder, width: 1),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    title: Row(
      children: [
        Icon(resolvedIcon, color: buttonDangerBg, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title.replaceAll('?', ''),
            style: TextStyle(
              color: textMain,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message
              .replaceAll('This action cannot be undone.', '')
              .replaceAll('This cannot be undone.', '')
              .trim(),
          style: TextStyle(
            color: textMain,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        if (!shouldNotRestart) ...[
          const SizedBox(height: 8),
          Text(
            "This cannot be undone.",
            style: TextStyle(
              color: textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: AnimatedScaleOnPress(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: lineBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onCancel,
                  child: Text(
                    shouldNotRestart ? 'Okay' : 'Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: buttonOutlineText,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!shouldNotRestart) ...[
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedScaleOnPress(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonDangerBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onConfirm,
                    child: Text(
                      okTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}
