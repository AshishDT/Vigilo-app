import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'animated_scale_on_press.dart';

class _PickerColors {
  final BuildContext context;
  _PickerColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get panel =>
      isDark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);
  Color get panel2 =>
      isDark ? const Color(0xFF16314D) : const Color(0xFFF1F5F9);
  Color get line => isDark ? const Color(0xFF294867) : const Color(0xFFE2E8F0);
  Color get lineSoft =>
      isDark ? const Color(0xFF395B7D) : const Color(0xFFCBD5E1);
  Color get text => isDark ? const Color(0xFFF3F7FC) : const Color(0xFF0B253A);
  Color get textSoft =>
      isDark ? const Color(0xFFB6C7D8) : const Color(0xFF475569);
  Color get blue => isDark ? const Color(0xFF4B86F8) : const Color(0xFF2563EB);
  Color get blackWhite =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get timeCardBg =>
      isDark ? const Color(0xFF0F2236) : const Color(0xFFF8FAFC);
}

class VigiloTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;

  const VigiloTimePickerSheet({
    super.key,
    required this.initialTime,
  });

  @override
  State<VigiloTimePickerSheet> createState() => _VigiloTimePickerSheetState();
}

class _VigiloTimePickerSheetState extends State<VigiloTimePickerSheet> {
  late TimeOfDay _selectedTime;

  bool _showManualEntry = false;
  late final TextEditingController _manualController;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
    _manualController = TextEditingController(
      text: _formatTime(_selectedTime),
    );
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  bool get _isChanged {
    return _selectedTime.hour != widget.initialTime.hour ||
        _selectedTime.minute != widget.initialTime.minute;
  }

  void _adjustTime(int hoursDelta, int minutesDelta) {
    int totalMinutes = _selectedTime.hour * 60 + _selectedTime.minute;
    totalMinutes += hoursDelta * 60 + minutesDelta;

    // Wrap around 24 hours (1440 minutes)
    if (totalMinutes < 0) {
      totalMinutes = 1440 + (totalMinutes % 1440);
    }
    totalMinutes = totalMinutes % 1440;

    final newTime = TimeOfDay(
      hour: totalMinutes ~/ 60,
      minute: totalMinutes % 60,
    );

    setState(() {
      _selectedTime = newTime;
      _manualController.text = _formatTime(newTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PickerColors(context);
    final hourStr = _selectedTime.hour.toString().padLeft(2, '0');
    final minuteStr = _selectedTime.minute.toString().padLeft(2, '0');
    final keyboardDepth = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + keyboardDepth),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        border: Border.all(
          color: colors.lineSoft.withValues(alpha: 0.55),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pinned Header ──────────────────────────────────────
            Container(
              width: 70,
              height: 5,
              decoration: BoxDecoration(
                color: colors.lineSoft,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Select Time',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Scrollable Body ────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick-selection + spinner card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: colors.panel2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.lineSoft),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Quick selection',
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickBtn(
                                  label: '-1h',
                                  onTap: () => _adjustTime(-1, 0),
                                  colors: colors,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuickBtn(
                                  label: '-5m',
                                  onTap: () => _adjustTime(0, -5),
                                  colors: colors,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuickBtn(
                                  label: '+5m',
                                  onTap: () => _adjustTime(0, 5),
                                  colors: colors,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuickBtn(
                                  label: '+1h',
                                  onTap: () => _adjustTime(1, 0),
                                  colors: colors,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: colors.timeCardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.lineSoft),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Hours column
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.keyboard_arrow_up_rounded,
                                          color: colors.textSoft,
                                          size: 30,
                                        ),
                                        onPressed: () => _adjustTime(1, 0),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Text(
                                        hourStr,
                                        style: TextStyle(
                                          color: colors.text,
                                          fontSize: 44,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: colors.textSoft,
                                          size: 30,
                                        ),
                                        onPressed: () => _adjustTime(-1, 0),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    ':',
                                    style: TextStyle(
                                      color: colors.text,
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Minutes column
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.keyboard_arrow_up_rounded,
                                          color: colors.textSoft,
                                          size: 30,
                                        ),
                                        onPressed: () => _adjustTime(0, 1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Text(
                                        minuteStr,
                                        style: TextStyle(
                                          color: colors.text,
                                          fontSize: 44,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: colors.textSoft,
                                          size: 30,
                                        ),
                                        onPressed: () => _adjustTime(0, -1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Type manually toggle
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          setState(() {
                            _showManualEntry = !_showManualEntry;
                          });
                        },
                        child: Text(
                          _showManualEntry ? 'Hide manual entry' : 'Type manually',
                          style: TextStyle(
                            color: colors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    // Animated manual entry field
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _showManualEntry
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                decoration: BoxDecoration(
                                  color: colors.panel2,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: colors.lineSoft),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Manual entry',
                                      style: TextStyle(
                                        color: colors.textSoft,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _manualController,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        _TimeInputFormatter(),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: 'HH:MM',
                                        hintStyle: TextStyle(
                                          color: colors.textSoft
                                              .withValues(alpha: 0.5),
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (value) {
                                        final parts = value.split(':');
                                        if (parts.length == 2) {
                                          final hour = int.tryParse(parts[0]);
                                          final minute = int.tryParse(parts[1]);
                                          if (hour != null &&
                                              minute != null &&
                                              hour >= 0 &&
                                              hour <= 23 &&
                                              minute >= 0 &&
                                              minute <= 59) {
                                            setState(() {
                                              _selectedTime = TimeOfDay(
                                                hour: hour,
                                                minute: minute,
                                              );
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Pinned Footer ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: AnimatedScaleOnPress(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.lineSoft),
                          backgroundColor:
                              colors.panel2.withValues(alpha: 0.62),
                          shape: const StadiumBorder(),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Cancel',
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.blackWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedScaleOnPress(
                    isDisabled: !_isChanged,
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.blue,
                          disabledBackgroundColor:
                              colors.blue.withValues(alpha: 0.45),
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.6),
                          shape: const StadiumBorder(),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          elevation: !_isChanged ? 0 : 2,
                        ),
                        onPressed: _isChanged
                            ? () {
                                Navigator.of(context).pop(_selectedTime);
                              }
                            : null,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Save',
                            textAlign: TextAlign.center,
                            softWrap: false,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
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
    );
  }
}

// ─── Quick-adjustment button ───────────────────────────────────────────────────

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _PickerColors colors;

  const _QuickBtn({
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 40,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colors.lineSoft),
            foregroundColor: colors.text,
            backgroundColor: colors.timeCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          onPressed: onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Strict HH:MM input formatter ─────────────────────────────────────────────
// FilteringTextInputFormatter.digitsOnly must run BEFORE this formatter so
// newValue.text is always digit-only (no colon). This formatter then:
//   • limits to 4 digits
//   • inserts ":" after position 2
//   • correctly maps the cursor from digit-space to formatted-string space

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;

    // Empty — pass through so backspace clears freely
    if (newText.isEmpty) {
      return newValue;
    }

    // Cap at 4 digits (digitsOnly already stripped non-digits)
    if (newText.length > 4) {
      newText = newText.substring(0, 4);
    }

    String formattedText;
    int selectionIndex = newValue.selection.end;

    if (newText.length <= 2) {
      // "1" or "12" — no colon yet
      formattedText = newText;
    } else {
      // "123" → "12:3"  |  "1234" → "12:34"
      formattedText = '${newText.substring(0, 2)}:${newText.substring(2)}';

      // digitsOnly strips the colon, so selectionIndex is in digit-space.
      // Add 1 to jump past the colon whenever the cursor is in the MM region.
      if (selectionIndex > 2) {
        selectionIndex++;
      }
    }

    // Guard: cursor must not overshoot
    if (selectionIndex > formattedText.length) {
      selectionIndex = formattedText.length;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: selectionIndex),
      composing: TextRange.empty,
    );
  }
}
