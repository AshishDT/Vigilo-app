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

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
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

    setState(() {
      _selectedTime = TimeOfDay(
        hour: totalMinutes ~/ 60,
        minute: totalMinutes % 60,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PickerColors(context);
    final hourStr = _selectedTime.hour.toString().padLeft(2, '0');
    final minuteStr = _selectedTime.minute.toString().padLeft(2, '0');

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
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quick selection',
                        style: TextStyle(
                          color: Colors.grey,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.timeCardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.lineSoft),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Hours adjustment column
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.keyboard_arrow_up_rounded, color: colors.textSoft, size: 30),
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
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSoft, size: 30),
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
                            // Minutes adjustment column
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.keyboard_arrow_up_rounded, color: colors.textSoft, size: 30),
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
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSoft, size: 30),
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
              const SizedBox(height: 18),
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
      ),
    );
  }
}

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
