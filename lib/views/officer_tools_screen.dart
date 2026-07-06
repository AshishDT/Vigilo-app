import 'widgets/animated_scale_on_press.dart';

// Vigilo ERC v1.0 — Stage 6 Polish R06
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigilo/views/briefings_library_sheet.dart';
import 'widgets/erc_notice.dart';

import '../enums/exam_phase.dart';
import '../models/briefing_model.dart';
import '../models/exam_card_data.dart';
import '../models/incident.dart';
import '../models/message.dart';
import '../models/schedule.dart';
import '../services/session_service.dart';
import '../utils/notifications.dart';

class OfficerToolsSheet extends StatefulWidget {
  const OfficerToolsSheet({
    super.key,
    required this.data,
    required this.onLog,
    required this.onReStart,
    required this.onPause,
    required this.onEnd,
    required this.onExportCopy,
    required this.onExportCsvDownload,
    required this.onExportCsvShare,
    required this.onToggleAutoStart,
    required this.onDeleteData,
    required this.onUpdateData,
    required this.onSaveData,
    required this.isExamCompleted,
    this.initialTabIndex = 0,
    this.openBriefingsOnStart = false,
  });

  final ExamCardData data;
  final void Function(Incident) onLog;
  final VoidCallback onReStart;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final VoidCallback onExportCopy;
  final VoidCallback onExportCsvDownload;
  final VoidCallback onExportCsvShare;
  final ValueChanged<bool> onToggleAutoStart;
  final VoidCallback onDeleteData;
  final ValueChanged<ExamCardData> onUpdateData;
  final VoidCallback onSaveData;
  final int initialTabIndex;
  final bool openBriefingsOnStart;
  final bool isExamCompleted;

  @override
  State<OfficerToolsSheet> createState() => _OfficerToolsSheetState();
}

class _OtSheetColorPalette {
  final BuildContext context;

  _OtSheetColorPalette(this.context);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get panel =>
      _isDark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);

  Color get panel2 =>
      _isDark ? const Color(0xFF16314D) : const Color(0xFFF1F5F9);

  Color get panel3 =>
      _isDark ? const Color(0xFF0D2035) : const Color(0xFFE4E8EE);

  Color get line => _isDark ? const Color(0xFF294867) : const Color(0xFFD0D7DE);

  Color get lineSoft =>
      _isDark ? const Color(0xFF395B7D) : const Color(0xFFCBD5E1);

  Color get text => _isDark ? const Color(0xFFF3F7FC) : const Color(0xFF0B253A);

  Color get textSoft =>
      _isDark ? const Color(0xFFB6C7D8) : const Color(0xFF475569);

  Color get textFaint =>
      _isDark ? const Color(0xFF7E98B2) : const Color(0xFF94A3B8);

  Color get blue => _isDark ? const Color(0xFF4B86F8) : const Color(0xFF2563EB);

  Color get blueSoft =>
      _isDark ? const Color(0xFF8FD4FF) : const Color(0xFF3B82F6);

  Color get green =>
      _isDark ? const Color(0xFF5ED68A) : const Color(0xFF249B62);

  Color get orange =>
      _isDark ? const Color(0xFFFFB64D) : const Color(0xFFD97706);

  Color get red => _isDark ? const Color(0xFFE05D74) : const Color(0xFFDC2626);

  Color get purple => const Color(0xFF7C5CFA);

  Color get blackWhite =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
}

class _OfficerToolsSheetState extends State<OfficerToolsSheet>
    with SingleTickerProviderStateMixin {
  // ignore: non_constant_identifier_names
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);
  static const String _requiredFieldWarning =
      "Required fields cannot be empty. Please fill in all mandatory fields.";

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final TabController _tabs = TabController(length: 6, vsync: this);
  final ScrollController _tabScrollController = ScrollController();
  final SessionService _sessionService = SessionService();
  final TextEditingController _setUpByController = TextEditingController();
  final TextEditingController _setupRoomController = TextEditingController();
  final TextEditingController _setupInvigilatorsController =
      TextEditingController();
  final TextEditingController _setupNotesController = TextEditingController();
  late final FocusNode _setupInvigilatorsFocus = FocusNode();
  late final FocusNode _setUpByFocus = FocusNode();
  late final FocusNode _setupNotesFocus = FocusNode();
  int? _expandedLogIndex;
  int? _expandedRecentIncidentIndex;
  final Set<String> _expandedPrivacySections = {};
  String _setUpRole = '';
  int _activeTabIndex = 0;
  bool _hasExported = false;

  late ExamCardData _currentData;
  Timer? _updateTimer;

  bool get _isExamCompleted => _currentData.phase == ExamPhase.finished;

  void _updateData(ExamCardData data) {
    setState(() {
      _currentData = data;
    });
    widget.onUpdateData(data);
  }

  Future<void> _syncLiveState() async {
    if (!mounted) return;
    final recordId = widget.data.recordId;
    if (recordId == null) return;

    final state = await _sessionService.loadHomeState();
    if (!mounted) return;

    ExamCardData? found;
    for (final card in state.cards) {
      if (card.recordId == recordId) {
        found = card;
        break;
      }
    }
    if (found == null) {
      for (final card in state.archiveCards) {
        if (card.recordId == recordId) {
          found = card;
          break;
        }
      }
    }

    if (found != null) {
      final hasChanges =
          found.phase != _currentData.phase ||
          found.running != _currentData.running ||
          found.isPaused != _currentData.isPaused ||
          found.progress != _currentData.progress ||
          found.start != _currentData.start ||
          found.end != _currentData.end ||
          found.normalDuration != _currentData.normalDuration ||
          found.extraTime != _currentData.extraTime ||
          found.logs.length != _currentData.logs.length ||
          (found.messages?.length ?? 0) != (_currentData.messages?.length ?? 0);

      if (hasChanges) {
        setState(() {
          _currentData = found!.copyWith(
            scheduleList: scheduleList,
            roomsSnapshot: _scheduleRoomsSummary(),
            invigilatorsSnapshot: allInvigilators.join(", "),
            setUpBy: _setUpByController.text.trim(),
            setUpRole: _setUpRole,
          );
          if (found.messages != null) {
            messageLog = List<Message>.from(found.messages!);
          }
        });
      }
    }
  }

  List<ScheduleData> scheduleList = [];

  final List<String> selectedInvigilators = [];
  List<String> presetMessages = [
    "Runner H2",
    "Check seating plan",
    "Candidate requires paper",
    "15 minutes remaining",
  ];
  List<Message> messageLog = [];
  final TextEditingController customMessageCtrl = TextEditingController();

  List<String> get allInvigilators {
    final names = scheduleList
        .expand((s) => s.invigilators)
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  bool autoStart = true;

  @override
  void initState() {
    super.initState();
    // _loadResolvedIncidents();
    _currentData = widget.data;
    autoStart = widget.data.autoStartUserModified
        ? widget.data.autoStart
        : true;
    if (!widget.data.autoStartUserModified && !widget.data.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onToggleAutoStart(true);
      });
    }
    _activeTabIndex = widget.initialTabIndex.clamp(0, _tabs.length - 1);
    _tabs.index = _activeTabIndex;

    // Smooth scroll synchronization: listen to page change progress
    _tabs.animation?.addListener(_handleTabAnimation);

    // Scroll tab bar to correct initial position once laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tabScrollController.hasClients) {
        _handleTabAnimation();
      }
    });

    _setUpByController.text = widget.data.setUpBy;
    _setUpRole = normalizeSetUpRole(widget.data.setUpRole);
    _loadPresetMessages();
    loadList();
    _migrateLegacyBriefings();
    _loadExportStatus();
    if (widget.openBriefingsOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openBriefingOptionsMenu();
        }
      });
    }
    _updateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncLiveState(),
    );
  }

  Future<void> _loadExportStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasExported =
            prefs.getBool('exported_${widget.data.recordId}') ?? false;
      });
    }
  }

  Future<void> _markAsExported() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('exported_${widget.data.recordId}', true);
    if (mounted) {
      setState(() {
        _hasExported = true;
      });
    }
  }

  void _handleTabAnimation() {
    if (!mounted) return;

    final animationValue = _tabs.animation?.value;
    if (animationValue == null) return;

    final int closestIndex = animationValue.round().clamp(0, _tabs.length - 1);
    if (closestIndex != _activeTabIndex) {
      setState(() {
        _activeTabIndex = closestIndex;
      });
    }

    if (!_tabScrollController.hasClients) return;

    const double itemWidth = 88.0;
    const double separatorWidth = 10.0;
    const double stepWidth = itemWidth + separatorWidth;
    const double horizontalPadding = 20.0;

    final double tabCenterOffset =
        horizontalPadding + (animationValue * stepWidth) + (itemWidth / 2);
    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final double targetOffset = tabCenterOffset - (viewportWidth / 2);
    final double maxScroll = _tabScrollController.position.maxScrollExtent;
    final double clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _tabScrollController.jumpTo(clampedOffset);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _tabs.dispose();
    _tabScrollController.dispose();
    customMessageCtrl.dispose();
    _setUpByController.dispose();
    _setupRoomController.dispose();
    _setupInvigilatorsController.dispose();
    _setupNotesController.dispose();
    _setupInvigilatorsFocus.dispose();
    _setUpByFocus.dispose();
    _setupNotesFocus.dispose();
    super.dispose();
  }

  void loadList() {
    if (widget.data.scheduleList != null) {
      scheduleList = List<ScheduleData>.from(widget.data.scheduleList!);
    }
    if (widget.data.messages != null) {
      messageLog = List<Message>.from(widget.data.messages!);
    }
    _setUpByController.text = widget.data.setUpBy;
    _setUpRole = normalizeSetUpRole(widget.data.setUpRole);
    _syncSetupControllersFromSchedule();
    _syncAssignmentSnapshots();
  }

  Future<void> _migrateLegacyBriefings() async {
    final legacyBriefings = widget.data.briefings;
    if (legacyBriefings == null || legacyBriefings.isEmpty) {
      return;
    }

    final sharedLibrary = await _sessionService.loadGlobalBriefingsLibrary();
    await _sessionService.saveGlobalBriefingsLibrary([
      ...legacyBriefings,
      ...sharedLibrary,
    ]);
  }

  List<String> _parseInvigilatorsInput(String raw) {
    final parts = raw
        .replaceAll('\r', '\n')
        .split(RegExp(r'[\n,;|.]+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty);
    return parts.toSet().toList();
  }

  void _syncAssignmentSnapshots() {
    final rooms =
        scheduleList
            .map((s) => s.room.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final invigilators =
        scheduleList
            .expand((s) => s.invigilators)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    selectedInvigilators.retainWhere(invigilators.contains);
    _updateData(
      _currentData.copyWith(
        roomsSnapshot: rooms.join(', '),
        invigilatorsSnapshot: invigilators.join(', '),
        setUpBy: _setUpByController.text.trim(),
        setUpRole: _setUpRole,
        scheduleList: scheduleList,
      ),
    );
  }

  String _setupTimeRange() =>
      "${_setupDisplayTime(_currentData.start)} - ${_setupDisplayTime(_currentData.end)}";

  String _setupDisplayTime(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^(\d{1,2}:\d{2})(?::\d{2})$').firstMatch(trimmed);
    return match == null ? trimmed : match.group(1)!;
  }

  void _syncSetupControllersFromSchedule() {
    _setupRoomController.text = _scheduleRoomsSummary();
    _setupInvigilatorsController.text = allInvigilators.join(", ");
    _setupNotesController.text = _scheduleNotesSummary();
  }

  void _updateOperationalSetup({bool save = false}) {
    final entry = ScheduleData(
      time: _setupTimeRange(),
      room: _setupRoomController.text.trim(),
      invigilators: _parseInvigilatorsInput(_setupInvigilatorsController.text),
      notes: _setupNotesController.text.trim(),
    );

    setState(() {
      scheduleList = [entry];
    });
    _syncAssignmentSnapshots();

    if (save) {
      widget.onSaveData();
      _showBanner(
        "Setup Saved",
        "Your setup details have been saved",
        Icons.save_rounded,
        NotificationType.success,
      );
    }
  }

  void _showBanner(
    String title, [
    String? subtitle,
    IconData? icon,
    NotificationType type = NotificationType.information,
  ]) {
    int durationSeconds;
    switch (type) {
      case NotificationType.success:
      case NotificationType.information:
        durationSeconds = 3;
        break;
      case NotificationType.warning:
        durationSeconds = 4;
        break;
      case NotificationType.error:
        durationSeconds = 5;
        break;
    }

    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: ERCNotice(
            icon: icon ?? Icons.info_outline_rounded,
            title: title,
            subtitle: subtitle,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          duration: Duration(seconds: durationSeconds),
        ),
      );
    } else {
      NotificationService.show(
        context,
        title: title,
        subtitle: subtitle,
        icon: icon ?? Icons.info_outline_rounded,
        type: type,
      );
    }
  }

  void _saveScheduleDetails({String? setUpBy, String? setUpRole}) {
    final nextSetUpBy = (setUpBy ?? _setUpByController.text).trim();
    final nextSetUpRole = normalizeSetUpRole(setUpRole ?? _setUpRole);
    _setUpRole = nextSetUpRole;
    _updateData(
      _currentData.copyWith(
        setUpBy: nextSetUpBy,
        setUpRole: nextSetUpRole,
        roomsSnapshot: _scheduleRoomsSummary(),
        invigilatorsSnapshot: allInvigilators.join(", "),
        scheduleList: scheduleList,
      ),
    );
    widget.onSaveData();
  }

  void _openBriefingOptionsMenu() {
    showBriefingsLibrarySheet(
      context,
      title: 'Briefings',
      isExamCompleted: _isExamCompleted,
      setUpBy: _setUpByController.text.trim(),
      setUpRole: _setUpRole,
    );
  }

  void _showMedicalIncidentDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _MedicalIncidentDialog(
        initialRoom: _scheduleRoomsSummary(),
        onSave: (room, student, details, action) {
          widget.onLog(
            Incident(
              "Medical incident",
              eventType: "incident",
              incidentType: "medical",
              room: room,
              studentID: student,
              staffMember: "",
              detail: details,
              action: action,
            ),
          );
          _showBanner(
            "Incident Logged",
            "Medical incident has been logged",
            Icons.local_hospital_rounded,
            NotificationType.success,
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showMalpracticeIncidentDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _MalpracticeIncidentDialog(
        initialRoom: _scheduleRoomsSummary(),
        onSave: (room, student, details, action) {
          widget.onLog(
            Incident(
              "Malpractice",
              eventType: "incident",
              incidentType: "malpractice",
              room: room,
              studentID: student,
              staffMember: "",
              detail: details,
              action: action,
            ),
          );
          _showBanner(
            "Incident Logged",
            "Malpractice incident has been logged",
            Icons.gavel_rounded,
            NotificationType.success,
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showToiletVisitIncidentDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _ToiletVisitIncidentDialog(
        initialRoom: _scheduleRoomsSummary(),
        onSave: (room, student, duration, notes, action) {
          widget.onLog(
            Incident(
              "Toilet break",
              eventType: "incident",
              incidentType: "toilet",
              room: room,
              studentID: student,
              duration: duration,
              detail: notes,
              action: action,
            ),
          );
          _showBanner(
            "Incident Logged",
            "Toilet visit has been logged",
            Icons.wc_rounded,
            NotificationType.success,
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _loadPresetMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('presetMessages');
    final cleaned = (saved ?? presetMessages)
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
    setState(() {
      presetMessages = cleaned.isEmpty
          ? [
              "Runner H2",
              "Check seating plan",
              "Candidate requires paper",
              "15 minutes remaining",
            ]
          : cleaned;
    });
  }

  Future<void> _savePresetMessages() async {
    final prefs = await SharedPreferences.getInstance();
    presetMessages = presetMessages
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
    await prefs.setStringList('presetMessages', presetMessages);
  }

  void _openRecipientSelector() {
    final all = allInvigilators;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _InvigilatorSelectorDialog(
        invigilators: all,
        initialSelection: selectedInvigilators,
        onSave: (selection) {
          setState(() {
            selectedInvigilators
              ..clear()
              ..addAll(selection);
          });
        },
      ),
    );
  }

  bool _send(String message) {
    if (message.trim().isEmpty || selectedInvigilators.isEmpty) {
      _showBanner(
        "Action Required",
        "Select a recipient and enter a message",
        Icons.warning_amber_rounded,
        NotificationType.warning,
      );
      return false;
    }

    setState(() {
      for (final name in selectedInvigilators) {
        messageLog.insert(0, Message("to $name: $message"));
        _updateData(_currentData.copyWith(messages: messageLog));
        widget.onSaveData();
      }
    });
    customMessageCtrl.clear();
    _showBanner(
      "Message Sent",
      "Your message has been sent",
      Icons.send_rounded,
      NotificationType.success,
    );
    return true;
  }

  void _sendPreset(String msg) => _send(msg);

  void _requestRunner() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _RequestRunnerDialog(
        initialRoom: _scheduleRoomsSummary(),
        onSend: (room, need, priority) {
          final roomText = room.trim().isEmpty ? '' : 'Room: ${room.trim()}. ';
          final message = '$roomText${need.trim()} (${priority.trim()})';
          if (_send(message)) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _editPresets() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _PresetMessagesDialog(
        initialPresets: presetMessages,
        requiredWarning: _requiredFieldWarning,
        onSave: (updatedPresets) {
          setState(() {
            presetMessages = updatedPresets;
          });
          _savePresetMessages();
        },
      ),
    );
  }

  void _openSelectBriefings() {
    showBriefingsLibrarySheet(
      context,
      allowSelection: true,
      title: 'Briefings',
      selectionActionLabel: 'Share Selected',
      emptySelectionMessage: 'Please select at least one briefing to share',
      isExamCompleted: _isExamCompleted,
      onSelectionApplied: _shareSelectedBriefings,
      setUpBy: _setUpByController.text.trim(),
      setUpRole: _setUpRole,
    );
  }

  void _shareSelectedBriefings(List<BriefingItem> selectedItems) {
    if (selectedItems.isEmpty) {
      return;
    }
    if (selectedInvigilators.isEmpty) {
      _showBanner(
        "Action Required",
        "Select recipients before sharing",
        Icons.warning_amber_rounded,
        NotificationType.warning,
      );
      return;
    }

    final validTitles = selectedItems
        .map((item) => item.title.trim())
        .where((title) => title.isNotEmpty)
        .toList();

    if (validTitles.isEmpty) {
      _showBanner(
        "Action Required",
        "Please select at least one briefing to share",
        Icons.warning_amber_rounded,
        NotificationType.warning,
      );
      return;
    }

    setState(() {
      for (final name in selectedInvigilators) {
        for (final title in validTitles) {
          messageLog.insert(0, Message('to $name: $title shared'));
        }
      }
      _updateData(_currentData.copyWith(messages: messageLog));
    });
    widget.onSaveData();
    _showBanner(
      "Briefings Shared",
      "Briefings have been shared successfully",
      Icons.share_rounded,
      NotificationType.success,
    );
  }

  Widget _buildAnimatedTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isActive = _activeTabIndex == index;
    final tab = GestureDetector(
      onTap: () => _selectOtTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: isActive ? 104 : 88,
        decoration: BoxDecoration(
          color: isActive
              ? _OtSheetColors.blue.withValues(alpha: 0.11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? _OtSheetColors.blue.withValues(alpha: 0.65)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? _OtSheetColors.blue : _OtSheetColors.textSoft,
              size: 25,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: isActive
                      ? _OtSheetColors.blue
                      : _OtSheetColors.textSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return tab;
  }

  void _selectOtTab(int index) {
    if (_activeTabIndex == index) return;
    setState(() {
      _activeTabIndex = index;
    });
    _tabs.animateTo(index, duration: Duration.zero);
  }

  Widget _otTabBar() {
    final labels = [
      'Setup',
      'Control',
      'Messages',
      'Incidents',
      'Log',
      'Privacy',
    ];
    final icons = [
      Icons.schedule_outlined,
      Icons.timer_outlined,
      CupertinoIcons.chat_bubble_2,
      Icons.warning_amber_rounded,
      Icons.article_outlined,
      Icons.verified_user_outlined,
    ];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _buildAnimatedTab(
            index: index,
            icon: icons[index],
            label: labels[index],
          );
        },
      ),
    );
  }

  Widget _otCardPanel(Widget child) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      child: child,
    );
  }

  Widget _otStandardPanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _OtSheetColors.line),
      ),
      child: child,
    );
  }

  Widget _otControlItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool disabled,
  }) {
    final Color borderColor = disabled
        ? _OtSheetColors.line.withValues(alpha: 0.4)
        : (color == _OtSheetColors.red
              ? _OtSheetColors.red.withValues(alpha: 0.7)
              : color.withValues(alpha: 0.7));
    final Color iconColor = disabled
        ? _OtSheetColors.textFaint.withValues(alpha: 0.4)
        : color;
    final Color titleColor = disabled
        ? _OtSheetColors.textFaint.withValues(alpha: 0.58)
        : _OtSheetColors.text;
    final Color subtitleColor = disabled
        ? _OtSheetColors.textFaint.withValues(alpha: 0.4)
        : _OtSheetColors.textSoft;
    final Color backgroundColor = disabled
        ? _OtSheetColors.panel2.withValues(alpha: 0.4)
        : (color == _OtSheetColors.red
              ? _OtSheetColors.red.withValues(alpha: 0.03)
              : color.withValues(alpha: 0.04));

    return IgnorePointer(
      ignoring: disabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: .7),
          ),
          child: Row(
            spacing: 16,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .2),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otIncidentActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool disabled,
  }) {
    final Color borderColor = disabled
        ? _OtSheetColors.line.withValues(alpha: 0.4)
        : color.withValues(alpha: 0.7);
    final Color iconColor = disabled
        ? _OtSheetColors.textFaint.withValues(alpha: 0.4)
        : color;
    final Color titleColor = disabled
        ? _OtSheetColors.textFaint.withValues(alpha: 0.58)
        : _OtSheetColors.text;
    final Color subtitleColor = disabled
        ? _OtSheetColors.textFaint.withValues(alpha: 0.4)
        : _OtSheetColors.textSoft;
    final Color backgroundColor = disabled
        ? _OtSheetColors.panel2.withValues(alpha: 0.2)
        : color.withValues(alpha: 0.04);

    return IgnorePointer(
      ignoring: disabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: .7),
          ),
          child: Row(
            spacing: 16,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor, width: .7),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otFilledButton(
    String text, {
    required VoidCallback onTap,
    bool danger = false,
    bool disabled = false,
    bool isExtraTime = false,
    EdgeInsets? padding,
  }) {
    final Color backgroundColor;
    if (disabled) {
      backgroundColor = Colors.grey.shade700;
    } else if (danger) {
      backgroundColor = _OtSheetColors.red;
    } else {
      backgroundColor = _OtSheetColors.blue;
    }

    return AnimatedScaleOnPress(
      isDisabled: disabled,
      child: SizedBox(
        height: 44,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isExtraTime
                ? _OtSheetColors.orange
                : backgroundColor,
            disabledBackgroundColor: Colors.grey.shade700,
            disabledForegroundColor: Colors.white70,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
            elevation: 0,
          ),
          onPressed: disabled ? null : onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
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
    );
  }

  Widget _otUtilityButton(
    String text, {
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _OtSheetColors.lineSoft),
            backgroundColor: _OtSheetColors.panel2.withValues(alpha: 0.62),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: _OtSheetColors.blue),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  text,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _OtSheetColors.blackWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets _otScrollPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      20,
      0,
      20,
      24 + MediaQuery.viewPaddingOf(context).bottom,
    );
  }

  Widget _otIconChipButton(
    IconData icon, {
    required VoidCallback onTap,
    String? tooltip,
    bool disabled = false,
    Color? backgroundColor,
    Color? borderColor,
    double size = 44,
    double iconSize = 22,
    double borderRadius = 14,
  }) {
    final button = Opacity(
      opacity: disabled ? 0.58 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? _OtSheetColors.panel2,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor ?? _OtSheetColors.line),
          ),
          child: Icon(icon, size: iconSize),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Widget _setupOverviewHeader(ExamCardData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OtSheetColors.line),
      ),
      child: Column(
        children: [
          Row(
            spacing: 12,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _OtSheetColors.panel2.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _OtSheetColors.lineSoft.withValues(alpha: 0.70),
                  ),
                ),
                child: Icon(
                  Icons.library_books_rounded,
                  color: _OtSheetColors.blueSoft,
                  size: 24,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'SESSION OVERVIEW',
                      style: TextStyle(
                        color: _OtSheetColors.blueSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _OtSheetColors.panel3.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _OtSheetColors.line.withValues(alpha: 0.75),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _setupTimingCell(
                    'START',
                    _setupDisplayTime(
                      data.phase == ExamPhase.extra
                          ? data.normalEnd
                          : data.start,
                    ),
                    _setupPhaseLabel(data.phase) == 'Finished'
                        ? Colors.grey
                        : _OtSheetColors.blue,
                  ),
                ),
                _setupTimingDivider(),
                Expanded(
                  child: _setupTimingCell(
                    'END',
                    _setupDisplayTime(
                      data.phase == ExamPhase.extra ? data.extraEnd : data.end,
                    ),
                    _setupPhaseLabel(data.phase) == 'Finished'
                        ? Colors.grey
                        : _OtSheetColors.blue,
                  ),
                ),
                _setupTimingDivider(),
                Expanded(
                  child: _setupTimingCell(
                    'PHASE',
                    data.isPaused ? 'Paused' : _setupPhaseLabel(data.phase),
                    data.phase == ExamPhase.extra
                        ? _OtSheetColors.orange
                        : data.phase == ExamPhase.finished
                            ? _OtSheetColors.green
                            : _OtSheetColors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _setupPhaseLabel(ExamPhase phase) {
    switch (phase) {
      case ExamPhase.normal:
        return 'Normal Time';
      case ExamPhase.extra:
        return 'Extra Time';
      case ExamPhase.finished:
        return 'Finished';
    }
  }

  Widget _setupTimingCell(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _OtSheetColors.textSoft,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            softWrap: false,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _setupTimingDivider() {
    return Container(
      width: 1,
      height: 44,
      color: _OtSheetColors.line.withValues(alpha: 0.65),
    );
  }

  Widget _setupSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _OtSheetColors.blueSoft,
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _setupInfoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OtSheetColors.line),
      ),
      child: Column(children: children),
    );
  }

  Widget _setupRowDivider() {
    return Container(
      height: 1,
      color: _OtSheetColors.line.withValues(alpha: 0.72),
    );
  }

  Widget _setupInfoRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isCompleted = false,
  }) {
    final trimmed = value.trim();
    final effectiveColor = isCompleted
        ? Colors.grey
        : valueColor ?? _OtSheetColors.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _OtSheetColors.textSoft,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Align(
              alignment: AlignmentGeometry.centerRight,
              child: Text(
                trimmed.isEmpty ? 'Pending' : trimmed,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: trimmed.isEmpty
                      ? _OtSheetColors.textFaint
                      : effectiveColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupEditableTextRow({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    bool disabled = false,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    TextInputAction? textInputAction,
  }) {
    final hintText = switch (label) {
      'Invigilators' => 'Add invigilator names',
      'Room' || 'Set Up By' => 'Pending',
      _ => 'Pending',
    };

    return Opacity(
      opacity: /*disabled ? 0.58 : */ 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _OtSheetColors.textSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: IgnorePointer(
                ignoring: disabled,
                child: TextField(
                  readOnly: disabled,
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction:
                      textInputAction ??
                      (nextFocusNode != null
                          ? TextInputAction.next
                          : TextInputAction.done),
                  onSubmitted: (_) {
                    if (nextFocusNode != null) {
                      nextFocusNode.requestFocus();
                    }
                  },
                  cursorColor: _OtSheetColors.blueSoft,
                  textAlign: TextAlign.right,
                  minLines: 1,
                  maxLines: 2,
                  style: TextStyle(
                    color: disabled ? Colors.grey : _OtSheetColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                  onChanged: disabled ? null : onChanged,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: _OtSheetColors.textFaint,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoleSelector() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _RoleSelectorDialog(
        initialSelection: _setUpRole,
        onSave: (selection) {
          setState(() {
            _setUpRole = selection;
          });
          _saveScheduleDetails(setUpRole: selection);
        },
      ),
    );
  }

  Widget _setupRoleRow({required bool disabled}) {
    final displayRole = _setUpRole.isEmpty ? 'Select role' : _setUpRole;
    final isSelected = _setUpRole.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Up Role',
            style: TextStyle(
              color: _OtSheetColors.textSoft,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: disabled ? null : _openRoleSelector,
            child: Opacity(
              opacity: disabled ? 0.58 : 1.0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _OtSheetColors.panel2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _OtSheetColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? _OtSheetColors.text
                              : _OtSheetColors.textFaint,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _OtSheetColors.textSoft,
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupNotesPanel({required bool disabled}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OtSheetColors.line),
      ),
      child: Opacity(
        opacity: disabled ? 0.58 : 1,
        child: IgnorePointer(
          ignoring: disabled,
          child: TextField(
            controller: _setupNotesController,
            focusNode: _setupNotesFocus,
            textInputAction: TextInputAction.done,
            cursorColor: _OtSheetColors.blueSoft,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            style: TextStyle(
              color: _OtSheetColors.textSoft,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
            onChanged: disabled ? null : (_) => _updateOperationalSetup(),
            decoration: InputDecoration(
              hintText:
                  'Add exam notes, special arrangements and briefing references',
              hintStyle: TextStyle(
                color: _OtSheetColors.textFaint,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatusSection(ExamCardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "CURRENT STATUS",
          style: TextStyle(
            color: _OtSheetColors.blueSoft,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final Color statusColor;
            Color borderColor = _OtSheetColors.lineSoft;
            final IconData statusIcon;
            final String statusTitle;

            if (_isExamCompleted) {
              statusColor = _OtSheetColors.green;
              statusIcon = Icons.check_circle_outline_rounded;
              statusTitle = "Exam Completed";
            } else if (data.isPaused) {
              statusColor = _OtSheetColors.orange;
              statusIcon = Icons.pause_circle_outline_rounded;
              statusTitle = "Exam Paused";
            } else if (data.phase == ExamPhase.extra) {
              statusColor = _OtSheetColors.orange;
              borderColor = _OtSheetColors.orange;
              statusIcon = Icons.access_time_rounded;
              statusTitle = "Extra Time Active";
            } else {
              statusColor = _OtSheetColors.blue;
              statusIcon = Icons.access_time_rounded;
              statusTitle = "Normal Time Active";
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: _OtSheetColors.panel2.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: .7),
              ),
              child: Row(
                spacing: 16,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .2),
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          spacing: 64,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Started",
                                  style: TextStyle(
                                    color: _OtSheetColors.textSoft,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _setupDisplayTime(
                                    data.phase == ExamPhase.extra
                                        ? data.normalEnd
                                        : data.start,
                                  ),
                                  style: TextStyle(
                                    color: _OtSheetColors.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isExamCompleted ? "Ended" : "Expected End",
                                  style: TextStyle(
                                    color: _OtSheetColors.textSoft,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _setupDisplayTime(
                                    data.phase == ExamPhase.extra
                                        ? data.extraEnd
                                        : data.end,
                                  ),
                                  style: TextStyle(
                                    color: _OtSheetColors.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _setupTab(ExamCardData data) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: _otScrollPadding(context),
      child: _otCardPanel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _setupOverviewHeader(data),
            const SizedBox(height: 22),
            _setupSectionLabel('SESSION'),
            const SizedBox(height: 12),
            _setupInfoCard(
              children: [
                _setupInfoRow(
                  label: 'Exam Time',
                  value: _setupTimeRange(),
                  valueColor: _OtSheetColors.blue,
                  isCompleted: _setupPhaseLabel(data.phase) == 'Finished',
                ),
                _setupRowDivider(),
                _setupEditableTextRow(
                  label: 'Room',
                  controller: _setupRoomController,
                  disabled: _isExamCompleted,
                  onChanged: (_) => _updateOperationalSetup(),
                ),
                _setupRowDivider(),
                _setupInfoRow(
                  label: 'Duration',
                  value: data.normalDuration,
                  valueColor: _OtSheetColors.blue,
                  isCompleted: _setupPhaseLabel(data.phase) == 'Finished',
                ),
                _setupRowDivider(),
                _setupInfoRow(
                  label: 'Extra Time',
                  value: data.extraTime,
                  valueColor: _OtSheetColors.orange,
                  isCompleted: _setupPhaseLabel(data.phase) == 'Finished',
                ),
              ],
            ),
            const SizedBox(height: 22),
            _setupSectionLabel('STAFFING'),
            const SizedBox(height: 12),
            _setupInfoCard(
              children: [
                _setupEditableTextRow(
                  label: 'Invigilators',
                  controller: _setupInvigilatorsController,
                  disabled: _isExamCompleted,
                  onChanged: (_) => _updateOperationalSetup(),
                  focusNode: _setupInvigilatorsFocus,
                  nextFocusNode: _setUpByFocus,
                ),
                _setupRowDivider(),
                _setupEditableTextRow(
                  label: 'Set Up By',
                  controller: _setUpByController,
                  disabled: _isExamCompleted,
                  focusNode: _setUpByFocus,
                  nextFocusNode: _setupNotesFocus,
                  onChanged: (value) {
                    _updateData(
                      _currentData.copyWith(
                        setUpBy: value.trim(),
                        setUpRole: _setUpRole,
                        roomsSnapshot: _scheduleRoomsSummary(),
                        invigilatorsSnapshot: allInvigilators.join(", "),
                        scheduleList: scheduleList,
                      ),
                    );
                  },
                ),
                _setupRowDivider(),
                _setupRoleRow(disabled: _isExamCompleted),
              ],
            ),
            const SizedBox(height: 22),
            _setupSectionLabel('NOTES & INSTRUCTIONS'),
            const SizedBox(height: 12),
            _setupNotesPanel(disabled: _isExamCompleted),
            const SizedBox(height: 18),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: _otUtilityButton(
                    'Briefings',
                    icon: Icons.description_outlined,
                    onTap: _openBriefingOptionsMenu,
                  ),
                ),
                Expanded(
                  child: _otFilledButton(
                    'Save Changes',
                    disabled: _isExamCompleted,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _updateOperationalSetup(save: true);
                      _saveScheduleDetails();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _joinUnique(Iterable<String> values) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) {
        ordered.add(trimmed);
      }
    }
    return ordered.join(", ");
  }

  String _scheduleRoomsSummary() {
    return _joinUnique(scheduleList.map((entry) => entry.room));
  }

  String _scheduleNotesSummary() {
    return _joinUnique(scheduleList.map((entry) => entry.notes));
  }

  Widget _otMessageSelectorField({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.58 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _OtSheetColors.panel2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _OtSheetColors.lineSoft, width: 0.7),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _OtSheetColors.blueSoft.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _OtSheetColors.blueSoft.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.groups,
                  color: _OtSheetColors.blueSoft,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _OtSheetColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _OtSheetColors.textSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _OtSheetColors.textSoft,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otMessageInputBox({required bool disabled}) {
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color),
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: customMessageCtrl,
      builder: (context, value, child) {
        final hasText = value.text.trim().isNotEmpty;
        return TextField(
          controller: customMessageCtrl,
          enabled: !disabled,
          minLines: 1,
          maxLines: 4,
          cursorColor: _OtSheetColors.blueSoft,
          keyboardType: TextInputType.text,
          style: TextStyle(
            color: _OtSheetColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: "Type a message",
            hintStyle: TextStyle(
              color: _OtSheetColors.textFaint,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: _OtSheetColors.panel2,
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            border: border(_OtSheetColors.line),
            enabledBorder: border(_OtSheetColors.line),
            focusedBorder: border(_OtSheetColors.blueSoft),
            disabledBorder: border(_OtSheetColors.line),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: hasText && !disabled
                      ? _OtSheetColors.blue
                      : Color(0xff9FB1C4),
                ),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: (hasText && !disabled)
                    ? () {
                        _send(customMessageCtrl.text);
                      }
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _otPresetChip(
    String text, {
    double? maxWidth,
    required VoidCallback onTap,
  }) {
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 48, maxWidth: maxWidth ?? 320),
        child: Material(
          color: _OtSheetColors.blue,
          borderRadius: BorderRadius.circular(24),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                text,
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsivePresetWrap(List<String> messages) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: messages.map((m) {
            return _otPresetChip(
              m,
              maxWidth: constraints.maxWidth,
              onTap: () => _sendPreset(m),
            );
          }).toList(),
        );
      },
    );
  }

  // Widget _otSectionLabel(String text) {
  //   return Text(
  //     text,
  //     style: TextStyle(
  //       color: _OtSheetColors.blueSoft,
  //       fontSize: 14,
  //       fontWeight: FontWeight.w900,
  //       letterSpacing: 0.2,
  //     ),
  //   );
  // }

  // Widget _otInlineSectionTitle(String text) {
  //   return Text(
  //     text,
  //     style: TextStyle(
  //       color: _OtSheetColors.text,
  //       fontSize: 17,
  //       fontWeight: FontWeight.w900,
  //     ),
  //   );
  // }

  Widget _otSectionDivider() {
    return Container(
      height: 1,
      width: double.infinity,
      color: _OtSheetColors.line.withValues(alpha: 0.72),
    );
  }

  Widget _otSmallTextButton(
    String text, {
    required IconData icon,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.58 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _OtSheetColors.blueSoft),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: _OtSheetColors.blueSoft,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otLogStatusPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OtSheetColors.lineSoft),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _OtSheetColors.blackWhite,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _recipientText(List<String> names) {
    if (names.isEmpty) return 'To: No recipients';
    if (names.length <= 2) return 'To: ${names.join(', ')}';
    return 'To: ${names.take(2).join(', ')} +${names.length - 2}';
  }

  List<_GroupedMessage> _getGroupedMessages() {
    final List<_GroupedMessage> grouped = [];
    for (final msg in messageLog) {
      final text = msg.message;
      String display = text;
      String recipient = '';
      final isToMessage = text.startsWith('to ') && text.contains(': ');
      if (isToMessage) {
        final colonIdx = text.indexOf(': ');
        recipient = text.substring(3, colonIdx).trim();
        display = text.substring(colonIdx + 2);
      }

      bool merged = false;
      for (final existing in grouped) {
        final timeDiff = msg.time.difference(existing.time).abs();
        if (existing.text == display && timeDiff.inSeconds < 5) {
          if (recipient.isNotEmpty &&
              !existing.recipients.contains(recipient)) {
            existing.recipients.add(recipient);
            existing.recipients.sort(
              (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
            );
          }
          merged = true;
          break;
        }
      }

      if (!merged) {
        grouped.add(
          _GroupedMessage(
            text: display,
            recipients: recipient.isNotEmpty ? [recipient] : [],
            time: msg.time,
            isToMessage: isToMessage,
          ),
        );
      }
    }
    return grouped;
  }

  Widget _otMessageBubble(_GroupedMessage message) {
    final display = message.text;

    String title = display;
    String? subtitle;
    IconData icon = Icons.chat_bubble_outline_rounded;

    if (display.endsWith(' shared')) {
      final String fileName = display.replaceAll(' shared', '');
      final String ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';

      final isImage =
          ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic'].contains(ext) ||
          fileName.toLowerCase().contains("image") ||
          fileName.toLowerCase().contains("photo") ||
          fileName.toLowerCase().contains("picture");

      if (isImage) {
        title = "Image shared";
        subtitle = "$fileName attached";
        icon = Icons.image_outlined;
      } else {
        title = "Briefing document shared";
        subtitle = "$fileName attached";
        icon = Icons.picture_as_pdf_outlined;
      }
    } else if (display.toLowerCase().contains("image") ||
        display.toLowerCase().contains("photo") ||
        display.toLowerCase().contains("picture")) {
      title = "Image shared";
      subtitle = display;
      icon = Icons.image_outlined;
    }

    final String timeString =
        "${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OtSheetColors.lineSoft, width: 0.7),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _OtSheetColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _OtSheetColors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, color: _OtSheetColors.blue, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _OtSheetColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _OtSheetColors.textSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (message.isToMessage) ...[
                  const SizedBox(height: 4),
                  Text(
                    _recipientText(message.recipients),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _OtSheetColors.textSoft.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeString,
            style: TextStyle(
              color: _OtSheetColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  bool _isDurationAdjustmentMessage(String message) {
    final msg = message.trim().toLowerCase();
    return msg.startsWith('normal time updated') ||
        msg.startsWith('extra time updated') ||
        msg.startsWith('normal time increased') ||
        msg.startsWith('normal time reduced') ||
        msg.startsWith('extra time increased') ||
        msg.startsWith('extra time reduced');
  }

  bool _isMalpracticeConcern(Incident incident) {
    return incident.message == 'Malpractice' ||
        incident.message == 'Suspected malpractice' ||
        incident.message == 'Malpractice concern' ||
        incident.message == 'Cheating concern';
  }

  String _logTime(Incident incident) {
    return "${incident.time.hour.toString().padLeft(2, '0')}:"
        "${incident.time.minute.toString().padLeft(2, '0')}:"
        "${incident.time.second.toString().padLeft(2, '0')}";
  }

  IconData _logIcon(Incident incident) {
    if (incident.message == 'Toilet break') {
      return Icons.wc;
    }
    if (_isMalpracticeConcern(incident)) {
      return Icons.warning_amber_rounded;
    }
    if (incident.message == 'Medical incident') {
      return Icons.medical_services;
    }
    if (incident.message == 'Invigilator list updated') {
      return Icons.group_rounded;
    }
    return Icons.schedule_rounded;
  }

  String _logCategory(Incident incident) {
    if (incident.eventType == 'incident' ||
        incident.message == 'Toilet break' ||
        _isMalpracticeConcern(incident) ||
        incident.message == 'Medical incident') {
      return 'Incident';
    }
    if (_isDurationAdjustmentMessage(incident.message) ||
        incident.message.toLowerCase().contains('pause') ||
        incident.message.toLowerCase().contains('restart') ||
        incident.message.toLowerCase().contains('resume') ||
        incident.message.toLowerCase().contains('end')) {
      return 'Control';
    }
    return 'Timing';
  }

  Widget _otCategoryBadge(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _OtSheetColors.lineSoft.withValues(alpha: 0.72),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: _OtSheetColors.blueSoft,
          fontSize: 11.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _formatStudentID(String s) {
    s = s.trim();
    // if (s.isEmpty) return s;
    // if (s.contains('(') && s.contains(')')) return s;
    // final parts = s.split(' ');
    // if (parts.length > 1) {
    //   final last = parts.last;
    //   if (RegExp(r'^\d+$').hasMatch(last)) {
    //     return '${parts.sublist(0, parts.length - 1).join(' ')} ($last)';
    //   }
    // }
    return s;
  }

  String _formatMinutesDescription(int minutes) {
    final absMinutes = minutes.abs();
    if (absMinutes == 0) return '0 minutes';
    final hours = absMinutes ~/ 60;
    final remainingMinutes = absMinutes % 60;

    String hoursStr = '';
    if (hours > 0) {
      hoursStr = '$hours ${hours == 1 ? "hour" : "hours"}';
    }

    String minsStr = '';
    if (remainingMinutes > 0) {
      minsStr =
          '$remainingMinutes ${remainingMinutes == 1 ? "minute" : "minutes"}';
    }

    if (hoursStr.isNotEmpty && minsStr.isNotEmpty) {
      return '$hoursStr and $minsStr';
    } else if (hoursStr.isNotEmpty) {
      return hoursStr;
    } else {
      return minsStr;
    }
  }

  String _formatDurationWording(String message) {
    final normalMatch = RegExp(
      r'Normal\s+Time\s+Updated\s*\((?:.*\s*,\s*)?([+-]?\d+)m\)',
      caseSensitive: false,
    ).firstMatch(message);
    if (normalMatch != null) {
      final diff = int.tryParse(normalMatch.group(1) ?? '0') ?? 0;
      final durationText = _formatMinutesDescription(diff);
      if (diff >= 0) {
        return 'Normal Time increased by $durationText';
      } else {
        return 'Normal Time reduced by $durationText';
      }
    }
    final extraMatch = RegExp(
      r'Extra\s+Time\s+updated\s*\((?:.*\s*,\s*)?([+-]?\d+)m\)',
      caseSensitive: false,
    ).firstMatch(message);
    if (extraMatch != null) {
      final diff = int.tryParse(extraMatch.group(1) ?? '0') ?? 0;
      final durationText = _formatMinutesDescription(diff);
      if (diff >= 0) {
        return 'Extra Time increased by $durationText';
      } else {
        return 'Extra Time reduced by $durationText';
      }
    }
    return message;
  }

  String _logTitle(Incident incident) {
    final formattedMessage = _formatDurationWording(incident.message);
    final isDurationAdjustment = _isDurationAdjustmentMessage(formattedMessage);

    if (incident.message == 'Toilet break') {
      final student = _formatStudentID(incident.studentID);
      if (student.isEmpty) return 'Toilet Visit';
      return 'Toilet Visit\n$student';
    }
    if (_isMalpracticeConcern(incident)) {
      final student = _formatStudentID(incident.studentID);
      if (student.isEmpty) return formattedMessage;
      return '$formattedMessage\n$student';
    }
    if (incident.message == 'Medical incident') {
      final student = _formatStudentID(incident.studentID);
      if (student.isEmpty) return 'Medical Incident';
      return 'Medical Incident\n$student';
    }
    if (isDurationAdjustment && incident.updatedDuration.isNotEmpty) {
      return '$formattedMessage - ${incident.updatedDuration} min';
    }
    return formattedMessage;
  }

  void _addLogDetail(List<String> details, String label, String value) {
    if (value.trim().isEmpty) return;
    details.add('$label: $value');
  }

  List<String> _logDetails(Incident incident, String time) {
    final details = <String>['Time: $time'];
    final isDurationAdjustment = _isDurationAdjustmentMessage(incident.message);

    if (incident.message == 'Toilet break') {
      _addLogDetail(details, 'Room', incident.room);
      _addLogDetail(details, 'Student ID', incident.studentID);
      _addLogDetail(
        details,
        'Duration',
        incident.duration.isEmpty ? '' : '${incident.duration} minutes',
      );
      _addLogDetail(details, 'Notes', incident.detail);
      _addLogDetail(details, 'Action taken', incident.action);
      return details;
    }

    if (_isMalpracticeConcern(incident) ||
        incident.message == 'Medical incident') {
      _addLogDetail(details, 'Room', incident.room);
      _addLogDetail(details, 'Student ID', incident.studentID);
      _addLogDetail(details, 'Invigilator(s)', incident.staffMember);
      _addLogDetail(details, 'Details', incident.detail);
      _addLogDetail(details, 'Action taken', incident.action);
      return details;
    }

    if (isDurationAdjustment) {
      _addLogDetail(
        details,
        'Updated Duration',
        incident.updatedDuration.isEmpty
            ? ''
            : '${incident.updatedDuration} minutes',
      );
      _addLogDetail(details, 'Details', incident.detail);
      return details;
    }

    _addLogDetail(details, 'Room', incident.room);
    _addLogDetail(details, 'Student ID', incident.studentID);
    _addLogDetail(details, 'Duration', incident.duration);
    _addLogDetail(details, 'Invigilator(s)', incident.staffMember);
    _addLogDetail(details, 'Details', incident.detail);
    _addLogDetail(details, 'Action taken', incident.action);
    _addLogDetail(details, 'Updated Duration', incident.updatedDuration);
    return details;
  }

  Widget _timelineLogRow({
    required Incident incident,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    final time = _logTime(incident);
    final details = _logDetails(incident, time);
    final category = _logCategory(incident);
    final isIncident = category == 'Incident';

    return InkWell(
      onTap: isIncident ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _OtSheetColors.line.withValues(alpha: 0.72),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _otCategoryBadge(category),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _logTitle(incident),
                    style: const TextStyle(
                      fontSize: 15.4,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  time,
                  style: TextStyle(
                    color: _OtSheetColors.textSoft,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  _logIcon(incident),
                  color: _OtSheetColors.blackWhite,
                  size: 22,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12, left: 78, right: 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details
                      .map(
                        (detail) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            detail,
                            style: TextStyle(
                              color: _OtSheetColors.textSoft,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              crossFadeState: (isIncident && expanded)
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  String _lastModifiedTime(ExamCardData data) {
    DateTime? latest = data.epochStart;

    for (final log in data.logs) {
      if (latest == null || log.time.isAfter(latest)) {
        latest = log.time;
      }
    }

    if (data.messages != null) {
      for (final msg in data.messages!) {
        if (latest == null || msg.time.isAfter(latest)) {
          latest = msg.time;
        }
      }
    }

    if (latest == null) {
      return "Not modified";
    }

    return "${latest.hour.toString().padLeft(2, '0')}:"
        "${latest.minute.toString().padLeft(2, '0')}:"
        "${latest.second.toString().padLeft(2, '0')}";
  }

  Widget _otPrivacyOverviewCard(ExamCardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 2),
      decoration: BoxDecoration(
        color: _OtSheetColors.panel2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OtSheetColors.lineSoft, width: .7),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _otPrivacyOverviewSegment(
                icon: Icons.shield_outlined,
                title: "DATA STORAGE",
                subtitle: "Stored locally\non this device",
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: .7,
              color: _OtSheetColors.lineSoft,
              indent: 14,
              endIndent: 14,
            ),
            Expanded(
              child: _otPrivacyOverviewSegment(
                icon: Icons.cloud_upload_outlined,
                title: "EXPORT STATUS",
                subtitle: _hasExported
                    ? "Generated"
                    : "No exports\ngenerated yet",
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: .7,
              color: _OtSheetColors.lineSoft,
              indent: 14,
              endIndent: 14,
            ),
            Expanded(
              child: _otPrivacyOverviewSegment(
                icon: Icons.update_rounded,
                title: "LAST MODIFIED",
                subtitle: _lastModifiedTime(data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otPrivacyOverviewSegment({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: _OtSheetColors.blueSoft, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _OtSheetColors.blueSoft,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _OtSheetColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _otPrivacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String sectionId,
    required String content,
    bool showCheckmark = false,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    final bool isAction = onTap != null;
    final bool expanded = _expandedPrivacySections.contains(sectionId);

    final Color primaryColor = _OtSheetColors.text;
    final Color secondaryColor = _OtSheetColors.textSoft;
    final Color iconColor = isDanger
        ? _OtSheetColors.red
        : _OtSheetColors.blueSoft;

    return InkWell(
      onTap: isAction
          ? onTap
          : () {
              setState(() {
                if (expanded) {
                  _expandedPrivacySections.remove(sectionId);
                } else {
                  _expandedPrivacySections.add(sectionId);
                }
              });
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                if (showCheckmark)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: _OtSheetColors.textSoft,
                    size: 24,
                  ),
                ),
              ],
            ),
            if (!isAction)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14, left: 40, right: 10),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: _OtSheetColors.textSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
                sizeCurve: Curves.easeInOut,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _currentData;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: _OtSheetColors.panel.withValues(alpha: 0.995),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: _OtSheetColors.lineSoft.withValues(alpha: 0.55),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 70,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _OtSheetColors.lineSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          data.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _OtSheetColors.text,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _otIconChipButton(
                        Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: () => Navigator.pop(context),
                        size: 45,
                        borderRadius: 14,
                        iconSize: 24,
                      ),
                    ],
                  ),
                ),
                _otTabBar(),
                SizedBox(height: 18),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _setupTab(data),
                      SingleChildScrollView(
                        padding: _otScrollPadding(context),
                        child: _otCardPanel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCurrentStatusSection(data),
                              Text(
                                "CONTROL ACTIONS",
                                style: TextStyle(
                                  color: _OtSheetColors.blueSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                spacing: 12,
                                children: [
                                  _otControlItem(
                                    title: data.isPaused
                                        ? "Resume Exam"
                                        : "Pause Exam",
                                    subtitle: data.isPaused
                                        ? "Resume the current exam timer"
                                        : "Pause the current exam timer",
                                    icon: data.isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    color:
                                        _setupPhaseLabel(data.phase) ==
                                            'Extra Time'
                                        ? _OtSheetColors.orange
                                        : _OtSheetColors.blue,
                                    onTap: widget.onPause,
                                    disabled: _isExamCompleted,
                                  ),
                                  _otControlItem(
                                    title: "Restart Exam",
                                    subtitle: "Restart the exam timer",
                                    icon: Icons.restart_alt_rounded,
                                    color:
                                        _setupPhaseLabel(data.phase) ==
                                            'Extra Time'
                                        ? _OtSheetColors.orange
                                        : _OtSheetColors.textSoft,
                                    onTap: widget.onReStart,
                                    disabled: _isExamCompleted || data.isPaused,
                                  ),
                                  _otControlItem(
                                    title: "End Exam",
                                    subtitle:
                                        "End the exam and close active timing",
                                    icon: Icons.stop_rounded,
                                    color: _OtSheetColors.red,
                                    onTap: widget.onEnd,
                                    disabled: _isExamCompleted || data.isPaused,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "AUTOMATION",
                                style: TextStyle(
                                  color: _OtSheetColors.blueSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.panel2.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _OtSheetColors.lineSoft,
                                    width: .7,
                                  ),
                                ),
                                child: Row(
                                  spacing: 16,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Auto-start exam",
                                            style: TextStyle(
                                              color: _isExamCompleted
                                                  ? _OtSheetColors.textFaint
                                                        .withValues(alpha: 0.58)
                                                  : _OtSheetColors.text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Automatically start the exam at the scheduled time",
                                            style: TextStyle(
                                              color: _isExamCompleted
                                                  ? _OtSheetColors.textFaint
                                                        .withValues(alpha: 0.4)
                                                  : _OtSheetColors.textSoft,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: autoStart,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: _OtSheetColors.blue,
                                      inactiveTrackColor: const Color(
                                        0xFF10263D,
                                      ),
                                      inactiveThumbColor: const Color(
                                        0xFF8FA7BF,
                                      ),
                                      trackOutlineColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.selected,
                                            )) {
                                              return Colors.transparent;
                                            }
                                            return const Color(0xFF35597B);
                                          }),
                                      onChanged: _isExamCompleted
                                          ? null
                                          : (v) {
                                              setState(() {
                                                autoStart = v;
                                              });
                                              widget.onToggleAutoStart(v);
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // MESSAGES
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                        },
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: _otScrollPadding(context),
                          child: _otCardPanel(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "RECIPIENTS",
                                  style: TextStyle(
                                    color: _OtSheetColors.blueSoft,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _otMessageSelectorField(
                                  title: "Select invigilators",
                                  subtitle: selectedInvigilators.isEmpty
                                      ? "No Invigilators selected"
                                      : (selectedInvigilators.length == 1
                                            ? "1 Invigilator selected"
                                            : "${selectedInvigilators.length} Invigilators selected"),
                                  disabled: _isExamCompleted,
                                  onTap: _openRecipientSelector,
                                ),
                                const SizedBox(height: 24),
                                _otSectionDivider(),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "QUICK MESSAGES",
                                        style: TextStyle(
                                          color: _OtSheetColors.blueSoft,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.3,
                                        ),
                                      ),
                                    ),
                                    _otSmallTextButton(
                                      'Edit',
                                      icon: Icons.edit_rounded,
                                      disabled: _isExamCompleted,
                                      onTap: _editPresets,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Opacity(
                                  opacity: _isExamCompleted ? 0.58 : 1,
                                  child: IgnorePointer(
                                    ignoring: _isExamCompleted,
                                    child: _buildResponsivePresetWrap(
                                      presetMessages,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Opacity(
                                  opacity: _isExamCompleted ? 0.58 : 1,
                                  child: IgnorePointer(
                                    ignoring: _isExamCompleted,
                                    child: Row(
                                      spacing: 10,
                                      children: [
                                        Expanded(
                                          child: _otUtilityButton(
                                            "Briefings",
                                            icon: Icons.description_outlined,
                                            onTap: _openSelectBriefings,
                                          ),
                                        ),
                                        Expanded(
                                          child: _otUtilityButton(
                                            "Request Runner",
                                            icon: Icons.directions_run_rounded,
                                            onTap: _requestRunner,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _otSectionDivider(),
                                const SizedBox(height: 18),
                                Text(
                                  "NEW MESSAGE",
                                  style: TextStyle(
                                    color: _OtSheetColors.blueSoft,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _otMessageInputBox(disabled: _isExamCompleted),
                                if (messageLog.isNotEmpty) ...[
                                  const SizedBox(height: 32),
                                  Text(
                                    "RECENT MESSAGES",
                                    style: TextStyle(
                                      color: _OtSheetColors.blueSoft,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._getGroupedMessages().map(
                                    _otMessageBubble,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // INCIDENTS
                      SingleChildScrollView(
                        padding: _otScrollPadding(context),
                        child: _otCardPanel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "LOG NEW INCIDENT",
                                style: TextStyle(
                                  color: _OtSheetColors.blueSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                spacing: 12,
                                children: [
                                  _otIncidentActionButton(
                                    title: "Toilet Visit",
                                    subtitle: "Record a toilet visit",
                                    icon: Icons.wc,
                                    color: _OtSheetColors.purple,
                                    onTap: _showToiletVisitIncidentDialog,
                                    disabled: _isExamCompleted,
                                  ),
                                  _otIncidentActionButton(
                                    title: "Medical",
                                    subtitle: "Record a medical incident",
                                    icon: Icons.medical_services,
                                    color: _OtSheetColors.blue,
                                    onTap: _showMedicalIncidentDialog,
                                    disabled: _isExamCompleted,
                                  ),
                                  _otIncidentActionButton(
                                    title: "Malpractice",
                                    subtitle: "Record a malpractice concern",
                                    icon: Icons.warning_amber_rounded,
                                    color: _OtSheetColors.orange,
                                    onTap: _showMalpracticeIncidentDialog,
                                    disabled: _isExamCompleted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "RECENT INCIDENTS",
                                style: TextStyle(
                                  color: _OtSheetColors.blueSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Builder(
                                builder: (context) {
                                  final recentIncidents = data.logs
                                      .where(
                                        (log) =>
                                            _logCategory(log) == 'Incident',
                                      )
                                      .toList();

                                  if (recentIncidents.isEmpty) {
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _OtSheetColors.panel2.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _OtSheetColors.lineSoft,
                                          width: .7,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "No recent incidents logged",
                                          style: TextStyle(
                                            color: _OtSheetColors.textSoft,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    spacing: 10,
                                    children: List.generate(recentIncidents.length, (
                                      idx,
                                    ) {
                                      final incident = recentIncidents[idx];
                                      final bool expanded =
                                          _expandedRecentIncidentIndex == idx;
                                      final timeStr =
                                          "${incident.time.hour.toString().padLeft(2, '0')}:${incident.time.minute.toString().padLeft(2, '0')}";

                                      final String visualTitle;
                                      final IconData visualIcon;
                                      final Color visualColor;

                                      if (incident.message == 'Toilet break') {
                                        visualTitle = "Toilet Visit";
                                        visualIcon = Icons.wc;
                                        visualColor = _OtSheetColors.purple;
                                      } else if (incident.message ==
                                          'Medical incident') {
                                        visualTitle = "Medical";
                                        visualIcon = Icons.medical_services;
                                        visualColor = _OtSheetColors.blue;
                                      } else {
                                        visualTitle = "Malpractice";
                                        visualIcon =
                                            Icons.warning_amber_rounded;
                                        visualColor = _OtSheetColors.orange;
                                      }

                                      return Container(
                                        width: double.infinity,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: _OtSheetColors.panel2
                                              .withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: _OtSheetColors.lineSoft,
                                            width: .7,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _expandedRecentIncidentIndex =
                                                    _expandedRecentIncidentIndex ==
                                                        idx
                                                    ? null
                                                    : idx;
                                              });
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 16,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: expanded
                                                        ? CrossAxisAlignment
                                                              .start
                                                        : CrossAxisAlignment
                                                              .center,
                                                    children: [
                                                      Icon(
                                                        visualIcon,
                                                        color: visualColor,
                                                        size: 24,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        timeStr,
                                                        style: TextStyle(
                                                          color: _OtSheetColors
                                                              .text,
                                                          fontSize: 15.5,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 20),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              visualTitle,
                                                              style: TextStyle(
                                                                color:
                                                                    visualColor,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 3,
                                                            ),
                                                            Text(
                                                              "Student: ${incident.studentID.trim()}",
                                                              style: TextStyle(
                                                                color:
                                                                    _OtSheetColors
                                                                        .textSoft,
                                                                fontSize: 13.8,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            AnimatedCrossFade(
                                                              firstChild:
                                                                  const SizedBox.shrink(),
                                                              secondChild: Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      top: 5.5,
                                                                      right: 10,
                                                                    ),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  spacing: 6,
                                                                  children: [
                                                                    if (incident
                                                                        .room
                                                                        .isNotEmpty)
                                                                      Text(
                                                                        "Room: ${incident.room}",
                                                                        style: TextStyle(
                                                                          color:
                                                                              _OtSheetColors.textSoft,
                                                                          fontSize:
                                                                              13.8,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    if (incident
                                                                        .duration
                                                                        .isNotEmpty)
                                                                      Text(
                                                                        "Duration: ${incident.duration} minutes",
                                                                        style: TextStyle(
                                                                          color:
                                                                              _OtSheetColors.textSoft,
                                                                          fontSize:
                                                                              13.8,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    if (incident
                                                                        .detail
                                                                        .isNotEmpty)
                                                                      Text(
                                                                        "Details: ${incident.detail}",
                                                                        style: TextStyle(
                                                                          color:
                                                                              _OtSheetColors.textSoft,
                                                                          fontSize:
                                                                              13.8,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    if (incident
                                                                        .action
                                                                        .isNotEmpty)
                                                                      Text(
                                                                        "Action: ${incident.action}",
                                                                        style: TextStyle(
                                                                          color:
                                                                              _OtSheetColors.textSoft,
                                                                          fontSize:
                                                                              13.8,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                              crossFadeState:
                                                                  expanded
                                                                  ? CrossFadeState
                                                                        .showSecond
                                                                  : CrossFadeState
                                                                        .showFirst,
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        180,
                                                                  ),
                                                              sizeCurve: Curves
                                                                  .easeInOut,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 2,
                                                            ),
                                                        child: AnimatedRotation(
                                                          turns: expanded
                                                              ? 0.25
                                                              : 0,
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    180,
                                                              ),
                                                          child: Icon(
                                                            Icons
                                                                .keyboard_arrow_right_rounded,
                                                            color:
                                                                _OtSheetColors
                                                                    .textSoft,
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                              // _otViewAllIncidentsTile(),
                            ],
                          ),
                        ),
                      ),

                      // LOG
                      SingleChildScrollView(
                        padding: _otScrollPadding(context),
                        child: _otCardPanel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "EXAM TIMELINE",
                                      style: TextStyle(
                                        color: _OtSheetColors.blueSoft,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                  ),
                                  _otLogStatusPill('Live audit record'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _otUtilityButton(
                                      "Copy Log",
                                      icon: Icons.copy_rounded,
                                      onTap: () {
                                        widget.onExportCopy();
                                        _markAsExported();
                                        if (Platform.isIOS) {
                                          showCopiedMessage(context);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Expanded(
                                  //   child: _otUtilityButton(
                                  //     "Download Log",
                                  //     icon: Icons.download_rounded,
                                  //     onTap: () {
                                  //       widget.onExportCsvDownload();
                                  //       _markAsExported();
                                  //     },
                                  //   ),
                                  // ),
                                  // const SizedBox(width: 12),
                                  Expanded(
                                    child: _otUtilityButton(
                                      "Share",
                                      icon: Icons.share_rounded,
                                      onTap: () {
                                        widget.onExportCsvShare();
                                        _markAsExported();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (_currentData.logs.isEmpty)
                                _otStandardPanel(
                                  child: Center(
                                    child: Text(
                                      "No log entries yet",
                                      style: TextStyle(
                                        color: _OtSheetColors.textSoft,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...List.generate(_currentData.logs.length, (i) {
                                  final incident = _currentData.logs[i];
                                  return _timelineLogRow(
                                    incident: incident,
                                    expanded: _expandedLogIndex == i,
                                    onTap: () {
                                      setState(() {
                                        _expandedLogIndex =
                                            _expandedLogIndex == i ? null : i;
                                      });
                                    },
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),

                      // PRIVACY
                      SingleChildScrollView(
                        padding: _otScrollPadding(context),
                        child: _otCardPanel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _otPrivacyOverviewCard(data),
                              const SizedBox(height: 24),
                              Text(
                                "DATA & PRIVACY",
                                style: TextStyle(
                                  color: _OtSheetColors.blueSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.panel2.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _OtSheetColors.lineSoft,
                                    width: .7,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _otPrivacyTile(
                                      icon: Icons.article_outlined,
                                      title: "Privacy Notice",
                                      subtitle:
                                          "How exam data is used and protected",
                                      sectionId: 'privacy',
                                      showCheckmark: true,
                                      content:
                                          "Vigilo ERC stores exam data locally on the device and does not transmit it to any external server.\n\nNo personal data is shared, synced, or stored outside of the device by the application.",
                                    ),
                                    Container(
                                      height: .7,
                                      width: double.infinity,
                                      color: _OtSheetColors.lineSoft,
                                    ),
                                    _otPrivacyTile(
                                      icon: Icons.download_rounded,
                                      title: "Export & Retention",
                                      subtitle:
                                          "Manage exports and data retention",
                                      sectionId: 'export',
                                      showCheckmark: true,
                                      content:
                                          "Exported logs are generated for organisational record keeping and should be stored, shared, retained, or deleted in accordance with the organisation's own procedures.\n\nVigilo ERC does not upload exported records to an external server.",
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "COMPLIANCE",
                                style: TextStyle(
                                  color: _OtSheetColors.blueSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.panel2.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _OtSheetColors.lineSoft,
                                    width: .7,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _otPrivacyTile(
                                      icon: Icons.group_outlined,
                                      title: "Responsibilities",
                                      subtitle:
                                          "Your role and responsibilities",
                                      sectionId: 'compliance',
                                      content:
                                          "The organisation is responsible for the retention, export, archiving, and deletion of records in accordance with its own policies, relevant examination regulations such as JCQ where applicable, and applicable data protection requirements.\n\nThis application should only be used by authorised staff during examinations.",
                                    ),
                                    Container(
                                      height: .7,
                                      width: double.infinity,
                                      color: _OtSheetColors.lineSoft,
                                    ),
                                    _otPrivacyTile(
                                      icon: Icons.info_outline_rounded,
                                      title: "Version Information",
                                      subtitle:
                                          "App version and compliance info",
                                      sectionId: 'version',
                                      content:
                                          "Vigilo ERC v1.0\n\nCopyright © 2026 Vigilo Platforms Ltd. All rights reserved.",
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "CRITICAL ACTIONS",
                                style: TextStyle(
                                  color: _OtSheetColors.blueSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.red.withValues(
                                    alpha: 0.03,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _OtSheetColors.red.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: .7,
                                  ),
                                ),
                                child: _otPrivacyTile(
                                  icon: Icons.delete_outline_rounded,
                                  title: "Delete Exam Data",
                                  subtitle:
                                      "Permanently delete all exam data from this device",
                                  sectionId: 'delete',
                                  content: "",
                                  isDanger: true,
                                  onTap: widget.onDeleteData,
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
            ),
          ),
        ),
      ),
    );
  }

  void showCopiedMessage(BuildContext context) {
    final overlay = Overlay.of(context);

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Copied to clipboard',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}

class _InvigilatorSelectorDialog extends StatefulWidget {
  const _InvigilatorSelectorDialog({
    required this.invigilators,
    required this.initialSelection,
    required this.onSave,
  });

  final List<String> invigilators;
  final List<String> initialSelection;
  final ValueChanged<List<String>> onSave;

  @override
  State<_InvigilatorSelectorDialog> createState() =>
      _InvigilatorSelectorDialogState();
}

class _InvigilatorSelectorDialogState
    extends State<_InvigilatorSelectorDialog> {
  // ignore: non_constant_identifier_names
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);
  late final Set<String> _selection = widget.initialSelection
      .where(widget.invigilators.contains)
      .toSet();

  bool get _allSelected {
    return widget.invigilators.isNotEmpty &&
        widget.invigilators.every(_selection.contains);
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selection.clear();
      } else {
        _selection
          ..clear()
          ..addAll(widget.invigilators);
      }
    });
  }

  void _toggleName(String name) {
    setState(() {
      if (_selection.contains(name)) {
        _selection.remove(name);
      } else {
        _selection.add(name);
      }
    });
  }

  void _save() {
    final orderedSelection = [
      for (final name in widget.invigilators)
        if (_selection.contains(name)) name,
    ];
    widget.onSave(orderedSelection);
    Navigator.pop(context);
  }

  Widget _selectionRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool isSelectAll = false,
  }) {
    final String initialLetter = label.trim().isNotEmpty
        ? label.trim().substring(0, 1).toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _OtSheetColors.blue.withValues(alpha: 0.15)
              : _OtSheetColors.panel2.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? _OtSheetColors.blue.withValues(alpha: 0.70)
                : _OtSheetColors.lineSoft,
            width: .7,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _OtSheetColors.blue : _OtSheetColors.panel3,
              ),
              alignment: Alignment.center,
              child: isSelectAll
                  ? Icon(
                      Icons.group_rounded,
                      color: _OtSheetColors.text,
                      size: 20,
                    )
                  : Text(
                      initialLetter,
                      style: TextStyle(
                        color: _OtSheetColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _OtSheetColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _OtSheetColors.blueSoft : Colors.transparent,
                border: selected
                    ? null
                    : Border.all(
                        color: _OtSheetColors.textSoft.withValues(alpha: 0.5),
                        width: 2.0,
                      ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Icon(
                      Icons.check,
                      color: _OtSheetColors.blue,
                      size: 18,
                      fontWeight: FontWeight.w700,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _OtSheetColors.panel,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _OtSheetColors.line),
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
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _OtSheetColors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _OtSheetColors.blue.withValues(alpha: 0.70),
                            width: .7,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.group_rounded,
                          color: _OtSheetColors.blue,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Invigilators',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _OtSheetColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selection.isEmpty
                                  ? 'No Invigilators selected'
                                  : (_selection.length == 1
                                        ? '1 Invigilator selected'
                                        : '${_selection.length} Invigilators selected'),
                              style: TextStyle(
                                color: _OtSheetColors.textSoft,
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
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _OtSheetColors.panel2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _OtSheetColors.lineSoft,
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 24,
                              color: _OtSheetColors.textSoft,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'AVAILABLE INVIGILATORS',
                    style: TextStyle(
                      color: _OtSheetColors.blueSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _selectionRow(
                          label: 'Select All',
                          selected: _allSelected,
                          isSelectAll: true,
                          onTap: _toggleAll,
                        ),
                        const SizedBox(height: 12),
                        if (widget.invigilators.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                            child: Center(
                              child: Text(
                                'No invigilators available',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _OtSheetColors.textSoft,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          ...widget.invigilators.map(
                            (name) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _selectionRow(
                                label: name,
                                selected: _selection.contains(name),
                                onTap: () => _toggleName(name),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: _otUtilityButton(
                          'Cancel',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      Expanded(
                        child: _otFilledButton('Save Changes', onTap: _save),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _otFilledButton(
    String text, {
    required VoidCallback onTap,
    bool danger = false,
    bool disabled = false,
    bool isExtraTime = false,
    EdgeInsets? padding,
  }) {
    final Color backgroundColor;
    if (disabled) {
      backgroundColor = Colors.grey.shade700;
    } else if (danger) {
      backgroundColor = _OtSheetColors.red;
    } else {
      backgroundColor = _OtSheetColors.blue;
    }

    return AnimatedScaleOnPress(
      isDisabled: disabled,
      child: SizedBox(
        height: 44,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isExtraTime
                ? _OtSheetColors.orange
                : backgroundColor,
            disabledBackgroundColor: Colors.grey.shade700,
            disabledForegroundColor: Colors.white70,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
            elevation: 0,
          ),
          onPressed: disabled ? null : onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
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
    );
  }

  Widget _otUtilityButton(String text, {required VoidCallback onTap}) {
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _OtSheetColors.lineSoft),
            backgroundColor: _OtSheetColors.panel2.withValues(alpha: 0.62),
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
                color: _OtSheetColors.blackWhite,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetMessagesDialog extends StatefulWidget {
  const _PresetMessagesDialog({
    required this.initialPresets,
    required this.requiredWarning,
    required this.onSave,
  });

  final List<String> initialPresets;
  final String requiredWarning;
  final ValueChanged<List<String>> onSave;

  @override
  State<_PresetMessagesDialog> createState() => _PresetMessagesDialogState();
}

class _PresetMessagesDialogState extends State<_PresetMessagesDialog> {
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);
  final TextEditingController _newPresetController = TextEditingController();
  late final List<TextEditingController> _presetControllers;

  bool _showLimitError = false;

  @override
  void initState() {
    super.initState();
    _presetControllers = widget.initialPresets
        .map((p) => TextEditingController(text: p))
        .toList();
    for (final c in _presetControllers) {
      c.addListener(_autoSave);
    }
  }

  @override
  void dispose() {
    _newPresetController.dispose();
    for (final c in _presetControllers) {
      c.removeListener(_autoSave);
      c.dispose();
    }
    super.dispose();
  }

  void _autoSave() {
    final cleaned = _presetControllers
        .map((c) => c.text.trim())
        .where((preset) => preset.isNotEmpty)
        .toList();
    widget.onSave(cleaned);
  }

  void _addPreset() {
    if (_presetControllers.length >= 50) {
      setState(() {
        _showLimitError = true;
      });
      return;
    }
    final value = _newPresetController.text.trim();
    if (value.isEmpty) return;

    setState(() {
      final newCtrl = TextEditingController(text: value);
      newCtrl.addListener(_autoSave);
      _presetControllers.add(newCtrl);
      _newPresetController.clear();
      _showLimitError = false;
    });
    _autoSave();
  }

  void _removePreset(int index) {
    setState(() {
      final removed = _presetControllers.removeAt(index);
      removed.removeListener(_autoSave);
      removed.dispose();
    });
    _autoSave();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final maxDialogHeight = (media.size.height - keyboardInset - 40)
        .clamp(260.0, media.size.height * 0.82)
        .toDouble();

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
                constraints: BoxConstraints(maxHeight: maxDialogHeight),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _OtSheetColors.panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _OtSheetColors.line.withValues(alpha: 0.75),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: _OtSheetColors.blue.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _OtSheetColors.blue.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.edit_note_rounded,
                              color: _OtSheetColors.blue,
                              size: 31,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Edit Presets',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _OtSheetColors.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      if (_presetControllers.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No preset messages yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _OtSheetColors.textSoft,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else ...[
                        ...List.generate(_presetControllers.length, (index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _presetControllers.length - 1
                                  ? 0
                                  : 16,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _OtSheetColors.panel2.withValues(
                                        alpha: 0.58,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: _OtSheetColors.lineSoft
                                            .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _presetControllers[index],
                                      maxLines: null,
                                      cursorColor: _OtSheetColors.blue,
                                      style: TextStyle(
                                        color: _OtSheetColors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        height: 1.35,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => _removePreset(index),
                                  child: Icon(
                                    Icons.delete_rounded,
                                    color: _OtSheetColors.red,
                                    size: 27,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 22),

                      Container(
                        height: 1,
                        color: _OtSheetColors.line.withValues(alpha: 0.18),
                      ),

                      const SizedBox(height: 22),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add new preset',
                          style: TextStyle(
                            color: _OtSheetColors.textSoft,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: _OtSheetColors.panel2,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _OtSheetColors.lineSoft.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        child: TextField(
                          controller: _newPresetController,
                          cursorColor: _OtSheetColors.blue,
                          onChanged: (_) {
                            setState(() {
                              if (_presetControllers.length >= 50 &&
                                  _newPresetController.text.isNotEmpty) {
                                _showLimitError = true;
                              } else {
                                _showLimitError = false;
                              }
                            });
                          },
                          style: TextStyle(
                            color: _OtSheetColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type message...',
                            hintStyle: TextStyle(
                              color: _OtSheetColors.textFaint,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      if (_showLimitError) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Quick Message limit reached (50). Delete an existing message to create a new one.',
                          style: TextStyle(
                            color: _OtSheetColors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: AnimatedScaleOnPress(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: _OtSheetColors.lineSoft,
                                    ),
                                    backgroundColor: _OtSheetColors.panel2
                                        .withValues(alpha: 0.62),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Close',
                                      style: TextStyle(
                                        color: _OtSheetColors.blackWhite,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _newPresetController,
                              builder: (context, val, _) {
                                final isEnabled =
                                    val.text.trim().isNotEmpty &&
                                    _presetControllers.length < 50;
                                return AnimatedScaleOnPress(
                                  isDisabled: !isEnabled,
                                  child: SizedBox(
                                    height: 44,
                                    child: FilledButton(
                                      onPressed: isEnabled ? _addPreset : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _OtSheetColors.blue,
                                        disabledBackgroundColor: _OtSheetColors
                                            .blue
                                            .withValues(alpha: 0.45),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors.white
                                            .withValues(alpha: 0.6),
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        elevation: isEnabled ? 2 : 0,
                                      ),
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Add',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestRunnerDialog extends StatefulWidget {
  const _RequestRunnerDialog({required this.initialRoom, required this.onSend});

  final String initialRoom;
  final void Function(String room, String need, String priority) onSend;

  @override
  State<_RequestRunnerDialog> createState() => _RequestRunnerDialogState();
}

class _RequestRunnerDialogState extends State<_RequestRunnerDialog> {
  // ignore: non_constant_identifier_names
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);

  late final TextEditingController _roomController = TextEditingController(
    text: widget.initialRoom,
  );

  final TextEditingController _messageController = TextEditingController();
  late final TextEditingController _requestTypeController =
      TextEditingController();
  late final FocusNode _requestTypeFocus = FocusNode();
  late final FocusNode _messageFocus = FocusNode();

  String _priority = 'Normal';

  bool get _isFormValid {
    return _requestTypeController.text.trim().isNotEmpty &&
        _messageController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _roomController.dispose();
    _messageController.dispose();
    _requestTypeController.dispose();
    _requestTypeFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  void _sendRequest() {
    if (!_isFormValid) return;
    final String combinedNeed =
        '${_requestTypeController.text.trim()}. Details: ${_messageController.text.trim()}';
    widget.onSend(_roomController.text, combinedNeed, _priority);
  }

  Widget _otSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _OtSheetColors.blueSoft,
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
            backgroundColor: _OtSheetColors.blue,
            disabledBackgroundColor: _OtSheetColors.blue.withValues(
              alpha: 0.45,
            ),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
            side: BorderSide(color: _OtSheetColors.lineSoft),
            backgroundColor: _OtSheetColors.panel2.withValues(alpha: 0.62),
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
                color: _OtSheetColors.blackWhite,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
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
                  maxHeight: media.size.height * 0.82,
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _OtSheetColors.panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _OtSheetColors.line),
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
                      padding: const EdgeInsets.only(top: 8, left: 8, right: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _OtSheetColors.blue.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _OtSheetColors.blue.withValues(
                                  alpha: 0.70,
                                ),
                                width: .7,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.directions_run_rounded,
                              color: _OtSheetColors.blue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Request Runner',
                                  style: TextStyle(
                                    color: _OtSheetColors.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Send an operational request for room support',
                                  style: TextStyle(
                                    color: _OtSheetColors.textSoft,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: 'Close',
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.panel2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _OtSheetColors.lineSoft,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 24,
                                  color: _OtSheetColors.textSoft,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _otSectionLabel('REQUEST TYPE'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _requestTypeController,
                                focusNode: _requestTypeFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _messageFocus.requestFocus();
                                },
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  hintText: 'Additional papers / materials',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            _otSectionLabel('PRIORITY'),
                            const SizedBox(height: 10),
                            Row(
                              spacing: 10,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _priority = 'Normal';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _priority == 'Normal'
                                            ? _OtSheetColors.blue.withValues(
                                                alpha: 0.15,
                                              )
                                            : _OtSheetColors.panel2.withValues(
                                                alpha: 0.30,
                                              ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: _priority == 'Normal'
                                              ? _OtSheetColors.blue.withValues(
                                                  alpha: .7,
                                                )
                                              : _OtSheetColors.line.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: .7,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Normal',
                                        style: TextStyle(
                                          color: _priority == 'Normal'
                                              ? _OtSheetColors.blue
                                              : _OtSheetColors.textSoft,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _priority = 'Urgent';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _priority == 'Urgent'
                                            ? _OtSheetColors.orange.withValues(
                                                alpha: 0.15,
                                              )
                                            : _OtSheetColors.panel2.withValues(
                                                alpha: 0.30,
                                              ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: _priority == 'Urgent'
                                              ? _OtSheetColors.orange
                                                    .withValues(alpha: .7)
                                              : _OtSheetColors.line.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: .7,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Urgent',
                                        style: TextStyle(
                                          color: _priority == 'Urgent'
                                              ? _OtSheetColors.orange
                                              : _OtSheetColors.textSoft,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _otSectionLabel('MESSAGE'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                focusNode: _messageFocus,
                                textInputAction: TextInputAction.done,
                                minLines: 3,
                                maxLines: 5,
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  hintText: 'Add details for the runner...',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.blue.withValues(
                                  alpha: .05,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.blue.withValues(
                                    alpha: 0.7,
                                  ),
                                  width: .7,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: _OtSheetColors.blue,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Runner requests should be short, clear and operational.',
                                      style: TextStyle(
                                        color: _OtSheetColors.blue,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
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
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          Expanded(
                            child: _otFilledButton(
                              'Send Request',
                              onTap: _isFormValid ? _sendRequest : null,
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

class _MedicalIncidentDialog extends StatefulWidget {
  const _MedicalIncidentDialog({
    required this.initialRoom,
    required this.onSave,
  });

  final String initialRoom;
  final void Function(
    String room,
    String student,
    String details,
    String actionTaken,
  )
  onSave;

  @override
  State<_MedicalIncidentDialog> createState() => _MedicalIncidentDialogState();
}

class _MedicalIncidentDialogState extends State<_MedicalIncidentDialog> {
  // ignore: non_constant_identifier_names
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);

  final TextEditingController _studentController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  late final FocusNode _studentFocus = FocusNode();
  late final FocusNode _detailsFocus = FocusNode();
  late final FocusNode _actionFocus = FocusNode();

  @override
  void dispose() {
    _studentController.dispose();
    _detailsController.dispose();
    _actionController.dispose();
    _studentFocus.dispose();
    _detailsFocus.dispose();
    _actionFocus.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final String student = _studentController.text.trim();
    final String details = _detailsController.text.trim();
    final String action = _actionController.text.trim();
    return student.isNotEmpty && details.isNotEmpty && action.isNotEmpty;
  }

  void _saveEntry() {
    if (!_isFormValid) return;

    widget.onSave(
      widget.initialRoom,
      _studentController.text.trim(),
      _detailsController.text.trim(),
      _actionController.text.trim(),
    );
  }

  Widget _otSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _OtSheetColors.blueSoft,
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
            backgroundColor: _OtSheetColors.blue,
            disabledBackgroundColor: _OtSheetColors.blue.withValues(
              alpha: 0.45,
            ),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
            side: BorderSide(color: _OtSheetColors.lineSoft),
            backgroundColor: _OtSheetColors.panel2.withValues(alpha: 0.62),
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
                color: _OtSheetColors.blackWhite,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
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
                  maxHeight: media.size.height * 0.82,
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _OtSheetColors.panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _OtSheetColors.line),
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
                      padding: const EdgeInsets.only(top: 8, left: 8, right: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _OtSheetColors.blue.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _OtSheetColors.blue.withValues(
                                  alpha: 0.70,
                                ),
                                width: .7,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.medical_services,
                              color: _OtSheetColors.blue,
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
                                    'Medical Incident',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: _OtSheetColors.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Record a medical incident',
                                  style: TextStyle(
                                    color: _OtSheetColors.textSoft,
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
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.panel2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _OtSheetColors.lineSoft,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 24,
                                  color: _OtSheetColors.textSoft,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _otSectionLabel('STUDENT'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _studentController,
                                focusNode: _studentFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _detailsFocus.requestFocus();
                                },
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Name and candidate number',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            _otSectionLabel('DETAILS'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _detailsController,
                                focusNode: _detailsFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _actionFocus.requestFocus();
                                },
                                minLines: 3,
                                maxLines: 5,
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'Describe the incident detail and symptoms...',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            _otSectionLabel('ACTION TAKEN'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _actionController,
                                focusNode: _actionFocus,
                                textInputAction: TextInputAction.done,
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'First aid / support / escalation',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            // Removed error text block
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
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          Expanded(
                            child: _otFilledButton(
                              'Save Entry',
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

class _MalpracticeIncidentDialog extends StatefulWidget {
  const _MalpracticeIncidentDialog({
    required this.initialRoom,
    required this.onSave,
  });

  final String initialRoom;
  final void Function(
    String room,
    String student,
    String details,
    String actionTaken,
  )
  onSave;

  @override
  State<_MalpracticeIncidentDialog> createState() =>
      _MalpracticeIncidentDialogState();
}

class _MalpracticeIncidentDialogState
    extends State<_MalpracticeIncidentDialog> {
  // ignore: non_constant_identifier_names
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);

  final TextEditingController _studentController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  late final FocusNode _studentFocus = FocusNode();
  late final FocusNode _detailsFocus = FocusNode();
  late final FocusNode _actionFocus = FocusNode();

  @override
  void dispose() {
    _studentController.dispose();
    _detailsController.dispose();
    _actionController.dispose();
    _studentFocus.dispose();
    _detailsFocus.dispose();
    _actionFocus.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final String student = _studentController.text.trim();
    final String details = _detailsController.text.trim();
    final String action = _actionController.text.trim();
    return student.isNotEmpty && details.isNotEmpty && action.isNotEmpty;
  }

  void _saveEntry() {
    if (!_isFormValid) return;

    widget.onSave(
      widget.initialRoom,
      _studentController.text.trim(),
      _detailsController.text.trim(),
      _actionController.text.trim(),
    );
  }

  Widget _otSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _OtSheetColors.blueSoft,
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
            backgroundColor: _OtSheetColors.orange,
            disabledBackgroundColor: _OtSheetColors.orange.withValues(
              alpha: 0.45,
            ),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
            side: BorderSide(color: _OtSheetColors.lineSoft),
            backgroundColor: _OtSheetColors.panel2.withValues(alpha: 0.62),
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
                color: _OtSheetColors.blackWhite,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
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
                  maxHeight: media.size.height * 0.82,
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _OtSheetColors.panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _OtSheetColors.line),
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
                      padding: const EdgeInsets.only(top: 8, left: 8, right: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _OtSheetColors.orange.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _OtSheetColors.orange.withValues(
                                  alpha: 0.7,
                                ),
                                width: .7,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: _OtSheetColors.orange,
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
                                    'Malpractice',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: _OtSheetColors.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Record a malpractice concern',
                                  style: TextStyle(
                                    color: _OtSheetColors.textSoft,
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
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.panel2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _OtSheetColors.lineSoft,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 24,
                                  color: _OtSheetColors.textSoft,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.orange.withValues(
                                  alpha: .05,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.orange.withValues(
                                    alpha: 0.7,
                                  ),
                                  width: .7,
                                ),
                              ),
                              child: Text(
                                'Use factual wording only. This records malpractice, not a confirmed outcome.',
                                style: TextStyle(
                                  color: _OtSheetColors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _otSectionLabel('STUDENT'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _studentController,
                                focusNode: _studentFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _detailsFocus.requestFocus();
                                },
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Name and candidate number',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            _otSectionLabel('DETAILS'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _detailsController,
                                focusNode: _detailsFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _actionFocus.requestFocus();
                                },
                                minLines: 3,
                                maxLines: 5,
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'Describe the observed behaviour factually...',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            _otSectionLabel('ACTION TAKEN'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _actionController,
                                focusNode: _actionFocus,
                                textInputAction: TextInputAction.done,
                                cursorColor: _OtSheetColors.blueSoft,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'Reported to EO / evidence retained',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            // Removed error text block
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
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          Expanded(
                            child: _otFilledButton(
                              'Save Entry',
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

class _ToiletVisitIncidentDialog extends StatefulWidget {
  const _ToiletVisitIncidentDialog({
    required this.initialRoom,
    required this.onSave,
  });

  final String initialRoom;
  final void Function(
    String room,
    String student,
    String duration,
    String notes,
    String actionTaken,
  )
  onSave;

  @override
  State<_ToiletVisitIncidentDialog> createState() =>
      _ToiletVisitIncidentDialogState();
}

class _ToiletVisitIncidentDialogState
    extends State<_ToiletVisitIncidentDialog> {
  // ignore: non_constant_identifier_names
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);

  final TextEditingController _studentController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  late final FocusNode _studentFocus = FocusNode();
  late final FocusNode _notesFocus = FocusNode();
  late final FocusNode _actionFocus = FocusNode();

  int _durationMinutes = 5;

  @override
  void dispose() {
    _studentController.dispose();
    _notesController.dispose();
    _actionController.dispose();
    _studentFocus.dispose();
    _notesFocus.dispose();
    _actionFocus.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final String student = _studentController.text.trim();
    final String notes = _notesController.text.trim();
    final String action = _actionController.text.trim();
    return student.isNotEmpty && notes.isNotEmpty && action.isNotEmpty;
  }

  void _saveEntry() {
    if (!_isFormValid) return;

    widget.onSave(
      widget.initialRoom,
      _studentController.text.trim(),
      _durationMinutes.toString(),
      _notesController.text.trim(),
      _actionController.text.trim(),
    );
  }

  Widget _otSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _OtSheetColors.blueSoft,
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _otDurationOptionButton(int mins) {
    final selected = _durationMinutes == mins;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _durationMinutes = mins;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: selected
                ? _OtSheetColors.purple.withValues(alpha: 0.15)
                : _OtSheetColors.panel2.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? _OtSheetColors.purple.withValues(alpha: 0.70)
                  : _OtSheetColors.lineSoft,
              width: .7,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$mins min',
            style: TextStyle(
              color: selected ? _OtSheetColors.purple : _OtSheetColors.textSoft,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
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
            backgroundColor: _OtSheetColors.purple,
            disabledBackgroundColor: _OtSheetColors.purple.withValues(
              alpha: 0.45,
            ),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
            side: BorderSide(color: _OtSheetColors.lineSoft),
            backgroundColor: _OtSheetColors.panel2.withValues(alpha: 0.62),
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
                color: _OtSheetColors.blackWhite,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
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
                  maxHeight: media.size.height * 0.82,
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _OtSheetColors.panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _OtSheetColors.line),
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
                      padding: const EdgeInsets.only(top: 8, left: 8, right: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _OtSheetColors.purple.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _OtSheetColors.purple.withValues(
                                  alpha: 0.70,
                                ),
                                width: .7,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.timer_outlined,
                              color: _OtSheetColors.purple,
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
                                    'Toilet Visit',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: _OtSheetColors.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Record a toilet visit',
                                  style: TextStyle(
                                    color: _OtSheetColors.textSoft,
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
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _OtSheetColors.panel2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _OtSheetColors.lineSoft,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 24,
                                  color: _OtSheetColors.textSoft,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _otSectionLabel('STUDENT'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _studentController,
                                focusNode: _studentFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _notesFocus.requestFocus();
                                },
                                cursorColor: _OtSheetColors.purple,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Name and candidate number',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            _otSectionLabel('TIMING'),
                            const SizedBox(height: 10),
                            Row(
                              spacing: 10,
                              children: [
                                _otDurationOptionButton(5),
                                _otDurationOptionButton(10),
                                _otDurationOptionButton(15),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _notesController,
                                focusNode: _notesFocus,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _actionFocus.requestFocus();
                                },
                                minLines: 3,
                                maxLines: 5,
                                cursorColor: _OtSheetColors.purple,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Time returned / notes',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            _otSectionLabel('ACTION TAKEN'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _OtSheetColors.panel2.withValues(
                                  alpha: 0.30,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _OtSheetColors.lineSoft,
                                ),
                              ),
                              child: TextField(
                                controller: _actionController,
                                focusNode: _actionFocus,
                                textInputAction: TextInputAction.done,
                                cursorColor: _OtSheetColors.purple,
                                style: TextStyle(
                                  color: _OtSheetColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Student escorted / returned',
                                  hintStyle: TextStyle(
                                    color: _OtSheetColors.textSoft.withValues(
                                      alpha: 0.60,
                                    ),
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
                            // Removed error text block
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
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          Expanded(
                            child: _otFilledButton(
                              'Save Entry',
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

class _RoleSelectorDialog extends StatefulWidget {
  const _RoleSelectorDialog({
    required this.initialSelection,
    required this.onSave,
  });

  final String initialSelection;
  final ValueChanged<String> onSave;

  @override
  State<_RoleSelectorDialog> createState() => _RoleSelectorDialogState();
}

class _RoleSelectorDialogState extends State<_RoleSelectorDialog> {
  // ignore: non_constant_identifier_names
  _OtSheetColorPalette get _OtSheetColors => _OtSheetColorPalette(context);
  late String _selection = widget.initialSelection;

  void _save(String role) {
    widget.onSave(role);
    Navigator.pop(context);
  }

  Widget _selectionRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? _OtSheetColors.blue.withValues(alpha: 0.15)
              : _OtSheetColors.panel2.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _OtSheetColors.blue.withValues(alpha: 0.70)
                : _OtSheetColors.lineSoft,
            width: .7,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _OtSheetColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _OtSheetColors.blueSoft : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: selected
                  ? Icon(
                      Icons.check,
                      color: _OtSheetColors.blue,
                      size: 18,
                      fontWeight: FontWeight.w700,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _OtSheetColors.panel,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _OtSheetColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _OtSheetColors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _OtSheetColors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.badge_outlined,
                          color: _OtSheetColors.blueSoft,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Set Up Role",
                              style: TextStyle(
                                color: _OtSheetColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Select the role completing setup",
                              style: TextStyle(
                                color: _OtSheetColors.textSoft,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Close',
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _OtSheetColors.panel2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _OtSheetColors.lineSoft,
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 24,
                              color: _OtSheetColors.textSoft,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      for (final role in kAllowedSetUpRoles)
                        _selectionRow(
                          label: role,
                          selected: _selection == role,
                          onTap: () => _save(role),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupedMessage {
  final String text;
  final List<String> recipients;
  final DateTime time;
  final bool isToMessage;

  _GroupedMessage({
    required this.text,
    required this.recipients,
    required this.time,
    required this.isToMessage,
  });
}
