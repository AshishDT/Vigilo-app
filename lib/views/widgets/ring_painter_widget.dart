import 'package:flutter/material.dart';
import 'dart:math' as math;

class RingPainter extends CustomPainter {
  const RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    this.isRunning = false,
    this.isDark = false,
  });

  final double progress;
  final Color trackColor, progressColor;
  final double strokeWidth;
  final bool isRunning;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth - 1
      ..color = trackColor
      ..strokeCap = StrokeCap.round;

    final glowOpacity = isDark ? 0.10 : (isRunning ? 0.07 : 0.09);
    final glowWidth = isDark ? (strokeWidth + 3) : (strokeWidth + 2);
    final glowBlur = isDark ? 4.0 : 3.0;

    final glow = Paint()
      ..color = progressColor.withValues(alpha: glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur);

    final progOpacity = isDark ? 1.0 : (isRunning ? 0.90 : 1.0);

    final prog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = progressColor.withValues(alpha: progOpacity)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, r, track);

    final start = -math.pi / 2;
    final sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: r);

    canvas.drawArc(rect, start, sweep, false, glow);
    canvas.drawArc(rect, start, sweep, false, prog);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.isRunning != isRunning ||
      old.isDark != isDark;
}
