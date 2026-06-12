import 'package:flutter/material.dart';

import '../../enums/exam_phase.dart';
import '../../models/exam_card_data.dart';
import '../../utils/constants.dart';
import 'animated_scale_on_press.dart';
import 'ring_painter_widget.dart';
import 'time_cell_widget.dart';
import 'timing_cell_widget.dart';

class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.data,
    required this.pulse,
    required this.onChevronTap,
    required this.onEditDate,
    required this.onEditStartTime,
    required this.onEditDuration,
    required this.onEditExtra,
    required this.onUpdate,
    required this.isArchiveMode,
    required this.onSelect,
    required this.extraPulse,
    required this.tapScale,
    required this.onTimeTap,
    required this.onProgressChangeEnd,
    required this.onProgressDragState,
    required this.isExamCompleted,
  });

  final bool isArchiveMode;
  final ExamCardData data;
  final AnimationController pulse;
  final VoidCallback onChevronTap,
      onEditDate,
      onEditStartTime,
      onEditDuration,
      onEditExtra,
      onSelect,
      onTimeTap;
  final ValueChanged<ExamCardData> onUpdate;
  final ValueChanged<double> onProgressChangeEnd;
  final ValueChanged<bool> onProgressDragState;
  final bool extraPulse;
  final double tapScale;
  final bool isExamCompleted;

  String _fmtHhMm(int seconds, {bool roundUp = false}) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final totalMinutes = roundUp && safeSeconds > 0
        ? (safeSeconds + 59) ~/ 60
        : safeSeconds ~/ 60;
    final hh = totalMinutes ~/ 60;
    final mm = totalMinutes % 60;
    return "${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}";
  }

  String _formatHeaderHm(String value) {
    final trimmed = value.trim();
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;

    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return trimmed;

    return "${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}";
  }

  int _phaseRemainingSeconds() {
    final total = data.totalSeconds;
    final elapsed = (data.progress * (total == 0 ? 1 : total)).round();
    if (data.phase == ExamPhase.normal) {
      final rem = data.normalSeconds - elapsed.clamp(0, data.normalSeconds);
      return rem.clamp(0, data.normalSeconds);
    } else if (data.phase == ExamPhase.extra) {
      final intoExtra = elapsed - data.normalSeconds;
      final rem = data.extraSeconds - intoExtra.clamp(0, data.extraSeconds);
      return rem.clamp(0, data.extraSeconds);
    } else {
      return 0;
    }
  }

  int _elapsedSecond() {
    final total = data.totalSeconds;
    return (data.progress * (total == 0 ? 1 : total)).round();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = Theme.of(context).colorScheme.onSurface;
    final subjectLine = data.subjectName.isEmpty
        ? data.subject
        : data.subjectName;
    final organizationLine = data.resolvedCentreNumber.isEmpty
        ? (data.organizationName.isEmpty ? data.school : data.organizationName)
        : '${data.organizationName} (${data.resolvedCentreNumber})';

    late Color phaseColor;
    late String phaseLabel;
    switch (data.phase) {
      case ExamPhase.normal:
        phaseColor = kBlue;
        phaseLabel = "NORMAL TIME";
        break;
      case ExamPhase.extra:
        phaseColor = kAmber;
        phaseLabel = "EXTRA TIME";
        break;
      case ExamPhase.finished:
        phaseColor = kFinished;
        phaseLabel = "FINISHED";
        break;
    }

    final valueBlue = const TextStyle(
      color: kBlue,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
    final valueAmber = const TextStyle(
      color: kAmber,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
    final valueGrey = const TextStyle(
      color: kFinished,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
    final phaseRemaining = _phaseRemainingSeconds();
    final phaseElapsed = _elapsedSecond();
    final usedPercent = (data.progress * 100).clamp(0, 100).round();

    return AnimatedScale(
      scale: tapScale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: () {
          if (isArchiveMode) {
            onSelect();
          } else {
            onChevronTap();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: data.phase == ExamPhase.extra && !data.expanded
                ? Border.all(width: 2, color: kAmber)
                : (data.phase == ExamPhase.normal ||
                          data.phase == ExamPhase.finished) &&
                      !data.expanded
                ? Border.all(width: 1, color: kFinished)
                : null,
            boxShadow: data.phase == ExamPhase.extra && !data.expanded
                ? [
                    BoxShadow(
                      color: Colors.orange.withValues(
                        alpha: extraPulse ? 0.45 : 0.25,
                      ),
                      blurRadius: extraPulse ? 10 : 6,
                      spreadRadius: extraPulse ? 2 : 1,
                    ),
                  ]
                : data.phase != ExamPhase.extra && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Card(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subjectLine,
                                style: t.titleMedium?.copyWith(
                                  fontSize: (t.titleMedium?.fontSize ?? 16) + 2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data.date,
                                style: t.bodySmall?.copyWith(
                                  fontSize: (t.bodySmall?.fontSize ?? 12) + 1,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                organizationLine,
                                style: t.bodyMedium?.copyWith(
                                  fontSize: (t.bodyMedium?.fontSize ?? 14) + 1,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            InkWell(
                              onTap: () {
                                if (!isArchiveMode) {
                                  onChevronTap();
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedRotation(
                                duration: const Duration(milliseconds: 200),
                                turns: data.expanded ? 0.5 : 0.0,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.expand_more),
                                ),
                              ),
                            ),
                            if (isArchiveMode)
                              Icon(
                                data.isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                color: data.isSelected
                                    ? kGreen
                                    : isDark
                                    ? Colors.white54
                                    : Colors.black87,
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Collapsed triplet
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TimeCell(
                              label: "Start Time",
                              value: _formatHeaderHm(data.start),
                              style: data.phase == ExamPhase.finished
                                  ? valueGrey
                                  : valueBlue,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Duration",
                                  style: t.bodySmall?.copyWith(
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data.duration,
                                  style: data.phase == ExamPhase.finished
                                      ? valueGrey
                                      : valueBlue,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TimeCell(
                                label: "End Time",
                                value: _formatHeaderHm(data.end),
                                style: data.phase == ExamPhase.finished
                                    ? valueGrey
                                    : valueBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (data.expanded) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey<bool>(data.expanded),
                          tween: Tween(begin: 0.0, end: data.progress),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => SizedBox(
                            width: 220,
                            height: 220,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.98, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: pulse,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size.square(220),
                                    painter: RingPainter(
                                      progress: v,
                                      trackColor: isDark
                                          ? const Color(0xFF27313B)
                                          : const Color(0xFFE6ECF3),
                                      progressColor: phaseColor,
                                      strokeWidth: 12,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: onTimeTap,
                                        child: Text(
                                          _fmtHhMm(
                                            data.isActiveTime
                                                ? phaseRemaining
                                                : phaseElapsed,
                                            roundUp: data.isActiveTime,
                                          ),
                                          style: t.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: phaseColor,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          phaseLabel,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Slider with % used label (read-only when running)
                      Row(
                        mainAxisAlignment:
                            MediaQuery.of(context).orientation ==
                                Orientation.landscape
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 260,
                            child: Row(
                              children: [
                                Text("$usedPercent%"),
                                Expanded(
                                  child: IgnorePointer(
                                    ignoring: isExamCompleted,
                                    child: Slider(
                                      value: data.progress,
                                      onChangeStart: data.running
                                          ? null
                                          : (_) => onProgressDragState(true),
                                      onChangeEnd: data.running
                                          ? null
                                          : (v) => onProgressChangeEnd(v),
                                      onChanged: (data.running)
                                          ? null
                                          : (v) => onUpdate(
                                                data.copyWith(
                                                  progress: v,
                                                  autoStart: false,
                                                  autoStartUserModified: true,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                                const Text("100%"),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Start Now (only if not started)
                      if (!data.running && data.progress == 0.0) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: FilledButton.icon(
                            onPressed: () => onUpdate(
                              data.copyWith(
                                running: true,
                                epochStart: DateTime.now(),
                                pausedSeconds: 0,
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Now'),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      MediaQuery.of(context).orientation ==
                              Orientation.landscape
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                AnimatedScaleOnPress(
                                  child: ElevatedButton.icon(
                                    style: ButtonStyle(
                                      side: WidgetStateProperty.all(
                                        BorderSide(
                                          color: kBlue.withValues(alpha: 0.45),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    onPressed: onEditDate,
                                    icon: const Icon(Icons.event),
                                    label: const Text("Date"),
                                  ),
                                ),
                                AnimatedScaleOnPress(
                                  child: ElevatedButton.icon(
                                    style: ButtonStyle(
                                      side: WidgetStateProperty.all(
                                        BorderSide(
                                          color: kBlue.withValues(alpha: 0.45),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    onPressed: onEditStartTime,
                                    icon: const Icon(Icons.schedule),
                                    label: const Text("Start Time"),
                                  ),
                                ),
                                AnimatedScaleOnPress(
                                  child: ElevatedButton.icon(
                                    style: ButtonStyle(
                                      side: WidgetStateProperty.all(
                                        BorderSide(
                                          color: kBlue.withValues(alpha: 0.45),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    onPressed: onEditDuration,
                                    icon: const Icon(Icons.timer),
                                    label: const Text("Duration"),
                                  ),
                                ),
                                AnimatedScaleOnPress(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kAmber,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: onEditExtra,
                                    icon: const Icon(Icons.more_time),
                                    label: const Text("Extra Time"),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 95,
                                      child: AnimatedScaleOnPress(
                                        child: ElevatedButton.icon(
                                          style: ButtonStyle(
                                            padding: WidgetStateProperty.all(
                                              EdgeInsets.all(4),
                                            ),
                                            side: WidgetStateProperty.all(
                                              BorderSide(
                                                color: kBlue.withValues(
                                                  alpha: 0.45,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          onPressed: onEditDate,
                                          icon: const Icon(Icons.event),
                                          label: const Text("Date"),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      flex: 110,
                                      child: AnimatedScaleOnPress(
                                        child: ElevatedButton.icon(
                                          style: ButtonStyle(
                                            padding: WidgetStateProperty.all(
                                              EdgeInsets.all(4),
                                            ),
                                            side: WidgetStateProperty.all(
                                              BorderSide(
                                                color: kBlue.withValues(
                                                  alpha: 0.45,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          onPressed: onEditStartTime,
                                          icon: const Icon(Icons.schedule),
                                          label: const Text("Start Time"),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      flex: 95,
                                      child: AnimatedScaleOnPress(
                                        child: ElevatedButton.icon(
                                          style: ButtonStyle(
                                            padding: WidgetStateProperty.all(
                                              EdgeInsets.all(4),
                                            ),
                                            side: WidgetStateProperty.all(
                                              BorderSide(
                                                color: kBlue.withValues(
                                                  alpha: 0.45,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          onPressed: onEditDuration,
                                          icon: const Icon(Icons.timer),
                                          label: const Text("Duration"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                AnimatedScaleOnPress(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kAmber,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: onEditExtra,
                                    icon: const Icon(Icons.more_time),
                                    label: const Text("Extra Time"),
                                  ),
                                ),
                              ],
                            ),

                      const SizedBox(height: 12),

                      // Normal & Extra rows
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TimingCell(
                                    label: "Start Time",
                                    value: _formatHeaderHm(data.normalStart),
                                    valueStyle: valueBlue,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Duration",
                                        style: t.bodySmall?.copyWith(
                                          color: labelColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data.normalDuration,
                                        style: valueBlue,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TimingCell(
                                      label: "End Time",
                                      value: _formatHeaderHm(data.normalEnd),
                                      valueStyle: valueBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TimingCell(
                                    label: "Extra Time",
                                    value: data.extraTime,
                                    valueStyle: valueAmber,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Duration",
                                        style: t.bodySmall?.copyWith(
                                          color: labelColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data.totalDuration,
                                        style: valueAmber,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TimingCell(
                                      label: "Extra End",
                                      value: _formatHeaderHm(data.extraEnd),
                                      valueStyle: valueAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
