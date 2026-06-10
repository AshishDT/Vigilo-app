class ExportArtifact {
  final String id;
  final String examRecordId;
  final String format;
  final String fileName;
  final String fileHash;
  final int eventCountAtExport;
  final DateTime exportedAtUtc;

  ExportArtifact({
    required this.id,
    required this.examRecordId,
    required this.format,
    required this.fileName,
    required this.fileHash,
    required this.eventCountAtExport,
    required this.exportedAtUtc,
  });

  Map<String, dynamic> toMap() {
    return {
      'export_id': id,
      'exam_record_id': examRecordId,
      'format': format,
      'file_name': fileName,
      'file_hash': fileHash,
      'event_count_at_export': eventCountAtExport,
      'exported_at_utc': exportedAtUtc.toIso8601String(),
    };
  }

  factory ExportArtifact.fromMap(Map<String, dynamic> map) {
    return ExportArtifact(
      id: map['export_id'] as String,
      examRecordId: map['exam_record_id'] as String,
      format: map['format'] as String,
      fileName: map['file_name'] as String,
      fileHash: map['file_hash'] as String,
      eventCountAtExport: map['event_count_at_export'] as int,
      exportedAtUtc: DateTime.parse(map['exported_at_utc'] as String),
    );
  }
}
