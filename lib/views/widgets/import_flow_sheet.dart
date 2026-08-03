import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/exam_card_data.dart';
import '../../services/import_service.dart';
import '../../services/license_service.dart';
import '../../utils/constants.dart';
import '../../utils/id_generator.dart';
import '../../utils/notifications.dart';

// Helper for UI styling and color retrieval matching the rest of the app
class _FlowColors {
  final BuildContext context;

  _FlowColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bg => VigiloUiColors.bg(isDark);

  Color get panel => VigiloUiColors.panel(isDark);

  Color get panel2 => VigiloUiColors.panel2(isDark);

  Color get panel3 => VigiloUiColors.panel3(isDark);

  Color get line => VigiloUiColors.line(isDark);

  Color get lineSoft => VigiloUiColors.lineSoft(isDark);

  Color get text => VigiloUiColors.text(isDark);

  Color get textSoft => VigiloUiColors.textSoft(isDark);

  Color get textFaint => VigiloUiColors.textFaint(isDark);

  Color get blue => VigiloUiColors.blue(isDark);

  Color get blueSoft => VigiloUiColors.blueSoft(isDark);

  Color get green => VigiloUiColors.green(isDark);

  Color get amber => VigiloUiColors.amber(isDark);

  Color get red => VigiloUiColors.red(isDark);
}

class ImportFlowSheet extends StatefulWidget {
  const ImportFlowSheet({
    super.key,
    required this.dark,
    required this.onToggleTheme,
    required this.initialCentreNumber,
    required this.onImportSessions,
    required this.onClose,
  });

  final bool dark;
  final VoidCallback onToggleTheme;
  final String initialCentreNumber;
  final Future<void> Function(List<ExamCardData> newSessions) onImportSessions;
  final VoidCallback onClose;

  @override
  State<ImportFlowSheet> createState() => _ImportFlowSheetState();
}

class _ImportFlowSheetState extends State<ImportFlowSheet> {
  int _step = 0; // 0: File Picker, 1: Map Columns, 2: Preview, 3: Result
  String? _selectedFileName;
  List<String> _detectedHeaders = [];
  List<Map<String, dynamic>> _parsedRows = [];
  bool _isLoading = false;

  // Licence details
  String _orgName = '';
  String _orgCode = '';

  // Mapping keys configuration: vigilo Field Name -> target CSV header
  final Map<String, String?> _mappings = {
    'Exam Subject': null,
    'Exam Level': null,
    'Exam Board': null,
    'Date': null,
    'Start Time': null,
    'Duration': null,
    'Extra Time': null,
    'Room': null,
    'Notes': null,
  };



  bool _centreHasError = false;
  late final TextEditingController _centreController;

  // Final parsed sessions for preview
  List<_PreviewSession> _previewSessions = [];
  int _totalSessionsToCreate = 0;

  @override
  void initState() {
    super.initState();
    _centreController = TextEditingController(text: widget.initialCentreNumber);
    _centreController.addListener(_onCentreChanged);
    _loadLicenceAndMappings();
  }

  void _onCentreChanged() {
    if (_centreHasError) {
      setState(() {
        _centreHasError = false;
      });
    }
  }

  @override
  void dispose() {
    _centreController.removeListener(_onCentreChanged);
    _centreController.dispose();
    super.dispose();
  }

  Future<void> _loadLicenceAndMappings() async {
    final snapshot = await LicenseService.getSnapshot();
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _orgName = snapshot.organizationName ?? 'Harris Clapham Sixth Form';
      _orgCode = snapshot.organizationCode ?? 'AA';

      // Load saved mappings from SharedPreferences
      _mappings['Exam Subject'] = prefs.getString('vigilo_import_map_subject');
      _mappings['Exam Level'] = prefs.getString('vigilo_import_map_level');
      _mappings['Exam Board'] = prefs.getString('vigilo_import_map_board');
      _mappings['Date'] = prefs.getString('vigilo_import_map_date');
      _mappings['Start Time'] = prefs.getString('vigilo_import_map_start_time');
      _mappings['Duration'] = prefs.getString('vigilo_import_map_duration');
      _mappings['Extra Time'] = prefs.getString('vigilo_import_map_extra_time');
      _mappings['Room'] = prefs.getString('vigilo_import_map_room');
      _mappings['Notes'] = prefs.getString('vigilo_import_map_notes');
    });
  }

  Future<void> _saveMappings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vigilo_import_map_subject',
      _mappings['Exam Subject'] ?? '',
    );
    await prefs.setString(
      'vigilo_import_map_level',
      _mappings['Exam Level'] ?? '',
    );
    await prefs.setString(
      'vigilo_import_map_board',
      _mappings['Exam Board'] ?? '',
    );
    await prefs.setString('vigilo_import_map_date', _mappings['Date'] ?? '');
    await prefs.setString(
      'vigilo_import_map_start_time',
      _mappings['Start Time'] ?? '',
    );
    await prefs.setString(
      'vigilo_import_map_duration',
      _mappings['Duration'] ?? '',
    );
    await prefs.setString(
      'vigilo_import_map_extra_time',
      _mappings['Extra Time'] ?? '',
    );
    await prefs.setString('vigilo_import_map_room', _mappings['Room'] ?? '');
    await prefs.setString('vigilo_import_map_notes', _mappings['Notes'] ?? '');
  }

  Future<void> _pickFile() async {
    if (_centreController.text.trim().isEmpty) {
      setState(() {
        _centreHasError = true;
      });
      NotificationService.show(
        context,
        title: 'Missing Organisation Number',
        subtitle: 'Please enter your Organisation Number before selecting a file.',
        type: NotificationType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final path = result.files.single.path!;
      final name = result.files.single.name;

      final parseStart = DateTime.now();
      final parsed = await ImportService.parseFile(path);

      final elapsed = DateTime.now().difference(parseStart);
      final remaining = const Duration(milliseconds: 600) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      setState(() {
        _selectedFileName = name;
        _detectedHeaders = parsed.headers;
        _parsedRows = parsed.rows;
        _isLoading = false;

        // Auto mapping suggestion based on header similarity
        for (var key in _mappings.keys) {
          if (_mappings[key] == null || _mappings[key]!.isEmpty) {
            // Find match
            final match = _findMatchingHeader(key, _detectedHeaders);
            if (match != null) {
              _mappings[key] = match;
            }
          } else {
            // Validate if previously stored mapping still exists in detected headers
            if (!_detectedHeaders.contains(_mappings[key])) {
              final match = _findMatchingHeader(key, _detectedHeaders);
              _mappings[key] = match;
            }
          }
        }

        _step = 1; // Proceed to Step 2: Map Columns
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NotificationService.show(
          context,
          title: 'Import Error',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: NotificationType.error,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  String? _findMatchingHeader(String field, List<String> headers) {
    final lowerField = field
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '');
    for (var h in headers) {
      final cleanH = h.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
      if (cleanH == lowerField) return h;
      if (lowerField.contains(cleanH) || cleanH.contains(lowerField)) return h;
      // Common timetable mapping aliases
      if (field == 'Exam Subject' &&
          (cleanH == 'subject' || cleanH == 'title' || cleanH == 'examname')) {
        return h;
      }
      if (field == 'Exam Level' &&
          (cleanH == 'level' || cleanH == 'qual' || cleanH == 'qualification')) {
        return h;
      }
      if (field == 'Exam Board' &&
          (cleanH == 'board' || cleanH == 'examboard' || cleanH == 'boardname')) {
        return h;
      }
      if (field == 'Date' && (cleanH == 'examdate' || cleanH == 'date')) {
        return h;
      }
      if (field == 'Start Time' &&
          (cleanH == 'start' || cleanH == 'starttime' || cleanH == 'time')) {
        return h;
      }
      if (field == 'Duration' &&
          (cleanH == 'duration' || cleanH == 'length' || cleanH == 'len')) {
        return h;
      }
      if (field == 'Extra Time' &&
          (cleanH == 'extratime' || cleanH == 'extralen' || cleanH == 'et')) {
        return h;
      }
      if (field == 'Room' &&
          (cleanH == 'room' || cleanH == 'rooms' || cleanH == 'location')) {
        return h;
      }
      if (field == 'Notes' &&
          (cleanH == 'notes' || cleanH == 'comment' || cleanH == 'comments')) {
        return h;
      }
    }
    return null;
  }

  bool _isMappingValid() {
    return _mappings['Exam Subject'] != null &&
        _mappings['Exam Board'] != null &&
        _mappings['Date'] != null &&
        _mappings['Start Time'] != null &&
        _mappings['Duration'] != null;
  }

  void _generatePreview() {
    setState(() {
      _previewSessions.clear();
      _totalSessionsToCreate = 0;
    });

    final List<_PreviewSession> list = [];
    int totalCount = 0;

    for (int idx = 0; idx < _parsedRows.length; idx++) {
      final row = _parsedRows[idx];

      // Read mapped columns
      final rawSubject = _getMappedValue(row, 'Exam Subject');
      final rawLevel = _getMappedValue(row, 'Exam Level');
      final rawBoard = _getMappedValue(row, 'Exam Board');
      final rawDate = _getMappedValue(row, 'Date');
      final rawStartTime = _getMappedValue(row, 'Start Time');
      final rawDuration = _getMappedValue(row, 'Duration');
      final rawExtraTime = _getMappedValue(row, 'Extra Time');
      final rawRoom = _getMappedValue(row, 'Room');
      final rawNotes = _getMappedValue(row, 'Notes');

      // Validation
      final List<String> errors = [];
      if (rawSubject == null || rawSubject.isEmpty) {
        errors.add('Missing Exam Subject');
      }
      if (rawBoard == null || rawBoard.isEmpty) {
        errors.add('Missing Exam Board');
      }

      final date = rawDate != null
          ? ImportService.normalizeDate(rawDate)
          : null;
      if (date == null) errors.add('Invalid or missing Date ("$rawDate")');

      final startTime = rawStartTime != null
          ? ImportService.normalizeStartTime(rawStartTime)
          : null;
      if (startTime == null) {
        errors.add('Invalid or missing Start Time ("$rawStartTime")');
      }

      final duration = rawDuration != null
          ? ImportService.normalizeDuration(rawDuration)
          : null;
      if (duration == null) {
        errors.add('Invalid or missing Duration ("$rawDuration")');
      }

      // Optional fields normalization
      final level = rawLevel?.isNotEmpty == true ? rawLevel : null;
      final extraTime = rawExtraTime != null
          ? (ImportService.normalizeDuration(rawExtraTime) ?? '00:00')
          : '00:00';
      final notes = rawNotes ?? '';

      // Split rooms
      final rooms = ImportService.splitRooms(rawRoom);

      final session = _PreviewSession(
        rowIndex: idx + 1,
        subject: rawSubject ?? '',
        level: level,
        board: rawBoard ?? '',
        date: date ?? rawDate ?? '',
        startTime: startTime ?? rawStartTime ?? '',
        duration: duration ?? rawDuration ?? '',
        extraTime: extraTime,
        rooms: rooms,
        notes: notes,
        errors: errors,
      );

      list.add(session);
      if (errors.isEmpty) {
        totalCount += rooms.length;
      }
    }

    setState(() {
      _previewSessions = list;
      _totalSessionsToCreate = totalCount;
      _step = 2; // Proceed to Step 3: Preview Sessions
    });
  }

  String? _getMappedValue(Map<String, dynamic> row, String field) {
    final col = _mappings[field];
    if (col == null || col.isEmpty) return null;
    final val = row[col];
    return val?.toString().trim();
  }

  void _showHeaderSelector(String field) {
    final colors = _FlowColors(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: BoxDecoration(
            color: colors.panel.withValues(alpha: 0.995),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Container(
                      width: 70,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.lineSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Map column for "$field"',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Divider(color: colors.lineSoft.withValues(alpha: 0.5)),
                    Expanded(
                      child: ListView(
                        children: [
                          // None/Unmapped Option (only allowed if optional)
                          ListTile(
                            leading: Icon(Icons.block, color: colors.textFaint),
                            title: Text(
                              'None (Unmapped)',
                              style: TextStyle(
                                color: colors.textFaint,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            trailing: _mappings[field] == null
                                ? Icon(Icons.check_circle, color: colors.blue)
                                : null,
                            onTap: () {
                              setState(() {
                                _mappings[field] = null;
                              });
                              Navigator.pop(ctx);
                            },
                          ),
                          ..._detectedHeaders.map((h) {
                            final isSelected = _mappings[field] == h;
                            return ListTile(
                              leading: Icon(Icons.tag, color: colors.textSoft),
                              title: Text(
                                h,
                                style: TextStyle(
                                  color: colors.text,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: colors.blue)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _mappings[field] = h;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ExamCardData _recompute(ExamCardData c) {
    // Basic recompute helpers replicated to avoid context gaps
    int toMin(String hhmm) {
      final p = hhmm.split(':');
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }

    String m2s(int m) {
      final h = (m ~/ 60) % 24;
      final mm = m % 60;
      return "${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}";
    }

    final startM = toMin(c.normalStart);
    final normM = toMin(c.normalDuration);
    final extraM = toMin(c.extraTime);
    final endM = startM + normM;
    final totalM = normM + extraM;
    final extraEndM = startM + totalM;

    return c.copyWith(
      start: c.normalStart,
      duration: c.normalDuration,
      end: m2s(endM),
      normalEnd: m2s(endM),
      totalDuration: m2s(totalM),
      extraEnd: m2s(extraEndM),
    );
  }

  Future<void> _executeImport() async {
    setState(() {
      _isLoading = true;
    });

    final List<ExamCardData> createdCards = [];

    for (var s in _previewSessions) {
      if (s.errors.isNotEmpty) continue; // skip errored rows

      // Each timetable row creates one session per room value detected
      for (var room in s.rooms) {
        bool isPast = false;
        try {
          final dateParts = s.date.split('/');
          final timeParts = s.startTime.split(':');
          if (dateParts.length == 3 && timeParts.length == 2) {
            final d = int.parse(dateParts[0]);
            final m = int.parse(dateParts[1]);
            final y = int.parse(dateParts[2]);
            final hh = int.parse(timeParts[0]);
            final mm = int.parse(timeParts[1]);
            final scheduled = DateTime(y, m, d, hh, mm);
            if (scheduled.isBefore(DateTime.now())) {
              isPast = true;
            }
          }
        } catch (_) {}

        var card = ExamCardData(
          recordId: generateId(),
          school: _orgName,
          centreNumber: _centreController.text.trim(),
          date: s.date,
          subject: s.level != null && s.level!.isNotEmpty
              ? '${s.subject} (${s.board})'
              : '${s.subject} (${s.board})',
          examLevel: s.level,
          start: s.startTime,
          duration: s.duration,
          end: s.startTime,
          normalStart: s.startTime,
          normalDuration: s.duration,
          normalEnd: s.startTime,
          extraTime: s.extraTime,
          totalDuration: '00:00',
          extraEnd: s.startTime,
          expanded: false,
          autoStart: !isPast,
          roomsSnapshot: room,
          notes: s.notes,
        );

        // Apply proper durations / end times
        card = _recompute(card);
        createdCards.add(card);
      }
    }

    try {
      await widget.onImportSessions(createdCards);
      await _saveMappings();

      setState(() {
        _isLoading = false;
        _step = 3; // Step 4: Import Complete (Result)
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NotificationService.show(
          context,
          title: 'Import Error',
          subtitle: 'Failed saving sessions: ${e.toString()}',
          type: NotificationType.error,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _FlowColors(context);
    final String currentTitle;
    switch (_step) {
      case 0:
        currentTitle = 'Import Exam Sessions';
        break;
      case 1:
        currentTitle = 'Map Columns';
        break;
      case 2:
        currentTitle = 'Preview Sessions';
        break;
      case 3:
        currentTitle = 'Import Complete';
        break;
      default:
        currentTitle = 'Import';
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: InkWell(
              onTap: _step > 0 && _step < 3
                  ? () {
                      setState(() {
                        _step--;
                      });
                    }
                  : widget.onClose,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VigiloUiColors.panel(colors.isDark).withValues(alpha: colors.isDark ? 0.72 : 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.isDark
                        ? VigiloUiColors.line(colors.isDark).withValues(alpha: 0.70)
                        : VigiloUiColors.line(colors.isDark),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: colors.isDark ? 0.16 : 0.07),
                      blurRadius: colors.isDark ? 8 : 10,
                      offset: Offset(0, colors.isDark ? 3 : 4),
                    ),
                  ],
                ),
                child: Icon(
                  _step > 0 && _step < 3
                      ? Icons.arrow_back_rounded
                      : Icons.close_rounded,
                  size: 23,
                  color: VigiloUiColors.textSoft(colors.isDark),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          currentTitle,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: InkWell(
                onTap: widget.onToggleTheme,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VigiloUiColors.panel(colors.isDark).withValues(alpha: colors.isDark ? 0.72 : 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.isDark
                          ? VigiloUiColors.line(colors.isDark).withValues(alpha: 0.70)
                          : VigiloUiColors.line(colors.isDark),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: colors.isDark ? 0.16 : 0.07),
                        blurRadius: colors.isDark ? 8 : 10,
                        offset: Offset(0, colors.isDark ? 3 : 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    colors.isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                    color: VigiloUiColors.textSoft(colors.isDark),
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              clipBehavior: Clip.hardEdge,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildStepChild(colors),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !_isLoading,
            child: AnimatedOpacity(
              opacity: _isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChild(_FlowColors colors) {
    switch (_step) {
      case 0:
        return Container(
          key: const ValueKey(0),
          child: _buildStep1FilePicker(colors),
        );
      case 1:
        return Container(
          key: const ValueKey(1),
          child: _buildStep2MapColumns(colors),
        );
      case 2:
        return Container(
          key: const ValueKey(2),
          child: _buildStep3Preview(colors),
        );
      case 3:
        return Container(
          key: const ValueKey(3),
          child: _buildStep4Result(colors),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 1: FILE PICKER ──────────────────────────────────────────────────
  Widget _buildStep1FilePicker(_FlowColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                _buildOtRow(
                  colors,
                  Icons.apartment_rounded,
                  'Organisation Name',
                  _orgName,
                  locked: true,
                ),
                Divider(height: 16, color: colors.lineSoft),
                _buildOtRow(
                  colors,
                  Icons.vpn_key_rounded,
                  'Organisation Code',
                  _orgCode,
                  locked: true,
                ),
                Divider(height: 16, color: colors.lineSoft),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        color: colors.blueSoft,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Organisation Number',
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _centreController,
                          textAlign: TextAlign.end,
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: _centreHasError
                                ? UnderlineInputBorder(
                                    borderSide: BorderSide(color: colors.red, width: 1.5),
                                  )
                                : InputBorder.none,
                            enabledBorder: _centreHasError
                                ? UnderlineInputBorder(
                                    borderSide: BorderSide(color: colors.red, width: 1.5),
                                  )
                                : InputBorder.none,
                            focusedBorder: _centreHasError
                                ? UnderlineInputBorder(
                                    borderSide: BorderSide(color: colors.red, width: 1.5),
                                  )
                                : InputBorder.none,
                            hintText: 'e.g. 10987',
                            hintStyle: TextStyle(
                              color: colors.textFaint,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select your timetable file',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One session per room will be created. You will review everything before confirming.',
            style: TextStyle(color: colors.textSoft, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.blue.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file_rounded, size: 52, color: colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to select file',
                    style: TextStyle(
                      color: colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'CSV (.csv)  ·  Excel (.xlsx, .xls)',
                    style: TextStyle(color: colors.textFaint, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Export your timetable from Arbor, SIMS, Bromcom, or your own spreadsheet as CSV or Excel. Vigilo remembers your column mapping after the first import.',
            style: TextStyle(
              color: colors.textFaint,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: MAP COLUMNS ──────────────────────────────────────────────────
  Widget _buildStep2MapColumns(_FlowColors colors) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: colors.green.withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFileName ?? 'timetable.csv',
                  style: TextStyle(
                    color: colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_detectedHeaders.length} columns  \u00b7  ${_parsedRows.length} rows',
                style: TextStyle(color: colors.textFaint, fontSize: 12),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.line),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'ORGANISATION',
                style: TextStyle(
                  color: colors.blueSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  children: [
                    _buildOtRow(
                      colors,
                      Icons.apartment_rounded,
                      'Organisation Name',
                      _orgName,
                      locked: true,
                    ),
                    Divider(height: 1, color: colors.lineSoft),
                    _buildOtRow(
                      colors,
                      Icons.vpn_key_rounded,
                      'Organisation Code',
                      _orgCode,
                      locked: true,
                    ),
                    Divider(height: 1, color: colors.lineSoft),
                    _buildOtRow(
                      colors,
                      Icons.tag_rounded,
                      'Organisation Number',
                      _centreController.text,
                      locked: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'TIMETABLE COLUMNS',
                style: TextStyle(
                  color: colors.blueSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Match each Vigilo field to the corresponding column in your file.',
                style: TextStyle(color: colors.textFaint, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Material(
                color: colors.panel,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.line),
                ),
                child: Column(
                  children: _mappings.keys.map((field) {
                    final isRequired =
                        field == 'Exam Subject' ||
                        field == 'Exam Board' ||
                        field == 'Date' ||
                        field == 'Start Time' ||
                        field == 'Duration';
                    final colVal = _mappings[field];
                    final isMapped = colVal != null && colVal.isNotEmpty;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (field != _mappings.keys.first)
                          Divider(height: 1, color: colors.lineSoft),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showHeaderSelector(field),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drag_indicator,
                                  color: colors.textFaint,
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        field,
                                        style: TextStyle(
                                          color: colors.text,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (!isRequired)
                                        Text(
                                          'optional',
                                          style: TextStyle(
                                            color: colors.textFaint,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  isMapped ? colVal : 'Unmapped',
                                  style: TextStyle(
                                    color: isMapped
                                        ? colors.blue
                                        : colors.textFaint,
                                    fontWeight: isMapped
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right,
                                  color: colors.textFaint,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        _buildBottomButton(
          colors: colors,
          label: 'Next: Preview Sessions',
          onPressed: _isMappingValid() ? _generatePreview : null,
        ),
      ],
    );
  }

  // ── STEP 3: PREVIEW SESSIONS ─────────────────────────────────────────────
  Widget _buildStep3Preview(_FlowColors colors) {
    // Group preview sessions by Date
    final Map<String, List<_PreviewSession>> groups = {};
    for (var s in _previewSessions) {
      groups.putIfAbsent(s.date, () => []).add(s);
    }
    final dates = groups.keys.toList();

    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: colors.panel,
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: colors.blue, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_totalSessionsToCreate sessions to create',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$_orgName  \u00b7  ${_centreController.text}',
                      style: TextStyle(color: colors.textSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.line),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: dates.length,
            itemBuilder: (ctx, idx) {
              final date = dates[idx];
              final dateSessions = groups[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colors.blueSoft,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: TextStyle(
                            color: colors.blueSoft,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.line),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < dateSessions.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: colors.lineSoft),
                          _buildPreviewSessionRow(colors, dateSessions[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Check subjects, boards, timings, and rooms. Tap Cancel to adjust column mapping.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textFaint,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        Container(
          color: colors.bg,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1), // Cancel -> back to Map Columns
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSoft,
                    side: BorderSide(color: colors.line),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _totalSessionsToCreate > 0 ? _executeImport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.green.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Create $_totalSessionsToCreate Sessions',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSessionRow(_FlowColors colors, _PreviewSession s) {
    final hasError = s.errors.isNotEmpty;
    final rooms = s.rooms;
    final multi = rooms.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.subject,
                      style: TextStyle(
                        color: hasError ? colors.red : colors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        if (s.level != null) ...[
                          Text(
                            s.level!,
                            style: TextStyle(
                              color: hasError
                                  ? colors.red.withValues(alpha: 0.8)
                                  : colors.blueSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '·  ${s.board}',
                          style: TextStyle(
                            color: hasError
                                ? colors.red.withValues(alpha: 0.6)
                                : colors.textSoft,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.startTime,
                    style: TextStyle(
                      color: hasError ? colors.red : colors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${s.duration}  +  ${s.extraTime} ET',
                    style: TextStyle(
                      color: hasError ? colors.red.withValues(alpha: 0.6) : colors.textSoft,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (s.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 12, color: colors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    s.notes,
                    style: TextStyle(
                      color: colors.amber,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (hasError) ...[
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: s.errors.map((err) {
                return Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      err,
                      style: TextStyle(
                        color: colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ] else if (multi) ...[
            Row(
              children: [
                Icon(Icons.meeting_room_outlined, size: 13, color: colors.blue),
                const SizedBox(width: 4),
                Text(
                  '${rooms.length} sessions will be created:',
                  style: TextStyle(
                    color: colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rooms.map((r) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    r.isEmpty ? 'No Room' : r,
                    style: TextStyle(color: colors.blue, fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 13,
                  color: colors.textFaint,
                ),
                const SizedBox(width: 4),
                Text(
                  rooms.isEmpty || rooms.first.isEmpty ? 'No Room' : rooms.first,
                  style: TextStyle(color: colors.textFaint, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── STEP 4: IMPORT RESULT ────────────────────────────────────────────────
  Widget _buildStep4Result(_FlowColors colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: colors.green,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$_totalSessionsToCreate sessions created',
            style: TextStyle(
              color: colors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                _buildOtRow(
                  colors,
                  Icons.apartment_rounded,
                  'Organisation Name',
                  _orgName,
                  locked: false,
                ),
                Divider(height: 1, color: colors.lineSoft),
                _buildOtRow(
                  colors,
                  Icons.vpn_key_rounded,
                  'Organisation Code',
                  _orgCode,
                  locked: false,
                ),
                Divider(height: 1, color: colors.lineSoft),
                _buildOtRow(
                  colors,
                  Icons.tag_rounded,
                  'Organisation Number',
                  _centreController.text,
                  locked: false,
                ),
                Divider(height: 1, color: colors.lineSoft),
                _buildOtRow(
                  colors,
                  Icons.save_rounded,
                  'Column mapping',
                  'Saved for future imports',
                  locked: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sessions are on your Home Screen, sorted by date and time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textFaint,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Go to Home Screen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Shared UI helper methods ─────────────────────────────────────────────
  Widget _buildOtRow(
    _FlowColors colors,
    IconData icon,
    String label,
    String value, {
    bool locked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: locked ? colors.textFaint : colors.blueSoft,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: locked ? colors.textFaint : colors.textSoft,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          if (locked) ...[
            Icon(Icons.lock_outline, color: colors.textFaint, size: 14),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: locked ? colors.textFaint : colors.text,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required _FlowColors colors,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      color: colors.bg,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colors.panel2,
            disabledForegroundColor: colors.textFaint.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _PreviewSession {
  final int rowIndex;
  final String subject;
  final String? level;
  final String board;
  final String date;
  final String startTime;
  final String duration;
  final String extraTime;
  final List<String> rooms;
  final String notes;
  final List<String> errors;

  _PreviewSession({
    required this.rowIndex,
    required this.subject,
    this.level,
    required this.board,
    required this.date,
    required this.startTime,
    required this.duration,
    required this.extraTime,
    required this.rooms,
    required this.notes,
    required this.errors,
  });
}
