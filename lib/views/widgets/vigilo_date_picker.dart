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
  late final DateTime _minDate;
  late DateTime _maxDate;

  bool _showManualEntry = false;
  late final TextEditingController _manualController;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minDate = DateTime(now.year, now.month, now.day);
    _maxDate = DateTime(now.year + 2, 12, 31);

    var initial = widget.initialDate;
    if (initial.isBefore(_minDate)) {
      initial = _minDate;
    } else if (initial.isAfter(_maxDate)) {
      initial = _maxDate;
    }
    _selectedDate = initial;
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _manualController = TextEditingController(text: _formatDate(_selectedDate));
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
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

  bool get _canPrevMonth {
    final prev = _currentMonth.month == 1
        ? DateTime(_currentMonth.year - 1, 12)
        : DateTime(_currentMonth.year, _currentMonth.month - 1);
    final minMonth = DateTime(_minDate.year, _minDate.month);
    return !prev.isBefore(minMonth);
  }

  bool get _canNextMonth {
    final next = _currentMonth.month == 12
        ? DateTime(_currentMonth.year + 1, 1)
        : DateTime(_currentMonth.year, _currentMonth.month + 1);
    final maxMonth = DateTime(_maxDate.year, _maxDate.month);
    return !next.isAfter(maxMonth);
  }

  void _prevMonth() {
    if (!_canPrevMonth) return;
    setState(() {
      if (_currentMonth.month == 1) {
        _currentMonth = DateTime(_currentMonth.year - 1, 12);
      } else {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      }
    });
  }

  void _nextMonth() {
    if (!_canNextMonth) return;
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
    final int currentYear = _minDate.year;
    
    // Show current and 5 future years (total 6 years).
    // If the manually typed year is even further, extend list to include it.
    final int maxYearToShow = _selectedDate.year > currentYear + 5 ? _selectedDate.year : currentYear + 5;
    final int count = maxYearToShow - currentYear + 1;
    final List<int> years = List.generate(count, (i) => currentYear + i);

    final selectedYear = await _showYearGridPicker(
      context: context,
      title: "Select Year",
      values: years,
      selectedVal: _currentMonth.year,
      colors: colors,
    );

    if (selectedYear != null) {
      setState(() {
        int newMonth = _currentMonth.month;
        final targetMonth = DateTime(selectedYear, newMonth);
        final minMonth = DateTime(_minDate.year, _minDate.month);

        if (selectedYear > _maxDate.year) {
          _maxDate = DateTime(selectedYear, 12, 31);
        }
        final maxMonth = DateTime(_maxDate.year, _maxDate.month);

        if (targetMonth.isBefore(minMonth)) {
          newMonth = _minDate.month;
        } else if (targetMonth.isAfter(maxMonth)) {
          newMonth = _maxDate.month;
        }

        _currentMonth = DateTime(selectedYear, newMonth);
        final maxDays = _daysInMonth(selectedYear, _selectedDate.month);
        final newDay = _selectedDate.day.clamp(1, maxDays);
        var newSelectedDate = DateTime(selectedYear, _selectedDate.month, newDay);

        if (newSelectedDate.isBefore(_minDate)) {
          newSelectedDate = _minDate;
        } else if (newSelectedDate.isAfter(_maxDate)) {
          newSelectedDate = _maxDate;
        }
        _selectedDate = newSelectedDate;
        _manualController.text = _formatDate(_selectedDate);
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
      final dayDate = DateTime(_currentMonth.year, _currentMonth.month, d);
      final isBeforeToday = dayDate.isBefore(_minDate);
      final isAfterMax = dayDate.isAfter(_maxDate);
      final isDisabled = isBeforeToday || isAfterMax;

      final isSelected = _selectedDate.year == _currentMonth.year &&
          _selectedDate.month == _currentMonth.month &&
          _selectedDate.day == d;

      dayWidgets.add(
        GestureDetector(
          onTap: isDisabled
              ? null
              : () {
                  setState(() {
                    _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, d);
                    _manualController.text = _formatDate(_selectedDate);
                  });
                },
          child: isSelected
              ? _SelectedDayChip('$d', colors)
              : _DayChip('$d', colors, isDisabled: isDisabled),
        ),
      );
    }

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
            // Pinned Header
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
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                      onTap: _canPrevMonth ? _prevMonth : null,
                                      child: Icon(
                                        Icons.chevron_left,
                                        color: _canPrevMonth ? colors.textSoft : colors.textSoft.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _canNextMonth ? _nextMonth : null,
                                      child: Icon(
                                        Icons.chevron_right,
                                        color: _canNextMonth ? colors.textSoft : colors.textSoft.withValues(alpha: 0.3),
                                      ),
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
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'DD/MM/YYYY',
                                        hintStyle: TextStyle(
                                            color: colors.textSoft.withValues(alpha: 0.5)),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (value) {
                                        final parts = value.split('/');
                                        if (parts.length == 3) {
                                          final day = int.tryParse(parts[0]);
                                          final month = int.tryParse(parts[1]);
                                          final year = int.tryParse(parts[2]);
                                          if (day != null && month != null && year != null) {
                                            try {
                                              final parsed = DateTime(year, month, day);
                                              if (parsed.day == day &&
                                                  parsed.month == month &&
                                                  parsed.year == year) {
                                                if (!parsed.isBefore(_minDate) && parsed.year < 3000) {
                                                  setState(() {
                                                    _selectedDate = parsed;
                                                    _currentMonth =
                                                        DateTime(parsed.year, parsed.month);
                                                    if (parsed.isAfter(_maxDate)) {
                                                      _maxDate = DateTime(parsed.year, 12, 31);
                                                    }
                                                  });
                                                }
                                              }
                                            } catch (_) {}
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
            const SizedBox(height: 18),
            // Pinned Bottom Actions
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
  final bool isDisabled;
  const _DayChip(this.text, this.colors, {this.isDisabled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isDisabled ? colors.textSoft.withValues(alpha: 0.35) : colors.text,
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

Future<int?> _showYearGridPicker({
  required BuildContext context,
  required String title,
  required List<int> values,
  required int selectedVal,
  required _PickerColors colors,
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
                            val.toString(),
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
