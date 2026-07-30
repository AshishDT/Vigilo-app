import '../enums/exam_phase.dart';
import 'briefing_model.dart';
import 'incident.dart' show Incident;
import 'message.dart';
import 'schedule.dart';

const List<String> kAllowedSetUpRoles = <String>[
  'Exam Officer',
  'Senior Invigilator',
  'Invigilator',
];

String normalizeSetUpRole(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return '';

  for (final allowed in kAllowedSetUpRoles) {
    if (allowed.toLowerCase() == normalized.toLowerCase()) {
      return allowed;
    }
  }
  return '';
}

class ExamCardData {
  ExamCardData({
    this.recordId,
    required this.school,
    this.centreNumber = '',
    required this.date,
    required this.subject,
    this.examLevel,
    required this.start,
    required this.duration,
    required this.end,
    required this.normalStart,
    required this.normalDuration,
    required this.normalEnd,
    required this.extraTime,
    required this.totalDuration,
    required this.extraEnd,
    this.roomsSnapshot = '',
    this.invigilatorsSnapshot = '',
    this.progress = 0.0,
    this.phase = ExamPhase.normal,
    this.expanded = false,
    this.notes = '',
    this.setUpBy = '',
    this.setUpRole = '',
    this.running = false,
    this.epochStart,
    this.pausedSeconds = 0,
    this.vibrateOn = true,
    this.autoStart = true,
    this.autoStartUserModified = false,
    this.isPaused = false,
    this.wasEverStarted = false,
    List<ScheduleData>? scheduleList,
    List<BriefingItem>? briefings,
    List<Message>? messages,
    this.isSelected = false,
    this.tapScale = 1.0,
    this.isActiveTime = true,
    List<Incident>? logs,
  }) : scheduleList = scheduleList == null
           ? null
           : List<ScheduleData>.unmodifiable(scheduleList),
       briefings = briefings == null
           ? null
           : List<BriefingItem>.unmodifiable(briefings),
       messages = messages == null
           ? null
           : List<Message>.unmodifiable(messages),
       logs = List<Incident>.unmodifiable(logs ?? const []);

  final String? recordId;
  final String school, centreNumber, date, subject;
  final String? examLevel;
  final String start, duration, end;
  final String normalStart, normalDuration, normalEnd;
  final String extraTime, totalDuration, extraEnd;
  final String roomsSnapshot, invigilatorsSnapshot;
  final double progress;
  final ExamPhase phase;
  final bool expanded;
  final String notes, setUpBy, setUpRole;

  final bool running;
  final DateTime? epochStart;
  final int pausedSeconds;

  /// True once the exam has ever been started. Survives a reset so that
  /// date-passed locking does not apply to exams that have a history.
  final bool wasEverStarted;

  final bool vibrateOn;
  final bool autoStart;
  final bool autoStartUserModified;
  final bool isPaused;
  final bool isSelected;
  final double tapScale;
  final bool isActiveTime;

  final List<ScheduleData>? scheduleList;
  final List<BriefingItem>? briefings;
  final List<Message>? messages;
  final List<Incident> logs;

  String get subjectName => _splitTrailingMetadata(subject).$1;

  String get subjectBoard => _splitTrailingMetadata(subject).$2;

  String get organizationName => _splitTrailingMetadata(school).$1;

  String get legacyCentreNumber => _splitTrailingMetadata(school).$2;

  String get resolvedCentreNumber {
    final explicit = centreNumber.trim();
    if (explicit.isNotEmpty) return explicit;
    return legacyCentreNumber;
  }

  String get organizationCode => resolvedCentreNumber;

  String get normalizedSetUpRole => normalizeSetUpRole(setUpRole);

  int _hhmmToMin(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  int get normalSeconds => _hhmmToMin(normalDuration) * 60;

  int get extraSeconds => _hhmmToMin(extraTime) * 60;

  int get totalSeconds => normalSeconds + extraSeconds;

  bool get isDatePassed {
    // An exam has a history if it is currently running/paused/finished OR
    // if it was ever started (even after a reset — wasEverStarted survives resets).
    // Imported idle sessions have epochStart pre-set by session_service so
    // we cannot rely on epochStart alone.
    final hasActuallyStarted =
        running || isPaused || phase == ExamPhase.finished || wasEverStarted;
    if (hasActuallyStarted) return false;

    try {
      String? cleanDate;
      final clean = date.trim().replaceAll(RegExp(r'\s+'), ' ');

      // 1. Try DD/MM/YYYY or DD-MM-YYYY
      final dmyRegex = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$');
      var match = dmyRegex.firstMatch(clean);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        if (year < 100) year += 2000;
        cleanDate = '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
      } else {
        // 2. Try D MMM YYYY (e.g. 12 May 2026)
        final parts = clean.split(' ');
        if (parts.length >= 3) {
          final day = int.tryParse(parts[0]);
          final monthStr = parts[1].toLowerCase();
          var year = int.tryParse(parts[2]);

          const months = {
            'jan': 1, 'january': 1,
            'feb': 2, 'february': 2,
            'mar': 3, 'march': 3,
            'apr': 4, 'april': 4,
            'may': 5,
            'jun': 6, 'june': 6,
            'jul': 7, 'july': 7,
            'aug': 8, 'august': 8,
            'sep': 9, 'september': 9,
            'oct': 10, 'october': 10,
            'nov': 11, 'november': 11,
            'dec': 12, 'december': 12,
          };
          final month = months[monthStr];
          if (day != null && month != null && year != null) {
            if (year < 100) year += 2000;
            cleanDate = '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
          }
        }
      }

      // 3. Try YYYY-MM-DD
      if (cleanDate == null) {
        final ymdRegex = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$');
        var ymdMatch = ymdRegex.firstMatch(clean);
        if (ymdMatch != null) {
          final year = int.parse(ymdMatch.group(1)!);
          final month = int.parse(ymdMatch.group(2)!);
          final day = int.parse(ymdMatch.group(3)!);
          cleanDate = '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
        }
      }

      if (cleanDate != null) {
        final dp = cleanDate.split('/');
        final tp = normalStart.split(':');
        if (dp.length == 3 && tp.length >= 2) {
          final d = int.parse(dp[0]);
          final m = int.parse(dp[1]);
          final y = int.parse(dp[2]);
          final hh = int.parse(tp[0]);
          final mm = int.parse(tp[1]);
          final scheduled = DateTime(y, m, d, hh, mm);
          return scheduled.isBefore(DateTime.now());
        }
      }
    } catch (_) {}

    try {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        final tp = normalStart.split(':');
        if (tp.length >= 2) {
          final hh = int.parse(tp[0]);
          final mm = int.parse(tp[1]);
          final scheduled = DateTime(parsed.year, parsed.month, parsed.day, hh, mm);
          return scheduled.isBefore(DateTime.now());
        }
      }
    } catch (_) {}

    return false;
  }

  (String, String) _splitTrailingMetadata(String value) {
    final trimmed = value.trim();
    final start = trimmed.lastIndexOf('(');
    final end = trimmed.lastIndexOf(')');
    if (start > 0 && end == trimmed.length - 1 && start < end) {
      return (
        trimmed.substring(0, start).trim(),
        trimmed.substring(start + 1, end).trim(),
      );
    }
    return (trimmed, '');
  }

  Map<String, dynamic> toJson() => {
    'recordId': recordId,
    'school': school,
    'centreNumber': centreNumber,
    'date': date,
    'subject': subject,
    'examLevel': examLevel,
    'start': start,
    'duration': duration,
    'end': end,
    'normalStart': normalStart,
    'normalDuration': normalDuration,
    'normalEnd': normalEnd,
    'extraTime': extraTime,
    'totalDuration': totalDuration,
    'extraEnd': extraEnd,
    'roomsSnapshot': roomsSnapshot,
    'invigilatorsSnapshot': invigilatorsSnapshot,
    'progress': progress,
    'phase': phase.index,
    'expanded': expanded,
    'notes': notes,
    'setUpBy': setUpBy,
    'setUpRole': normalizedSetUpRole,
    'running': running,
    'epochStart': epochStart?.millisecondsSinceEpoch,
    'pausedSeconds': pausedSeconds,
    'vibrateOn': vibrateOn,
    'autoStart': autoStart,
    'autoStartUserModified': autoStartUserModified,
    'isPaused': isPaused,
    'wasEverStarted': wasEverStarted,
    'scheduleList': scheduleList?.map((item) => item.toJson()).toList(),
    'briefings': briefings?.map((item) => item.toJson()).toList(),
    'messages': messages?.map((item) => item.toJson()).toList(),
    'logs': logs.map((item) => item.toJson()).toList(),
  };

  static ExamCardData fromJson(Map<String, dynamic> m) => ExamCardData(
    recordId: (m['recordId'] ?? m['examRecordId']) as String?,
    school: m['school'],
    centreNumber: ((m['centreNumber'] ?? m['centerNumber']) ?? '') as String,
    date: m['date'],
    subject: m['subject'],
    examLevel: m['examLevel'] as String?,
    start: m['start'],
    duration: m['duration'],
    end: m['end'],
    normalStart: m['normalStart'],
    normalDuration: m['normalDuration'],
    normalEnd: m['normalEnd'],
    extraTime: m['extraTime'],
    totalDuration: m['totalDuration'],
    extraEnd: m['extraEnd'],
    roomsSnapshot: (m['roomsSnapshot'] ?? '') as String,
    invigilatorsSnapshot: (m['invigilatorsSnapshot'] ?? '') as String,
    progress: (m['progress'] ?? 0.0).toDouble(),
    phase: ExamPhase.values[(m['phase'] ?? 0) as int],
    expanded: (m['expanded'] ?? false) as bool,
    notes: (m['notes'] ?? '') as String,
    setUpBy: (m['setUpBy'] ?? '') as String,
    setUpRole: normalizeSetUpRole((m['setUpRole'] ?? '') as String),
    running: (m['running'] ?? false) as bool,
    epochStart: (m['epochStart'] == null)
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['epochStart'] as int),
    pausedSeconds: (m['pausedSeconds'] ?? 0) as int,
    vibrateOn: (m['vibrateOn'] ?? true) as bool,
    autoStart: (m['autoStart'] ?? true) as bool,
    autoStartUserModified: (m['autoStartUserModified'] ?? false) as bool,
    isPaused: (m['isPaused'] ?? false) as bool,
    wasEverStarted: (m['wasEverStarted'] ?? false) as bool,
    scheduleList: m['scheduleList'] != null
        ? (m['scheduleList'] as List)
              .map(
                (item) =>
                    ScheduleData.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : null,
    briefings: m['briefings'] != null
        ? (m['briefings'] as List)
              .map(
                (item) =>
                    BriefingItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : null,
    messages: m['messages'] != null
        ? (m['messages'] as List)
              .map((item) => Message.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : null,
    logs: m['logs'] != null
        ? (m['logs'] as List)
              .map((item) => Incident.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : [],
  );

  ExamCardData copyWith({
    String? recordId,
    String? school,
    String? centreNumber,
    String? date,
    String? subject,
    String? examLevel,
    bool clearExamLevel = false,
    String? start,
    String? duration,
    String? end,
    String? normalStart,
    String? normalDuration,
    String? normalEnd,
    String? extraTime,
    String? totalDuration,
    String? extraEnd,
    String? roomsSnapshot,
    String? invigilatorsSnapshot,
    double? progress,
    ExamPhase? phase,
    bool? expanded,
    String? notes,
    String? setUpBy,
    String? setUpRole,
    bool? running,
    DateTime? epochStart,
    int? pausedSeconds,
    bool? vibrateOn,
    bool? autoStart,
    bool? autoStartUserModified,
    bool? isPaused,
    bool? wasEverStarted,
    bool? isSelected,
    bool? isImage,
    String? fileName,
    String? filePath,
    List<ScheduleData>? scheduleList,
    List<BriefingItem>? briefings,
    List<Message>? messages,
    List<Incident>? logs,
    double? tapScale,
    bool? isActiveTime,
  }) {
    return ExamCardData(
      recordId: recordId ?? this.recordId,
      school: school ?? this.school,
      centreNumber: centreNumber ?? this.centreNumber,
      date: date ?? this.date,
      subject: subject ?? this.subject,
      examLevel: clearExamLevel ? null : (examLevel ?? this.examLevel),
      start: start ?? this.start,
      duration: duration ?? this.duration,
      end: end ?? this.end,
      normalStart: normalStart ?? this.normalStart,
      normalDuration: normalDuration ?? this.normalDuration,
      normalEnd: normalEnd ?? this.normalEnd,
      extraTime: extraTime ?? this.extraTime,
      totalDuration: totalDuration ?? this.totalDuration,
      extraEnd: extraEnd ?? this.extraEnd,
      roomsSnapshot: roomsSnapshot ?? this.roomsSnapshot,
      invigilatorsSnapshot: invigilatorsSnapshot ?? this.invigilatorsSnapshot,
      progress: progress ?? this.progress,
      phase: phase ?? this.phase,
      expanded: expanded ?? this.expanded,
      notes: notes ?? this.notes,
      setUpBy: setUpBy ?? this.setUpBy,
      setUpRole: normalizeSetUpRole(setUpRole ?? this.setUpRole),
      running: running ?? this.running,
      epochStart: epochStart ?? this.epochStart,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      vibrateOn: vibrateOn ?? this.vibrateOn,
      autoStart: autoStart ?? this.autoStart,
      autoStartUserModified:
          autoStartUserModified ?? this.autoStartUserModified,
      isPaused: isPaused ?? this.isPaused,
      wasEverStarted: wasEverStarted ?? this.wasEverStarted,
      isSelected: isSelected ?? this.isSelected,
      scheduleList: scheduleList ?? this.scheduleList,
      briefings: briefings ?? this.briefings,
      messages: messages ?? this.messages,
      logs: logs ?? this.logs,
      tapScale: tapScale ?? this.tapScale,
      isActiveTime: isActiveTime ?? this.isActiveTime,
    );
  }
}
