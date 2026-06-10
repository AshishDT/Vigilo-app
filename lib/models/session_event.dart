enum SessionEventType {
  start,
  endNormalTime,
  startExtraTime,
  pause,
  resume,
  end,
  recoveryAutoEnd,
  recoveredAfterTermination,
  checkpoint,
  incident,
  controlAction,
}

extension SessionEventTypeExtension on SessionEventType {
  String get code {
    switch (this) {
      case SessionEventType.start:
        return 'start';
      case SessionEventType.endNormalTime:
        return 'end_normal_time';
      case SessionEventType.startExtraTime:
        return 'start_extra_time';
      case SessionEventType.pause:
        return 'pause';
      case SessionEventType.resume:
        return 'resume';
      case SessionEventType.end:
        return 'end';
      case SessionEventType.recoveryAutoEnd:
        return 'recovery_auto_end';
      case SessionEventType.recoveredAfterTermination:
        return 'recovered_after_termination';
      case SessionEventType.checkpoint:
        return 'checkpoint';
      case SessionEventType.incident:
        return 'incident';
      case SessionEventType.controlAction:
        return 'control_action';
    }
  }

  static SessionEventType fromCode(String code) {
    switch (code) {
      case 'start':
        return SessionEventType.start;
      case 'end_normal_time':
        return SessionEventType.endNormalTime;
      case 'start_extra_time':
        return SessionEventType.startExtraTime;
      case 'pause':
        return SessionEventType.pause;
      case 'resume':
        return SessionEventType.resume;
      case 'end':
        return SessionEventType.end;
      case 'recovery_auto_end':
        return SessionEventType.recoveryAutoEnd;
      case 'recovered_after_termination':
        return SessionEventType.recoveredAfterTermination;
      case 'checkpoint':
        return SessionEventType.checkpoint;
      case 'incident':
        return SessionEventType.incident;
      case 'control_action':
        return SessionEventType.controlAction;
      default:
        return SessionEventType.incident;
    }
  }

  String get description {
    switch (this) {
      case SessionEventType.start:
        return 'Session started';
      case SessionEventType.endNormalTime:
        return 'End of normal time';
      case SessionEventType.startExtraTime:
        return 'Start of extra time';
      case SessionEventType.pause:
        return 'Session paused';
      case SessionEventType.resume:
        return 'Session resumed';
      case SessionEventType.end:
        return 'Session ended';
      case SessionEventType.recoveryAutoEnd:
        return 'Session auto-ended during recovery';
      case SessionEventType.recoveredAfterTermination:
        return 'Recovered after termination';
      case SessionEventType.checkpoint:
        return 'Checkpoint recorded';
      case SessionEventType.incident:
        return 'Incident detected';
      case SessionEventType.controlAction:
        return 'Control action';
    }
  }
}

class SessionEvent {
  final String id;
  final String examRecordId;
  final int seqNo;
  final SessionEventType type;
  final DateTime occurredAtUtc;
  final String? payloadJson;
  final DateTime persistedAtUtc;

  SessionEvent({
    required this.id,
    required this.examRecordId,
    required this.seqNo,
    required this.type,
    required this.occurredAtUtc,
    required this.persistedAtUtc,
    this.payloadJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'event_id': id,
      'exam_record_id': examRecordId,
      'seq_no': seqNo,
      'type': type.code,
      'occurred_at_utc': occurredAtUtc.toIso8601String(),
      'payload_json': payloadJson,
      'persisted_at_utc': persistedAtUtc.toIso8601String(),
    };
  }

  factory SessionEvent.fromMap(Map<String, dynamic> map) {
    return SessionEvent(
      id: map['event_id'] as String,
      examRecordId: map['exam_record_id'] as String,
      seqNo: map['seq_no'] as int,
      type: SessionEventTypeExtension.fromCode(map['type'] as String),
      occurredAtUtc: DateTime.parse(map['occurred_at_utc'] as String),
      payloadJson: map['payload_json'] as String?,
      persistedAtUtc: DateTime.parse(map['persisted_at_utc'] as String),
    );
  }
}
