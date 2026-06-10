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
