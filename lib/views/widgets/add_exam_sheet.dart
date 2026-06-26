import 'package:flutter/material.dart';
import '../../utils/constants.dart';

import 'vigilo_date_picker.dart';
import 'vigilo_time_picker.dart';
import 'vigilo_duration_picker.dart';
import 'animated_scale_on_press.dart';
import '../../utils/screen_util.dart';

class _SheetColors {
  final BuildContext context;
  _SheetColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get panel => VigiloUiColors.panel(isDark);
  Color get panel2 => isDark ? const Color(0xFF16314D) : const Color(0xFFF1F5F9);
  Color get line => VigiloUiColors.line(isDark);
  Color get lineSoft => VigiloUiColors.lineSoft(isDark);
  Color get text => VigiloUiColors.text(isDark);
  Color get textSoft => VigiloUiColors.textSoft(isDark);
  Color get textFaint => VigiloUiColors.textFaint(isDark);
  Color get blue => VigiloUiColors.blue(isDark);
  Color get blueSoft => VigiloUiColors.blueSoft(isDark);
  Color get blackWhite => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get inputBg => isDark ? const Color(0xFF0F2236) : const Color(0xFFF8FAFC);
}

class AddExamSheet extends StatefulWidget {
  const AddExamSheet({
    super.key,
    this.lastSchool,
    this.lastCentre,
    this.lastSubject,
    this.lastBoard,
    this.lastStart,
    this.lastDuration,
    this.lastExtra,
    this.knownCentres = const {},
    required this.onSave,
  });

  final String? lastSchool;
  final String? lastCentre;
  final String? lastSubject;
  final String? lastBoard;
  final String? lastStart;
  final String? lastDuration;
  final String? lastExtra;
  final Map<String, String> knownCentres;
  final Future<void> Function({
    required String school,
    required String centre,
    required String subject,
    required String board,
    required DateTime date,
    required String startTime,
    required String duration,
    required String extraTime,
  }) onSave;

  @override
  State<AddExamSheet> createState() => _AddExamSheetState();
}

class _AddExamSheetState extends State<AddExamSheet> {
  late final TextEditingController _schoolCtl;
  late final TextEditingController _centreCtl;
  late final TextEditingController _subjectCtl;
  late final TextEditingController _boardCtl;

  late final DraggableScrollableController _dragController;
  late final FocusNode _schoolFocus;
  late final FocusNode _centreFocus;
  late final FocusNode _subjectFocus;
  late final FocusNode _boardFocus;

  late DateTime _selectedDate;
  late String _startHHMM;
  late String _durationHHMM;
  late String _extraHHMM;

  @override
  void initState() {
    super.initState();
    _schoolCtl = TextEditingController(text: widget.lastSchool ?? "");
    _centreCtl = TextEditingController(text: widget.lastCentre ?? "");
    _subjectCtl = TextEditingController(text: widget.lastSubject ?? "");
    _boardCtl = TextEditingController(text: widget.lastBoard ?? "");
    _previousSchoolText = _schoolCtl.text.trim();

    if (_centreCtl.text.trim().isEmpty && _previousSchoolText.isNotEmpty) {
      debugPrint("[AddExamSheet] initState: _centreCtl is empty, checking if '$_previousSchoolText' is known...");
      final known = widget.knownCentres[_previousSchoolText];
      if (known != null && known.isNotEmpty) {
        _centreCtl.text = known;
        debugPrint("[AddExamSheet] initState: Auto-populated centre number with '$known'");
      } else {
        debugPrint("[AddExamSheet] initState: '$_previousSchoolText' not found in knownCentres.");
      }
    }

    _schoolCtl.addListener(_onSchoolTextChanged);
    _centreCtl.addListener(_onTextChanged);
    _subjectCtl.addListener(_onTextChanged);
    _boardCtl.addListener(_onTextChanged);

    _dragController = DraggableScrollableController();
    _schoolFocus = FocusNode();
    _centreFocus = FocusNode();
    _subjectFocus = FocusNode();
    _boardFocus = FocusNode();

    _schoolFocus.addListener(_onFocusChanged);
    _centreFocus.addListener(_onFocusChanged);
    _subjectFocus.addListener(_onFocusChanged);
    _boardFocus.addListener(_onFocusChanged);
    
    _selectedDate = DateTime.now();
    _startHHMM = _normalizeHHMM(widget.lastStart, fallback: "09:00");
    _durationHHMM = _normalizeHHMM(
      widget.lastDuration,
      fallback: "01:30",
      allowZero: false,
    );
    _extraHHMM = _normalizeHHMM(widget.lastExtra, fallback: "00:15");
  }

  String _previousSchoolText = "";

  void _onSchoolTextChanged() {
    final currentSchool = _schoolCtl.text.trim();
    if (currentSchool != _previousSchoolText) {
      debugPrint("[AddExamSheet] _onSchoolTextChanged: School changed from '$_previousSchoolText' to '$currentSchool'");
      _previousSchoolText = currentSchool;
      final known = widget.knownCentres[currentSchool];
      if (known != null && known.isNotEmpty) {
        _centreCtl.text = known;
        debugPrint("[AddExamSheet] _onSchoolTextChanged: Auto-populated centre number with '$known' for school '$currentSchool'");
      } else {
        debugPrint("[AddExamSheet] _onSchoolTextChanged: '$currentSchool' not found in knownCentres.");
      }
    }
    setState(() {});
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onFocusChanged() {
    if (_schoolFocus.hasFocus ||
        _centreFocus.hasFocus ||
        _subjectFocus.hasFocus ||
        _boardFocus.hasFocus) {
      if (_dragController.isAttached) {
        _dragController.animateTo(
          0.95,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  bool _isValidToSave() {
    return _schoolCtl.text.trim().isNotEmpty &&
        _centreCtl.text.trim().isNotEmpty &&
        _subjectCtl.text.trim().isNotEmpty &&
        _boardCtl.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _schoolCtl.removeListener(_onSchoolTextChanged);
    _centreCtl.removeListener(_onTextChanged);
    _subjectCtl.removeListener(_onTextChanged);
    _boardCtl.removeListener(_onTextChanged);

    _schoolFocus.removeListener(_onFocusChanged);
    _centreFocus.removeListener(_onFocusChanged);
    _subjectFocus.removeListener(_onFocusChanged);
    _boardFocus.removeListener(_onFocusChanged);

    _schoolFocus.dispose();
    _centreFocus.dispose();
    _subjectFocus.dispose();
    _boardFocus.dispose();
    _dragController.dispose();

    _schoolCtl.dispose();
    _centreCtl.dispose();
    _subjectCtl.dispose();
    _boardCtl.dispose();
    super.dispose();
  }

  String _normalizeHHMM(
    String? value, {
    required String fallback,
    bool allowZero = true,
  }) {
    final raw = (value ?? '').trim();
    if (_isValidHHMM(raw, allowZero: allowZero)) {
      return raw;
    }
    return fallback;
  }

  bool _isValidHHMM(String value, {bool allowZero = true}) {
    final p = value.split(':');
    if (p.length != 2) return false;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return false;
    if (h < 0 || h > 23) return false;
    if (m < 0 || m > 59) return false;
    if (!allowZero && h == 0 && m == 0) return false;
    return true;
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString()}";

  (int, int) _parseHHMM(String s) {
    final p = s.split(':');
    return ((int.tryParse(p[0]) ?? 0), (int.tryParse(p[1]) ?? 0));
  }

  Future<void> _pickStart() async {
    final t = _parseHHMM(_startHHMM);
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => VigiloTimePickerSheet(
        initialTime: TimeOfDay(hour: t.$1, minute: t.$2),
        showIcons: true,
      ),
    );
    if (picked != null) {
      setState(() {
        _startHHMM =
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => VigiloDatePickerSheet(
        initialDate: _selectedDate,
        showIcons: true,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<String> _pickDur(String time, String title) async {
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => VigiloDurationPickerSheet(
        initialDuration: time,
        title: title,
        showIcons: true,
      ),
    );
    return res ?? "";
  }

  Future<void> _pickDuration() async {
    final res = await _pickDur(_durationHHMM, "Set Duration");
    if (res.isNotEmpty) {
      setState(() {
        _durationHHMM = res;
      });
    }
  }

  Future<void> _pickExtra() async {
    final res = await _pickDur(_extraHHMM, "Add Extra Time");
    if (res.isNotEmpty) {
      setState(() {
        _extraHHMM = res;
      });
    }
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colors = _SheetColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.line),
                ),
                child: Icon(icon, color: colors.blueSoft, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _formLabel(String text) {
    final colors = _SheetColors(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          text,
          style: TextStyle(
            color: colors.textSoft,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required FocusNode focusNode,
  }) {
    final colors = _SheetColors(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: TextStyle(
        color: colors.text,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: colors.textFaint,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: colors.inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.blue, width: 1.4),
        ),
      ),
    );
  }

  Widget _tapTimingField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = _SheetColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: colors.inputBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.blackWhite, size: 20.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.textSoft,
              size: 20.r,
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final colors = _SheetColors(context);
    return AnimatedScaleOnPress(
      isDisabled: onTap == null,
      child: SizedBox(
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.blue,
            disabledBackgroundColor: colors.blue.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: onTap == null ? 0 : 2,
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = _SheetColors(context);
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colors.blue, width: 1.5),
            foregroundColor: colors.blue,
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: colors.blue),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    final colors = _SheetColors(context);
    final realViewInsets = MediaQuery.of(context).viewInsets;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: DraggableScrollableSheet(
        controller: _dragController,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colors.panel.withValues(alpha: 0.985),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _SheetBorderPainter(
                color: colors.line,
                radius: 32,
              ),
              child: Column(
              children: [
                // Pinned Header & Drag Handle
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: (details) {
                    if (_dragController.isAttached) {
                      final delta = details.primaryDelta ?? 0;
                      final screenHeight = MediaQuery.of(context).size.height;
                      if (screenHeight > 0) {
                        final newSize = _dragController.size - (delta / screenHeight);
                        _dragController.jumpTo(newSize.clamp(0.4, 0.95));
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
                    decoration: BoxDecoration(
                      color: colors.panel.withValues(alpha: 0.985),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.lineSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'Add Exam',
                              style: TextStyle(
                               color: colors.text,
                               fontSize: 22,
                               fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Tooltip(
                              message: 'Close',
                              child: InkWell(
                                onTap: () => Navigator.pop(context, false),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: colors.panel2,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: colors.lineSoft,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 24,
                                    color: colors.textSoft,
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      15.h,
                      16.w,
                      18.h + realViewInsets.bottom,
                    ),
                    child: Column(
                      children: [
                        _sectionCard(
                          title: 'Exam Details',
                          icon: Icons.library_books_rounded,
                          child: Column(
                            children: [
                              _formLabel('Exam Subject'),
                              _textField(
                                controller: _subjectCtl,
                                hint: 'Enter exam subject',
                                focusNode: _subjectFocus,
                              ),
                              const SizedBox(height: 14),
                              _formLabel('Exam Board'),
                              _textField(
                                controller: _boardCtl,
                                hint: 'OCR, AQA, Edexcel',
                                focusNode: _boardFocus,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Organisation',
                          icon: Icons.apartment_rounded,
                          child: Column(
                            children: [
                              _formLabel('Organisation Name'),
                              _textField(
                                controller: _schoolCtl,
                                hint: 'Enter organisation name',
                                focusNode: _schoolFocus,
                              ),
                              const SizedBox(height: 14),
                              _formLabel('Centre Number'),
                              _textField(
                                controller: _centreCtl,
                                hint: 'Enter centre number',
                                focusNode: _centreFocus,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Timing',
                          icon: Icons.schedule_rounded,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _tapTimingField(
                                      label: 'Date',
                                      value: _fmtDate(_selectedDate),
                                      icon: Icons.calendar_month_outlined,
                                      onTap: _pickDate,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: _tapTimingField(
                                      label: 'Start Time',
                                      value: _startHHMM,
                                      icon: Icons.access_time_rounded,
                                      onTap: _pickStart,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: _tapTimingField(
                                      label: 'Duration',
                                      value: _durationHHMM,
                                      icon: Icons.timer_outlined,
                                      onTap: _pickDuration,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: _tapTimingField(
                                      label: 'Extra Time',
                                      value: _extraHHMM,
                                      icon: Icons.more_time_rounded,
                                      onTap: _pickExtra,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _secondaryButton(
                          label: 'Cancel',
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _primaryButton(
                          label: 'Save',
                          icon: Icons.check_rounded,
                          onTap: _isValidToSave()
                              ? () async {
                                  final school = _schoolCtl.text.trim();
                                  final centre = _centreCtl.text.trim();
                                  final subj = _subjectCtl.text.trim();
                                  final board = _boardCtl.text.trim();
 
                                  await widget.onSave(
                                    school: school,
                                    centre: centre,
                                    subject: subj,
                                    board: board,
                                    date: _selectedDate,
                                    startTime: _startHHMM,
                                    duration: _durationHHMM,
                                    extraTime: _extraHHMM,
                                  );
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }
}

class _SheetBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double width;

  _SheetBorderPainter({
    required this.color,
    required this.radius,
    this.width = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, radius)
      ..arcToPoint(
        Offset(radius, 0),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SheetBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.width != width;
  }
}


