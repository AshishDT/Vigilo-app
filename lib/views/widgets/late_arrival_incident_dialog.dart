import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/notifications.dart';
import '../../utils/safe_navigator.dart';
import 'animated_scale_on_press.dart';

class LateArrivalIncidentDialog extends StatefulWidget {
  const LateArrivalIncidentDialog({
    super.key,
    required this.initialRoom,
    required this.onSave,
  });

  final String initialRoom;
  final void Function(
    String room,
    String candidateRef,
    bool admitted,
    String supervisionTime,
    String actualStartTime,
    String reason,
    String actions,
  ) onSave;

  @override
  State<LateArrivalIncidentDialog> createState() =>
      _LateArrivalIncidentDialogState();
}

class _LateArrivalIncidentDialogState extends State<LateArrivalIncidentDialog> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  final TextEditingController _candidateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _actionsController = TextEditingController();
  late final FocusNode _candidateFocus = FocusNode();
  late final FocusNode _reasonFocus = FocusNode();
  late final FocusNode _actionsFocus = FocusNode();

  bool? _admitted;
  late TimeOfDay _supervisionTime;
  late TimeOfDay _candidateStartTime;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _supervisionTime = now;
    _candidateStartTime = now;
  }

  @override
  void dispose() {
    _candidateController.dispose();
    _reasonController.dispose();
    _actionsController.dispose();
    _candidateFocus.dispose();
    _reasonFocus.dispose();
    _actionsFocus.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final hh = hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hh:$mm $period';
  }

  Future<TimeOfDay?> _showLateArrivalThemedTimePicker(TimeOfDay initialTime) {
    final isDark = _isDark;
    final gold = VigiloUiColors.incidentLateArrival(isDark);
    final panelBg = VigiloUiColors.panel(isDark);
    final panel2Bg = VigiloUiColors.panel2(isDark);
    final textColor = VigiloUiColors.text(isDark);
    final textSoftColor = VigiloUiColors.textSoft(isDark);
    final lineSoftColor = VigiloUiColors.lineSoft(isDark);

    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: (isDark
                    ? const ColorScheme.dark()
                    : const ColorScheme.light())
                .copyWith(
              primary: gold,
              onPrimary: VigiloUiColors.bg(isDark),
              surface: panelBg,
              onSurface: textColor,
              surfaceContainerHighest: panel2Bg,
              outline: lineSoftColor,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: panelBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: lineSoftColor),
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: lineSoftColor),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: lineSoftColor),
              ),
              dialHandColor: gold,
              dialBackgroundColor: panel2Bg.withValues(alpha: 0.50),
              dialTextColor: textColor,
              entryModeIconColor: gold,
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return gold.withValues(alpha: 0.22);
                }
                return panel2Bg.withValues(alpha: 0.45);
              }),
              hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return gold;
                }
                return textColor;
              }),
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return gold.withValues(alpha: 0.22);
                }
                return panel2Bg.withValues(alpha: 0.45);
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return gold;
                }
                return textSoftColor;
              }),
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(gold),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(textSoftColor),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool get _isTimingValid {
    if (_admitted != true) return true;
    return _timeToMinutes(_candidateStartTime) >=
        _timeToMinutes(_supervisionTime);
  }

  Future<void> _selectSupervisionTime() async {
    final picked = await _showLateArrivalThemedTimePicker(_supervisionTime);
    if (picked != null) {
      setState(() {
        _supervisionTime = picked;
        if (_admitted == true &&
            _timeToMinutes(_candidateStartTime) < _timeToMinutes(picked)) {
          _candidateStartTime = picked;
        }
      });
    }
  }

  Future<void> _selectCandidateStartTime() async {
    final picked = await _showLateArrivalThemedTimePicker(_candidateStartTime);
    if (!mounted) return;
    if (picked != null) {
      final isEarlier =
          _timeToMinutes(picked) < _timeToMinutes(_supervisionTime);
      setState(() => _candidateStartTime = picked);
      if (isEarlier) {
        await _showInvalidStartTimeAlert(picked);
      }
    }
  }

  Future<void> _showInvalidStartTimeAlert(TimeOfDay invalidTime) async {
    final isDark = _isDark;
    final panelColor = VigiloUiColors.panel(isDark);
    final lineColor = VigiloUiColors.line(isDark);
    final textColor = VigiloUiColors.text(isDark);
    final textSoftColor = VigiloUiColors.textSoft(isDark);
    final blueColor = VigiloUiColors.blue(isDark);
    final goldColor = VigiloUiColors.incidentLateArrival(isDark);
    final goldSoftColor = goldColor.withValues(alpha: 0.18);
    final buttonTextColor = VigiloUiColors.bg(isDark);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: lineColor.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
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
                      color: goldSoftColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: goldColor.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: goldColor,
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
                            'Invalid Start Time',
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
                            'Candidate actual start time (${_formatTime(invalidTime)}) cannot be earlier than supervision time (${_formatTime(_supervisionTime)}).',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFD2DCE8)
                                  : textSoftColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.42,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please select a start time at or after ${_formatTime(_supervisionTime)}.',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFAEBCCC)
                                  : textSoftColor.withValues(alpha: 0.8),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.42,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  AnimatedScaleOnPress(
                    child: SizedBox(
                      height: 58,
                      child: OutlinedButton(
                        onPressed: () {
                          ctx.safePop();
                          _selectCandidateStartTime();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          side: BorderSide(
                            color: lineColor.withValues(alpha: 0.85),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          'Pick Again',
                          style: TextStyle(
                            color: blueColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedScaleOnPress(
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _candidateStartTime = _supervisionTime;
                            });
                            ctx.safePop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: goldColor,
                            foregroundColor: buttonTextColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            'Use Supervision Time',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: buttonTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setAdmissionOutcome(bool value) {
    setState(() {
      _admitted = value;
      if (_admitted == true) {
        final now = TimeOfDay.now();
        if (_timeToMinutes(now) >= _timeToMinutes(_supervisionTime)) {
          _candidateStartTime = now;
        } else {
          _candidateStartTime = _supervisionTime;
        }
      }
    });
  }

  bool get _isFormValid {
    return _candidateController.text.trim().isNotEmpty &&
        _admitted != null &&
        _isTimingValid &&
        _reasonController.text.trim().isNotEmpty &&
        _actionsController.text.trim().isNotEmpty;
  }

  void _saveEntry() {
    if (_candidateController.text.trim().isEmpty) {
      NotificationService.show(
        context,
        title: "Required Field",
        subtitle: "Enter a candidate reference before logging.",
        icon: Icons.warning_amber_rounded,
        type: NotificationType.error,
      );
      return;
    }
    if (_admitted == null) {
      NotificationService.show(
        context,
        title: "Required Field",
        subtitle: "Select Admitted or Not Admitted before logging.",
        icon: Icons.warning_amber_rounded,
        type: NotificationType.error,
      );
      return;
    }
    if (_admitted == true && !_isTimingValid) {
      NotificationService.show(
        context,
        title: "Invalid Timing",
        subtitle:
            "Candidate actual start time must be at or after supervision time.",
        icon: Icons.warning_amber_rounded,
        type: NotificationType.error,
      );
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      NotificationService.show(
        context,
        title: "Required Field",
        subtitle: "Enter the reason for late arrival before logging.",
        icon: Icons.warning_amber_rounded,
        type: NotificationType.error,
      );
      return;
    }
    if (_actionsController.text.trim().isEmpty) {
      NotificationService.show(
        context,
        title: "Required Field",
        subtitle:
            "Record actions taken / security assurance before logging.",
        icon: Icons.warning_amber_rounded,
        type: NotificationType.error,
      );
      return;
    }

    widget.onSave(
      widget.initialRoom,
      _candidateController.text.trim(),
      _admitted!,
      _formatTime(_supervisionTime),
      _admitted == true ? _formatTime(_candidateStartTime) : '',
      _reasonController.text.trim(),
      _actionsController.text.trim(),
    );
  }

  Widget _otSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: VigiloUiColors.blueSoft(_isDark),
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _otFilledButton(String text, {VoidCallback? onTap}) {
    final disabled = onTap == null;
    return AnimatedScaleOnPress(
      isDisabled: disabled,
      child: SizedBox(
        height: 44,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: VigiloUiColors.incidentLateArrival(_isDark),
            disabledBackgroundColor: VigiloUiColors.incidentLateArrival(_isDark)
                .withValues(alpha: 0.45),
            foregroundColor: VigiloUiColors.bg(_isDark),
            disabledForegroundColor:
                VigiloUiColors.bg(_isDark).withValues(alpha: 0.6),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            elevation: disabled ? 0 : 2,
          ),
          onPressed: onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              softWrap: false,
              style: TextStyle(
                color: VigiloUiColors.bg(_isDark),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _otUtilityButton(String text, {required VoidCallback onTap}) {
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: VigiloUiColors.lineSoft(_isDark)),
            backgroundColor:
                VigiloUiColors.panel2(_isDark).withValues(alpha: 0.62),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VigiloUiColors.blackWhite(_isDark),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeField(
    String value,
    VoidCallback onTap, {
    bool isError = false,
  }) {
    final borderColor = isError
        ? VigiloUiColors.red(_isDark)
        : VigiloUiColors.lineSoft(_isDark);
    final iconColor = isError
        ? VigiloUiColors.red(_isDark)
        : VigiloUiColors.incidentLateArrival(_isDark);
    final textColor = isError
        ? VigiloUiColors.red(_isDark)
        : VigiloUiColors.text(_isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isError
              ? VigiloUiColors.red(_isDark).withValues(alpha: 0.10)
              : VigiloUiColors.panel2(_isDark).withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isError ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.edit_outlined,
              color: isError
                  ? VigiloUiColors.red(_isDark)
                  : VigiloUiColors.textSoft(_isDark),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _admissionToggleButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : VigiloUiColors.panel2(_isDark).withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : VigiloUiColors.lineSoft(_isDark),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : VigiloUiColors.textSoft(_isDark),
              fontSize: 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.88,
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VigiloUiColors.panel(_isDark),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: VigiloUiColors.line(_isDark)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 8, left: 8, right: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: VigiloUiColors.incidentLateArrival(_isDark)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    VigiloUiColors.incidentLateArrival(_isDark)
                                        .withValues(alpha: 0.70),
                                width: .7,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.schedule_rounded,
                              color: VigiloUiColors.incidentLateArrival(_isDark),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Late Arrival',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: VigiloUiColors.text(_isDark),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Record a late arrival',
                                  style: TextStyle(
                                    color: VigiloUiColors.textSoft(_isDark),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Tooltip(
                            message: 'Close',
                            child: InkWell(
                              onTap: () => context.safePop(),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: VigiloUiColors.panel2(_isDark),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: VigiloUiColors.lineSoft(_isDark),
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 24,
                                  color: VigiloUiColors.textSoft(_isDark),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _otSectionLabel('CANDIDATE REFERENCE'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: VigiloUiColors.panel2(_isDark)
                                    .withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: VigiloUiColors.lineSoft(_isDark),
                                ),
                              ),
                              child: TextField(
                                controller: _candidateController,
                                focusNode: _candidateFocus,
                                textInputAction: TextInputAction.next,
                                cursorColor:
                                    VigiloUiColors.incidentLateArrival(_isDark),
                                style: TextStyle(
                                  color: VigiloUiColors.text(_isDark),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'Enter candidate reference, e.g. CD341',
                                  hintStyle: TextStyle(
                                    color: VigiloUiColors.textSoft(_isDark)
                                        .withValues(alpha: 0.60),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _otSectionLabel(
                                'TIME CANDIDATE CAME UNDER STAFF SUPERVISION'),
                            const SizedBox(height: 10),
                            _timeField(
                              _formatTime(_supervisionTime),
                              _selectSupervisionTime,
                            ),
                            const SizedBox(height: 20),
                            _otSectionLabel('ADMITTED TO SIT THE EXAM?'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _admissionToggleButton(
                                    label: 'Admitted',
                                    selected: _admitted == true,
                                    color: VigiloUiColors.green(_isDark),
                                    onTap: () => _setAdmissionOutcome(true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _admissionToggleButton(
                                    label: 'Not Admitted',
                                    selected: _admitted == false,
                                    color: VigiloUiColors.red(_isDark),
                                    onTap: () => _setAdmissionOutcome(false),
                                  ),
                                ),
                              ],
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOutCubic,
                              child: _admitted == true
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 20),
                                        _otSectionLabel(
                                            'CANDIDATE ACTUAL START TIME'),
                                        const SizedBox(height: 10),
                                        _timeField(
                                          _formatTime(_candidateStartTime),
                                          _selectCandidateStartTime,
                                          isError: !_isTimingValid,
                                        ),
                                        if (!_isTimingValid) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: VigiloUiColors.red(_isDark)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: VigiloUiColors.red(
                                                        _isDark)
                                                    .withValues(alpha: 0.45),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 18,
                                                  color: VigiloUiColors.red(
                                                      _isDark),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Actual start time (${_formatTime(_candidateStartTime)}) cannot be earlier than supervision time (${_formatTime(_supervisionTime)}).',
                                                    style: TextStyle(
                                                      color: VigiloUiColors.red(
                                                          _isDark),
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _candidateStartTime =
                                                          _supervisionTime;
                                                    });
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: VigiloUiColors.red(
                                                              _isDark)
                                                          .withValues(
                                                              alpha: 0.22),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      'Align Time',
                                                      style: TextStyle(
                                                        color:
                                                            VigiloUiColors.red(
                                                                _isDark),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 20),
                            _otSectionLabel('REASON FOR LATE ARRIVAL'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: VigiloUiColors.panel2(_isDark)
                                    .withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: VigiloUiColors.lineSoft(_isDark),
                                ),
                              ),
                              child: TextField(
                                controller: _reasonController,
                                focusNode: _reasonFocus,
                                textInputAction: TextInputAction.next,
                                minLines: 3,
                                maxLines: 5,
                                cursorColor:
                                    VigiloUiColors.incidentLateArrival(_isDark),
                                style: TextStyle(
                                  color: VigiloUiColors.text(_isDark),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'State the reason for the late arrival.',
                                  hintStyle: TextStyle(
                                    color: VigiloUiColors.textSoft(_isDark)
                                        .withValues(alpha: 0.60),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _otSectionLabel(
                                'ACTIONS TAKEN / SECURITY ASSURANCE'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: VigiloUiColors.panel2(_isDark)
                                    .withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: VigiloUiColors.lineSoft(_isDark),
                                ),
                              ),
                              child: TextField(
                                controller: _actionsController,
                                focusNode: _actionsFocus,
                                textInputAction: TextInputAction.done,
                                minLines: 3,
                                maxLines: 5,
                                cursorColor:
                                    VigiloUiColors.incidentLateArrival(_isDark),
                                style: TextStyle(
                                  color: VigiloUiColors.text(_isDark),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'Record supervision and any assurance given.',
                                  hintStyle: TextStyle(
                                    color: VigiloUiColors.textSoft(_isDark)
                                        .withValues(alpha: 0.60),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                      child: Row(
                        spacing: 10,
                        children: [
                          Expanded(
                            child: _otUtilityButton(
                              'Cancel',
                              onTap: () => context.safePop(),
                            ),
                          ),
                          Expanded(
                            child: _otFilledButton(
                              'Log Incident',
                              onTap: _isFormValid ? _saveEntry : null,
                            ),
                          ),
                        ],
                      ),
                    ),
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
