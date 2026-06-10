enum RecordStatus { open, closed, exported }

extension RecordStatusExtension on RecordStatus {
  String get code {
    switch (this) {
      case RecordStatus.open:
        return 'open';
      case RecordStatus.closed:
        return 'closed';
      case RecordStatus.exported:
        return 'exported';
    }
  }

  static RecordStatus fromCode(String code) {
    switch (code) {
      case 'open':
        return RecordStatus.open;
      case 'closed':
        return RecordStatus.closed;
      case 'exported':
        return RecordStatus.exported;
      default:
        return RecordStatus.open;
    }
  }
}

class ExamRecord {
  final String id;
  final String examName;
  final String? examCenter;
  final String? createdBy;
  final DateTime createdAtUtc;
  final DateTime? closedAtUtc;
  final RecordStatus recordStatus;
  final int schemaVersion;

  ExamRecord({
    required this.id,
    required this.examName,
    required this.createdAtUtc,
    required this.recordStatus,
    required this.schemaVersion,
    this.examCenter,
    this.createdBy,
    this.closedAtUtc,
  });

  Map<String, dynamic> toMap() {
    return {
      'exam_record_id': id,
      'exam_name': examName,
      'exam_center': examCenter,
      'created_by': createdBy,
      'created_at_utc': createdAtUtc.toIso8601String(),
      'closed_at_utc': closedAtUtc?.toIso8601String(),
      'record_status': recordStatus.code,
      'schema_version': schemaVersion,
    };
  }

  factory ExamRecord.fromMap(Map<String, dynamic> map) {
    return ExamRecord(
      id: map['exam_record_id'] as String,
      examName: map['exam_name'] as String,
      examCenter: map['exam_center'] as String?,
      createdBy: map['created_by'] as String?,
      createdAtUtc: DateTime.parse(map['created_at_utc'] as String),
      closedAtUtc: map['closed_at_utc'] != null
          ? DateTime.parse(map['closed_at_utc'] as String)
          : null,
      recordStatus: RecordStatusExtension.fromCode(
        map['record_status'] as String,
      ),
      schemaVersion: map['schema_version'] as int,
    );
  }
}
