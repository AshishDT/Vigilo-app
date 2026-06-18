import 'package:flutter/material.dart';
import 'dart:math' as math;

class RingPainter extends CustomPainter {
  const RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    this.isRunning = false,
  });

  final double progress;
  final Color trackColor, progressColor;
  final double strokeWidth;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth - 1
      ..color = trackColor
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = progressColor.withValues(alpha:isRunning ? 0.07 : 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final prog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = progressColor.withValues(alpha:isRunning ? 0.90 : 1.0)
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
      old.isRunning != isRunning;
}
