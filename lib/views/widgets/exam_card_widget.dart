// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../enums/exam_phase.dart';
import '../../models/exam_card_data.dart';
import '../../utils/constants.dart';
import 'animated_scale_on_press.dart';
import 'elapsed_remaining_line.dart';
import 'ring_painter_widget.dart';

class ExamCard extends StatefulWidget {
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

  @override
  State<ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<ExamCard> with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  double _localScale = 1.0;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    if (widget.data.expanded) {
      _expandController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant ExamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.expanded != oldWidget.data.expanded) {
      if (widget.data.expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  bool get isArchiveMode => widget.isArchiveMode;
  ExamCardData get data => widget.data;
  AnimationController get pulse => widget.pulse;
  VoidCallback get onChevronTap => widget.onChevronTap;
  VoidCallback get onEditDate => widget.onEditDate;
  VoidCallback get onEditStartTime => widget.onEditStartTime;
  VoidCallback get onEditDuration => widget.onEditDuration;
  VoidCallback get onEditExtra => widget.onEditExtra;
  VoidCallback get onSelect => widget.onSelect;
  VoidCallback get onTimeTap => widget.onTimeTap;
  ValueChanged<ExamCardData> get onUpdate => widget.onUpdate;
  ValueChanged<double> get onProgressChangeEnd => widget.onProgressChangeEnd;
  ValueChanged<bool> get onProgressDragState => widget.onProgressDragState;
  bool get extraPulse => widget.extraPulse;
  double get tapScale => widget.tapScale;
  bool get isExamCompleted => widget.isExamCompleted;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subjectLine = data.subjectName.isEmpty ? data.subject : data.subjectName;
    final organizationLine = data.resolvedCentreNumber.isEmpty
        ? (data.organizationName.isEmpty ? data.school : data.organizationName)
        : '${data.organizationName} (${data.resolvedCentreNumber})';

    late Color phaseColor;
    switch (data.phase) {
      case ExamPhase.normal:
        phaseColor = VigiloUiColors.blue(isDark);
        break;
      case ExamPhase.extra:
        phaseColor = VigiloUiColors.amber(isDark);
        break;
      case ExamPhase.finished:
        phaseColor = VigiloUiColors.finished(isDark);
        break;
    }

    final phaseRemaining = _phaseRemainingSeconds();
    final phaseElapsed = _elapsedSecond();
    final usedPercent = (data.progress * 100).clamp(0, 100).round();
    final collapsedExtra = data.phase == ExamPhase.extra && !data.expanded;
    final showRunning = data.running || data.progress > 0.0;

    return AnimatedScale(
      scale: isArchiveMode ? widget.tapScale : _localScale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: (data.isLocked && !isExamCompleted && !isArchiveMode)
            ? null
            : () {
                setState(() {
                  _localScale = 1.02;
                });
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    setState(() {
                      _localScale = 1.0;
                    });
                  }
                });
                if (isArchiveMode) {
                  onSelect();
                } else {
                  onChevronTap();
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: collapsedExtra
                ? Border.all(
                    width: 1.4,
                    color: VigiloUiColors.amber(isDark).withOpacity(isDark ? 0.76 : 0.70),
                  )
                : !data.expanded
                    ? Border.all(
                        width: 1,
                        color: VigiloUiColors.lineSoft(isDark).withOpacity(isDark ? 0.42 : 0.54),
                      )
                    : Border.all(width: 1, color: phaseColor.withOpacity(isDark ? 0.26 : 0.34)),
            boxShadow: [
              BoxShadow(
                color: phaseColor.withOpacity(collapsedExtra ? 0.14 : (isDark ? 0.055 : 0.075)),
                blurRadius: collapsedExtra ? 12 : (isDark ? 9 : 10),
                spreadRadius: collapsedExtra ? 1 : 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.08),
                blurRadius: isDark ? 8 : 12,
                offset: Offset(0, isDark ? 4.0 : 5.0),
              ),
            ],
          ),
          child: Card(
            color: isDark ? VigiloUiColors.panel(isDark).withOpacity(0.96) : VigiloUiColors.panel(isDark),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final hasExamLevel = (data.examLevel ?? '').trim().isNotEmpty;
                    final hasExamBoard = data.subjectBoard.trim().isNotEmpty;
                    final hasLevelOrBoard = hasExamLevel || hasExamBoard;
                    final hasStatusPill = data.isDatePassed ||
                        data.phase == ExamPhase.finished ||
                        data.isPaused ||
                        data.running;
                    final showArchiveCheck = isArchiveMode && (isExamCompleted || data.isLocked);
                    final hideChevronInArchive = isArchiveMode && isExamCompleted;
                    final showChevron = !data.isLocked && !hideChevronInArchive;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Subject Line + Top Controls (Chevron & Selection Checkbox)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                subjectLine,
                                style: TextStyle(
                                  color: VigiloUiColors.text(isDark),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.15,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showArchiveCheck) ...[
                                  Icon(
                                    data.isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked,
                                    color: data.isSelected
                                        ? VigiloUiColors.green(isDark)
                                        : VigiloUiColors.textSoft(isDark),
                                  ),
                                ],
                                if (showChevron) ...[
                                  if (showArchiveCheck)
                                    const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () {
                                      if (!isArchiveMode) {
                                        setState(() {
                                          _localScale = 1.02;
                                        });
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          if (mounted) {
                                            setState(() {
                                              _localScale = 1.0;
                                            });
                                          }
                                        });
                                        onChevronTap();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: AnimatedRotation(
                                      duration: const Duration(milliseconds: 200),
                                      turns: data.expanded ? 0.5 : 0.0,
                                      child: Icon(Icons.expand_more, color: VigiloUiColors.textSoft(isDark)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),

                        // Row 2 (Level + Board Line - rendered if level or board is present)
                        if (hasLevelOrBoard) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      if (hasExamLevel)
                                        TextSpan(
                                          text: data.examLevel!,
                                          style: TextStyle(
                                            color: VigiloUiColors.textSoft(isDark),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                      if (hasExamLevel && hasExamBoard)
                                        TextSpan(
                                          text: '  ·  ',
                                          style: TextStyle(
                                            color: VigiloUiColors.textFaint(isDark),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                      if (hasExamBoard)
                                        TextSpan(
                                          text: data.subjectBoard,
                                          style: TextStyle(
                                            color: VigiloUiColors.textSoft(isDark),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (hasStatusPill) ...[
                                const SizedBox(width: 8),
                                _buildClosedCardStatusPill(data, isDark),
                              ],
                            ],
                          ),
                        ],

                        // Inter-group spacing between (Name + Level/Board) and (Date + Org)
                        const SizedBox(height: 8),

                        // Date Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                data.date,
                                style: TextStyle(
                                  color: VigiloUiColors.textSoft(isDark),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (!hasLevelOrBoard && hasStatusPill) ...[
                              const SizedBox(width: 8),
                              _buildClosedCardStatusPill(data, isDark),
                            ],
                          ],
                        ),

                        // Organization Line
                        const SizedBox(height: 3),
                        Text(
                          organizationLine,
                          style: TextStyle(
                            color: VigiloUiColors.textSoft(isDark),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: data.isLocked ? 0.4 : 1.0,
                    child: _compactTimingBox(isDark),
                  ),
                  SizeTransition(
                    sizeFactor: _expandAnimation,
                    axisAlignment: -1.0,
                    child: ClipRect(
                      child: FadeTransition(
                        opacity: _expandAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _timerRing(isDark, phaseColor, phaseRemaining, phaseElapsed, usedPercent),
                            const SizedBox(height: 8),
                            _elapsedRemainingRow(context, isDark),
                            const SizedBox(height: 24),
                            _editButtonRows(context, isDark, showRunning: showRunning),
                            const SizedBox(height: 14),
                            _fullTimingSummaryBox(isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactTimingBox(bool isDark) {
    final color = data.phase == ExamPhase.finished
        ? VigiloUiColors.finished(isDark)
        : VigiloUiColors.blue(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel3(isDark).withOpacity(isDark ? 0.58 : 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VigiloUiColors.blue(isDark).withOpacity(isDark ? 0.44 : 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _compactTimeValue(isDark, 'ST', _formatHeaderHm(data.start), color)),
          _verticalDivider(isDark, height: 30),
          Expanded(child: _compactTimeValue(isDark, 'D', data.duration, color)),
          _verticalDivider(isDark, height: 30),
          Expanded(child: _compactTimeValue(isDark, 'ET', _formatHeaderHm(data.end), color)),
        ],
      ),
    );
  }

  Widget _compactTimeValue(bool isDark, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: VigiloUiColors.textFaint(isDark),
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.55,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _timerRing(bool isDark, Color phaseColor, int phaseRemaining, int phaseElapsed, int usedPercent) {
    late String phaseLabel;
    switch (data.phase) {
      case ExamPhase.normal:
        phaseLabel = 'NORMAL TIME';
        break;
      case ExamPhase.extra:
        phaseLabel = 'EXTRA TIME';
        break;
      case ExamPhase.finished:
        phaseLabel = 'FINISHED';
        break;
    }

    return Center(
      child: SizedBox(
        width: 228,
        height: 228,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: data.progress),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ScaleTransition(
            scale: data.running
                ? Tween(begin: 0.98, end: 1.0).animate(
                    CurvedAnimation(
                      parent: pulse,
                      curve: Curves.easeInOut,
                    ),
                  )
                : const AlwaysStoppedAnimation(1.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(228),
                  painter: RingPainter(
                    progress: v,
                    trackColor: isDark ? VigiloUiColors.line(isDark).withOpacity(0.42) : VigiloUiColors.line(isDark).withOpacity(0.62),
                    progressColor: phaseColor,
                    strokeWidth: 12,
                    isRunning: data.running,
                    isDark: isDark,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onTimeTap,
                      child: Text(
                        _fmtHhMm(
                          data.isActiveTime ? phaseRemaining : phaseElapsed,
                          roundUp: data.isActiveTime,
                        ),
                        style: TextStyle(
                          color: VigiloUiColors.text(isDark),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: (data.phase == ExamPhase.finished ? VigiloUiColors.green(isDark) : phaseColor).withOpacity(0.88),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        phaseLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$usedPercent%',
                      style: TextStyle(
                        color: phaseColor.withOpacity(data.running ? (isDark ? 1.0 : 0.78) : (isDark ? 1.0 : 0.95)),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _elapsedRemainingRow(BuildContext context, bool isDark) {
    return ElapsedRemainingLine(
      elapsedStr: _fmtHhMm(_elapsedSecond()),
      remainingStr: _fmtHhMm(_phaseRemainingSeconds(), roundUp: data.isActiveTime),
      isDark: isDark,
    );
  }

  Widget _editButtonRows(BuildContext context, bool isDark, {required bool showRunning}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedScaleOnPress(
                child: _editButton(isDark, 'Date', Icons.event, onEditDate),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedScaleOnPress(
                child: _editButton(isDark, 'Start Time', Icons.schedule, onEditStartTime),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedScaleOnPress(
                child: _editButton(isDark, 'Duration', Icons.timer, onEditDuration),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AnimatedScaleOnPress(
                child: _editButton(
                  isDark,
                  'Extra Time',
                  Icons.more_time,
                  onEditExtra,
                  accent: VigiloUiColors.amber(isDark),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedScaleOnPress(
                child: showRunning
                    ? _runningButton(isDark)
                    : _startNowButton(isDark, () {
                        onUpdate(
                          data.copyWith(
                            running: true,
                            epochStart: DateTime.now(),
                            pausedSeconds: 0,
                            wasEverStarted: true,
                          ),
                        );
                      }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClosedCardStatusPill(ExamCardData data, bool isDark) {
    if (data.isDatePassed) {
      if (data.importedAsPast || data.autoStart) {
        return _pill('DATE PASSED', VigiloUiColors.textFaint(isDark));
      } else {
        return _pill('READY TO START', VigiloUiColors.blue(isDark));
      }
    }
    if (data.phase == ExamPhase.finished) {
      return _pill('FINISHED', VigiloUiColors.green(isDark));
    }
    if (data.isPaused) {
      return _pill('PAUSED', VigiloUiColors.amber(isDark));
    }
    if (data.running) {
      return _pill('RUNNING', VigiloUiColors.blue(isDark));
    }
    return const SizedBox.shrink();
  }

  Widget _pill(String label, Color color) {
    return AnimatedScaleOnPress(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 9.5,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _editButton(
    bool isDark,
    String label,
    IconData icon,
    VoidCallback onPressed, {
    Color? accent,
  }) {
    final activeAccent = accent ?? VigiloUiColors.blueSoft(isDark);

    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? VigiloUiColors.panel3(isDark).withOpacity(0.86) : VigiloUiColors.panel3(isDark),
          foregroundColor: VigiloUiColors.text(isDark),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: activeAccent.withOpacity(isDark ? 0.36 : 0.34), width: 1),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: activeAccent),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.05,
            ),
          ),
        ),
      ),
    );
  }

  Widget _startNowButton(bool isDark, VoidCallback onTap) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: VigiloUiColors.blue(isDark),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text(
          'Start Now',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.05,
          ),
        ),
      ),
    );
  }

  Widget _runningButton(bool isDark) {
    final bool completed = isExamCompleted || data.phase == ExamPhase.finished;
    final String labelText = completed ? 'Finished' : 'Running';
    final IconData iconData = completed ? Icons.check_circle_outline_rounded : Icons.lock_rounded;

    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        height: 42,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            disabledBackgroundColor: completed
                ? VigiloUiColors.finished(isDark).withOpacity(isDark ? 0.27 : 0.16)
                : VigiloUiColors.blue(isDark).withOpacity(isDark ? 0.27 : 0.16),
            disabledForegroundColor: VigiloUiColors.textSoft(isDark),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: completed
                    ? VigiloUiColors.finished(isDark).withOpacity(isDark ? 0.36 : 0.30)
                    : VigiloUiColors.blue(isDark).withOpacity(isDark ? 0.36 : 0.30),
                width: 1,
              ),
            ),
          ),
          onPressed: null,
          icon: Icon(iconData, size: 16),
          label: Text(
            labelText,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.05,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fullTimingSummaryBox(bool isDark) {
    final normalActive = data.phase == ExamPhase.normal;
    final extraActive = data.phase == ExamPhase.extra;
    final finished = data.phase == ExamPhase.finished;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? VigiloUiColors.panel3(isDark).withOpacity(0.58) : VigiloUiColors.panel3(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: finished
              ? VigiloUiColors.finished(isDark).withOpacity(isDark ? 0.32 : 0.34)
              : VigiloUiColors.line(isDark).withOpacity(isDark ? 0.58 : 0.76),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _summaryRowBox(
            isDark,
            active: normalActive,
            borderColor: finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.blue(isDark),
            children: [
              Expanded(
                child: _summaryTimeValue(
                  isDark,
                  'Start Time',
                  _formatHeaderHm(data.normalStart),
                  finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.blue(isDark),
                ),
              ),
              _verticalDivider(isDark, height: 30),
              Expanded(
                child: _summaryTimeValue(
                  isDark,
                  'Duration',
                  data.normalDuration,
                  finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.blue(isDark),
                ),
              ),
              _verticalDivider(isDark, height: 30),
              Expanded(
                child: _summaryTimeValue(
                  isDark,
                  'End Time',
                  _formatHeaderHm(data.normalEnd),
                  finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.blue(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryRowBox(
            isDark,
            active: extraActive,
            borderColor: finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.amber(isDark),
            children: [
              Builder(builder: (context) {
                final hasExtra = data.extraTime.isNotEmpty &&
                    data.extraTime != '00:00' &&
                    data.extraTime != '0';
                final extraTimeVal = hasExtra ? data.extraTime : '00:00';
                final durationVal = hasExtra ? data.totalDuration : '00:00';
                final extraEndVal = hasExtra ? _formatHeaderHm(data.extraEnd) : '00:00';

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _summaryTimeValue(
                          isDark,
                          'Extra Time',
                          extraTimeVal,
                          finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.amber(isDark),
                        ),
                      ),
                      _verticalDivider(isDark, height: 30),
                      Expanded(
                        child: _summaryTimeValue(
                          isDark,
                          'Duration',
                          durationVal,
                          finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.amber(isDark),
                        ),
                      ),
                      _verticalDivider(isDark, height: 30),
                      Expanded(
                        child: _summaryTimeValue(
                          isDark,
                          'Extra End',
                          extraEndVal,
                          finished ? VigiloUiColors.finished(isDark) : VigiloUiColors.amber(isDark),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRowBox(
    bool isDark, {
    required bool active,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? borderColor.withOpacity(isDark ? 0.56 : 0.46) : Colors.transparent,
          width: 1,
        ),
        color: active ? borderColor.withOpacity(isDark ? 0.04 : 0.045) : Colors.transparent,
      ),
      child: Row(children: children),
    );
  }

  Widget _summaryTimeValue(bool isDark, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: VigiloUiColors.textSoft(isDark),
            fontSize: 11.7,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 18.2,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider(bool isDark, {double height = 34}) {
    return Container(
      width: 1,
      height: height,
      color: VigiloUiColors.line(isDark).withOpacity(isDark ? 0.50 : 0.74),
    );
  }
}
