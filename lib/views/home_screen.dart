import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:vibration/vibration.dart';

import '../enums/exam_phase.dart';
import '../models/exam_card_data.dart';
import '../models/incident.dart';
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
import 'widgets/animated_scale_on_press.dart';
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
import 'widgets/home_sessions_list_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dark,
    required this.onToggleTheme,
    this.initialLicenseRequired,
  });

  final bool dark;
  final VoidCallback onToggleTheme;
  final bool? initialLicenseRequired;

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
  final Set<String> _scheduledReadyNotifiedIds = <String>{};
  bool _tickInFlight = false;
  bool _isAdjustingProgress = false;
  final ScrollController _homeScrollController = ScrollController();

  List<String> _getUniqueInvigilators(ExamCardData s) {
    if (s.scheduleList != null && s.scheduleList!.isNotEmpty) {
      final names = s.scheduleList!
          .expand((p) => p.invigilators)
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      return names;
    }
    if (s.invigilatorsSnapshot.trim().isNotEmpty) {
      final names = s.invigilatorsSnapshot
          .replaceAll('\r', '\n')
          .split(RegExp(r'[\n,;|]+'))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
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
  final Map<String, ValueNotifier<ExamCardData>> _cardNotifiers = {};
  bool _licenseRequired = true;
  bool _isSessionsLoaded = false;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _isUserScrolling = false;
  bool _pendingCardRefreshAfterScroll = false;
  bool _isThemeSwitching = false;
  Timer? _themeSwitchTimer;

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) {
      _isThemeSwitching = true;
      _themeSwitchTimer?.cancel();
      _themeSwitchTimer = Timer(
        kThemeFadeDuration + const Duration(milliseconds: 100),
        () {
          if (mounted) {
            setState(() {
              _isThemeSwitching = false;
            });
          }
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _licenseRequired = widget.initialLicenseRequired ?? true;
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
    // Eliminated _extraPulseTicker periodic setState to avoid periodic scroll interruptions
  }

  Future<void> _initializeHomeState() async {
    await _loadLicenseStatus();
    if (!mounted) return;
    if (_licenseRequired) return;
    await _sessionService.initialize();
    if (!mounted) return;
    await _loadState();
    if (!mounted) return;
    await _clearLegacyLicenceCentrePrefillIfNeeded();
    if (!mounted) return;
    await _seedOrganizationFromLicenseIfNeeded();
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

  Future<void> _refreshCards({bool resort = false}) async {
    final state = await _sessionService.loadHomeState();
    final lastImportIds = await _sessionService.getLastImportedSessionIds();
    final activeIds = state.cards
        .map((card) => card.recordId)
        .whereType<String>()
        .toSet();
    _normalTimeWarningVibrationSent.retainAll(activeIds);
    _extraTimeWarningVibrationSent.retainAll(activeIds);
    _scheduledReadyNotifiedIds.retainAll(activeIds);
    if (!mounted) return;
    setState(() {
      _isSessionsLoaded = true;
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
      _updateFilteredAndGroupedCards(resort: resort);
      for (final card in _cards) {
        final id = card.recordId;
        if (id != null && _cardNotifiers.containsKey(id)) {
          _cardNotifiers[id]!.value = card;
        }
      }
      for (final card in _archiveCards) {
        final id = card.recordId;
        if (id != null && _cardNotifiers.containsKey(id)) {
          _cardNotifiers[id]!.value = card;
        }
      }
    });
  }

  Future<void> _loadState() async {
    final state = await _sessionService.loadHomeState();
    final lastImportIds = await _sessionService.getLastImportedSessionIds();
    if (!mounted) return;
    setState(() {
      _isSessionsLoaded = true;
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
      _updateFilteredAndGroupedCards(resort: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _sessionService.checkpoint();
      _sessionService.flushPendingDeltaSaves();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    await _loadLicenseStatus();
    if (!mounted || _licenseRequired) return;
    final ended = await _sessionService.autoEndIfNeeded();
    if (!mounted) return;
    if (ended || _cards.any((c) => c.running || c.isPaused)) {
      await _refreshCards();
    }
    if (!mounted) return;
    _tick();
  }

  Future<void> _loadLicenseStatus() async {
    final required = await LicenseService.requiresValidLicense();
    if (!mounted) return;
    final wasRequired = _licenseRequired;
    setState(() {
      _licenseRequired = required;
    });
    if (wasRequired && !required) {
      await _sessionService.initialize();
      if (!mounted) return;
      await _loadState();
      if (!mounted) return;
      await _clearLegacyLicenceCentrePrefillIfNeeded();
      if (!mounted) return;
      await _seedOrganizationFromLicenseIfNeeded();
    }
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
    _sessionService.flushPendingDeltaSaves();
    for (final notifier in _cardNotifiers.values) {
      notifier.dispose();
    }
    _cardNotifiers.clear();
    _scheduledReadyNotifiedIds.clear();
    _pulse.dispose();
    _fabDialCtrl.dispose();
    _homeScrollController.dispose();
    _ticker?.cancel();
    _extraPulseTicker?.cancel();
    _clickTimer?.cancel();
    _themeSwitchTimer?.cancel();
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
    if (incoming.isEmpty) return [];
    if (previous.isEmpty) {
      return incoming.map((c) => c.copyWith(expanded: false)).toList();
    }

    final incomingById = <String, ExamCardData>{
      for (final card in incoming)
        if (card.recordId != null) card.recordId!: card,
    };

    final result = <ExamCardData>[];
    final seenIds = <String>{};

    // Preserve the exact in-session order from previous
    for (final prior in previous) {
      final id = prior.recordId;
      if (id != null && incomingById.containsKey(id)) {
        final card = incomingById[id]!;
        seenIds.add(id);

        final priorMessages = prior.messages;
        final incomingMessages = card.messages;
        final resolvedMessages = (priorMessages != null &&
                (incomingMessages == null ||
                    priorMessages.length > incomingMessages.length))
            ? priorMessages
            : incomingMessages;

        final priorLogs = prior.logs;
        final incomingLogs = card.logs;
        final resolvedLogs = (priorLogs.length > incomingLogs.length)
            ? priorLogs
            : incomingLogs;

        final priorRecipients = prior.selectedRecipients;
        final incomingRecipients = card.selectedRecipients;
        final resolvedRecipients = (priorRecipients != null && priorRecipients.isNotEmpty)
            ? priorRecipients
            : incomingRecipients;

        result.add(
          card.copyWith(
            expanded: prior.expanded,
            isSelected: prior.isSelected,
            tapScale: prior.tapScale,
            isActiveTime: prior.isActiveTime,
            messages: resolvedMessages,
            logs: resolvedLogs,
            selectedRecipients: resolvedRecipients,
          ),
        );
      } else if (id == null) {
        result.add(prior);
      }
    }

    // Append any newly added cards from incoming that were not in previous
    for (final card in incoming) {
      final id = card.recordId;
      if (id == null || !seenIds.contains(id)) {
        result.add(card.copyWith(expanded: false));
      }
    }

    return result;
  }

  DateTime? _scheduledDateTime(ExamCardData c) {
    final sched = c.scheduledDateTime;
    if (sched != null) return sched;
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
    if (_licenseRequired ||
        _tickInFlight ||
        _isAdjustingProgress ||
        _isThemeSwitching) {
      return;
    }
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

      final sched = _scheduledDateTime(card);
      final recordId = card.recordId;

      if (!card.autoStart || card.progress != 0.0) {
        // Redraw idle manual-start cards the exact second their scheduled time arrives
        if (sched != null && recordId != null) {
          if (!now.isBefore(sched)) {
            if (!_scheduledReadyNotifiedIds.contains(recordId)) {
              _scheduledReadyNotifiedIds.add(recordId);
              final idx = _cards.indexWhere((c) => c.recordId == recordId);
              if (idx != -1) {
                final updated = _cards[idx].copyWith();
                _cards[idx] = updated;
                if (_cardNotifiers.containsKey(recordId)) {
                  _cardNotifiers[recordId]!.value = updated;
                }
              }
            }
          } else {
            _scheduledReadyNotifiedIds.remove(recordId);
          }
        }
        continue;
      }

      if (sched == null || now.isBefore(sched)) continue;
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

    final isActivelyScrolling = _isUserScrolling ||
        (_homeScrollController.hasClients &&
            _homeScrollController.position.isScrollingNotifier.value);

    if (_pendingCardRefreshAfterScroll && !isActivelyScrolling) {
      _pendingCardRefreshAfterScroll = false;
      await _refreshCards();
      return;
    }

    final ended = await _sessionService.autoEndIfNeeded();
    if (autoStartTriggered || ended) {
      if (!isActivelyScrolling) {
        await _refreshCards();
      } else {
        _pendingCardRefreshAfterScroll = true;
      }
      await _vibrateForTenMinutesBeforeNormalEnd();
      await _vibrateForTenMinutesBeforeExtraEnd();
      return;
    }

    // Isolated tick refresh: only update active running cards; avoid scanning 500 records on disk every second.
    final hasRunningCards = _cards.any((c) => c.running);
    if (hasRunningCards && !isActivelyScrolling) {
      final updatedActive =
          await _sessionService.refreshActiveCardsOnly(_cards);
      if (updatedActive.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (final updated in updatedActive) {
            final idx = _cards.indexWhere((c) => c.recordId == updated.recordId);
            if (idx != -1) {
              final current = _cards[idx];
              final merged = current.copyWith(
                running: updated.running,
                isPaused: updated.isPaused,
                progress: updated.progress,
                phase: updated.phase,
                pausedSeconds: updated.pausedSeconds,
                epochStart: updated.epochStart,
                end: updated.end,
                normalEnd: updated.normalEnd,
                extraEnd: updated.extraEnd,
                logs: updated.logs.length >= current.logs.length
                    ? updated.logs
                    : current.logs,
              );
              _cards[idx] = merged;
              final id = updated.recordId;
              if (id != null && _cardNotifiers.containsKey(id)) {
                _cardNotifiers[id]!.value = merged;
              }
            } else {
              final archIdx =
                  _archiveCards.indexWhere((c) => c.recordId == updated.recordId);
              if (archIdx != -1) {
                final current = _archiveCards[archIdx];
                final merged = current.copyWith(
                  running: updated.running,
                  isPaused: updated.isPaused,
                  progress: updated.progress,
                  phase: updated.phase,
                  pausedSeconds: updated.pausedSeconds,
                  epochStart: updated.epochStart,
                  end: updated.end,
                  normalEnd: updated.normalEnd,
                  extraEnd: updated.extraEnd,
                  logs: updated.logs.length >= current.logs.length
                      ? updated.logs
                      : current.logs,
                );
                _archiveCards[archIdx] = merged;
                final id = updated.recordId;
                if (id != null && _cardNotifiers.containsKey(id)) {
                  _cardNotifiers[id]!.value = merged;
                }
              }
            }
          }
        });
      }
    }
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
    final idx = _cards.indexWhere((c) => c.recordId == recordId);
    if (idx != -1) {
      final current = _cards[idx];
      final updated = current.copyWith(
        logs: [...current.logs, inc],
      );
      _cards[idx] = updated;
      if (_cardNotifiers.containsKey(recordId)) {
        _cardNotifiers[recordId]!.value = updated;
      }
    }
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
          running: true,
          isPaused: false,
          epochStart: now,
          pausedSeconds: 0,
          wasEverStarted: true,
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
                subject: subject.trim(),
                examLevel: (level?.trim().isEmpty ?? true)
                    ? null
                    : level!.trim(),
                examBoard: board.trim().isEmpty ? null : board.trim(),
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
              await _sessionService.saveCardDelta(newCard, debounceDurationMs: 0);
              unawaited(
                _sessionService.saveLastUsed({
                  'school': null,
                  'centre': null,
                  'subject': null,
                  'board': null,
                  'start': null,
                  'duration': null,
                  'extra': null,
                }),
              );
              if (context.mounted) {
                context.safePop(true);
              }
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




    if (_licenseRequired) {
      return AnimatedContainer(
        duration: kThemeFadeDuration,
        curve: kThemeFadeCurve,
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
          body: SafeArea(
            child: Column(
              children: [
                _header(dark),
                Expanded(
                  child: LicenseRequiredView(dark: dark),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: kThemeFadeDuration,
      curve: kThemeFadeCurve,
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
            opacity: (_isSessionsLoaded && !anyOpen) ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
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
              extendedPadding: const EdgeInsetsDirectional.only(
                start: 13,
                end: 16,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: _fabOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.add, size: 16),
                  ),
                  const SizedBox(width: 2),
                  AnimatedSwitcher(
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
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: FooterWidget(
              isDark: dark,
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
                        onSaveData: () async {
                          final targetId = _cards[i].recordId;
                          final idx = targetId != null
                              ? _cards.indexWhere((c) => c.recordId == targetId)
                              : i;
                          if (idx >= 0 && idx < _cards.length) {
                            await _sessionService.saveCardDelta(
                              _cards[idx],
                              debounceDurationMs: 0,
                            );
                          } else {
                            final archIdx = targetId != null
                                ? _archiveCards.indexWhere((c) => c.recordId == targetId)
                                : -1;
                            if (archIdx != -1) {
                              await _sessionService.saveCardDelta(
                                _archiveCards[archIdx],
                                debounceDurationMs: 0,
                              );
                            }
                          }
                        },
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
                          final cardToSave = _cards[i];
                          _sessionService.saveCardDelta(
                            cardToSave,
                            debounceDurationMs: 0,
                          );
                        },
                        onUpdateData: (updated) {
                          if (!mounted) return;
                          final targetId = updated.recordId;
                          final idx = targetId != null
                              ? _cards.indexWhere((c) => c.recordId == targetId)
                              : -1;
                          final resolvedIndex = idx != -1 ? idx : i;
                          if (resolvedIndex >= 0 && resolvedIndex < _cards.length) {
                            final current = _cards[resolvedIndex];
                            final merged = _mergeOfficerToolsUpdate(
                              current: current,
                              updated: updated,
                            );
                            _cards[resolvedIndex] = merged;
                            if (targetId != null &&
                                _cardNotifiers.containsKey(targetId)) {
                              _cardNotifiers[targetId]!.value = merged;
                            }
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _updateFilteredAndGroupedCards();
                                });
                              }
                            });
                          } else {
                            final archIdx = targetId != null
                                ? _archiveCards.indexWhere(
                                    (c) => c.recordId == targetId,
                                  )
                                : -1;
                            if (archIdx != -1) {
                              final current = _archiveCards[archIdx];
                              final merged = _mergeOfficerToolsUpdate(
                                current: current,
                                updated: updated,
                              );
                              _archiveCards[archIdx] = merged;
                              if (targetId != null &&
                                  _cardNotifiers.containsKey(targetId)) {
                                _cardNotifiers[targetId]!.value = merged;
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _updateFilteredAndGroupedCards();
                                  });
                                }
                              });
                            }
                          }
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
                    child: AnimatedOpacity(
                      opacity: _isSessionsLoaded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: StatChip(
                        isDark: dark,
                        invigilatorsOnDuty: allInvigilators,
                        activeExams: isArchiveView
                            ? _archiveCards.length
                            : _activeExamCount,
                        isArchiveView: isArchiveView,
                      ),
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: isArchiveView
                          ? (_archiveCards.isEmpty
                              ? SingleChildScrollView(
                                  key: ValueKey('archive_empty'),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(height: 20),
                                        HomeEmptyStateWidget(dark: dark),
                                        SizedBox(height: 120),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  key: const ValueKey('archive_list'),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    380,
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
                          : (!_isSessionsLoaded
                              ? Center(
                                  key: const ValueKey('sessions_loading'),
                                  child: CircularProgressIndicator(
                                    color: VigiloUiColors.blue(dark),
                                  ),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('sessions_loaded'),
                                  child: (_filteredCardsCached.isEmpty
                                      ? LayoutBuilder(
                                          builder: (context, constraints) =>
                                              SingleChildScrollView(
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    minHeight:
                                                        constraints.maxHeight,
                                                  ),
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        _cards.isEmpty
                                                            ? HomeEmptyStateWidget(dark: dark)
                                                            : FilteredEmptyStateWidget(
                                                                dark: dark,
                                                                onClear: () => setState(
                                                                  () {
                                                                    _statusFilter =
                                                                        'All';
                                                                    _dateFilter = 'All';
                                                                    _updateFilteredAndGroupedCards();
                                                                  },
                                                                ),
                                                              ),
                                                        const SizedBox(height: 45),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                        )
                                      : NotificationListener<ScrollNotification>(
                                          onNotification: (notification) {
                                            if (notification is ScrollStartNotification) {
                                              _isUserScrolling = true;
                                            } else if (notification is ScrollEndNotification) {
                                              _isUserScrolling = false;
                                            }
                                            return false;
                                          },
                                          child: HomeSessionsListView(
                                            itemScrollController: _itemScrollController,
                                            itemPositionsListener: _itemPositionsListener,
                                            groupedCards: _groupedCardsCached,
                                            highlightedDate: _highlightedDate,
                                            dark: dark,
                                            dateKeys: _dateKeys,
                                            formatDate: _fd,
                                            buildCard: _buildExamCard,
                                          ),
                                        )),
                                )),
                    ),
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
                                        await _refreshCards(resort: true);
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

  void _updateFilteredAndGroupedCards({bool resort = false}) {
    if (_cards.length <= 5) {
      _showSessionMgr = false;
      _statusFilter = 'All';
      _dateFilter = 'All';
    }

    if (resort) {
      _cards.sort(SessionService.compareExamCards);
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

    if (resort) {
      list.sort(SessionService.compareExamCards);
    }

    _filteredCardsCached = list;

    final map = <String, List<ExamCardData>>{};
    for (final s in list) {
      map.putIfAbsent(s.date, () => []).add(s);
    }

    final sortedKeys = map.keys.toList()
      ..sort((ka, kb) {
        DateTime? da, db;
        try {
          final pa = ka.split('/');
          da = DateTime(int.parse(pa[2]), int.parse(pa[1]), int.parse(pa[0]));
        } catch (_) {}
        try {
          final pb = kb.split('/');
          db = DateTime(int.parse(pb[2]), int.parse(pb[1]), int.parse(pb[0]));
        } catch (_) {}
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return ka.compareTo(kb);
      });

    final sortedMap = <String, List<ExamCardData>>{
      for (final k in sortedKeys) k: map[k]!,
    };
    _groupedCardsCached = sortedMap;
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

    debugPrint('[JumpToDate] === Date Picker Returned === selectedDate: $selectedDate');
    if (selectedDate != null && mounted) {
      // 1. Close session manager panel if open
      if (_showSessionMgr) {
        setState(() => _showSessionMgr = false);
      }

      final dates = _groupedCardsCached.keys.toList();
      final targetIndex = dates.indexOf(selectedDate);
      if (targetIndex != -1 && _itemScrollController.isAttached) {
        await _itemScrollController.scrollTo(
          index: targetIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      }

      if (mounted) {
        setState(() => _highlightedDate = selectedDate);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) {
            setState(() => _highlightedDate = null);
          }
        });
      }
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
              child: AnimatedDefaultTextStyle(
                duration: kThemeFadeDuration,
                curve: kThemeFadeCurve,
                style: TextStyle(
                  color: VigiloUiColors.text(dark),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
                child: const Text('Vigilo ERC'),
              ),
            ),
          ),
          const Spacer(),
          _conditionalHeaderAction(
            show: _archiveCards.isNotEmpty || isArchiveView,
            child: _headerIcon(
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
          ),
          _conditionalHeaderAction(
            show: _cards.length > 5,
            child: _headerIcon(
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
          ),
          _headerIcon(
            dark,
            dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
            onTap: () {
              _isThemeSwitching = true;
              _themeSwitchTimer?.cancel();
              _themeSwitchTimer = Timer(
                kThemeFadeDuration + const Duration(milliseconds: 100),
                () {
                  if (mounted) {
                    setState(() {
                      _isThemeSwitching = false;
                    });
                  }
                },
              );
              widget.onToggleTheme();
            },
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
    return AnimatedScaleOnPress(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
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
          child: TweenAnimationBuilder<Color?>(
            duration: kThemeFadeDuration,
            curve: kThemeFadeCurve,
            tween: ColorTween(end: color ?? VigiloUiColors.textSoft(dark)),
            builder: (context, iconColor, _) {
              return Icon(
                icon,
                color: iconColor,
                size: 23,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _conditionalHeaderAction({
    required bool show,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: show
          ? Padding(
              key: const ValueKey(true),
              padding: const EdgeInsets.only(right: 10),
              child: child,
            )
          : const SizedBox.shrink(key: ValueKey(false)),
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

    final currentData = listToUse[idx];
    final id = currentData.recordId ?? '';
    final notifier = _cardNotifiers.putIfAbsent(
      id,
      () => ValueNotifier<ExamCardData>(currentData),
    );
    if (notifier.value != currentData) {
      notifier.value = currentData;
    }

    return RepaintBoundary(
      key: ValueKey('repaint_${currentData.recordId}'),
      child: ValueListenableBuilder<ExamCardData>(
        key: ValueKey('val_listen_${currentData.recordId}'),
        valueListenable: notifier,
        builder: (context, cardData, _) {
          return ExamCard(
          key: key ?? ValueKey('exam_card_${cardData.recordId}'),
          isDark: widget.dark,
          data: cardData,
          pulse: _pulse,
          isExamCompleted:
              cardData.phase == ExamPhase.finished || isArchiveView,
          isArchiveMode: isArchiveMode,
          extraPulse: extraPulse,
          tapScale: isArchiveView ? 1.0 : cardData.tapScale,
      onProgressDragState: (dragging) {
        _isAdjustingProgress = dragging;
      },
      onProgressChangeEnd: (v) async {
        final currentIdx = _cards.indexWhere(
          (card) => card.recordId == c.recordId,
        );
        if (!mounted || currentIdx == -1) return;
        _isAdjustingProgress = true;
        final updated = _applyManualProgress(_cards[currentIdx], v);
        setState(() {
          _cards[currentIdx] = updated;
        });
        try {
          await _sessionService.saveCardDelta(updated);
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
            final updated = c.copyWith(date: "$dd/$mm/$yy");
            setState(() => _cards[saveIdx] = updated);
            await _sessionService.saveCardDelta(updated, debounceDurationMs: 0);
            await _refreshCards();
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
            final updated = _recompute(
              c.copyWith(normalStart: selectedStart),
            );
            setState(() => _cards[saveIdx] = updated);
            await _sessionService.saveCardDelta(updated, debounceDurationMs: 0);
            await _refreshCards();
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
            final updated = _recompute(c.copyWith(normalDuration: res));
            setState(() => _cards[saveIdx] = updated);
            await _sessionService.saveCardDelta(updated);
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
            final updated = _recompute(c.copyWith(extraTime: res));
            setState(() => _cards[saveIdx] = updated);
            await _sessionService.saveCardDelta(updated);
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
          final runningCard = _recompute(
            u.copyWith(
              running: true,
              isPaused: false,
              epochStart: now,
              pausedSeconds: 0,
              progress: 0.0,
              phase: ExamPhase.normal,
              normalStart: "$hh:$mm",
              wasEverStarted: true,
            ),
          );
          setState(() {
            _cards[saveIdx] = runningCard;
          });
          final recordId = runningCard.recordId;
          if (recordId != null) {
            if (_cardNotifiers.containsKey(recordId)) {
              _cardNotifiers[recordId]!.value = runningCard;
            }
            await _sessionService.startSession(
              examRecordId: recordId,
              startedAt: now,
              normalDurationMs: runningCard.normalSeconds * 1000,
              extraTimeMs: runningCard.extraSeconds * 1000,
            );
          }
          _tick();
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
      },
    ),
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
