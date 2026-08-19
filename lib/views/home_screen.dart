import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../enums/exam_phase.dart';
import '../models/exam_card_data.dart';
import '../models/incident.dart';
import '../models/home_list_item.dart';
import '../services/license_service.dart';
import '../services/session_service.dart';
import '../utils/constants.dart';
import '../utils/safe_navigator.dart';
import '../utils/export_logs.dart';
import '../utils/id_generator.dart';
import 'briefings_library_sheet.dart';
import 'license_activation_screen.dart';
import '../utils/notifications.dart';
import 'officer_tools_screen.dart';
import 'widgets/add_exam_sheet.dart';
import 'widgets/import_flow_sheet.dart';
import 'widgets/confirmation_dialog.dart';
import 'widgets/exam_card_widget.dart';
import 'widgets/footer_widget.dart';
import 'widgets/home_empty_state_widget.dart';
import 'widgets/filtered_empty_state_widget.dart';
import 'widgets/license_required_view.dart';
import 'widgets/stat_chip_widget.dart';
import 'widgets/vigilo_date_picker.dart';
import 'widgets/vigilo_time_picker.dart';
import 'widgets/vigilo_duration_picker.dart';
import 'widgets/session_manager_panel.dart';
import 'widgets/vigilo_date_jump_sheet.dart';
import 'widgets/speed_dial_option.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dark,
    required this.onToggleTheme,
  });

  final bool dark;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final List<ExamCardData> _cards = [];
  final List<ExamCardData> _archiveCards = [];
  List<String> _lastImportedSessionIds = [];
  final SessionService _sessionService = SessionService();
  final Set<String> _normalTimeWarningVibrationSent = <String>{};
  final Set<String> _extraTimeWarningVibrationSent = <String>{};
  bool _tickInFlight = false;
  bool _isAdjustingProgress = false;

  List<String> _getUniqueInvigilators(ExamCardData s) {
    if (s.scheduleList != null && s.scheduleList!.isNotEmpty) {
      final names = s.scheduleList!
          .expand((p) => p.invigilators)
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return names;
    }
    if (s.invigilatorsSnapshot.trim().isNotEmpty) {
      final names = s.invigilatorsSnapshot
          .replaceAll('\r', '\n')
          .split(RegExp(r'[\n,;|.]+'))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return names;
    }
    return const [];
  }

  int get allInvigilators {
    int total = 0;
    for (final s in _cards) {
      if ((s.running || s.isPaused) && s.phase != ExamPhase.finished) {
        total += _getUniqueInvigilators(s).length;
      }
    }
    return total;
  }

  // Last-used for wizard prefill
  String? _lastSchool,
      _lastCentre,
      _lastSubject,
      _lastBoard,
      _lastLevel,
      _lastStart,
      _lastDuration,
      _lastExtra;

  late final AnimationController _pulse;
  Future<void>? _activeSaveFuture;
  Timer? _ticker;
  Timer? _extraPulseTicker;
  Timer? _clickTimer;
  bool _licenseLoaded = false;
  bool _licenseRequired = true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fabDialCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fabDialAnim = CurvedAnimation(
      parent: _fabDialCtrl,
      curve: Curves.easeOutBack,
    );
    WidgetsBinding.instance.addObserver(this);
    _initializeHomeState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _extraPulseTicker = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) setState(() => extraPulse = !extraPulse);
    });
  }

  Future<void> _initializeHomeState() async {
    await _sessionService.initialize();
    if (!mounted) return;
    await _loadState();
    if (!mounted) return;
    await _clearLegacyLicenceCentrePrefillIfNeeded();
    if (!mounted) return;
    await _seedOrganizationFromLicenseIfNeeded();
    if (!mounted) return;
    await _loadLicenseStatus();
  }

  Future<void> _saveState() async {
    final completer = Completer<void>();
    final previousFuture = _activeSaveFuture;
    _activeSaveFuture = completer.future;

    if (previousFuture != null) {
      try {
        await previousFuture;
      } catch (_) {}
    }

    try {
      final persisted = await _sessionService.persistHomeState(
        cards: _cards,
        archiveCards: _archiveCards,
        lastUsed: {
          'school': _lastSchool,
          'centre': _lastCentre,
          'subject': _lastSubject,
          'board': _lastBoard,
          'start': _lastStart,
          'duration': _lastDuration,
          'extra': _lastExtra,
        },
      );
      if (!mounted) return;
      setState(() {
        final currentCards = List<ExamCardData>.from(_cards);
        final currentArchiveCards = List<ExamCardData>.from(_archiveCards);
        _cards
          ..clear()
          ..addAll(
            _preserveTransientCardState(
              previous: currentCards,
              incoming: persisted.cards,
            ),
          );
        _archiveCards
          ..clear()
          ..addAll(
            _preserveTransientCardState(
              previous: currentArchiveCards,
              incoming: persisted.archiveCards,
            ),
          );
        _lastSchool = persisted.lastUsed['school'];
        _lastCentre = persisted.lastUsed['centre'];
        _lastSubject = persisted.lastUsed['subject'];
        _lastBoard = persisted.lastUsed['board'];
        _lastStart = persisted.lastUsed['start'];
        _lastDuration = persisted.lastUsed['duration'];
        _lastExtra = persisted.lastUsed['extra'];
      });
    } finally {
      completer.complete();
    }
  }

  Future<void> _refreshCards() async {
    final state = await _sessionService.loadHomeState();
    final lastImportIds = await _sessionService.getLastImportedSessionIds();
    final activeIds = state.cards
        .map((card) => card.recordId)
        .whereType<String>()
        .toSet();
    _normalTimeWarningVibrationSent.retainAll(activeIds);
    _extraTimeWarningVibrationSent.retainAll(activeIds);
    if (!mounted) return;
    setState(() {
      _lastImportedSessionIds = lastImportIds;
      final previousCards = List<ExamCardData>.from(_cards);
      final previousArchiveCards = List<ExamCardData>.from(_archiveCards);
      _cards
        ..clear()
        ..addAll(
          _preserveTransientCardState(
            previous: previousCards,
            incoming: state.cards,
          ),
        );
      _archiveCards
        ..clear()
        ..addAll(
          _preserveTransientCardState(
            previous: previousArchiveCards,
            incoming: state.archiveCards,
          ),
        );
      _lastSchool = state.lastUsed['school'];
      _lastCentre = state.lastUsed['centre'];
      _lastSubject = state.lastUsed['subject'];
      _lastBoard = state.lastUsed['board'];
      _lastStart = state.lastUsed['start'];
      _lastDuration = state.lastUsed['duration'];
      _lastExtra = state.lastUsed['extra'];
      _updateFilteredAndGroupedCards();
    });
  }

  Future<void> _loadState() async {
    final state = await _sessionService.loadHomeState();
    final lastImportIds = await _sessionService.getLastImportedSessionIds();
    if (!mounted) return;
    setState(() {
      _lastImportedSessionIds = lastImportIds;
      _cards
        ..clear()
        ..addAll(state.cards);
      for (int i = 0; i < _cards.length; i++) {
        _cards[i] = _cards[i].copyWith(expanded: false);
      }
      _archiveCards
        ..clear()
        ..addAll(state.archiveCards);
      _lastSchool = state.lastUsed['school'];
      _lastCentre = state.lastUsed['centre'];
      _lastSubject = state.lastUsed['subject'];
      _lastBoard = state.lastUsed['board'];
      _lastStart = state.lastUsed['start'];
      _lastDuration = state.lastUsed['duration'];
      _lastExtra = state.lastUsed['extra'];
      _updateFilteredAndGroupedCards();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _sessionService.checkpoint();
    } else if (state == AppLifecycleState.resumed) {
      _loadLicenseStatus();
    }
  }

  Future<void> _loadLicenseStatus() async {
    final required = await LicenseService.requiresValidLicense();
    if (!mounted) return;
    setState(() {
      _licenseRequired = required;
      _licenseLoaded = true;
    });
  }

  Future<void> _seedOrganizationFromLicenseIfNeeded() async {
    final snapshot = await LicenseService.getSnapshot();
    final organizationName = _readText(snapshot.organizationName);
    if (organizationName == null || _readText(_lastSchool) != null) {
      return;
    }

    _lastSchool = organizationName;
    await _saveState();
  }

  Future<void> _clearLegacyLicenceCentrePrefillIfNeeded() async {
    final storedCentre = _readText(_lastCentre);
    if (storedCentre == null) return;

    final snapshot = await LicenseService.getSnapshot();
    final licenceCode = _readText(snapshot.organizationCode);
    if (licenceCode == null) return;

    final normalizedStoredCentre = LicenseService.sanitizeOrganizationCode(
      storedCentre,
    );
    final normalizedLicenceCode = LicenseService.sanitizeOrganizationCode(
      licenceCode,
    );
    if (normalizedStoredCentre.isEmpty ||
        normalizedStoredCentre != normalizedLicenceCode) {
      return;
    }

    final storedSchool = _normalizedTextForComparison(_lastSchool);
    final licenceSchool = _normalizedTextForComparison(
      snapshot.organizationName,
    );
    final namesMatch =
        storedSchool == null ||
        licenceSchool == null ||
        storedSchool == licenceSchool;
    final anyExplicitCentreNumber = [
      ..._cards,
      ..._archiveCards,
    ].any((card) => card.centreNumber.trim().isNotEmpty);
    if (!namesMatch || anyExplicitCentreNumber) return;

    _lastCentre = null;
    await _saveState();
  }

  String? _readText(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? _normalizedTextForComparison(String? raw) {
    final value = _readText(raw);
    if (value == null) return null;
    return value.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    _fabDialCtrl.dispose();
    _ticker?.cancel();
    _extraPulseTicker?.cancel();
    _clickTimer?.cancel();
    super.dispose();
  }

  // ── Speed Dial FAB helpers ───────────────────────────────────────────────
  // Tap FAB → speed dial opens (icon rotates 45°, label → "Close",
  // backdrop dims). Tap again → closes.
  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    _fabOpen ? _fabDialCtrl.forward() : _fabDialCtrl.reverse();
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _fabDialCtrl.reverse();
    }
  }

  // ---- recompute helpers ----
  int _toMin(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  bool _isValidHHMM(String value, {bool allowZero = true}) {
    final trimmed = value.trim();
    final match = RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmed);
    if (!match) return false;
    final parts = trimmed.split(':');
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return false;
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return false;
    if (!allowZero && hh == 0 && mm == 0) return false;
    return true;
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

  String _m2s(int m) {
    final h = (m ~/ 60) % 24; // wrap hours at 24
    final mm = m % 60;
    return "${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}";
  }

  String _formatExtraTimeUpdateReason({
    required int previousMinutes,
    required int updatedMinutes,
  }) {
    final diffMinutes = updatedMinutes - previousMinutes;
    final sign = diffMinutes >= 0 ? '+' : '';
    return 'Extra Time Updated (${previousMinutes}m -> ${updatedMinutes}m, $sign${diffMinutes}m)';
  }

  String _formatNormalTimeUpdateReason({
    required int previousMinutes,
    required int updatedMinutes,
  }) {
    final diffMinutes = updatedMinutes - previousMinutes;
    final sign = diffMinutes >= 0 ? '+' : '';
    return 'Normal Time Updated (${previousMinutes}m -> ${updatedMinutes}m, $sign${diffMinutes}m)';
  }

  ExamCardData _recompute(ExamCardData c) {
    final startM = _toMin(c.normalStart);
    final normM = _toMin(c.normalDuration);
    final extraM = _toMin(c.extraTime);
    final endM = startM + normM;
    final totalM = normM + extraM;
    final extraEndM = startM + totalM;

    return c.copyWith(
      start: c.normalStart,
      duration: c.normalDuration,
      end: _m2s(endM),
      normalEnd: _m2s(endM),
      totalDuration: _m2s(totalM),
      extraEnd: _m2s(extraEndM),
    );
  }

  ExamPhase _phaseForProgress(ExamCardData c, double progress) {
    final totalSeconds = c.totalSeconds;
    if (totalSeconds <= 0) {
      return ExamPhase.normal;
    }
    final clamped = progress.clamp(0.0, 1.0);
    final elapsedSeconds = (clamped * totalSeconds).round();
    if (elapsedSeconds >= totalSeconds) {
      return ExamPhase.finished;
    }
    if (elapsedSeconds < c.normalSeconds) {
      return ExamPhase.normal;
    }
    return ExamPhase.extra;
  }

  ExamCardData _applyManualProgress(ExamCardData c, double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    return c.copyWith(
      progress: clamped,
      phase: _phaseForProgress(c, clamped),
      autoStart: false,
      autoStartUserModified: true,
    );
  }

  ExamCardData _mergeOfficerToolsUpdate({
    required ExamCardData current,
    required ExamCardData updated,
  }) {
    return updated.copyWith(
      running: current.running,
      isPaused: current.isPaused,
      epochStart: current.epochStart,
      pausedSeconds: current.pausedSeconds,
      progress: current.progress,
      phase: current.phase,
      autoStart: current.autoStart,
      autoStartUserModified: current.autoStartUserModified,
      expanded: current.expanded,
      isSelected: current.isSelected,
      tapScale: current.tapScale,
      isActiveTime: current.isActiveTime,
      wasEverStarted: current.wasEverStarted,
    );
  }

  List<ExamCardData> _preserveTransientCardState({
    required List<ExamCardData> previous,
    required List<ExamCardData> incoming,
  }) {
    if (previous.isEmpty || incoming.isEmpty) {
      return incoming.map((c) => c.copyWith(expanded: false)).toList();
    }

    final previousById = <String, ExamCardData>{
      for (final card in previous)
        if (card.recordId != null) card.recordId!: card,
    };

    return incoming.map((card) {
      final id = card.recordId;
      if (id == null) return card;
      final prior = previousById[id];
      if (prior == null) return card;
      return card.copyWith(
        expanded: prior.expanded,
        isSelected: prior.isSelected,
        tapScale: prior.tapScale,
        isActiveTime: prior.isActiveTime,
      );
    }).toList();
  }

  DateTime? _scheduledDateTime(ExamCardData c) {
    try {
      final dp = c.date.split('/');
      final tp = c.normalStart.split(':');
      final d = int.parse(dp[0]);
      final m = int.parse(dp[1]);
      final y = int.parse(dp[2]);
      final hh = int.parse(tp[0]);
      final mm = int.parse(tp[1]);
      return DateTime(y, m, d, hh, mm);
    } catch (_) {
      return null;
    }
  }

  void _tick() {
    if (!mounted) return;
    if (_licenseRequired || _tickInFlight || _isAdjustingProgress) return;
    _tickInFlight = true;
    _tickAsync().whenComplete(() {
      _tickInFlight = false;
    });
  }

  Future<void> _tickAsync() async {
    if (!mounted) return;
    final now = DateTime.now();
    bool autoStartTriggered = false;

    for (final card in List<ExamCardData>.from(_cards)) {
      if (card.running || card.isPaused || card.phase == ExamPhase.finished) {
        continue;
      }
      if (!card.autoStart || card.progress != 0.0) continue;

      final sched = _scheduledDateTime(card);
      if (sched == null || now.isBefore(sched)) continue;
      final recordId = card.recordId;
      if (recordId == null) continue;
      final totalSeconds = card.totalSeconds;
      DateTime effectiveStart = now;
      if (totalSeconds > 0) {
        final elapsedSinceScheduled = now.difference(sched).inSeconds;
        if (elapsedSinceScheduled > 0 && elapsedSinceScheduled < totalSeconds) {
          effectiveStart = sched;
        }
      }

      await _sessionService.startSession(
        examRecordId: recordId,
        startedAt: effectiveStart,
        autoStart: true,
        normalDurationMs: card.normalSeconds * 1000,
        extraTimeMs: card.extraSeconds * 1000,
      );
      autoStartTriggered = true;
    }

    final ended = await _sessionService.autoEndIfNeeded();
    if (autoStartTriggered || ended) {
      await _refreshCards();
      await _vibrateForTenMinutesBeforeNormalEnd();
      await _vibrateForTenMinutesBeforeExtraEnd();
      return;
    }

    // UI tick refresh only; no per-second persistence.
    await _refreshCards();
    await _vibrateForTenMinutesBeforeNormalEnd();
    await _vibrateForTenMinutesBeforeExtraEnd();
  }

  int _elapsedSecondsForWarning(ExamCardData card) {
    if (card.totalSeconds <= 0) return 0;
    final elapsed = (card.progress * card.totalSeconds).round();
    return elapsed.clamp(0, card.totalSeconds);
  }

  Future<void> _vibrateForTenMinutesBeforeNormalEnd() async {
    bool shouldVibrate = false;

    for (final current in _cards) {
      final id = current.recordId;
      if (id == null) continue;
      if (!current.vibrateOn) continue;
      if (_normalTimeWarningVibrationSent.contains(id)) continue;
      if (!current.running && !current.isPaused && current.progress <= 0.0) {
        continue;
      }

      final normalSeconds = current.normalSeconds;
      if (normalSeconds <= 0) continue;

      final thresholdSeconds = (normalSeconds - 600).clamp(0, normalSeconds);
      final currentElapsedSeconds = _elapsedSecondsForWarning(current);
      if (currentElapsedSeconds >= normalSeconds) continue;
      if (currentElapsedSeconds < thresholdSeconds) continue;

      _normalTimeWarningVibrationSent.add(id);
      shouldVibrate = true;
    }

    if (!shouldVibrate) return;
    await _triggerWarningVibration();
  }

  Future<void> _vibrateForTenMinutesBeforeExtraEnd() async {
    bool shouldVibrate = false;

    for (final current in _cards) {
      final id = current.recordId;
      if (id == null) continue;
      if (!current.vibrateOn) continue;
      if (_extraTimeWarningVibrationSent.contains(id)) continue;
      if (!current.running && !current.isPaused && current.progress <= 0.0) {
        continue;
      }

      final extraSeconds = current.extraSeconds;
      if (extraSeconds <= 0) continue;

      final totalSeconds = current.totalSeconds;
      final thresholdSeconds = (totalSeconds - 600).clamp(
        current.normalSeconds,
        totalSeconds,
      );
      final currentElapsedSeconds = _elapsedSecondsForWarning(current);
      if (currentElapsedSeconds >= totalSeconds) continue;
      if (currentElapsedSeconds < thresholdSeconds) continue;

      _extraTimeWarningVibrationSent.add(id);
      shouldVibrate = true;
    }

    if (!shouldVibrate) return;
    await _triggerWarningVibration();
  }

  Future<void> _triggerWarningVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(pattern: const [0, 350, 150, 350, 150, 500]);
        return;
      }
    } catch (_) {}

    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  void _toggleExpanded(int i) {
    if (i < 0 || i >= _cards.length) return;
    setState(() {
      for (int j = 0; j < _cards.length; j++) {
        if (j == i) {
          _cards[j] = _cards[j].copyWith(expanded: !_cards[j].expanded);
        } else {
          _cards[j] = _cards[j].copyWith(expanded: false);
        }
      }
      _updateFilteredAndGroupedCards();
    });
  }

  void _toast(
    String title, [
    String? subtitle,
    IconData? icon,
    NotificationType type = NotificationType.information,
  ]) {
    NotificationService.show(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon ?? Icons.info_outline_rounded,
      type: type,
    );
  }

  void _log(ExamCardData data, Incident inc) {
    final recordId = data.recordId;
    if (recordId == null) return;
    _sessionService
        .appendIncident(examRecordId: recordId, incident: inc)
        .then((_) => _refreshCards());
  }

  Future<void> _openLicenseActivation() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LicenseActivationScreen()));
    await _seedOrganizationFromLicenseIfNeeded();
    await _loadLicenseStatus();
  }

  bool _isProcessingRestart = false;

  Future<void> _onReStart(int i) async {
    if (_isProcessingRestart) return;
    _isProcessingRestart = true;
    try {
      final c = _cards[i];
      final recordId = c.recordId;
      if (recordId == null) {
        _toast(
          "Not Ready",
          "Complete exam setup before starting",
          Icons.warning_amber_rounded,
          NotificationType.warning,
        );
        return;
      }
      if (c.totalSeconds <= 0) {
        _toast(
          "Missing Information",
          "Set the exam duration before starting",
          Icons.warning_amber_rounded,
          NotificationType.warning,
        );
        return;
      }

      final now = DateTime.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      _cards[i] = _recompute(
        c.copyWith(
          normalStart: "$hh:$mm",
          progress: 0.0,
          phase: ExamPhase.normal,
          running: false,
          isPaused: false,
          epochStart: null,
          pausedSeconds: 0,
        ),
      );
      await _saveState();
      await _sessionService.startSession(
        examRecordId: recordId,
        startedAt: now,
        restart: true,
        normalDurationMs: _cards[i].normalSeconds * 1000,
        extraTimeMs: _cards[i].extraSeconds * 1000,
      );
      _normalTimeWarningVibrationSent.remove(recordId);
      _extraTimeWarningVibrationSent.remove(recordId);
      await _refreshCards();
      _toast(
        "Exam Restarted",
        "The exam timer has been reset",
        Icons.restart_alt_rounded,
        NotificationType.information,
      );
      if (mounted) context.safePop();
    } finally {
      _isProcessingRestart = false;
    }
  }

  bool _isProcessingPause = false;

  Future<void> _onPause(int i) async {
    if (_isProcessingPause) return;
    _isProcessingPause = true;
    try {
      final c = _cards[i];
      final recordId = c.recordId;
      if (recordId == null) return;

      if (c.isPaused) {
        await _sessionService.resumeSession(recordId);
        _toast(
          "Exam Resumed",
          "The exam timer has resumed",
          Icons.play_circle_fill_rounded,
          NotificationType.success,
        );
      } else {
        await _sessionService.pauseSession(recordId);
        _toast(
          "Exam Paused",
          "The exam timer has been paused",
          Icons.pause_circle_filled_rounded,
          NotificationType.information,
        );
      }

      await _refreshCards();
      if (mounted) context.safePop();
    } finally {
      _isProcessingPause = false;
    }
  }

  bool _isProcessingEnd = false;

  Future<void> _onEnd(int i) async {
    if (_isProcessingEnd) return;
    _isProcessingEnd = true;
    try {
      final c = _cards[i];
      final recordId = c.recordId;
      if (recordId == null) return;
      await _sessionService.endSession(
        recordId,
        manual: true,
        reason: 'manual_end',
      );
      await _refreshCards();
      _toast(
        "Exam ended",
        "The exam has been marked as finished",
        Icons.stop_circle_rounded,
        NotificationType.success,
      );
      if (mounted) context.safePop();
    } finally {
      _isProcessingEnd = false;
    }
  }

  // ------------------ Quick Add Wizard ------------------
  (int, int) _parseHHMM(String s) {
    final p = s.split(':');
    return ((int.tryParse(p[0]) ?? 0), (int.tryParse(p[1]) ?? 0));
  }

  Future<void> _openQuickAddWizard() async {
    final Map<String, String> knownCentres = {};
    debugPrint(
      "[QuickAdd] Building knownCentres map from ${_archiveCards.length} archive cards and ${_cards.length} active cards...",
    );
    for (final card in [..._archiveCards.reversed, ..._cards.reversed]) {
      final school = card.school.trim();
      final centre = card.resolvedCentreNumber.trim();
      if (school.isNotEmpty && centre.isNotEmpty) {
        knownCentres[school] = centre;
        debugPrint("[QuickAdd] Mapped from card: '$school' -> '$centre'");
      }
    }
    if (_lastSchool != null &&
        _lastSchool!.trim().isNotEmpty &&
        _lastCentre != null &&
        _lastCentre!.trim().isNotEmpty) {
      knownCentres[_lastSchool!.trim()] = _lastCentre!.trim();
      debugPrint(
        "[QuickAdd] Mapped from last session variables: '${_lastSchool!.trim()}' -> '${_lastCentre!.trim()}'",
      );
    }
    debugPrint("[QuickAdd] Final knownCentres map: $knownCentres");

    setState(() {
      _lastSchool = null;
      _lastCentre = null;
      _lastSubject = null;
      _lastBoard = null;
      _lastLevel = null;
      _lastStart = null;
      _lastDuration = null;
      _lastExtra = null;
    });

    // Prefill school from license snapshot in-memory (no DB write needed here —
    // the real _saveState happens when the user actually saves an exam).
    final snapshot = await LicenseService.getSnapshot();
    final orgName = _readText(snapshot.organizationName);
    if (orgName != null) _lastSchool = orgName;
    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExamSheet(
        lastSchool: _lastSchool,
        lastCentre: _lastCentre,
        lastSubject: _lastSubject,
        lastBoard: _lastBoard,
        lastLevel: _lastLevel,
        lastStart: _lastStart,
        lastDuration: _lastDuration,
        lastExtra: _lastExtra,
        knownCentres: knownCentres,
        onSave:
            ({
              required String school,
              required String centre,
              required String subject,
              required String board,
              String? level,
              required DateTime date,
              required String startTime,
              required String duration,
              required String extraTime,
            }) async {
              final normalizedStart = _normalizeHHMM(
                startTime,
                fallback: "09:00",
              );
              final normalizedDuration = _normalizeHHMM(
                duration,
                fallback: "01:30",
                allowZero: false,
              );
              final normalizedExtra = _normalizeHHMM(
                extraTime,
                fallback: "00:15",
              );

              if (_toMin(normalizedDuration) <= 0) {
                _toast(
                  "Invalid Duration",
                  "Set a valid exam duration before saving",
                  Icons.warning_amber_rounded,
                  NotificationType.error,
                );
                return;
              }

              final dd = date.day.toString().padLeft(2, '0');
              final mm = date.month.toString().padLeft(2, '0');
              final yy = date.year.toString();


              var newCard = ExamCardData(
                recordId: generateId(),
                school: school,
                centreNumber: centre,
                date: "$dd/$mm/$yy",
                subject: "$subject ($board)",
                examLevel: (level?.trim().isEmpty ?? true)
                    ? null
                    : level!.trim(),
                start: normalizedStart,
                duration: normalizedDuration,
                end: normalizedStart,
                normalStart: normalizedStart,
                normalDuration: normalizedDuration,
                normalEnd: normalizedStart,
                extraTime: normalizedExtra,
                totalDuration: "00:00",
                extraEnd: normalizedStart,
                expanded: false,
                autoStart: false,
              );
              newCard = _recompute(newCard);

              setState(() {
                _cards.insert(0, newCard);
                _lastSchool = null;
                _lastCentre = null;
                _lastSubject = null;
                _lastBoard = null;
                _lastLevel = null;
                _lastStart = null;
                _lastDuration = null;
                _lastExtra = null;
                _updateFilteredAndGroupedCards();
              });
              await _saveState();
              if (!mounted) return;
              context.safePop(true);
            },
      ),
    );

    if (result == true) {
      _toast(
        "Exam Created",
        "New exam successfully created",
        Icons.check_circle_rounded,
        NotificationType.success,
      );
    }
  }

  Future<String> pickDur(String time, String title) async {
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) =>
          VigiloDurationPickerSheet(initialDuration: time, title: title),
    );
    return res ?? "";
  }

  int get _activeExamCount => _cards
      .where((c) => (c.running || c.isPaused) && c.phase != ExamPhase.finished)
      .length;

  bool _isArchivableExam(ExamCardData card) {
    final isFinished = card.phase == ExamPhase.finished || card.progress >= 1.0;
    // Also allow archiving date-passed exams (never started, date elapsed).
    return (!card.running && !card.isPaused && isFinished) || card.isLocked;
  }

  int get _archivableExamCount => _cards.where(_isArchivableExam).length;

  // int get _incidentsToday {
  //   final now = DateTime.now();
  //   final start = DateTime(now.year, now.month, now.day);
  //   final end = start.add(const Duration(days: 1));
  //   int count = 0;
  //   for (final list in _logs.values) {
  //     count += list
  //         .where((i) => i.time.isAfter(start) && i.time.isBefore(end))
  //         .length;
  //   }
  //   return count;
  // }

  bool get anyOpen => _cards.any((e) => e.expanded);
  bool isArchiveMode = false;
  bool isArchiveView = false;

  bool extraPulse = false;

  // ── Session Manager Filter state ──────────────────────────────────────────
  String _statusFilter = 'All';
  String _dateFilter = 'All';
  bool _showSessionMgr = false;
  String? _highlightedDate;
  final Map<String, GlobalKey> _dateKeys = {};

  // ── Speed Dial FAB state ─────────────────────────────────────────────────
  bool _fabOpen = false;
  late AnimationController _fabDialCtrl;
  late Animation<double> _fabDialAnim;

  @override
  Widget build(BuildContext context) {
    final sig = _computeCardsSignature();
    if (sig != _lastCardsSignature) {
      _lastCardsSignature = sig;
      _updateFilteredAndGroupedCards();
    }
    final dark = widget.dark;

    if (!_licenseLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openLicenseActivation,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text('Vigilo ERC'),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_licenseRequired) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openLicenseActivation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                'Vigilo ERC',
                style: TextStyle(
                  color: VigiloUiColors.text(dark),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          actions: [
            _headerIcon(
              dark,
              dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
              onTap: widget.onToggleTheme,
            ),
            const SizedBox(width: 20),
          ],
        ),
        body: const LicenseRequiredView(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VigiloUiColors.bg(dark),
            VigiloUiColors.bg2(dark),
            VigiloUiColors.bg(dark),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: AnimatedSlide(
          offset: anyOpen ? const Offset(0, 2) : Offset.zero,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: anyOpen ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            // Speed Dial FAB: expands to reveal Import / Create options
            child: FloatingActionButton.extended(
              tooltip: _fabOpen ? 'Close' : 'Add Exam',
              elevation: 4,
              backgroundColor: VigiloUiColors.blue(dark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onPressed: _toggleFab,
              icon: AnimatedRotation(
                turns: _fabOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.add, size: 16),
              ),
              label: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _fabOpen ? 'Close' : 'Exam',
                  key: ValueKey(_fabOpen),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: FooterWidget(
              onVibrate: () async {
                if (!isArchiveView) {
                  int i = getExpandedCardIndex();
                  if (i != -1) {
                    final c = _cards[i];
                    final nowOn = !c.vibrateOn;
                    setState(() => _cards[i] = c.copyWith(vibrateOn: nowOn));
                    _saveState();
                    if (nowOn) {
                      try {
                        _toast(
                          "Vibration Enabled",
                          "Vibration is on for this exam",
                          Icons.vibration_rounded,
                          NotificationType.success,
                        );
                        await HapticFeedback.vibrate();
                      } catch (_) {}
                    } else {
                      _toast(
                        "Vibration Disabled",
                        "Vibration is off for this exam",
                        Icons.phonelink_erase_rounded,
                        NotificationType.information,
                      );
                    }
                  } else {
                    _toast(
                      "Action Required",
                      "Open an exam to use Vibrate",
                      Icons.touch_app_rounded,
                      NotificationType.warning,
                    );
                  }
                }
              },
              onArchive: () {
                if (!isArchiveView) {
                  if (isArchiveMode) {
                    int archivedCount = 0;
                    final remaining = <ExamCardData>[];
                    for (final item in _cards) {
                      if (item.isSelected && _isArchivableExam(item)) {
                        _archiveCards.add(
                          item.copyWith(isSelected: false, expanded: false),
                        );
                        archivedCount++;
                      } else {
                        remaining.add(item.copyWith(isSelected: false));
                      }
                    }
                    _cards
                      ..clear()
                      ..addAll(remaining);
                    _saveState();
                    if (archivedCount > 0) {
                      _toast(
                        archivedCount == 1
                            ? "Exam archived"
                            : "$archivedCount exams archived",
                        null,
                        Icons.archive_rounded,
                        NotificationType.success,
                      );
                    } else {
                      _toast(
                        "Archive Failed",
                        "No finished selected exams to archive",
                        Icons.archive_rounded,
                        NotificationType.error,
                      );
                    }
                    _toast(
                      "Archive Mode",
                      "Archive mode has been disabled",
                      Icons.archive_outlined,
                      NotificationType.information,
                    );
                    isArchiveMode = false;
                    setState(() {});
                    return;
                  }

                  if (_cards.isEmpty) {
                    _toast(
                      "Archive Failed",
                      "No exams available to archive",
                      Icons.archive_rounded,
                      NotificationType.error,
                    );
                    return;
                  }
                  if (_archivableExamCount == 0) {
                    _toast(
                      "Action Restricted",
                      "Only finished exams can be archived",
                      Icons.block_rounded,
                      NotificationType.error,
                    );
                    return;
                  }
                  _toast(
                    "Archive Mode",
                    "Tap finished exams to archive them",
                    Icons.archive_rounded,
                    NotificationType.information,
                  );
                  isArchiveMode = true;
                  setState(() {});
                }
              },
              onBriefings: () async {
                await showBriefingsLibrarySheet(context);
              },
              onOfficerTools: () {
                if (!isArchiveView) {
                  int i = getExpandedCardIndex();
                  if (i != -1) {
                    final c = _cards[i];
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      builder: (_) => OfficerToolsSheet(
                        data: _cards[i],
                        isExamCompleted: _cards[i].phase == ExamPhase.finished,
                        onLog: (inc) {
                          _log(_cards[i], inc);
                        },
                        onSaveData: _saveState,
                        onReStart: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => confirmationDialog(
                              context: ctx,
                              title: "Restart Exam?",
                              message: _cards[i].progress == 0.0
                                  ? 'The exam has not started yet. You cannot restart it'
                                  : _cards[i].phase == ExamPhase.finished
                                  ? 'This exam has already been completed. Restarting or modifying it is not allowed'
                                  : "This will restart the exam from the beginning",
                              okTitle: "Restart",
                              onCancel: () => ctx.safePop(false),
                              onConfirm: () => ctx.safePop(true),
                              shouldNotRestart:
                                  _cards[i].progress == 0.0 ||
                                  _cards[i].phase == ExamPhase.finished,
                            ),
                          );
                          if (ok == true) {
                            await _onReStart(i);
                          }
                        },
                        onPause: () {
                          _onPause(i);
                        },
                        onEnd: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => confirmationDialog(
                              context: ctx,
                              title: "End Exam ?",
                              message:
                                  "This action will end the exam session and record the final finish time",
                              okTitle: "End Exam",
                              onCancel: () => ctx.safePop(false),
                              onConfirm: () => ctx.safePop(true),
                            ),
                          );
                          if (ok == true) {
                            await _onEnd(i);
                          }
                        },
                        onExportCopy: () => exportCopy(_cards[i], context),
                        onExportCsvDownload: () =>
                            exportCsvDownload(_cards[i], context),
                        onExportCsvShare: () =>
                            exportCsvShare(_cards[i], context),
                        onToggleAutoStart: (v) {
                          setState(
                            () => _cards[i] = _cards[i].copyWith(
                              autoStart: v,
                              autoStartUserModified: true,
                            ),
                          );
                          if (v) {
                            _toast(
                              "Auto-Start Enabled",
                              "The exam will auto-start at the scheduled time",
                              Icons.timer_rounded,
                              NotificationType.success,
                            );
                          } else {
                            _toast(
                              "Auto-Start Disabled",
                              "Auto start is off",
                              Icons.timer_off_rounded,
                              NotificationType.information,
                            );
                          }
                          _saveState();
                        },
                        onUpdateData: (updated) {
                          if (!mounted || i < 0 || i >= _cards.length) return;
                          final current = _cards[i];
                          _cards[i] = _mergeOfficerToolsUpdate(
                            current: current,
                            updated: updated,
                          );
                          _saveState();
                        },
                        onDeleteData: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => confirmationDialog(
                              context: ctx,
                              title: "Delete Exam Data",
                              message:
                                  "This action will permanently remove data for this exam only",
                              okTitle: "Delete",
                              onCancel: () => ctx.safePop(false),
                              onConfirm: () => ctx.safePop(true),
                            ),
                          );
                          if (!context.mounted) return;
                          if (ok == true) {
                            final deleteRecordId = c.recordId;
                            if (deleteRecordId != null) {
                              _cards.removeWhere(
                                (card) => card.recordId == deleteRecordId,
                              );
                            } else if (i >= 0 && i < _cards.length) {
                              _cards.removeAt(i);
                            }
                            context.safePop();
                            _saveState();
                            setState(() {});
                          }
                        },
                      ),
                    );
                  } else {
                    _toast(
                      "Action Required",
                      "Open an exam to use Officer Tools",
                      Icons.touch_app_rounded,
                      NotificationType.warning,
                    );
                  }
                }
              },
              isVibrateOn: checkVibrateOn(),
              isArchiveMode: isArchiveMode,
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _header(dark),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: StatChip(
                      invigilatorsOnDuty: allInvigilators,
                      activeExams: isArchiveView
                          ? _archiveCards.length
                          : _activeExamCount,
                      isArchiveView: isArchiveView,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    clipBehavior: Clip.hardEdge,
                    child: _showSessionMgr
                        ? SessionManagerPanel(
                            dark: dark,
                            statusFilter: _statusFilter,
                            dateFilter: _dateFilter,
                            onStatusFilterChanged: (val) => setState(() {
                              _statusFilter = val;
                              _updateFilteredAndGroupedCards();
                            }),
                            onDateFilterChanged: (val) => setState(() {
                              _dateFilter = val;
                              _updateFilteredAndGroupedCards();
                            }),
                            onClear: () => setState(() {
                              _statusFilter = 'All';
                              _dateFilter = 'All';
                              _updateFilteredAndGroupedCards();
                            }),
                            onJumpToDateTap: _openDatePicker,
                            lastImportSessions: [
                              ..._cards.where(
                                (c) => _lastImportedSessionIds.contains(
                                  c.recordId,
                                ),
                              ),
                              ..._archiveCards
                                  .where(
                                    (c) => _lastImportedSessionIds.contains(
                                      c.recordId,
                                    ),
                                  )
                                  .map((c) => c.copyWith(wasEverStarted: true)),
                            ],
                            onUndoLastImport: () async {
                              final lastImportSessions = _cards
                                  .where(
                                    (c) => _lastImportedSessionIds.contains(
                                      c.recordId,
                                    ),
                                  )
                                  .toList();
                              final protected = lastImportSessions
                                  .where(
                                    (s) =>
                                        s.running ||
                                        s.isPaused ||
                                        s.wasEverStarted ||
                                        s.phase == ExamPhase.finished ||
                                        s.logs.isNotEmpty,
                                  )
                                  .toList();
                              final undoable = lastImportSessions
                                  .where((s) => !protected.contains(s))
                                  .toList();
                              final undoableIds = undoable
                                  .map((c) => c.recordId)
                                  .whereType<String>()
                                  .toList();
                              if (undoableIds.isNotEmpty) {
                                await _sessionService.undoLastImport(
                                  undoableIds,
                                );
                                if (mounted) {
                                  _toast(
                                    'Import Reverted',
                                    'Reverted ${undoableIds.length} session${undoableIds.length == 1 ? '' : 's'} from the last import.',
                                    Icons.undo_rounded,
                                    NotificationType.success,
                                  );
                                }
                                await _refreshCards();
                              }
                            },
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                  Expanded(
                    child: isArchiveView
                        ? (_archiveCards.isEmpty
                              ? const SingleChildScrollView(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(height: 20),
                                        HomeEmptyStateWidget(),
                                        SizedBox(height: 120),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    100,
                                  ),
                                  itemCount: _archiveCards.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, idx) {
                                    final c = _archiveCards[idx];
                                    return _buildExamCard(
                                      c,
                                      key: ValueKey('archive_${c.recordId}'),
                                    );
                                  },
                                ))
                        : (_filteredCardsCached.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) =>
                                      SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: constraints.maxHeight,
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _cards.isEmpty
                                                    ? const HomeEmptyStateWidget()
                                                    : FilteredEmptyStateWidget(
                                                        onClear: () => setState(
                                                          () {
                                                            _statusFilter =
                                                                'All';
                                                            _dateFilter = 'All';
                                                            _updateFilteredAndGroupedCards();
                                                          },
                                                        ),
                                                      ),

                                                SizedBox(height: 45),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                )
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    100,
                                  ),
                                  child: Column(
                                    children: _groupedCardsCached.keys.map((
                                      date,
                                    ) {
                                      final sessions =
                                          _groupedCardsCached[date] ?? [];
                                      final sessionsCount = sessions.length;
                                      final headerKey = _dateKeys.putIfAbsent(
                                        date,
                                        () => GlobalKey(),
                                      );
                                      final isHighlighted =
                                          _highlightedDate == date;
                                      return Column(
                                        key: ValueKey('group_$date'),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            key: headerKey,
                                            padding: const EdgeInsets.fromLTRB(
                                              0,
                                              14,
                                              0,
                                              14,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 3,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        VigiloUiColors.blueSoft(
                                                          dark,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          2,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _fd(date),
                                                  style: TextStyle(
                                                    color:
                                                        VigiloUiColors.blueSoft(
                                                          dark,
                                                        ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '$sessionsCount session${sessionsCount == 1 ? '' : 's'}',
                                                  style: TextStyle(
                                                    color:
                                                        VigiloUiColors.textFaint(
                                                          dark,
                                                        ),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                            padding: EdgeInsets.zero,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: isHighlighted
                                                    ? VigiloUiColors.blue(dark)
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              children: sessions.map((c) {
                                                final isLast =
                                                    c == sessions.last;
                                                return Padding(
                                                  key: ValueKey(
                                                    'card_${c.recordId}',
                                                  ),
                                                  padding: EdgeInsets.only(
                                                    bottom: isLast ? 0 : 16,
                                                  ),
                                                  child: _buildExamCard(c),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                )),
                  ),
                ],
              ),

              // ── Speed dial backdrop ─────────────────────────────────────────
              // Semi-transparent overlay dims content while speed dial is open.
              // Tapping it closes the dial without navigating anywhere.
              IgnorePointer(
                ignoring: !_fabOpen,
                child: AnimatedOpacity(
                  opacity: _fabOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: GestureDetector(
                    onTap: _closeFab,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),

              // ── Speed dial options ──────────────────────────────────────────
              // Positioned above the FAB (bottom: 90). Each option has a label
              // on the left and a mini circular button on the right.
              Positioned(
                right: 16,
                bottom: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Option 1 – Import Exam Sessions (upload icon)
                    ScaleTransition(
                      scale: _fabDialAnim,
                      alignment: Alignment.bottomRight,
                      child: FadeTransition(
                        opacity: _fabDialAnim,
                        child: SpeedDialOption(
                          icon: Icons.upload_file_rounded,
                          label: 'Import Exam Sessions',
                          dark: dark,
                          onTap: () {
                            _closeFab();
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                    ) => ImportFlowSheet(
                                      dark: dark,
                                      onToggleTheme: widget.onToggleTheme,
                                      initialCentreNumber:
                                          _lastCentre ??
                                          (_cards.isNotEmpty
                                              ? _cards.first.centreNumber
                                              : ''),
                                      onImportSessions: (newSessions) async {
                                        await _sessionService.importSessions(
                                          newSessions,
                                        );
                                        if (newSessions.isNotEmpty) {
                                          setState(() {
                                            _lastCentre =
                                                newSessions.first.centreNumber;
                                          });
                                        }
                                        await _refreshCards();
                                        await _saveState();
                                      },
                                      onClose: () => context.safePop(),
                                    ),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      final tween =
                                          Tween(
                                            begin: const Offset(0.0, 1.0),
                                            end: Offset.zero,
                                          ).chain(
                                            CurveTween(
                                              curve: Curves.easeOutCubic,
                                            ),
                                          );
                                      return SlideTransition(
                                        position: animation.drive(tween),
                                        child: child,
                                      );
                                    },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Option 2 – Create Single Exam (edit icon)
                    ScaleTransition(
                      scale: _fabDialAnim,
                      alignment: Alignment.bottomRight,
                      child: FadeTransition(
                        opacity: _fabDialAnim,
                        child: SpeedDialOption(
                          icon: Icons.edit_outlined,
                          label: 'Create Single Exam',
                          dark: dark,
                          onTap: () {
                            // Create Single Exam → opens existing Add Exam form
                            _closeFab();
                            _openQuickAddWizard();
                          },
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
    );
  }

  List<ExamCardData> _filteredCardsCached = [];
  Map<String, List<ExamCardData>> _groupedCardsCached = {};
  String? _lastCardsSignature;

  String _computeCardsSignature() {
    final sb = StringBuffer();
    sb.write('$_statusFilter|$_dateFilter|${_cards.length}|');
    for (final c in _cards) {
      sb.write(
        '${c.recordId}:${c.expanded}:${c.phase.index}:${c.running}:${c.isPaused}:${c.progress}:${c.date}:${c.normalStart}:${c.roomsSnapshot};',
      );
    }
    return sb.toString();
  }

  void _updateFilteredAndGroupedCards() {
    if (_cards.length <= 5) {
      _showSessionMgr = false;
      _statusFilter = 'All';
      _dateFilter = 'All';
    }
    var list = List<ExamCardData>.from(_cards);

    if (_statusFilter != 'All') {
      list = list.where((c) {
        if (_statusFilter == 'Not Started') {
          return !c.running && !c.isPaused && c.phase != ExamPhase.finished;
        } else if (_statusFilter == 'Running') {
          return c.running || c.isPaused;
        } else if (_statusFilter == 'Finished') {
          return c.phase == ExamPhase.finished;
        }
        return true;
      }).toList();
    }

    if (_dateFilter != 'All') {
      final now = DateTime.now();
      final todayStr =
          "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      list = list.where((c) {
        if (_dateFilter == 'Today') {
          return c.date == todayStr;
        } else if (_dateFilter == 'This Week') {
          try {
            final parts = c.date.split('/');
            if (parts.length == 3) {
              final d = int.parse(parts[0]);
              final m = int.parse(parts[1]);
              final y = int.parse(parts[2]);
              final examDate = DateTime(y, m, d);
              final weekday = now.weekday;
              final startOfWeek = DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(Duration(days: weekday - 1));
              final endOfWeek = startOfWeek.add(const Duration(days: 7));
              return (examDate.isAfter(
                    startOfWeek.subtract(const Duration(seconds: 1)),
                  ) &&
                  examDate.isBefore(endOfWeek));
            }
          } catch (_) {}
          return false;
        }
        return true;
      }).toList();
    }

    list.sort((a, b) {
      // Date comparison
      DateTime? da, db;
      try {
        final pa = a.date.split('/');
        da = DateTime(int.parse(pa[2]), int.parse(pa[1]), int.parse(pa[0]));
      } catch (_) {}
      try {
        final pb = b.date.split('/');
        db = DateTime(int.parse(pb[2]), int.parse(pb[1]), int.parse(pb[0]));
      } catch (_) {}

      if (da != null && db != null) {
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }

      // Start time comparison
      final sa = a.normalStart;
      final sb = b.normalStart;
      final cmpTime = sa.compareTo(sb);
      if (cmpTime != 0) return cmpTime;

      // Subject alphabetically
      final subA = a.subject;
      final subB = b.subject;
      final cmpSub = subA.toLowerCase().compareTo(subB.toLowerCase());
      if (cmpSub != 0) return cmpSub;

      // Room alphabetically
      final ra = a.roomsSnapshot;
      final rb = b.roomsSnapshot;
      return ra.toLowerCase().compareTo(rb.toLowerCase());
    });

    _filteredCardsCached = list;

    final map = <String, List<ExamCardData>>{};
    for (final s in list) {
      map.putIfAbsent(s.date, () => []).add(s);
    }
    _groupedCardsCached = map;

    final flattened = <HomeListItem>[];
    for (final date in map.keys) {
      final sessions = map[date]!;
      flattened.add(HomeListItem(dateHeader: date));
      for (final c in sessions) {
        final idx = _cards.indexOf(c);
        if (idx != -1) {
          flattened.add(HomeListItem(card: c, cardIndex: idx));
        }
      }
    }
  }

  String _fd(String date) {
    try {
      final p = date.split('/');
      if (p.length == 3) {
        final d = int.parse(p[0]);
        final m = int.parse(p[1]);
        final y = int.parse(p[2]);
        final dt = DateTime(y, m, d);
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final weekday = days[dt.weekday - 1];
        final monthStr = months[m];
        return '$weekday, $d $monthStr $y';
      }
    } catch (_) {}
    return date;
  }

  Future<void> _openDatePicker() async {
    debugPrint('[JumpToDate] Opening Date Picker...');
    final Map<String, int> dateCounts = {};
    for (final entry in _groupedCardsCached.entries) {
      dateCounts[entry.key] = entry.value.length;
    }
    debugPrint(
      '[JumpToDate] Available dates in Session Manager: ${dateCounts.keys.toList()}',
    );

    final selectedDate = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          VigiloDateJumpSheet(dark: widget.dark, dateSessionCounts: dateCounts),
    );

    debugPrint('[JumpToDate] User selected date from sheet: $selectedDate');
    if (selectedDate != null && mounted) {
      // 1. Close Session Manager
      setState(() {
        _showSessionMgr = false;
      });

      // 2. Scroll to date section
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final key = _dateKeys[selectedDate];
        debugPrint(
          '[JumpToDate] GlobalKey lookup for date $selectedDate: $key',
        );
        if (key != null) {
          debugPrint('[JumpToDate] key.currentContext: ${key.currentContext}');
          if (key.currentContext != null) {
            debugPrint(
              '[JumpToDate] Attempting scroll to element: ${key.currentContext}',
            );
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.05,
            );
          } else {
            debugPrint(
              '[JumpToDate] WARNING: currentContext is null! Widget might be offscreen/not rendered.',
            );
          }
        } else {
          debugPrint('[JumpToDate] ERROR: key not found in _dateKeys mapping.');
        }
        setState(() => _highlightedDate = selectedDate);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _highlightedDate = null);
        });
      });
    }
  }

  Widget _header(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          InkWell(
            onTap: _openLicenseActivation,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                'Vigilo ERC',
                style: TextStyle(
                  color: VigiloUiColors.text(dark),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (_archiveCards.isNotEmpty || isArchiveView) ...[
            _headerIcon(
              dark,
              isArchiveView ? Icons.archive : Icons.archive_outlined,
              color: isArchiveView ? VigiloUiColors.green(dark) : null,
              selected: isArchiveView,
              onTap: () => setState(() {
                isArchiveView = !isArchiveView;
                isArchiveMode = false;
                if (isArchiveView) {
                  _showSessionMgr = false;
                  _toast(
                    "Showing archived exams",
                    "Archived exam records are shown below",
                    Icons.archive_rounded,
                    NotificationType.information,
                  );
                } else {
                  _toast(
                    "Showing active exams",
                    "Current running and scheduled exams are shown below",
                    Icons.play_circle_fill_rounded,
                    NotificationType.information,
                  );
                }
              }),
            ),
            const SizedBox(width: 10),
          ],
          if (_cards.length > 5) ...[
            _headerIcon(
              dark,
              Icons.tune_rounded,
              color:
                  (_showSessionMgr ||
                      _statusFilter != 'All' ||
                      _dateFilter != 'All')
                  ? VigiloUiColors.blue(dark)
                  : null,
              selected:
                  _showSessionMgr ||
                  _statusFilter != 'All' ||
                  _dateFilter != 'All',
              onTap: () => setState(() {
                _showSessionMgr = !_showSessionMgr;
                if (_showSessionMgr) {
                  isArchiveView = false;
                  isArchiveMode = false;
                }
              }),
            ),
            const SizedBox(width: 10),
          ],
          _headerIcon(
            dark,
            dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
            onTap: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(
    bool dark,
    IconData icon, {
    required VoidCallback onTap,
    Color? color,
    bool selected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: VigiloUiColors.panel(
            dark,
          ).withValues(alpha: dark ? 0.72 : 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? (color ?? VigiloUiColors.blue(dark))
                : (dark
                      ? VigiloUiColors.line(dark).withValues(alpha: 0.70)
                      : VigiloUiColors.line(dark)),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.16 : 0.07),
              blurRadius: dark ? 8 : 10,
              offset: Offset(0, dark ? 3 : 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color ?? VigiloUiColors.textSoft(dark),
          size: 23,
        ),
      ),
    );
  }

  bool checkVibrateOn() {
    int i = getExpandedCardIndex();
    if (i != -1) {
      return _cards[getExpandedCardIndex()].vibrateOn;
    } else {
      return false;
    }
  }

  int getExpandedCardIndex() {
    return _cards.indexWhere((card) => card.expanded);
  }

  Widget _buildExamCard(ExamCardData c, {Key? key}) {
    final listToUse = isArchiveView ? _archiveCards : _cards;
    final idx = listToUse.indexWhere((card) => card.recordId == c.recordId);
    if (idx == -1) {
      return const SizedBox.shrink();
    }

    return ExamCard(
      key: key,
      data: c,
      pulse: _pulse,
      isExamCompleted: c.phase == ExamPhase.finished || isArchiveView,
      isArchiveMode: isArchiveMode,
      extraPulse: extraPulse,
      tapScale: isArchiveView ? 1.0 : _cards[idx].tapScale,
      onProgressDragState: (dragging) {
        _isAdjustingProgress = dragging;
      },
      onProgressChangeEnd: (v) async {
        final currentIdx = _cards.indexWhere(
          (card) => card.recordId == c.recordId,
        );
        if (!mounted || currentIdx == -1) return;
        _isAdjustingProgress = true;
        setState(() {
          _cards[currentIdx] = _applyManualProgress(_cards[currentIdx], v);
        });
        try {
          await _saveState();
          await _refreshCards();
        } finally {
          _isAdjustingProgress = false;
        }
      },
      onSelect: () {
        if (!isArchiveView) {
          final currentIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (currentIdx == -1) return;
          if (!_isArchivableExam(c)) {
            _toast(
              "Action Restricted",
              "Only finished exams can be archived",
              Icons.block_rounded,
              NotificationType.error,
            );
            return;
          }
          setState(() {
            _cards[currentIdx] = _cards[currentIdx].copyWith(
              isSelected: !_cards[currentIdx].isSelected,
            );
          });
        }
      },
      onChevronTap: () {
        if (!isArchiveView) {
          final currentIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (currentIdx != -1) {
            _toggleExpanded(currentIdx);
          }
        } else {
          final currentIdx = _archiveCards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (currentIdx == -1) return;
          _cards.add(_archiveCards[currentIdx]);
          _archiveCards.removeAt(currentIdx);
          if (_archiveCards.isEmpty) {
            isArchiveView = false;
          }
          _toast(
            "Exam Restored",
            "The exam has been successfully restored",
            Icons.settings_backup_restore_rounded,
            NotificationType.success,
          );
          _saveState();
          setState(() {
            _updateFilteredAndGroupedCards();
          });
        }
      },
      onEditDate: () async {
        final currentIdx = _cards.indexWhere(
          (card) => card.recordId == c.recordId,
        );
        if (currentIdx == -1 ||
            _cards[currentIdx].phase == ExamPhase.finished) {
          return;
        }
        final now = DateTime.now();
        final parts = c.date.split('/');
        DateTime initial = now;
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]) ?? now.day;
          final m = int.tryParse(parts[1]) ?? now.month;
          final y = int.tryParse(parts[2]) ?? now.year;
          initial = DateTime(y, m, d);
        }
        final picked = await showModalBottomSheet<DateTime>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          builder: (_) => VigiloDatePickerSheet(initialDate: initial),
        );
        if (picked != null) {
          final dd = picked.day.toString().padLeft(2, '0');
          final mm = picked.month.toString().padLeft(2, '0');
          final yy = picked.year.toString();
          final saveIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (saveIdx != -1) {
            setState(() => _cards[saveIdx] = c.copyWith(date: "$dd/$mm/$yy"));
            _saveState();
          }
        }
      },
      onEditStartTime: () async {
        final currentIdx = _cards.indexWhere(
          (card) => card.recordId == c.recordId,
        );
        if (currentIdx == -1 ||
            _cards[currentIdx].phase == ExamPhase.finished) {
          return;
        }

        DateTime? cardDate;
        try {
          final clean = c.date.trim().replaceAll(RegExp(r'\s+'), ' ');
          final dmyRegex = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$');
          var match = dmyRegex.firstMatch(clean);
          if (match != null) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);
            if (year < 100) year += 2000;
            cardDate = DateTime(year, month, day);
          } else {
            final parts = clean.split(' ');
            if (parts.length >= 3) {
              final day = int.tryParse(parts[0]);
              final monthStr = parts[1].toLowerCase();
              var year = int.tryParse(parts[2]);

              const months = {
                'jan': 1,
                'january': 1,
                'feb': 2,
                'february': 2,
                'mar': 3,
                'march': 3,
                'apr': 4,
                'april': 4,
                'may': 5,
                'jun': 6,
                'june': 6,
                'jul': 7,
                'july': 7,
                'aug': 8,
                'august': 8,
                'sep': 9,
                'september': 9,
                'oct': 10,
                'october': 10,
                'nov': 11,
                'november': 11,
                'dec': 12,
                'december': 12,
              };
              final month = months[monthStr];
              if (day != null && month != null && year != null) {
                if (year < 100) year += 2000;
                cardDate = DateTime(year, month, day);
              }
            }
          }

          if (cardDate == null) {
            final ymdRegex = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$');
            var ymdMatch = ymdRegex.firstMatch(clean);
            if (ymdMatch != null) {
              final year = int.parse(ymdMatch.group(1)!);
              final month = int.parse(ymdMatch.group(2)!);
              final day = int.parse(ymdMatch.group(3)!);
              cardDate = DateTime(year, month, day);
            }
          }

          cardDate ??= DateTime.tryParse(c.date);
        } catch (_) {}

        final now = DateTime.now();
        final isToday =
            cardDate != null &&
            cardDate.year == now.year &&
            cardDate.month == now.month &&
            cardDate.day == now.day;

        final t = _parseHHMM(c.normalStart);
        final picked = await showModalBottomSheet<TimeOfDay>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          builder: (_) => VigiloTimePickerSheet(
            initialTime: TimeOfDay(hour: t.$1, minute: t.$2),
            restrictPastTime: isToday,
          ),
        );
        if (picked != null) {
          final hh = picked.hour.toString().padLeft(2, '0');
          final mm = picked.minute.toString().padLeft(2, '0');
          final selectedStart = "$hh:$mm";
          final saveIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (saveIdx != -1) {
            setState(
              () => _cards[saveIdx] = _recompute(
                c.copyWith(normalStart: selectedStart),
              ),
            );
            _saveState();
          }
        }
      },
      onEditDuration: () async {
        final currentIdx = _cards.indexWhere(
          (card) => card.recordId == c.recordId,
        );
        if (currentIdx == -1 ||
            _cards[currentIdx].phase == ExamPhase.finished) {
          return;
        }
        String res = await pickDur(c.normalDuration, "Set Duration");
        if (res != "") {
          int newNormalSec = _toMin(res) * 60;
          int elapsedSec = (c.progress * c.totalSeconds).round();

          if (c.phase == ExamPhase.normal && newNormalSec < elapsedSec) {
            NotificationService.show(
              context,
              title: "Invalid Duration",
              subtitle: "Cannot reduce duration below elapsed time",
              type: NotificationType.error,
              icon: Icons.error_outline_rounded,
            );
            return;
          } else if (c.phase == ExamPhase.extra &&
              newNormalSec + c.extraSeconds < elapsedSec) {
            NotificationService.show(
              context,
              title: "Invalid Duration",
              subtitle: "Cannot reduce total time below elapsed time",
              type: NotificationType.error,
              icon: Icons.error_outline_rounded,
            );
            return;
          }

          DateTime now = DateTime.now();
          DateTime dateTime1 = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(c.normalDuration.split(":")[0]),
            int.parse(c.normalDuration.split(":")[1]),
          );
          DateTime dateTime2 = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(res.split(":")[0]),
            int.parse(res.split(":")[1]),
          );
          int _ = dateTime2.difference(dateTime1).inMinutes;
          String detail = "";
          if (c.phase == ExamPhase.normal) {
            detail = "Adjustment entered before extra time";
          } else if (c.phase == ExamPhase.extra) {
            detail = "Adjustment entered during extra time";
          } else {
            detail = "Adjustment entered after exam finished";
          }
          final saveIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (saveIdx != -1) {
            setState(
              () =>
                  _cards[saveIdx] = _recompute(c.copyWith(normalDuration: res)),
            );
            await _saveState();
            final recordId = _cards[saveIdx].recordId;
            if (recordId != null) {
              await _sessionService.updatePlannedDuration(
                examRecordId: recordId,
                normalDurationMs: _cards[saveIdx].normalSeconds * 1000,
                extraTimeMs: _cards[saveIdx].extraSeconds * 1000,
                reason: _formatNormalTimeUpdateReason(
                  previousMinutes: _toMin(c.normalDuration),
                  updatedMinutes: _toMin(res),
                ),
                detail: detail,
              );
              await _refreshCards();
            }
          }
        }
      },
      onEditExtra: () async {
        final currentIdx = _cards.indexWhere(
          (card) => card.recordId == c.recordId,
        );
        if (currentIdx == -1 ||
            _cards[currentIdx].phase == ExamPhase.finished) {
          return;
        }
        String res = await pickDur(c.extraTime, "Add Extra Time");
        if (res != "") {
          int newExtraSec = _toMin(res) * 60;
          int elapsedSec = (c.progress * c.totalSeconds).round();

          if (c.phase == ExamPhase.extra &&
              c.normalSeconds + newExtraSec < elapsedSec) {
            NotificationService.show(
              context,
              title: "Invalid Extra Time",
              subtitle: "Cannot reduce total time below elapsed time",
              type: NotificationType.error,
              icon: Icons.error_outline_rounded,
            );
            return;
          }

          final previousMinutes = _toMin(c.extraTime);
          final updatedMinutes = _toMin(res);

          final saveIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (saveIdx != -1) {
            setState(
              () => _cards[saveIdx] = _recompute(c.copyWith(extraTime: res)),
            );
            String detail = "";
            if (c.phase == ExamPhase.normal) {
              detail = "Adjustment entered before extra time";
            } else if (c.phase == ExamPhase.extra) {
              detail = "Adjustment entered during extra time";
            } else {
              detail = "Adjustment entered after exam finished";
            }
            await _saveState();
            final recordId = _cards[saveIdx].recordId;
            if (recordId != null) {
              await _sessionService.updatePlannedDuration(
                examRecordId: recordId,
                normalDurationMs: _cards[saveIdx].normalSeconds * 1000,
                extraTimeMs: _cards[saveIdx].extraSeconds * 1000,
                reason: _formatExtraTimeUpdateReason(
                  previousMinutes: previousMinutes,
                  updatedMinutes: updatedMinutes,
                ),
                detail: detail,
              );
              await _refreshCards();
            }
          }
        }
      },
      onUpdate: (u) async {
        final wasRunning = c.running;
        final becameRunning = u.running && !wasRunning && u.epochStart != null;
        if (becameRunning) {
          final saveIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (saveIdx == -1) return;
          final now = u.epochStart!;
          final hh = now.hour.toString().padLeft(2, '0');
          final mm = now.minute.toString().padLeft(2, '0');
          final fixed = _recompute(
            u.copyWith(
              running: false,
              isPaused: false,
              epochStart: null,
              pausedSeconds: 0,
              progress: 0.0,
              phase: ExamPhase.normal,
              normalStart: "$hh:$mm",
            ),
          );
          setState(() {
            _cards[saveIdx] = fixed;
          });
          await _saveState();
          final recordId = fixed.recordId;
          if (recordId != null) {
            await _sessionService.startSession(
              examRecordId: recordId,
              startedAt: now,
              normalDurationMs: fixed.normalSeconds * 1000,
              extraTimeMs: fixed.extraSeconds * 1000,
            );
          }
          await _refreshCards();
        } else {
          final saveIdx = _cards.indexWhere(
            (card) => card.recordId == c.recordId,
          );
          if (saveIdx == -1) return;
          setState(() {
            _cards[saveIdx] = _applyManualProgress(u, u.progress);
          });
        }
      },
      onTimeTap: () {
        final currentIdx = _cards.indexWhere(
          (card) => card.recordId == c.recordId,
        );
        if (currentIdx == -1 ||
            _cards[currentIdx].phase == ExamPhase.finished) {
          return;
        }
        _cards[currentIdx] = c.copyWith(isActiveTime: !c.isActiveTime);
        setState(() {});
        if (c.isActiveTime) {
          _clickTimer = Timer(const Duration(seconds: 7), () {
            final saveIdx = _cards.indexWhere(
              (card) => card.recordId == c.recordId,
            );
            if (saveIdx != -1) {
              _cards[saveIdx] = c.copyWith(isActiveTime: true);
              setState(() {});
            }
          });
        } else {
          _clickTimer?.cancel();
        }
      },
    );
  }

  @visibleForTesting
  void highlightDateForTest(String date) {
    setState(() {
      _highlightedDate = date;
    });
  }

  @visibleForTesting
  List<ExamCardData> get cardsForTesting => _cards;

  @visibleForTesting
  List<String> get lastImportedSessionIdsForTesting => _lastImportedSessionIds;

  @visibleForTesting
  List<ExamCardData> get archiveCardsForTesting => _archiveCards;
}
