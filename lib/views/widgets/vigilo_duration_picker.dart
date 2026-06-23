import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';
import 'animated_scale_on_press.dart';

class _PickerColors {
  final BuildContext context;

  _PickerColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get panel => VigiloUiColors.panel(isDark);

  Color get panel2 => isDark ? const Color(0xFF16314D) : const Color(0xFFF1F5F9);

  Color get line => VigiloUiColors.line(isDark);

  Color get lineSoft => VigiloUiColors.lineSoft(isDark);

  Color get text => VigiloUiColors.text(isDark);

  Color get textSoft => VigiloUiColors.textSoft(isDark);

  Color get blue => VigiloUiColors.blue(isDark);

  Color get blackWhite => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  Color get timeCardBg => isDark ? const Color(0xFF0F2236) : const Color(0xFFF8FAFC);
}

class VigiloDurationPickerSheet extends StatefulWidget {
  final String initialDuration;
  final String title;
  final bool showIcons;

  const VigiloDurationPickerSheet({
    super.key,
    required this.initialDuration,
    required this.title,
    this.showIcons = false,
  });

  @override
  State<VigiloDurationPickerSheet> createState() =>
      _VigiloDurationPickerSheetState();
}

class _VigiloDurationPickerSheetState extends State<VigiloDurationPickerSheet> {
  late int _hours;
  late int _minutes;
  late int _initialHours;
  late int _initialMinutes;

  bool _showManualEntry = false;
  late final TextEditingController _manualController;

  @override
  void initState() {
    super.initState();
    final parsed = _parseHHMM(widget.initialDuration);
    _hours = parsed.$1;
    _minutes = parsed.$2;
    _initialHours = parsed.$1;
    _initialMinutes = parsed.$2;
    _manualController = TextEditingController(text: _formatDuration(_hours, _minutes));
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  String _formatDuration(int hours, int minutes) {
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  (int, int) _parseHHMM(String val) {
    final parts = val.trim().split(':');
    if (parts.length < 2) return (0, 0);
    return (int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }

  bool get _isChanged {
    return _hours != _initialHours || _minutes != _initialMinutes;
  }

  void _showHoursMenu(BuildContext context) async {
    final colors = _PickerColors(context);
    final selected = await _showGridPicker(
      context: context,
      title: "Select Hours",
      values: List.generate(10, (i) => i),
      selectedVal: _hours,
      colors: colors,
    );
    if (selected != null) {
      setState(() {
        _hours = selected;
        _manualController.text = _formatDuration(_hours, _minutes);
      });
    }
  }

  void _showMinutesMenu(BuildContext context) async {
    final colors = _PickerColors(context);
    final selected = await _showGridPicker(
      context: context,
      title: "Select Minutes",
      values: List.generate(12, (i) => i * 5),
      selectedVal: _minutes,
      colors: colors,
      padLeft: true,
    );
    if (selected != null) {
      setState(() {
        _minutes = selected;
        _manualController.text = _formatDuration(_hours, _minutes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PickerColors(context);
    final hourStr = _hours.toString();
    final minuteStr = _minutes.toString().padLeft(2, '0');
    final keyboardDepth = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 60, 16, 16 + keyboardDepth),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: colors.line),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pinned Header
            Container(
              width: 68,
              height: 6,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (widget.showIcons) ...[
                  const Spacer(),
                  Icon(
                    Icons.tune_rounded,
                    color: colors.textSoft,
                    size: 22,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (cellCtx) => _ValueCard(
                              label: 'Hours',
                              value: hourStr,
                              colors: colors,
                              onTap: () => _showHoursMenu(cellCtx),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Builder(
                            builder: (cellCtx) => _ValueCard(
                              label: 'Minutes',
                              value: minuteStr,
                              colors: colors,
                              onTap: () => _showMinutesMenu(cellCtx),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                  border: Border.all(color: colors.line),
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
                                        _DurationInputFormatter(),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: 'HH:MM',
                                        hintStyle: TextStyle(
                                            color: colors.textSoft.withValues(alpha: 0.5)),
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
                                              hour <= 24 &&
                                              minute >= 0 &&
                                              minute <= 59) {
                                            setState(() {
                                              _hours = hour;
                                              _minutes = hour == 24 ? 0 : minute;
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
            // Pinned Bottom Actions
            Row(
              children: [
                Expanded(
                  child: AnimatedScaleOnPress(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.blue, width: 1.5),
                          foregroundColor: colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.showIcons) ...[
                                Icon(Icons.close_rounded, size: 18, color: colors.blue),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                'Cancel',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedScaleOnPress(
                    isDisabled: !_isChanged,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.blue,
                          disabledBackgroundColor: colors.blue.withValues(
                            alpha: 0.45,
                          ),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: colors.blackWhite.withValues(
                            alpha: 0.6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: !_isChanged ? 0 : 2,
                        ),
                        onPressed: _isChanged
                            ? () {
                                final result =
                                    "${_hours.toString().padLeft(2, '0')}:${_minutes.toString().padLeft(2, '0')}";
                                Navigator.of(context).pop(result);
                              }
                            : null,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.showIcons) ...[
                                const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                'Save',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
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

class _ValueCard extends StatelessWidget {
  final String label;
  final String value;
  final _PickerColors colors;
  final VoidCallback onTap;

  const _ValueCard({
    required this.label,
    required this.value,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.panel2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: colors.timeCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.line),
              ),
              child: Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: colors.textSoft, size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<int?> _showGridPicker({
  required BuildContext context,
  required String title,
  required List<int> values,
  required int selectedVal,
  required _PickerColors colors,
  bool padLeft = false,
}) {
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: colors.line.withValues(alpha: 0.9),
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
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.6,
                        ),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: values.length,
                    itemBuilder: (context, index) {
                      final val = values[index];
                      final isSelected = val == selectedVal;
                      final displayStr = padLeft
                          ? val.toString().padLeft(2, '0')
                          : val.toString();
                      return AnimatedScaleOnPress(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isSelected
                                ? colors.blue
                                : colors.panel2,
                            foregroundColor: isSelected
                                ? Colors.white
                                : colors.text,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : colors.line,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(val);
                          },
                          child: Text(
                            displayStr,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.line),
                    backgroundColor: colors.panel2.withValues(alpha: 0.62),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: colors.blackWhite,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DurationInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;

    // Handle backspace or empty input smoothly
    if (newText.isEmpty) {
      return newValue;
    }

    // Limit to maximum 4 digits (HHMM) — digitsOnly runs before this
    if (newText.length > 4) {
      newText = newText.substring(0, 4);
    }

    String formattedText;
    int selectionIndex = newValue.selection.end;

    // Build the formatted string based on length
    if (newText.length <= 2) {
      formattedText = newText;
    } else {
      // Splits into HH and MM and inserts the colon
      formattedText = '${newText.substring(0, 2)}:${newText.substring(2)}';

      // Always shift cursor past the colon if it's in the MM region.
      // digitsOnly strips the colon so selectionIndex is in digit-space;
      // we need to add 1 to map it back into formatted-string space.
      if (selectionIndex > 2) {
        selectionIndex++;
      }
    }

    // Ensure cursor doesn't overshoot the length of the text
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

