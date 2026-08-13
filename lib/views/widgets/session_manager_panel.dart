import 'package:flutter/material.dart';
import '../../enums/exam_phase.dart';
import '../../models/exam_card_data.dart';
import '../../utils/constants.dart';

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

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VigiloUiColors.line(dark)),
      ),
      child: Column(
        children: [
          Container(
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
                Icon(
                  Icons.tune_rounded,
                  color: VigiloUiColors.blueSoft(dark),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Session Manager',
                  style: TextStyle(
                    color: VigiloUiColors.blueSoft(dark),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (statusFilter != 'All' || dateFilter != 'All')
                  GestureDetector(
                    onTap: onClear,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: VigiloUiColors.amber(dark),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: TextStyle(
                    color: VigiloUiColors.blueSoft(dark),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
                ),
                const SizedBox(height: 12),
                Text(
                  'DATE',
                  style: TextStyle(
                    color: VigiloUiColors.blueSoft(dark),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...['All', 'Today', 'This Week'].map(
                        (o) => _buildChip(
                          o,
                          selected: dateFilter == o,
                          onTap: () => onDateFilterChanged(o),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onJumpToDateTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: VigiloUiColors.blue(dark),
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Jump to date',
                                style: TextStyle(
                                  color: VigiloUiColors.blue(dark),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (lastImportSessions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                            Icon(
                              Icons.history_rounded,
                              color: VigiloUiColors.amber(dark),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LAST IMPORT',
                              style: TextStyle(
                                color: VigiloUiColors.amber(dark),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${lastImportSessions.length} session${lastImportSessions.length == 1 ? '' : 's'}'
                          '${protected.isEmpty ? '' : ' · ${protected.length} protected (started, completed, archived, or has an incident)'}',
                          style: TextStyle(
                            color: VigiloUiColors.textSoft(dark),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: undoable.isEmpty ? null : onUndoLastImport,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.undo_rounded,
                                  size: 14,
                                  color: undoable.isEmpty
                                      ? VigiloUiColors.textFaint(dark)
                                      : VigiloUiColors.amber(dark),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  undoable.isEmpty
                                      ? "Can't undo - all sessions protected"
                                      : 'Undo ${undoable.length} session${undoable.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: undoable.isEmpty
                                        ? VigiloUiColors.textFaint(dark)
                                        : VigiloUiColors.amber(dark),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? VigiloUiColors.blue(dark) : VigiloUiColors.panel3(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? VigiloUiColors.blue(dark) : VigiloUiColors.line(dark)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : VigiloUiColors.textSoft(dark),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
