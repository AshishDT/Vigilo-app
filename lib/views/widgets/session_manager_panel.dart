import 'package:flutter/material.dart';
import '../../enums/exam_phase.dart';
import '../../models/exam_card_data.dart';
import '../../utils/constants.dart';
import 'animated_scale_on_press.dart';

class SessionManagerPanel extends StatelessWidget {
  final bool dark;
  final String statusFilter;
  final String dateFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onDateFilterChanged;
  final VoidCallback onClear;
  final VoidCallback onJumpToDateTap;
  final List<ExamCardData> lastImportSessions;
  final VoidCallback onUndoLastImport;

  const SessionManagerPanel({
    super.key,
    required this.dark,
    required this.statusFilter,
    required this.dateFilter,
    required this.onStatusFilterChanged,
    required this.onDateFilterChanged,
    required this.onClear,
    required this.onJumpToDateTap,
    required this.lastImportSessions,
    required this.onUndoLastImport,
  });

  @override
  Widget build(BuildContext context) {
    final protected = lastImportSessions
        .where(
          (s) =>
              s.running ||
              s.isPaused ||
              s.wasEverStarted ||
              s.phase == ExamPhase.finished ||
              s.logs.isNotEmpty,
        )
        .toList();
    final undoable =
        lastImportSessions.where((s) => !protected.contains(s)).toList();

    return AnimatedContainer(
      duration: kThemeFadeDuration,
      curve: kThemeFadeCurve,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VigiloUiColors.line(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: kThemeFadeDuration,
            curve: kThemeFadeCurve,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: VigiloUiColors.blue(dark).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: VigiloUiColors.line(dark)),
              ),
            ),
            child: Row(
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: kThemeFadeDuration,
                  curve: kThemeFadeCurve,
                  tween: ColorTween(end: VigiloUiColors.blueSoft(dark)),
                  builder: (context, iconColor, _) {
                    return Icon(
                      Icons.tune_rounded,
                      color: iconColor,
                      size: 16,
                    );
                  },
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: kThemeFadeDuration,
                  curve: kThemeFadeCurve,
                  style: TextStyle(
                    color: VigiloUiColors.blueSoft(dark),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  child: const Text('Session Manager'),
                ),
                const Spacer(),
                if (statusFilter != 'All' || dateFilter != 'All')
                  AnimatedScaleOnPress(
                    child: GestureDetector(
                      onTap: onClear,
                      child: AnimatedDefaultTextStyle(
                        duration: kThemeFadeDuration,
                        curve: kThemeFadeCurve,
                        style: TextStyle(
                          color: VigiloUiColors.amber(dark),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        child: const Text('Clear Filters'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: kThemeFadeDuration,
                  curve: kThemeFadeCurve,
                  style: TextStyle(
                    color: VigiloUiColors.blueSoft(dark),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  child: const Text('STATUS'),
                ),
                const SizedBox(height: 6),
                Wrap(
                  children: [
                    'All',
                    'Not Started',
                    'Running',
                    'Finished',
                  ].map(
                    (o) => _buildChip(
                      o,
                      selected: statusFilter == o,
                      onTap: () => onStatusFilterChanged(o),
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 10),
                AnimatedDefaultTextStyle(
                  duration: kThemeFadeDuration,
                  curve: kThemeFadeCurve,
                  style: TextStyle(
                    color: VigiloUiColors.blueSoft(dark),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  child: const Text('DATE'),
                ),
                const SizedBox(height: 6),
                Wrap(
                  runSpacing: 6,
                  children: [
                    ...['All', 'Today', 'This Week'].map(
                      (o) => _buildChip(
                        o,
                        selected: dateFilter == o,
                        onTap: () => onDateFilterChanged(o),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedScaleOnPress(
                      child: GestureDetector(
                        onTap: onJumpToDateTap,
                        child: AnimatedContainer(
                          duration: kThemeFadeDuration,
                          curve: kThemeFadeCurve,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: VigiloUiColors.blue(dark).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: VigiloUiColors.blue(dark).withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: TweenAnimationBuilder<Color?>(
                            duration: kThemeFadeDuration,
                            curve: kThemeFadeCurve,
                            tween: ColorTween(end: VigiloUiColors.blue(dark)),
                            builder: (context, iconColor, _) {
                              return Icon(
                                Icons.calendar_today_rounded,
                                color: iconColor,
                                size: 15,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (lastImportSessions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: kThemeFadeDuration,
                    curve: kThemeFadeCurve,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VigiloUiColors.amber(dark).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: VigiloUiColors.amber(dark).withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TweenAnimationBuilder<Color?>(
                              duration: kThemeFadeDuration,
                              curve: kThemeFadeCurve,
                              tween: ColorTween(end: VigiloUiColors.amber(dark)),
                              builder: (context, iconColor, _) {
                                return Icon(
                                  Icons.history_rounded,
                                  color: iconColor,
                                  size: 13,
                                );
                              },
                            ),
                            const SizedBox(width: 5),
                            AnimatedDefaultTextStyle(
                              duration: kThemeFadeDuration,
                              curve: kThemeFadeCurve,
                              style: TextStyle(
                                color: VigiloUiColors.amber(dark),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                              child: const Text('LAST IMPORT'),
                            ),
                            const Spacer(),
                            AnimatedDefaultTextStyle(
                              duration: kThemeFadeDuration,
                              curve: kThemeFadeCurve,
                              style: TextStyle(
                                color: VigiloUiColors.textSoft(dark),
                                fontSize: 11.5,
                              ),
                              child: Text(
                                '${lastImportSessions.length} session${lastImportSessions.length == 1 ? '' : 's'}'
                                '${protected.isEmpty ? '' : ' \u00b7 ${protected.length} protected'}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedScaleOnPress(
                          isDisabled: undoable.isEmpty,
                          child: GestureDetector(
                            onTap: undoable.isEmpty ? null : onUndoLastImport,
                            child: AnimatedContainer(
                              duration: kThemeFadeDuration,
                              curve: kThemeFadeCurve,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: undoable.isEmpty
                                    ? VigiloUiColors.panel3(dark)
                                    : VigiloUiColors.amber(dark).withValues(
                                        alpha: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: undoable.isEmpty
                                      ? VigiloUiColors.line(dark)
                                      : VigiloUiColors.amber(dark),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TweenAnimationBuilder<Color?>(
                                    duration: kThemeFadeDuration,
                                    curve: kThemeFadeCurve,
                                    tween: ColorTween(
                                      end: undoable.isEmpty
                                          ? VigiloUiColors.textFaint(dark)
                                          : VigiloUiColors.amber(dark),
                                    ),
                                    builder: (context, iconColor, _) {
                                      return Icon(
                                        Icons.undo_rounded,
                                        size: 14,
                                        color: iconColor,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedDefaultTextStyle(
                                    duration: kThemeFadeDuration,
                                    curve: kThemeFadeCurve,
                                    style: TextStyle(
                                      color: undoable.isEmpty
                                          ? VigiloUiColors.textFaint(dark)
                                          : VigiloUiColors.amber(dark),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    child: Text(
                                      undoable.isEmpty
                                          ? "Can't undo, all protected"
                                          : 'Undo ${undoable.length} session${undoable.length == 1 ? '' : 's'}',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (protected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 2),
                      child: AnimatedDefaultTextStyle(
                        duration: kThemeFadeDuration,
                        curve: kThemeFadeCurve,
                        style: TextStyle(
                          color: VigiloUiColors.textFaint(dark),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                        child: const Text(
                          'Protected = started, archived, or has an incident',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) => AnimatedScaleOnPress(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kThemeFadeDuration,
        curve: kThemeFadeCurve,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? VigiloUiColors.blue(dark) : VigiloUiColors.panel3(dark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? VigiloUiColors.blue(dark) : VigiloUiColors.line(dark)),
        ),
        child: AnimatedDefaultTextStyle(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          style: TextStyle(
            color: selected ? Colors.white : VigiloUiColors.textSoft(dark),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          child: Text(label),
        ),
      ),
    ),
  );
}
