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
  Color get calendarBg =>
      isDark ? const Color(0xFF0F2236) : const Color(0xFFF8FAFC);
}

class VigiloDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;

  const VigiloDatePickerSheet({
    super.key,
    required this.initialDate,
  });

  @override
  State<VigiloDatePickerSheet> createState() => _VigiloDatePickerSheetState();
}

class _VigiloDatePickerSheetState extends State<VigiloDatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool get _isChanged {
    return _selectedDate.year != widget.initialDate.year ||
        _selectedDate.month != widget.initialDate.month ||
        _selectedDate.day != widget.initialDate.day;
  }

  int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  int _firstWeekdayOfMonth(int year, int month) {
    final dateTime = DateTime(year, month, 1);
    return dateTime.weekday % 7; // Sunday is 0, Monday is 1, ..., Saturday is 6
  }

  void _prevMonth() {
    setState(() {
      if (_currentMonth.month == 1) {
        _currentMonth = DateTime(_currentMonth.year - 1, 12);
      } else {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth.month == 12) {
        _currentMonth = DateTime(_currentMonth.year + 1, 1);
      } else {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      }
    });
  }

  void _showYearPickerMenu(BuildContext context) async {
    final colors = _PickerColors(context);
    final int currentYear = DateTime.now().year;
    final List<int> years = List.generate(16, (i) => currentYear - 5 + i);

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final selectedYear = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + 80,
        position.dx + size.width,
        position.dy + 400,
      ),
      color: colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.lineSoft),
      ),
      items: years.map((year) {
        final isSelected = year == _currentMonth.year;
        return PopupMenuItem<int>(
          value: year,
          child: Text(
            year.toString(),
            style: TextStyle(
              color: isSelected ? colors.blue : colors.text,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );

    if (selectedYear != null) {
      setState(() {
        _currentMonth = DateTime(selectedYear, _currentMonth.month);
        final maxDays = _daysInMonth(selectedYear, _selectedDate.month);
        final newDay = _selectedDate.day.clamp(1, maxDays);
        _selectedDate = DateTime(selectedYear, _selectedDate.month, newDay);
      });
    }
  }

  String _formatSelectedDate(DateTime date) {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final monthsShort = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayName = daysOfWeek[date.weekday % 7];
    final monthName = monthsShort[date.month - 1];
    return "$dayName, $monthName ${date.day}";
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PickerColors(context);
    final int daysCount = _daysInMonth(_currentMonth.year, _currentMonth.month);
    final int startOffset = _firstWeekdayOfMonth(_currentMonth.year, _currentMonth.month);

    final List<Widget> dayWidgets = [];

    for (int i = 0; i < startOffset; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

    for (int d = 1; d <= daysCount; d++) {
      final isSelected = _selectedDate.year == _currentMonth.year &&
          _selectedDate.month == _currentMonth.month &&
          _selectedDate.day == d;

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, d);
            });
          },
          child: isSelected ? _SelectedDayChip('$d', colors) : _DayChip('$d', colors),
        ),
      );
    }

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
                    'Select Date',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected date',
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatSelectedDate(_selectedDate),
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.calendarBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.lineSoft),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showYearPickerMenu(context),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_months[_currentMonth.month - 1]} ${_currentMonth.year}',
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: colors.textSoft,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _prevMonth,
                                child: Icon(Icons.chevron_left, color: colors.textSoft),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _nextMonth,
                                child: Icon(Icons.chevron_right, color: colors.textSoft),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _WeekLabel('S', colors),
                              _WeekLabel('M', colors),
                              _WeekLabel('T', colors),
                              _WeekLabel('W', colors),
                              _WeekLabel('T', colors),
                              _WeekLabel('F', colors),
                              _WeekLabel('S', colors),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 7,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                            children: dayWidgets,
                          ),
                        ],
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
                                  Navigator.of(context).pop(_selectedDate);
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

class _WeekLabel extends StatelessWidget {
  final String text;
  final _PickerColors colors;
  const _WeekLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: colors.textSoft,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String text;
  final _PickerColors colors;
  const _DayChip(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SelectedDayChip extends StatelessWidget {
  final String text;
  final _PickerColors colors;
  const _SelectedDayChip(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
