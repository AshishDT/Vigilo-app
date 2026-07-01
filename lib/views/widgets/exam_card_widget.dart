// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../enums/exam_phase.dart';
import '../../models/exam_card_data.dart';
import 'animated_scale_on_press.dart';
import 'elapsed_remaining_line.dart';
import 'ring_painter_widget.dart';

class VigiloColors {
  final bool isDark;
  const VigiloColors(this.isDark);

  Color get bg => isDark ? const Color(0xFF071A2B) : const Color(0xFFEAF1F8);
  Color get bg2 => isDark ? const Color(0xFF0C2238) : const Color(0xFFF7FAFD);
  Color get panel => isDark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);
  Color get panel3 => isDark ? const Color(0xFF0F2236) : const Color(0xFFF1F6FB);
  Color get line => isDark ? const Color(0xFF294867) : const Color(0xFFC9D8E8);
  Color get lineSoft => isDark ? const Color(0xFF395B7D) : const Color(0xFFAFC3D8);

  Color get text => isDark ? const Color(0xFFF3F7FC) : const Color(0xFF10263D);
  Color get textSoft => isDark ? const Color(0xFFB6C7D8) : const Color(0xFF50677F);
  Color get textFaint => isDark ? const Color(0xFF7E98B2) : const Color(0xFF8297AC);

  Color get blue => isDark ? const Color(0xFF4B86F8) : const Color(0xFF256BDB);
  Color get blueSoft => isDark ? const Color(0xFF8FD4FF) : const Color(0xFF3F86F5);
  Color get amber => isDark ? const Color(0xFFFFB64D) : const Color(0xFFE59422);
  Color get finished => isDark ? const Color(0xFF8FA6BE) : const Color(0xFF7C91A8);
  Color get green => isDark ? const Color(0xFF5ED68A) : const Color(0xFF249B62);
}

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
    final vColors = VigiloColors(isDark);

    final subjectLine = data.subjectName.isEmpty ? data.subject : data.subjectName;
    final organizationLine = data.resolvedCentreNumber.isEmpty
        ? (data.organizationName.isEmpty ? data.school : data.organizationName)
        : '${data.organizationName} (${data.resolvedCentreNumber})';

    late Color phaseColor;
    switch (data.phase) {
      case ExamPhase.normal:
        phaseColor = vColors.blue;
        break;
      case ExamPhase.extra:
        phaseColor = vColors.amber;
        break;
      case ExamPhase.finished:
        phaseColor = vColors.finished;
        break;
    }

    final phaseRemaining = _phaseRemainingSeconds();
    final phaseElapsed = _elapsedSecond();
    final usedPercent = (data.progress * 100).clamp(0, 100).round();
    final collapsedExtra = data.phase == ExamPhase.extra && !data.expanded;
    final showRunning = data.running || data.progress > 0.0;

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
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: collapsedExtra
                ? Border.all(
                    width: 1.4,
                    color: vColors.amber.withOpacity(isDark ? 0.76 : 0.70),
                  )
                : !data.expanded
                    ? Border.all(
                        width: 1,
                        color: vColors.lineSoft.withOpacity(isDark ? 0.42 : 0.54),
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
            color: isDark ? vColors.panel.withOpacity(0.96) : vColors.panel,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectLine,
                              style: TextStyle(
                                color: vColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.15,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              data.date,
                              style: TextStyle(
                                color: vColors.textSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              organizationLine,
                              style: TextStyle(
                                color: vColors.textSoft,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isArchiveMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                data.isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                color: data.isSelected
                                    ? vColors.green
                                    : vColors.textSoft,
                              ),
                            ),
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
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(Icons.expand_more, color: vColors.textSoft),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _compactTimingBox(isDark, vColors),
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
                            _timerRing(isDark, vColors, phaseColor, phaseRemaining, phaseElapsed, usedPercent),
                            const SizedBox(height: 8),
                            _elapsedRemainingRow(context, isDark, vColors),
                            const SizedBox(height: 24),
                            _editButtonRows(context, isDark, vColors, showRunning: showRunning),
                            const SizedBox(height: 14),
                            _fullTimingSummaryBox(isDark, vColors),
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

  Widget _compactTimingBox(bool isDark, VigiloColors vColors) {
    final color = data.phase == ExamPhase.finished
        ? vColors.finished
        : vColors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: vColors.panel3.withOpacity(isDark ? 0.58 : 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vColors.blue.withOpacity(isDark ? 0.44 : 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _compactTimeValue(vColors, 'ST', _formatHeaderHm(data.start), color)),
          _verticalDivider(vColors, height: 30),
          Expanded(child: _compactTimeValue(vColors, 'D', data.duration, color)),
          _verticalDivider(vColors, height: 30),
          Expanded(child: _compactTimeValue(vColors, 'ET', _formatHeaderHm(data.end), color)),
        ],
      ),
    );
  }

  Widget _compactTimeValue(VigiloColors vColors, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: vColors.textFaint,
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

  Widget _timerRing(bool isDark, VigiloColors vColors, Color phaseColor, int phaseRemaining, int phaseElapsed, int usedPercent) {
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
                    trackColor: isDark ? vColors.line.withOpacity(0.42) : vColors.line.withOpacity(0.62),
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
                          color: vColors.text,
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
                        color: (data.phase == ExamPhase.finished ? vColors.green : phaseColor).withOpacity(0.88),
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

  Widget _elapsedRemainingRow(BuildContext context, bool isDark, VigiloColors vColors) {
    return ElapsedRemainingLine(
      elapsedStr: _fmtHhMm(_elapsedSecond()),
      remainingStr: _fmtHhMm(_phaseRemainingSeconds(), roundUp: data.isActiveTime),
      vColors: vColors,
    );
  }

  Widget _editButtonRows(BuildContext context, bool isDark, VigiloColors vColors, {required bool showRunning}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedScaleOnPress(
                child: _editButton(isDark, vColors, 'Date', Icons.event, onEditDate),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedScaleOnPress(
                child: _editButton(isDark, vColors, 'Start Time', Icons.schedule, onEditStartTime),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedScaleOnPress(
                child: _editButton(isDark, vColors, 'Duration', Icons.timer, onEditDuration),
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
                  vColors,
                  'Extra Time',
                  Icons.more_time,
                  onEditExtra,
                  accent: vColors.amber,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedScaleOnPress(
                child: showRunning
                    ? _runningButton(isDark, vColors)
                    : _startNowButton(vColors, () {
                        onUpdate(
                          data.copyWith(
                            running: true,
                            epochStart: DateTime.now(),
                            pausedSeconds: 0,
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

  Widget _editButton(
    bool isDark,
    VigiloColors vColors,
    String label,
    IconData icon,
    VoidCallback onPressed, {
    Color? accent,
  }) {
    final activeAccent = accent ?? vColors.blueSoft;

    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? vColors.panel3.withOpacity(0.86) : vColors.panel3,
          foregroundColor: vColors.text,
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

  Widget _startNowButton(VigiloColors vColors, VoidCallback onTap) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: vColors.blue,
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

  Widget _runningButton(bool isDark, VigiloColors vColors) {
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
                ? vColors.finished.withOpacity(isDark ? 0.27 : 0.16)
                : vColors.blue.withOpacity(isDark ? 0.27 : 0.16),
            disabledForegroundColor: vColors.textSoft,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: completed 
                    ? vColors.finished.withOpacity(isDark ? 0.36 : 0.30)
                    : vColors.blue.withOpacity(isDark ? 0.36 : 0.30),
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

  Widget _fullTimingSummaryBox(bool isDark, VigiloColors vColors) {
    final normalActive = data.phase == ExamPhase.normal;
    final extraActive = data.phase == ExamPhase.extra;
    final finished = data.phase == ExamPhase.finished;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? vColors.panel3.withOpacity(0.58) : vColors.panel3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: finished
              ? vColors.finished.withOpacity(isDark ? 0.32 : 0.34)
              : vColors.line.withOpacity(isDark ? 0.58 : 0.76),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _summaryRowBox(
            isDark,
            active: normalActive,
            borderColor: finished ? vColors.finished : vColors.blue,
            children: [
              Expanded(
                child: _summaryTimeValue(
                  vColors,
                  'Start Time',
                  _formatHeaderHm(data.normalStart),
                  finished ? vColors.finished : vColors.blue,
                ),
              ),
              _verticalDivider(vColors, height: 30),
              Expanded(
                child: _summaryTimeValue(
                  vColors,
                  'Duration',
                  data.normalDuration,
                  finished ? vColors.finished : vColors.blue,
                ),
              ),
              _verticalDivider(vColors, height: 30),
              Expanded(
                child: _summaryTimeValue(
                  vColors,
                  'End Time',
                  _formatHeaderHm(data.normalEnd),
                  finished ? vColors.finished : vColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryRowBox(
            isDark,
            active: extraActive,
            borderColor: finished ? vColors.finished : vColors.amber,
            children: [
              Expanded(
                child: _summaryTimeValue(
                  vColors,
                  'Extra Time',
                  data.extraTime,
                  finished ? vColors.finished : vColors.amber,
                ),
              ),
              _verticalDivider(vColors, height: 30),
              Expanded(
                child: _summaryTimeValue(
                  vColors,
                  'Duration',
                  data.totalDuration,
                  finished ? vColors.finished : vColors.amber,
                ),
              ),
              _verticalDivider(vColors, height: 30),
              Expanded(
                child: _summaryTimeValue(
                  vColors,
                  'Extra End',
                  _formatHeaderHm(data.extraEnd),
                  finished ? vColors.finished : vColors.amber,
                ),
              ),
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

  Widget _summaryTimeValue(VigiloColors vColors, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: vColors.textSoft,
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

  Widget _verticalDivider(VigiloColors vColors, {double height = 34}) {
    return Container(
      width: 1,
      height: height,
      color: vColors.line.withOpacity(vColors.isDark ? 0.50 : 0.74),
    );
  }
}
