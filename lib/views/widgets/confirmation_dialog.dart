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
  final panelColor = isDark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);
  final lineColor = isDark ? const Color(0xFF294867) : const Color(0xFFE2E8F0);
  final textColor = isDark ? const Color(0xFFF3F7FC) : const Color(0xFF0B253A);
  final textSoftColor = isDark ? const Color(0xFFB6C7D8) : const Color(0xFF475569);
  final blueColor = isDark ? const Color(0xFF4B86F8) : const Color(0xFF2563EB);

  final dangerColor = const Color(0xFFE85D73);
  final dangerSoftColor = const Color(0x33E85D73);

  final resolvedIcon = title.toLowerCase().contains('delete')
      ? Icons.delete_outline_rounded
      : title.toLowerCase().contains('end')
          ? Icons.stop_circle_outlined
          : title.toLowerCase().contains('restart')
              ? Icons.restart_alt_rounded
              : Icons.info_outline_rounded;

  final cleanMessage = message
      .replaceAll('This action cannot be undone', '')
      .replaceAll('This cannot be undone', '')
      .trim();

  return Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: lineColor.withOpacity(0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: dangerSoftColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: dangerColor.withOpacity(0.55),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  resolvedIcon,
                  color: dangerColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        cleanMessage,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFD2DCE8) : textSoftColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.42,
                        ),
                      ),
                      if (!shouldNotRestart) ...[
                        const SizedBox(height: 4),
                        Text(
                          'This cannot be undone',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFAEBCCC)
                                : textSoftColor.withOpacity(0.8),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: AnimatedScaleOnPress(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      side: BorderSide(
                        color: lineColor.withOpacity(0.85),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Text(
                      shouldNotRestart ? 'Okay' : 'Cancel',
                      style: TextStyle(
                        color: blueColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              if (!shouldNotRestart) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedScaleOnPress(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dangerColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        okTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

