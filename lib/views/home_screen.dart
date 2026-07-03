import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../enums/exam_phase.dart';
import '../models/exam_card_data.dart';
import '../models/incident.dart';
import '../services/license_service.dart';
import '../services/session_service.dart';
import '../utils/constants.dart';
import '../utils/export_logs.dart';
import '../utils/id_generator.dart';
import 'briefings_library_sheet.dart';
import 'license_activation_screen.dart';
import '../utils/screen_util.dart';
import '../utils/notifications.dart';
import 'officer_tools_screen.dart';
import 'widgets/add_exam_sheet.dart';
import 'widgets/confirmation_dialog.dart';
import 'widgets/exam_card_widget.dart';
import 'widgets/footer_widget.dart';
import 'widgets/home_empty_state_widget.dart';
import 'widgets/license_required_view.dart';
import 'widgets/stat_chip_widget.dart';
import 'widgets/vigilo_date_picker.dart';
import 'widgets/vigilo_time_picker.dart';
import 'widgets/vigilo_duration_picker.dart';

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
  final SessionService _sessionService = SessionService();
  final Set<String> _normalTimeWarningVibrationSent = <String>{};
  final Set<String> _extraTimeWarningVibrationSent = <String>{};
  bool _tickInFlight = false;
  bool _isAdjustingProgress = false;

  int get allInvigilators => _cards
      .expand(
        (s) => s.scheduleList != null && s.phase != ExamPhase.finished
            ? s.scheduleList!.expand((p) => p.invigilators)
            : [],
      )
      .toSet()
      .toList()
      .length;

  // Last-used for wizard prefill
  String? _lastSchool,
      _lastCentre,
      _lastSubject,
      _lastBoard,
      _lastStart,
      _lastDuration,
      _lastExtra;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  Timer? _ticker;
  Timer? _extraPulseTicker;
  Timer? _clickTimer;
  bool _licenseLoaded = false;
  bool _licenseRequired = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeHomeState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _extraPulseTicker = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) setState(() => extraPulse = !extraPulse);
    });
  }

  Future<void> _initializeHomeState() async {
    await _sessionService.initialize();
    await _loadState();
    await _clearLegacyLicenceCentrePrefillIfNeeded();
    await _seedOrganizationFromLicenseIfNeeded();
    await _loadLicenseStatus();
  }

  Future<void> _saveState() async {
    final previousCards = List<ExamCardData>.from(_cards);
    final previousArchiveCards = List<ExamCardData>.from(_archiveCards);
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
      _cards
        ..clear()
        ..addAll(
          _preserveTransientCardState(
            previous: previousCards,
            incoming: persisted.cards,
          ),
        );
      _archiveCards
        ..clear()
        ..addAll(
          _preserveTransientCardState(
            previous: previousArchiveCards,
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
  }

  Future<void> _refreshCards() async {
    final previousCards = List<ExamCardData>.from(_cards);
    final previousArchiveCards = List<ExamCardData>.from(_archiveCards);
    final state = await _sessionService.loadHomeState();
    final activeIds = state.cards
        .map((card) => card.recordId)
        .whereType<String>()
        .toSet();
    _normalTimeWarningVibrationSent.retainAll(activeIds);
    _extraTimeWarningVibrationSent.retainAll(activeIds);
    if (!mounted) return;
    setState(() {
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
    });
  }

  Future<void> _loadState() async {
    final state = await _sessionService.loadHomeState();
    if (!mounted) return;
    setState(() {
      _cards
        ..clear()
        ..addAll(state.cards);
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
    _ticker?.cancel();
    _extraPulseTicker?.cancel();
    _clickTimer?.cancel();
    super.dispose();
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
      minsStr = '$remainingMinutes ${remainingMinutes == 1 ? "minute" : "minutes"}';
    }

    if (hoursStr.isNotEmpty && minsStr.isNotEmpty) {
      return '$hoursStr and $minsStr';
    } else if (hoursStr.isNotEmpty) {
      return hoursStr;
    } else {
      return minsStr;
    }
  }

  String _formatExtraTimeUpdateReason({
    required int previousMinutes,
    required int updatedMinutes,
  }) {
    final diffMinutes = updatedMinutes - previousMinutes;
    final durationText = _formatMinutesDescription(diffMinutes);
    if (diffMinutes >= 0) {
      return 'Extra Time increased by $durationText';
    } else {
      return 'Extra Time reduced by $durationText';
    }
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
    );
  }

  List<ExamCardData> _preserveTransientCardState({
    required List<ExamCardData> previous,
    required List<ExamCardData> incoming,
  }) {
    if (previous.isEmpty || incoming.isEmpty) {
      return incoming;
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
    if (_licenseRequired || _tickInFlight || _isAdjustingProgress) return;
    _tickInFlight = true;
    _tickAsync().whenComplete(() {
      _tickInFlight = false;
    });
  }

  Future<void> _tickAsync() async {
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
      final thresholdSeconds = (totalSeconds - 600).clamp(current.normalSeconds, totalSeconds);
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

  void _toggleExpanded(int i) => setState(() {
    for (int j = 0; j < _cards.length; j++) {
      if (j == i) {
        _cards[j] = _cards[j].copyWith(expanded: !_cards[j].expanded);
      } else {
        _cards[j] = _cards[j].copyWith(expanded: false);
      }
    }
    _cards[i] = _cards[i].copyWith(tapScale: 1.02);
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _cards[i] = _cards[i].copyWith(tapScale: 1.0));
    });
    _saveState();
  });

  void _toast(String title, [String? subtitle, IconData? icon, NotificationType type = NotificationType.information]) {
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

  Future<void> _onReStart(int i) async {
    final c = _cards[i];
    final recordId = c.recordId;
    if (recordId == null) {
      _toast("Not Ready", "Complete exam setup before starting", Icons.warning_amber_rounded, NotificationType.warning);
      return;
    }
    if (c.totalSeconds <= 0) {
      _toast("Missing Information", "Set the exam duration before starting", Icons.warning_amber_rounded, NotificationType.warning);
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
    _toast("Exam Restarted", "The exam timer has been reset", Icons.restart_alt_rounded, NotificationType.information);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onPause(int i) async {
    final c = _cards[i];
    final recordId = c.recordId;
    if (recordId == null) return;

    if (c.isPaused) {
      await _sessionService.resumeSession(recordId);
      _toast("Exam Resumed", "The exam timer has resumed", Icons.play_circle_fill_rounded, NotificationType.success);
    } else {
      await _sessionService.pauseSession(recordId);
      _toast("Exam Paused", "The exam timer has been paused", Icons.pause_circle_filled_rounded, NotificationType.information);
    }

    await _refreshCards();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onEnd(int i) async {
    final c = _cards[i];
    final recordId = c.recordId;
    if (recordId == null) return;
    await _sessionService.endSession(
      recordId,
      manual: true,
      reason: 'manual_end',
    );
    await _refreshCards();
    _toast("Exam ended", "The exam has been marked as finished", Icons.stop_circle_rounded, NotificationType.success);
    if (mounted) Navigator.pop(context);
  }

  // ------------------ Quick Add Wizard ------------------
  (int, int) _parseHHMM(String s) {
    final p = s.split(':');
    return ((int.tryParse(p[0]) ?? 0), (int.tryParse(p[1]) ?? 0));
  }


  Future<void> _openQuickAddWizard() async {
    final Map<String, String> knownCentres = {};
    debugPrint("[QuickAdd] Building knownCentres map from ${_archiveCards.length} archive cards and ${_cards.length} active cards...");
    for (final card in [..._archiveCards.reversed, ..._cards.reversed]) {
      final school = card.school.trim();
      final centre = card.resolvedCentreNumber.trim();
      if (school.isNotEmpty && centre.isNotEmpty) {
        knownCentres[school] = centre;
        debugPrint("[QuickAdd] Mapped from card: '$school' -> '$centre'");
      }
    }
    if (_lastSchool != null && _lastSchool!.trim().isNotEmpty &&
        _lastCentre != null && _lastCentre!.trim().isNotEmpty) {
      knownCentres[_lastSchool!.trim()] = _lastCentre!.trim();
      debugPrint("[QuickAdd] Mapped from last session variables: '${_lastSchool!.trim()}' -> '${_lastCentre!.trim()}'");
    }
    debugPrint("[QuickAdd] Final knownCentres map: $knownCentres");

    setState(() {
      _lastSchool = null;
      _lastCentre = null;
      _lastSubject = null;
      _lastBoard = null;
      _lastStart = null;
      _lastDuration = null;
      _lastExtra = null;
    });
    await _seedOrganizationFromLicenseIfNeeded();
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
        lastStart: _lastStart,
        lastDuration: _lastDuration,
        lastExtra: _lastExtra,
        knownCentres: knownCentres,
        onSave: ({
          required String school,
          required String centre,
          required String subject,
          required String board,
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
            _toast("Invalid Duration", "Set a valid exam duration before saving", Icons.warning_amber_rounded, NotificationType.error);
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
            autoStart: true,
          );
          newCard = _recompute(newCard);

          setState(() {
            _cards.insert(0, newCard);
            _lastSchool = null;
            _lastCentre = null;
            _lastSubject = null;
            _lastBoard = null;
            _lastStart = null;
            _lastDuration = null;
            _lastExtra = null;
          });
          await _saveState();
          if (!mounted) return;
          Navigator.of(context).pop(true);
        },
      ),
    );

    if (result == true) {
      _toast("Exam Created", "New exam successfully created", Icons.check_circle_rounded, NotificationType.success);
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
      builder: (_) => VigiloDurationPickerSheet(
        initialDuration: time,
        title: title,
      ),
    );
    return res ?? "";
  }

  int get _activeExamCount =>
      _cards.where((c) => (c.running || c.isPaused) && c.phase != ExamPhase.finished).length;

  bool _isArchivableExam(ExamCardData card) {
    final isFinished = card.phase == ExamPhase.finished || card.progress >= 1.0;
    return !card.running && !card.isPaused && isFinished;
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

  @override
  Widget build(BuildContext context) {
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
            child: FloatingActionButton.extended(
              tooltip: 'Quick Add',
              elevation: 4,
              backgroundColor: VigiloUiColors.blue(dark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onPressed: _openQuickAddWizard,
              label: const Text(
                "+ Exam",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.05,
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
                        _toast("Vibration Enabled", "Vibration is on for this exam", Icons.vibration_rounded, NotificationType.success);
                        await HapticFeedback.vibrate();
                      } catch (_) {}
                    } else {
                      _toast("Vibration Disabled", "Vibration is off for this exam", Icons.phonelink_erase_rounded, NotificationType.information);
                    }
                  } else {
                    _toast("Action Required", "Open an exam to use Vibrate", Icons.touch_app_rounded, NotificationType.warning);
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
                      _toast("Archive Failed", "No finished selected exams to archive", Icons.archive_rounded, NotificationType.error);
                    }
                    _toast("Archive Mode", "Archive mode has been disabled", Icons.archive_outlined, NotificationType.information);
                    isArchiveMode = false;
                    setState(() {});
                    return;
                  }

                  if (_cards.isEmpty) {
                    _toast("Archive Failed", "No exams available to archive", Icons.archive_rounded, NotificationType.error);
                    return;
                  }
                  if (_archivableExamCount == 0) {
                    _toast("Action Restricted", "Only finished exams can be archived", Icons.block_rounded, NotificationType.error);
                    return;
                  }
                  _toast("Archive Mode", "Tap finished exams to archive them", Icons.archive_rounded, NotificationType.information);
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
                              onCancel: () => Navigator.pop(ctx, false),
                              onConfirm: () => Navigator.pop(ctx, true),
                              shouldNotRestart:
                                  _cards[i].progress == 0.0 ||
                                  _cards[i].phase == ExamPhase.finished,
                            ),
                          );
                          if (ok == true) {
                            _onReStart(i);
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
                              onCancel: () => Navigator.pop(ctx, false),
                              onConfirm: () => Navigator.pop(ctx, true),
                            ),
                          );
                          if (ok == true) {
                            _onEnd(i);
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
                            _toast("Auto-Start Enabled", "The exam will auto-start at the scheduled time", Icons.timer_rounded, NotificationType.success);
                          } else {
                            _toast("Auto-Start Disabled", "Auto start is off", Icons.timer_off_rounded, NotificationType.information);
                          }
                          _saveState();
                        },
                        onUpdateData: (updated) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || i < 0 || i >= _cards.length) return;
                            final current = _cards[i];
                            setState(() {
                              _cards[i] = _mergeOfficerToolsUpdate(
                                current: current,
                                updated: updated,
                              );
                            });
                            _saveState();
                          });
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
                              onCancel: () => Navigator.pop(ctx, false),
                              onConfirm: () => Navigator.pop(ctx, true),
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
                            Navigator.of(context).pop();
                            _saveState();
                            setState(() {});
                          }
                        },
                      ),
                    );
                  } else {
                    _toast("Action Required", "Open an exam to use Officer Tools", Icons.touch_app_rounded, NotificationType.warning);
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
                  Expanded(
                    child: (!isArchiveView && _cards.isEmpty)
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Spacer(),
                              HomeEmptyStateWidget(),
                              Spacer(),
                              SizedBox(height: 100),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            itemCount: isArchiveView
                                ? _archiveCards.length
                                : _cards.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 16),
                            itemBuilder: (context, idx) {
                              final c = isArchiveView ? _archiveCards[idx] : _cards[idx];
                              return ExamCard(
                                key: ValueKey(c.recordId),
                                data: c,
                                pulse: _pulse,
                                isExamCompleted: c.phase == ExamPhase.finished,
                                isArchiveMode: isArchiveMode,
                                extraPulse: extraPulse,
                                tapScale: isArchiveView ? 1.0 : _cards[idx].tapScale,
                                onProgressDragState: (dragging) {
                                  _isAdjustingProgress = dragging;
                                },
                                onProgressChangeEnd: (v) async {
                                  if (!mounted || idx < 0 || idx >= _cards.length) return;
                                  _isAdjustingProgress = true;
                                  setState(() {
                                    _cards[idx] = _applyManualProgress(_cards[idx], v);
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
                                    if (!_isArchivableExam(c)) {
                                      _toast("Action Restricted", "Only finished exams can be archived", Icons.block_rounded, NotificationType.error);
                                      return;
                                    }
                                    setState(() {
                                      _cards[idx] = _cards[idx].copyWith(
                                        isSelected: !_cards[idx].isSelected,
                                      );
                                    });
                                  }
                                },
                                onChevronTap: () {
                                  if (!isArchiveView) {
                                    _toggleExpanded(idx);
                                  } else {
                                    _cards.add(_archiveCards[idx]);
                                    _archiveCards.removeAt(idx);
                                    if (_archiveCards.isEmpty) {
                                      isArchiveView = false;
                                    }
                                    _toast("Exam Restored", "The exam has been successfully restored", Icons.settings_backup_restore_rounded, NotificationType.success);
                                    _saveState();
                                    setState(() {});
                                  }
                                },
                                onEditDate: () async {
                                  if (_cards[idx].phase == ExamPhase.finished) {
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
                                    setState(() => _cards[idx] = c.copyWith(date: "$dd/$mm/$yy"));
                                    _saveState();
                                  }
                                },
                                onEditStartTime: () async {
                                  if (_cards[idx].phase == ExamPhase.finished) {
                                    return;
                                  }
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
                                    ),
                                  );
                                  if (picked != null) {
                                    final hh = picked.hour.toString().padLeft(2, '0');
                                    final mm = picked.minute.toString().padLeft(2, '0');
                                    final selectedStart = "$hh:$mm";
                                    setState(
                                      () => _cards[idx] = _recompute(
                                        c.copyWith(normalStart: selectedStart),
                                      ),
                                    );
                                    _saveState();
                                  }
                                },
                                onEditDuration: () async {
                                  if (_cards[idx].phase == ExamPhase.finished) {
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
                                    } else if (c.phase == ExamPhase.extra && newNormalSec + c.extraSeconds < elapsedSec) {
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
                                    int diff = dateTime2.difference(dateTime1).inMinutes;
                                    String detail = "";
                                    if (c.phase == ExamPhase.normal) {
                                      detail = "Adjustment entered before extra time";
                                    } else if (c.phase == ExamPhase.extra) {
                                      detail = "Adjustment entered during extra time";
                                    } else {
                                      detail = "Adjustment entered after exam finished";
                                    }
                                    setState(
                                      () => _cards[idx] = _recompute(
                                        c.copyWith(normalDuration: res),
                                      ),
                                    );
                                    await _saveState();
                                    final recordId = _cards[idx].recordId;
                                    if (recordId != null) {
                                      final String reason;
                                      final durationText = _formatMinutesDescription(diff);
                                      if (diff >= 0) {
                                        reason = "Normal Time increased by $durationText";
                                      } else {
                                        reason = "Normal Time reduced by $durationText";
                                      }
                                      await _sessionService.updatePlannedDuration(
                                        examRecordId: recordId,
                                        normalDurationMs: _cards[idx].normalSeconds * 1000,
                                        extraTimeMs: _cards[idx].extraSeconds * 1000,
                                        reason: reason,
                                        detail: detail,
                                      );
                                      await _refreshCards();
                                    }
                                  }
                                },
                                onEditExtra: () async {
                                  if (_cards[idx].phase == ExamPhase.finished) {
                                    return;
                                  }
                                  String res = await pickDur(c.extraTime, "Add Extra Time");
                                  if (res != "") {
                                    int newExtraSec = _toMin(res) * 60;
                                    int elapsedSec = (c.progress * c.totalSeconds).round();

                                    if (c.phase == ExamPhase.extra && c.normalSeconds + newExtraSec < elapsedSec) {
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

                                    setState(
                                      () => _cards[idx] = _recompute(c.copyWith(extraTime: res)),
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
                                    final recordId = _cards[idx].recordId;
                                    if (recordId != null) {
                                      await _sessionService.updatePlannedDuration(
                                        examRecordId: recordId,
                                        normalDurationMs: _cards[idx].normalSeconds * 1000,
                                        extraTimeMs: _cards[idx].extraSeconds * 1000,
                                        reason: _formatExtraTimeUpdateReason(
                                          previousMinutes: previousMinutes,
                                          updatedMinutes: updatedMinutes,
                                        ),
                                        detail: detail,
                                      );
                                      await _refreshCards();
                                    }
                                  }
                                },
                                onUpdate: (u) async {
                                  final wasRunning = c.running;
                                  final becameRunning =
                                      u.running && !wasRunning && u.epochStart != null;
                                  if (becameRunning) {
                                    if (!mounted || idx < 0 || idx >= _cards.length) return;
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
                                      _cards[idx] = fixed;
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
                                    if (!mounted || idx < 0 || idx >= _cards.length) return;
                                    setState(() {
                                      _cards[idx] = _applyManualProgress(u, u.progress);
                                    });
                                  }
                                },
                                onTimeTap: () {
                                  if (_cards[idx].phase == ExamPhase.finished) {
                                    return;
                                  }
                                  _cards[idx] = c.copyWith(isActiveTime: !c.isActiveTime);
                                  setState(() {});
                                  if (c.isActiveTime) {
                                    _clickTimer = Timer(const Duration(seconds: 7), () {
                                      _cards[idx] = c.copyWith(isActiveTime: true);
                                      setState(() {});
                                    });
                                  } else {
                                    _clickTimer?.cancel();
                                  }
                                },
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
    );
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
              onTap: () => setState(() {
                isArchiveView = !isArchiveView;
                isArchiveMode = false;
                if (isArchiveView) {
                  _toast("Viewing Archived Exams", "Archived exam records are shown below", Icons.archive_rounded, NotificationType.information);
                } else {
                  _toast("Viewing Active Exams", "Current running and scheduled exams are shown below", Icons.play_circle_fill_rounded, NotificationType.information);
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

  Widget _headerIcon(bool dark, IconData icon, {required VoidCallback onTap, Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: VigiloUiColors.panel(dark).withOpacity(dark ? 0.72 : 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dark
                ? VigiloUiColors.line(dark).withOpacity(0.70)
                : VigiloUiColors.line(dark),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.16 : 0.07),
              blurRadius: dark ? 8 : 10,
              offset: Offset(0, dark ? 3 : 4),
            ),
          ],
        ),
        child: Icon(icon, color: color ?? VigiloUiColors.textSoft(dark), size: 23),
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
}
