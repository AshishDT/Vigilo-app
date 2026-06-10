enum SessionStatus { idle, running, paused, ended }

extension SessionStatusExtension on SessionStatus {
  String get code {
    switch (this) {
      case SessionStatus.idle:
        return 'idle';
      case SessionStatus.running:
        return 'running';
      case SessionStatus.paused:
        return 'paused';
      case SessionStatus.ended:
        return 'ended';
    }
  }

  static SessionStatus fromCode(String code) {
    switch (code) {
      case 'idle':
        return SessionStatus.idle;
      case 'running':
        return SessionStatus.running;
      case 'paused':
        return SessionStatus.paused;
      case 'ended':
        return SessionStatus.ended;
      default:
        return SessionStatus.idle;
    }
  }
}

class SessionSnapshot {
  final String examRecordId;
  final SessionStatus sessionStatus;
  final DateTime startedAtUtc;
  final DateTime? pauseStartedAtUtc;
  final int totalPausedMs;
  final int plannedDurationMs;
  final DateTime? endedAtUtc;
  final DateTime? lastCheckpointAtUtc;
  final DateTime? lastKnownNowUtc;
  final String? integrityFlag;

  SessionSnapshot({
    required this.examRecordId,
    required this.sessionStatus,
    required this.startedAtUtc,
    required this.totalPausedMs,
    required this.plannedDurationMs,
    this.pauseStartedAtUtc,
    this.endedAtUtc,
    this.lastCheckpointAtUtc,
    this.lastKnownNowUtc,
    this.integrityFlag,
  });

  Map<String, dynamic> toMap() {
    return {
      'exam_record_id': examRecordId,
      'session_status': sessionStatus.code,
      'started_at_utc': startedAtUtc.toIso8601String(),
      'pause_started_at_utc': pauseStartedAtUtc?.toIso8601String(),
      'total_paused_ms': totalPausedMs,
      'planned_duration_ms': plannedDurationMs,
      'ended_at_utc': endedAtUtc?.toIso8601String(),
      'last_checkpoint_at_utc': lastCheckpointAtUtc?.toIso8601String(),
      'last_known_now_utc': lastKnownNowUtc?.toIso8601String(),
      'integrity_flag': integrityFlag,
    };
  }

  factory SessionSnapshot.fromMap(Map<String, dynamic> map) {
    return SessionSnapshot(
      examRecordId: map['exam_record_id'] as String,
      sessionStatus: SessionStatusExtension.fromCode(
        map['session_status'] as String,
      ),
      startedAtUtc: DateTime.parse(map['started_at_utc'] as String),
      pauseStartedAtUtc: map['pause_started_at_utc'] != null
          ? DateTime.parse(map['pause_started_at_utc'] as String)
          : null,
      totalPausedMs: map['total_paused_ms'] as int,
      plannedDurationMs: map['planned_duration_ms'] as int,
      endedAtUtc: map['ended_at_utc'] != null
          ? DateTime.parse(map['ended_at_utc'] as String)
          : null,
      lastCheckpointAtUtc: map['last_checkpoint_at_utc'] != null
          ? DateTime.parse(map['last_checkpoint_at_utc'] as String)
          : null,
      lastKnownNowUtc: map['last_known_now_utc'] != null
          ? DateTime.parse(map['last_known_now_utc'] as String)
          : null,
      integrityFlag: map['integrity_flag'] as String?,
    );
  }
}
