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
import 'officer_tools_screen.dart';
import 'widgets/confirmation_dialog.dart';
import 'widgets/exam_card_widget.dart';
import 'widgets/footer_widget.dart';
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

  String _formatExtraTimeUpdateReason({
    required int previousMinutes,
    required int updatedMinutes,
  }) {
    final diffMinutes = updatedMinutes - previousMinutes;
    final diffText = '${diffMinutes >= 0 ? '+' : ''}${diffMinutes}m';
    return 'Extra Time Updated '
        '(${previousMinutes}m -> ${updatedMinutes}m, $diffText)';
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

  ExamCardData _recomputePreservingTimer(
    ExamCardData c, {
    String? newNormalStart,
    String? newNormalDuration,
    String? newExtraTime,
  }) {
    final updated = _recompute(
      c.copyWith(
        normalStart: newNormalStart ?? c.normalStart,
        normalDuration: newNormalDuration ?? c.normalDuration,
        extraTime: newExtraTime ?? c.extraTime,
      ),
    );

    if (!c.running || c.epochStart == null) {
      return updated.copyWith(
        running: c.running,
        epochStart: c.epochStart,
        pausedSeconds: c.pausedSeconds,
        progress: c.progress,
        phase: c.phase,
      );
    }

    final now = DateTime.now();
    final elapsed = c.pausedSeconds + now.difference(c.epochStart!).inSeconds;
    final newTotal = _toMin(updated.totalDuration) * 60;
    if (elapsed >= newTotal && newTotal > 0) {
      _log(
        c,
        Incident(
          "Duration changed; elapsed exceeded new total. Exam ended.",
          eventType: "control",
        ),
      );
      return updated.copyWith(
        running: false,
        epochStart: null,
        pausedSeconds: newTotal,
        progress: 1.0,
        phase: ExamPhase.finished,
      );
    } else if (newTotal <= 0) {
      _log(
        c,
        Incident(
          "Invalid new duration (00:00). Ignored.",
          eventType: "control",
        ),
      );
      return c;
    } else {
      final prog = (elapsed / newTotal).clamp(0.0, 1.0);
      final phase = elapsed < _toMin(updated.normalDuration) * 60
          ? ExamPhase.normal
          : (elapsed < newTotal ? ExamPhase.extra : ExamPhase.finished);
      return updated.copyWith(
        running: phase != ExamPhase.finished,
        progress: prog,
        phase: phase,
        epochStart: c.epochStart,
        pausedSeconds: c.pausedSeconds,
      );
    }
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
      return;
    }

    // UI tick refresh only; no per-second persistence.
    await _refreshCards();
    await _vibrateForTenMinutesBeforeNormalEnd();
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

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );

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
      _toast("Exam is not ready yet");
      return;
    }
    if (c.totalSeconds <= 0) {
      _toast("Set Duration/Extra Time first");
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
    await _refreshCards();
    _toast("Exam restarted");
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onPause(int i) async {
    final c = _cards[i];
    final recordId = c.recordId;
    if (recordId == null) return;

    if (c.isPaused) {
      await _sessionService.resumeSession(recordId);
      _toast("Exam resumed");
    } else {
      await _sessionService.pauseSession(recordId);
      _toast("Exam paused");
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
    _toast("Exam end");
    if (mounted) Navigator.pop(context);
  }

  // ------------------ Quick Add Wizard ------------------
  (int, int) _parseHHMM(String s) {
    final p = s.split(':');
    return ((int.tryParse(p[0]) ?? 0), (int.tryParse(p[1]) ?? 0));
  }

  DateTime _suggestDate() => DateTime.now();

  Future<void> _openQuickAddWizard() async {
    final schoolCtl = TextEditingController(text: _lastSchool ?? "");
    final centreCtl = TextEditingController(text: _lastCentre ?? "");
    final subjectCtl = TextEditingController(text: _lastSubject ?? "");
    final boardCtl = TextEditingController(text: _lastBoard ?? "");
    DateTime selectedDate = _suggestDate();
    String startHHMM = _normalizeHHMM(_lastStart, fallback: "09:00");
    String durationHHMM = _normalizeHHMM(
      _lastDuration,
      fallback: "01:30",
      allowZero: false,
    );
    String extraHHMM = _normalizeHHMM(_lastExtra, fallback: "00:15");

    int step = 0;

    Future<void> pickStart() async {
      final t = _parseHHMM(startHHMM);
      final picked = await showModalBottomSheet<TimeOfDay>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => VigiloTimePickerSheet(
          initialTime: TimeOfDay(hour: t.$1, minute: t.$2),
        ),
      );
      if (picked != null) {
        startHHMM =
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      }
    }

    bool validStep0() =>
        subjectCtl.text.trim().isNotEmpty && boardCtl.text.trim().isNotEmpty;
    bool validStep1() => true;
    bool validStep2() =>
        schoolCtl.text.trim().isNotEmpty && centreCtl.text.trim().isNotEmpty;
    bool validStep3() => true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget buildHeader() {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Add Exam",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "Step ${step + 1} / 4",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
              );
            }

            Widget buildStep() {
              switch (step) {
                case 0:
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16 + MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: subjectCtl,
                          decoration: const InputDecoration(
                            labelText: "Exam Subject",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: boardCtl,
                          decoration: const InputDecoration(
                            labelText: "Exam Board (OCR, AQA, Edexcel)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // _lastSchool == null
                        //     ? Align(
                        //         alignment: Alignment.centerLeft,
                        //         child: TextButton.icon(
                        //           onPressed: () {
                        //             if (_lastSchool != null) {
                        //               setSheet(() {
                        //                 schoolCtl.text = _lastSchool!;
                        //                 centreCtl.text = _lastCentre ?? "";
                        //               });
                        //             }
                        //           },
                        //           icon: const Icon(Icons.history),
                        //           label: const Text("Use last"),
                        //         ),
                        //       )
                        //     : Container(),
                      ],
                    ),
                  );
                case 1:
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event),
                          title: const Text("Date"),
                          subtitle: Text(_fmtDate(selectedDate)),
                          trailing: TextButton(
                            onPressed: () async {
                              final picked = await showModalBottomSheet<DateTime>(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => VigiloDatePickerSheet(initialDate: selectedDate),
                              );
                              if (picked != null) {
                                setSheet(() => selectedDate = picked);
                              }
                            },
                            child: const Text("Change"),
                          ),
                        ),
                      ],
                    ),
                  );
                case 2:
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16 + MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: schoolCtl,
                          decoration: const InputDecoration(
                            labelText: "Organisation Name",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: centreCtl,
                          decoration: const InputDecoration(
                            labelText: "Centre Number",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // _lastSubject == null
                        //     ? Align(
                        //         alignment: Alignment.centerLeft,
                        //         child: TextButton.icon(
                        //           onPressed: () {
                        //             if (_lastSubject != null) {
                        //               setSheet(() {
                        //                 subjectCtl.text = _lastSubject!;
                        //                 boardCtl.text = _lastBoard ?? "";
                        //               });
                        //             }
                        //           },
                        //           icon: const Icon(Icons.history),
                        //           label: const Text("Use last"),
                        //         ),
                        //       )
                        //     : Container(),
                      ],
                    ),
                  );
                default:
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule),
                          title: const Text("Start time"),
                          subtitle: Text(startHHMM),
                          trailing: TextButton(
                            onPressed: () async {
                              await pickStart();
                              setSheet(() {});
                            },
                            child: const Text("Change"),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.timer),
                          title: const Text("Duration"),
                          subtitle: Text(durationHHMM),
                          trailing: TextButton(
                            onPressed: () async {
                              String res = await pickDur(
                                durationHHMM,
                                "Set Duration",
                              );
                              if (res != "") {
                                setState(() {
                                  durationHHMM = res;
                                });
                              }
                              setSheet(() {});
                            },
                            child: const Text("Change"),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.more_time),
                          title: const Text("Extra time"),
                          subtitle: Text(extraHHMM),
                          trailing: TextButton(
                            onPressed: () async {
                              String res = await pickDur(
                                extraHHMM,
                                "Add Extra Time",
                              );
                              if (res != "") {
                                setState(() {
                                  extraHHMM = res;
                                });
                              }
                              setSheet(() {});
                            },
                            child: const Text("Change"),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // _lastStart == null
                        //     ? Align(
                        //         alignment: Alignment.centerLeft,
                        //         child: TextButton.icon(
                        //           onPressed: () {
                        //             if (_lastStart != null) {
                        //               setSheet(() {
                        //                 startHHMM = _lastStart!;
                        //                 durationHHMM =
                        //                     _lastDuration ?? durationHHMM;
                        //                 extraHHMM = _lastExtra ?? extraHHMM;
                        //               });
                        //             }
                        //           },
                        //           icon: const Icon(Icons.history),
                        //           label: const Text("Use last"),
                        //         ),
                        //       )
                        //     : Container(),
                      ],
                    ),
                  );
              }
            }

            bool canNext() {
              switch (step) {
                case 0:
                  return validStep0();
                case 1:
                  return validStep1();
                case 2:
                  return validStep2();
                case 3:
                  return validStep3();
              }
              return false;
            }

            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildHeader(),
                  Flexible(child: SingleChildScrollView(child: buildStep())),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Row(
                      children: [
                        if (step > 0)
                          OutlinedButton.icon(
                            onPressed: () => setSheet(() => step--),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text("Back"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBlue),
                            ),
                          ),
                        if (step == 0)
                          const SizedBox(width: 0)
                        else
                          const SizedBox(width: 8),
                        const Spacer(),
                        if (step < 3)
                          FilledButton.icon(
                            onPressed: canNext()
                                ? () => setSheet(() => step++)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text("Next"),
                          )
                        else
                          FilledButton.icon(
                            onPressed: canNext()
                                ? () async {
                                    final school = schoolCtl.text.trim();
                                    final centre = centreCtl.text.trim();
                                    final subj = subjectCtl.text.trim();
                                    final board = boardCtl.text.trim();

                                    if (school.isEmpty ||
                                        centre.isEmpty ||
                                        subj.isEmpty ||
                                        board.isEmpty) {
                                      _toast(
                                        "Required fields cannot be empty. Please fill in all mandatory fields.",
                                      );
                                      return;
                                    }

                                    final normalizedStart = _normalizeHHMM(
                                      startHHMM,
                                      fallback: "09:00",
                                    );
                                    final normalizedDuration = _normalizeHHMM(
                                      durationHHMM,
                                      fallback: "01:30",
                                      allowZero: false,
                                    );
                                    final normalizedExtra = _normalizeHHMM(
                                      extraHHMM,
                                      fallback: "00:15",
                                    );

                                    if (_toMin(normalizedDuration) <= 0) {
                                      _toast(
                                        "Set a valid exam duration before saving.",
                                      );
                                      return;
                                    }

                                    final dd = selectedDate.day
                                        .toString()
                                        .padLeft(2, '0');
                                    final mm = selectedDate.month
                                        .toString()
                                        .padLeft(2, '0');
                                    final yy = selectedDate.year.toString();

                                    var newCard = ExamCardData(
                                      recordId: generateId(),
                                      school: school,
                                      centreNumber: centre,
                                      date: "$dd/$mm/$yy",
                                      subject: "$subj ($board)",
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
                                      _lastSchool = school;
                                      _lastCentre = centre;
                                      _lastSubject = subj;
                                      _lastBoard = board;
                                      _lastStart = normalizedStart;
                                      _lastDuration = normalizedDuration;
                                      _lastExtra = normalizedExtra;
                                    });
                                    await _saveState();
                                    if (!mounted) return;
                                    Navigator.of(context).pop(true);
                                  }
                                : null,
                            icon: const Icon(Icons.check),
                            label: const Text("Save"),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      _toast("Exam created");
    }
  }

  Future<String> pickDur(String time, String title) async {
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VigiloDurationPickerSheet(
        initialDuration: time,
        title: title,
      ),
    );
    return res ?? "";
  }

  int get _activeExamCount =>
      _cards.where((c) => c.running && c.phase != ExamPhase.finished).length;

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
        appBar: AppBar(
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openLicenseActivation,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text('Vigilo ERC'),
            ),
          ),
          actions: [
            const SizedBox(width: 8),
            IconButton(
              tooltip: dark ? 'Light theme' : 'Dark theme',
              icon: Icon(dark ? Icons.wb_sunny : Icons.nights_stay),
              onPressed: widget.onToggleTheme,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const LicenseRequiredView(),
      );
    }

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
        actions: [
          _archiveCards.isNotEmpty
              ? InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    isArchiveView = !isArchiveView;
                    isArchiveMode = false;
                    if (isArchiveView) {
                      _toast(" Viewing archived exams");
                    } else {
                      _toast(" Viewing active exams");
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      isArchiveView ? Icons.archive : Icons.archive_outlined,
                      color: isArchiveView ? kGreen : null,
                    ),
                  ),
                )
              : Container(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: dark ? 'Light theme' : 'Dark theme',
            icon: Icon(dark ? Icons.wb_sunny : Icons.nights_stay),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: isArchiveView
                ? _archiveCards.length + 1
                : _cards.length + 1,
            separatorBuilder: (_, index) => const SizedBox(height: 16),
            itemBuilder: (context, idx) {
              if (idx == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatChip(
                      invigilatorsOnDuty: allInvigilators,
                      activeExams: isArchiveView
                          ? _archiveCards.length
                          : _activeExamCount,
                      isArchiveView: isArchiveView,
                    ),
                    if (!isArchiveView && _cards.isEmpty) ...[
                      const SizedBox(height: 28),
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              "Vigilo",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Exam Room Control",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No exams yet",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Tap + Exam to create your first exam",
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : const Color(0xFF5B708A),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }
              final i = idx - 1;
              final c = isArchiveView ? _archiveCards[i] : _cards[i];
              return ExamCard(
                data: c,
                pulse: _pulse,
                isExamCompleted: c.phase == ExamPhase.finished,
                isArchiveMode: isArchiveMode,
                extraPulse: extraPulse,
                tapScale: isArchiveView ? 1.0 : _cards[i].tapScale,
                onProgressDragState: (dragging) {
                  _isAdjustingProgress = dragging;
                },
                onProgressChangeEnd: (v) async {
                  if (!mounted || i < 0 || i >= _cards.length) return;
                  _isAdjustingProgress = true;
                  setState(() {
                    _cards[i] = _applyManualProgress(_cards[i], v);
                  });
                  try {
                    await _saveState();
                  } finally {
                    _isAdjustingProgress = false;
                  }
                },
                onSelect: () {
                  if (!isArchiveView) {
                    if (!_isArchivableExam(c)) {
                      _toast("Only finished exams can be archived");
                      return;
                    }
                    setState(() {
                      _cards[i] = _cards[i].copyWith(
                        isSelected: !_cards[i].isSelected,
                      );
                    });
                  }
                },
                onChevronTap: () {
                  if (!isArchiveView) {
                    _toggleExpanded(i);
                  } else {
                    _cards.add(_archiveCards[i]);
                    _archiveCards.removeAt(i);
                    if (_archiveCards.isEmpty) {
                      isArchiveView = false;
                    }
                    _toast("Exam restored");
                    _saveState();
                    setState(() {});
                  }
                },
                onEditDate: () async {
                  if (_cards[i].phase == ExamPhase.finished) {
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
                    builder: (_) => VigiloDatePickerSheet(initialDate: initial),
                  );
                  if (picked != null) {
                    final dd = picked.day.toString().padLeft(2, '0');
                    final mm = picked.month.toString().padLeft(2, '0');
                    final yy = picked.year.toString();
                    setState(() => _cards[i] = c.copyWith(date: "$dd/$mm/$yy"));
                    _saveState();
                  }
                },
                onEditStartTime: () async {
                  if (_cards[i].phase == ExamPhase.finished) {
                    return;
                  }
                  final t = _parseHHMM(c.normalStart);
                  final picked = await showModalBottomSheet<TimeOfDay>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => VigiloTimePickerSheet(
                      initialTime: TimeOfDay(hour: t.$1, minute: t.$2),
                    ),
                  );
                  if (picked != null) {
                    final hh = picked.hour.toString().padLeft(2, '0');
                    final mm = picked.minute.toString().padLeft(2, '0');
                    final selectedStart = "$hh:$mm";
                    setState(
                      () => _cards[i] = _recompute(
                        c.copyWith(normalStart: selectedStart),
                      ),
                    );
                    _saveState();
                  }
                },
                onEditDuration: () async {
                  if (_cards[i].phase == ExamPhase.finished) {
                    return;
                  }
                  String res = await pickDur(c.normalDuration, "Set Duration");
                  if (res != "") {
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
                      () => _cards[i] = _recompute(
                        c.copyWith(normalDuration: res),
                      ),
                    );
                    await _saveState();
                    final recordId = _cards[i].recordId;
                    if (recordId != null) {
                      await _sessionService.updatePlannedDuration(
                        examRecordId: recordId,
                        normalDurationMs: _cards[i].normalSeconds * 1000,
                        extraTimeMs: _cards[i].extraSeconds * 1000,
                        reason:
                            "Normal Time Updated (${diff >= 0 ? '+' : ''}${diff}m)",
                        detail: detail,
                      );
                      await _refreshCards();
                    }
                  }
                },
                onEditExtra: () async {
                  if (_cards[i].phase == ExamPhase.finished) {
                    return;
                  }
                  String res = await pickDur(c.extraTime, "Add Extra Time");
                  if (res != "") {
                    final previousMinutes = _toMin(c.extraTime);
                    final updatedMinutes = _toMin(res);

                    setState(
                      () => _cards[i] = _recompute(c.copyWith(extraTime: res)),
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
                    final recordId = _cards[i].recordId;
                    if (recordId != null) {
                      await _sessionService.updatePlannedDuration(
                        examRecordId: recordId,
                        normalDurationMs: _cards[i].normalSeconds * 1000,
                        extraTimeMs: _cards[i].extraSeconds * 1000,
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
                    if (!mounted || i < 0 || i >= _cards.length) return;
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
                      _cards[i] = fixed;
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
                    if (!mounted || i < 0 || i >= _cards.length) return;
                    setState(() {
                      _cards[i] = _applyManualProgress(u, u.progress);
                    });
                  }
                },
                onTimeTap: () {
                  if (_cards[i].phase == ExamPhase.finished) {
                    return;
                  }
                  _cards[i] = c.copyWith(isActiveTime: !c.isActiveTime);
                  setState(() {});
                  if (c.isActiveTime) {
                    _clickTimer = Timer(const Duration(seconds: 7), () {
                      _cards[i] = c.copyWith(isActiveTime: true);
                      setState(() {});
                    });
                  } else {
                    _clickTimer?.cancel();
                  }
                },
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: AnimatedSlide(
              offset: anyOpen ? const Offset(0, 2) : Offset.zero,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: anyOpen ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: FloatingActionButton.extended(
                  tooltip: 'Quick Add',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  foregroundColor: Colors.white,
                  onPressed: _openQuickAddWizard,
                  label: const Text(
                    "+ Exam",
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                  // icon: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
                      _toast("Vibration on for this exam");
                      await HapticFeedback.vibrate();
                    } catch (_) {}
                  } else {
                    _toast("Vibration off for this exam");
                  }
                } else {
                  _toast("Open an exam to use Vibrate");
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
                    );
                  } else {
                    _toast("No finished selected exams to archive");
                  }
                  _toast("Archive mode off");
                  isArchiveMode = false;
                  setState(() {});
                  return;
                }

                if (_cards.isEmpty) {
                  _toast("No exams available to archive");
                  return;
                }
                if (_archivableExamCount == 0) {
                  _toast("Only finished exams can be archived");
                  return;
                }
                _toast("Archive mode is on - tap finished exams to archive");
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
                          _toast("Auto-start at the scheduled time");
                        } else {
                          _toast("Auto start is off");
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
                  _toast("Open an exam to use Officer Tools");
                }
              }
            },
            isVibrateOn: checkVibrateOn(),
            isArchiveMode: isArchiveMode,
          ),
        ),
      ),
    );
  }

  bool checkVibrateOn() {
    int i = getExpandedCardIndex();
    if (i != -1) {
      return _cards[getExpandedCardIndex()].vibrateOn;
    } else {
      return true;
    }
  }

  int getExpandedCardIndex() {
    return _cards.indexWhere((card) => card.expanded);
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString()}";
}
