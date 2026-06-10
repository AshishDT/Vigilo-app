class LicenseState {
  final String examRecordId;
  final String activationStatus;
  final String? activationCodeHash;
  final DateTime? activatedAtUtc;
  final DateTime? expiresAtUtc;
  final String? deviceBindingId;

  LicenseState({
    required this.examRecordId,
    required this.activationStatus,
    this.activationCodeHash,
    this.activatedAtUtc,
    this.expiresAtUtc,
    this.deviceBindingId,
  });

  Map<String, dynamic> toMap() {
    return {
      'exam_record_id': examRecordId,
      'activation_status': activationStatus,
      'activation_code_hash': activationCodeHash,
      'activated_at_utc': activatedAtUtc?.toIso8601String(),
      'expires_at_utc': expiresAtUtc?.toIso8601String(),
      'device_binding_id': deviceBindingId,
    };
  }

  factory LicenseState.fromMap(Map<String, dynamic> map) {
    return LicenseState(
      examRecordId: map['exam_record_id'] as String,
      activationStatus: map['activation_status'] as String,
      activationCodeHash: map['activation_code_hash'] as String?,
      activatedAtUtc: map['activated_at_utc'] != null
          ? DateTime.parse(map['activated_at_utc'] as String)
          : null,
      expiresAtUtc: map['expires_at_utc'] != null
          ? DateTime.parse(map['expires_at_utc'] as String)
          : null,
      deviceBindingId: map['device_binding_id'] as String?,
    );
  }
}
