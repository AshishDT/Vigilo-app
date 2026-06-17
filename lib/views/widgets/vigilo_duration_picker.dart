import 'package:flutter/material.dart';
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

class VigiloDurationPickerSheet extends StatefulWidget {
  final String initialDuration;
  final String title;

  const VigiloDurationPickerSheet({
    super.key,
    required this.initialDuration,
    required this.title,
  });

  @override
  State<VigiloDurationPickerSheet> createState() => _VigiloDurationPickerSheetState();
}

class _VigiloDurationPickerSheetState extends State<VigiloDurationPickerSheet> {
  late int _hours;
  late int _minutes;
  late int _initialHours;
  late int _initialMinutes;

  @override
  void initState() {
    super.initState();
    final parsed = _parseHHMM(widget.initialDuration);
    _hours = parsed.$1;
    _minutes = parsed.$2;
    _initialHours = parsed.$1;
    _initialMinutes = parsed.$2;
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
    final selected = await showGridPicker(
      context: context,
      title: "Select Hours",
      values: List.generate(10, (i) => i),
      selectedVal: _hours,
      colors: colors,
    );
    if (selected != null) {
      setState(() {
        _hours = selected;
      });
    }
  }

  void _showMinutesMenu(BuildContext context) async {
    final colors = _PickerColors(context);
    final selected = await showGridPicker(
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PickerColors(context);
    final hourStr = _hours.toString();
    final minuteStr = _minutes.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    widget.title,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AnimatedScaleOnPress(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.lineSoft),
                            backgroundColor: colors.panel2.withValues(alpha: 0.62),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                            disabledBackgroundColor: colors.blue.withValues(
                              alpha: 0.45,
                            ),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            elevation: !_isChanged ? 0 : 2,
                          ),
                          onPressed: _isChanged
                              ? () {
                                  final result = "${_hours.toString().padLeft(2, '0')}:${_minutes.toString().padLeft(2, '0')}";
                                  Navigator.of(context).pop(result);
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
        border: Border.all(color: colors.lineSoft),
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
                border: Border.all(color: colors.lineSoft),
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

Future<int?> showGridPicker({
  required BuildContext context,
  required String title,
  required List<int> values,
  required int selectedVal,
  required _PickerColors colors,
  bool padLeft = false,
}) {
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
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
              color: colors.line.withOpacity(0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      final displayStr = padLeft ? val.toString().padLeft(2, '0') : val.toString();
                      return AnimatedScaleOnPress(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isSelected ? colors.blue : colors.panel2,
                            foregroundColor: isSelected ? Colors.white : colors.text,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? Colors.transparent : colors.lineSoft,
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
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
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
                    side: BorderSide(color: colors.lineSoft),
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
