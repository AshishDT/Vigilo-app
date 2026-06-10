import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'license_key_codec.dart';

class LicenseSnapshot {
  const LicenseSnapshot({
    this.licenceCode,
    this.activationDate,
    this.expiryDate,
    this.schoolName,
    this.schoolNumber,
    this.licenceType,
    this.isPermanentlyInvalid = false,
  });

  final String? licenceCode;
  final DateTime? activationDate;
  final DateTime? expiryDate;
  final String? schoolName;
  final String? schoolNumber;
  final String? licenceType;
  final bool isPermanentlyInvalid;

  String? get organizationName => schoolName;
  String? get organizationCode => schoolNumber;

  bool get isPilot => licenceType == LicenseService.pilotLicenceType;
  bool get isPro => licenceType == LicenseService.proLicenceType;

  bool isLicensed({DateTime? now}) {
    if (isPermanentlyInvalid) return false;
    final current = now ?? DateTime.now();
    return expiryDate != null && !current.isAfter(expiryDate!);
  }
}

class LicenseService {
  static const String productIdentifier = LicenseKeyCodec.productIdentifier;
  static const String issuerName = 'Vigilo';
  static const String legacySchoolLicenceType =
      LicenseKeyCodec.legacySchoolLicenceType;
  static const String pilotLicenceType = LicenseKeyCodec.pilotLicenceType;
  static const String coreLicenceType = LicenseKeyCodec.coreLicenceType;
  static const String proLicenceType = LicenseKeyCodec.proLicenceType;
  static const int pilotTrialDurationDays = LicenseKeyCodec.pilotDurationDays;
  static const String organizationLicenceType = coreLicenceType;
  static const String schoolLicenceType = organizationLicenceType;
  static const String deviceAllowance = 'Unlimited';
  static const String userAllowance = 'Organisation-wide licence';
  static const List<String> pilotFeatures = <String>[
    'Exam timer',
    'Incident logging',
    'Officer Tools',
    'Basic exam session export',
    'Organisation setup',
  ];
  static const List<String> coreFeatures = <String>[
    'Exam timer',
    'Normal / Extra Time control',
    'Incident logging',
    'Exam session export',
    'Briefings',
    'Invigilator list',
  ];
  static const List<String> proFeatureAdditions = <String>[
    'Invigilator messaging',
    'Officer Tools quick messages',
    'Photo / PDF sharing',
    'Multi-device coordination',
  ];

  static const String _licenceCodeKey = 'vigilo_licence_code';
  static const String _activationDateKey = 'vigilo_licence_activation_date';
  static const String _expiryDateKey = 'vigilo_licence_expiry_date';
  static const String _licenceProofKey = 'vigilo_licence_proof';
  static const String _schoolNameKey = 'vigilo_licence_school_name';
  static const String _schoolNumberKey = 'vigilo_licence_school_number';
  static const String _licenceTypeKey = 'vigilo_licence_type';
  static const String _usedLicensesKey = 'vigilo_used_licenses';
  static const String _highestTierKey = 'vigilo_highest_activated_tier';
  static const String _lastKnownTimeKey = 'vigilo_last_known_time';
  static const String _permanentlyExpiredKey =
      'vigilo_permanently_expired_licenses';

  static const String _msgExpiredReuse =
      'This licence has expired and can no longer be used.';
  static const String _msgAlreadyUsed =
      'This licence has already been used and cannot be reactivated.';
  static const String _msgPilotBlocked =
      'A Pilot licence cannot be used after a Core or Pro licence has been activated on this device.';
  static const String _msgInvalidLicense =
      'Invalid licence. Please check the code and try again.';
  static const String _msgOrgCodeMismatch =
      'This licence does not match the Organisation Code for this device.';
  static const String _msgRequiredFields =
      'Required fields cannot be empty. Please fill in all mandatory fields.';

  static const String _licenseValidationSecret =
      LicenseKeyCodec.validationSecret;

  static Future<LicenseSnapshot> getSnapshot({
    String? currentOrganizationName,
    String? currentOrganizationCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString(_licenceCodeKey);
    final activation = _readDate(prefs.getString(_activationDateKey));
    final storedExpiry = _readDate(prefs.getString(_expiryDateKey));
    final storedProof = prefs.getString(_licenceProofKey);
    final organizationName = _readText(prefs.getString(_schoolNameKey));
    final organizationCode = _normalizeOrganizationCode(
      prefs.getString(_schoolNumberKey),
    );
    final storedType = _readText(prefs.getString(_licenceTypeKey));
    final now = DateTime.now();

    // 1. Maintain Last Known Time to detect back-dating
    final lastKnownRaw = prefs.getString(_lastKnownTimeKey);
    final lastKnown = _readDate(lastKnownRaw) ?? now;
    final effectiveTime = now.isAfter(lastKnown) ? now : lastKnown;
    await prefs.setString(_lastKnownTimeKey, effectiveTime.toIso8601String());

    if (storedCode == null || storedCode.isEmpty) {
      return const LicenseSnapshot();
    }

    // 2. Check if this specific license is permanently expired/blocked
    final blockedRaw = prefs.getString(_permanentlyExpiredKey);
    final blockedLicenses = blockedRaw != null
        ? (jsonDecode(blockedRaw) as List<dynamic>).cast<String>().toSet()
        : <String>{};

    if (blockedLicenses.contains(storedCode)) {
      return LicenseSnapshot(
        licenceCode: storedCode,
        licenceType: storedType,
        isPermanentlyInvalid: true,
      );
    }

    final resolved = LicenseKeyCodec.resolve(storedCode);
    if (resolved == null || activation == null) {
      await _clearStoredLicense(prefs);
      return const LicenseSnapshot();
    }

    final expiry = resolved.expiryDateForActivation(activation);
    final licenceType = resolved.licenceType;
    final resolvedOrganizationCode = _normalizeOrganizationCode(
      resolved.organizationCode,
    );
    if (organizationCode != null &&
        resolvedOrganizationCode != null &&
        organizationCode != resolvedOrganizationCode) {
      await _clearStoredLicense(prefs);
      return const LicenseSnapshot();
    }
    final expectedProof = _buildIntegrityProof(
      code: resolved.normalizedCode,
      activation: activation,
      expiry: expiry,
      organizationName: organizationName,
      organizationCode: organizationCode,
      licenceType: licenceType,
    );
    final previousYearEndExpiry = licenceType == pilotLicenceType
        ? null
        : LicenseKeyCodec.expiryFromYear(resolved.expiryYear);
    final legacyExpectedProof =
        storedType == null || storedType == legacySchoolLicenceType
        ? _buildIntegrityProof(
            code: resolved.normalizedCode,
            activation: activation,
            expiry: expiry,
            organizationName: organizationName,
            organizationCode: organizationCode,
            licenceType: legacySchoolLicenceType,
          )
        : null;
    final previousYearEndProof = previousYearEndExpiry == null
        ? null
        : _buildIntegrityProof(
            code: resolved.normalizedCode,
            activation: activation,
            expiry: previousYearEndExpiry,
            organizationName: organizationName,
            organizationCode: organizationCode,
            licenceType: licenceType,
          );
    final previousYearEndLegacyTypeProof =
        previousYearEndExpiry == null ||
            (storedType != null && storedType != legacySchoolLicenceType)
        ? null
        : _buildIntegrityProof(
            code: resolved.normalizedCode,
            activation: activation,
            expiry: previousYearEndExpiry,
            organizationName: organizationName,
            organizationCode: organizationCode,
            licenceType: legacySchoolLicenceType,
          );
    final proofMismatch =
        storedProof != null &&
        storedProof != expectedProof &&
        storedProof != legacyExpectedProof &&
        storedProof != previousYearEndProof &&
        storedProof != previousYearEndLegacyTypeProof;

    final needsRefresh =
        storedCode != resolved.normalizedCode ||
        storedProof == null ||
        storedExpiry == null ||
        storedExpiry != expiry ||
        storedType != licenceType ||
        proofMismatch ||
        storedProof != expectedProof;

    if (needsRefresh) {
      await prefs.setString(_licenceCodeKey, resolved.normalizedCode);
      await prefs.setString(_activationDateKey, activation.toIso8601String());
      await prefs.setString(_expiryDateKey, expiry.toIso8601String());
      await prefs.setString(_licenceTypeKey, licenceType);
      await prefs.setString(_licenceProofKey, expectedProof);

      if (organizationName == null) {
        await prefs.remove(_schoolNameKey);
      } else {
        await prefs.setString(_schoolNameKey, organizationName);
      }

      if (organizationCode == null) {
        await prefs.remove(_schoolNumberKey);
      } else {
        await prefs.setString(_schoolNumberKey, organizationCode);
      }
    }

    // 3. Check for permanent expiry (if it ever hits expiry, it's gone)
    if (effectiveTime.isAfter(expiry)) {
      if (!blockedLicenses.contains(storedCode)) {
        blockedLicenses.add(storedCode);
        await prefs.setString(
          _permanentlyExpiredKey,
          jsonEncode(blockedLicenses.toList()),
        );
      }
      return LicenseSnapshot(
        licenceCode: resolved.normalizedCode,
        activationDate: activation,
        expiryDate: expiry,
        schoolName: organizationName,
        schoolNumber: organizationCode,
        licenceType: licenceType,
        isPermanentlyInvalid: true,
      );
    }

    return LicenseSnapshot(
      licenceCode: resolved.normalizedCode,
      activationDate: activation,
      expiryDate: expiry,
      schoolName: organizationName,
      schoolNumber: organizationCode,
      licenceType: licenceType,
    );
  }

  static Future<LicenseSnapshot> activate(
    String organizationName,
    String organizationCode,
    String licenceKey, {
    DateTime? now,
  }) async {
    final activation = now ?? DateTime.now();
    final normalizedOrganizationName = _readText(organizationName);
    final normalizedOrganizationCode = _normalizeOrganizationCode(
      organizationCode,
    );
    final resolved = LicenseKeyCodec.resolve(licenceKey);

    if (normalizedOrganizationName == null ||
        normalizedOrganizationCode == null ||
        licenceKey.trim().isEmpty) {
      throw const FormatException(_msgRequiredFields);
    }

    if (resolved == null) {
      throw const FormatException(_msgInvalidLicense);
    }

    if (resolved.organizationCode != normalizedOrganizationCode) {
      throw const FormatException(_msgOrgCodeMismatch);
    }

    await _validateLicenseHardening(resolved, now: activation);

    return _storeActivatedLicense(
      resolved: resolved,
      organizationName: normalizedOrganizationName,
      organizationCode: normalizedOrganizationCode,
      now: activation,
    );
  }

  static Future<LicenseSnapshot> activateFromParts(
    String licenceIdSegment,
    String validationCode, {
    DateTime? now,
    String? organizationName,
    String? organizationCode,
    String? schoolName,
    String? schoolNumber,
  }) async {
    final activation = now ?? DateTime.now();
    final sanitizedSegment = licenceIdSegment.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final sanitizedValidation = validationCode.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final normalizedOrganizationName =
        _readText(organizationName) ?? _readText(schoolName);
    final normalizedOrganizationCode =
        _normalizeOrganizationCode(organizationCode) ??
        _normalizeOrganizationCode(schoolNumber);

    if (normalizedOrganizationName == null ||
        normalizedOrganizationCode == null ||
        sanitizedSegment.isEmpty ||
        sanitizedValidation.isEmpty) {
      throw const FormatException(_msgRequiredFields);
    }

    final resolved = LicenseKeyCodec.resolve(
      '$productIdentifier-$sanitizedSegment-$sanitizedValidation',
    );

    if (resolved == null) {
      throw const FormatException(_msgInvalidLicense);
    }

    if (normalizedOrganizationCode != null &&
        resolved.organizationCode != normalizedOrganizationCode) {
      throw const FormatException(_msgOrgCodeMismatch);
    }

    await _validateLicenseHardening(resolved, now: activation);

    return _storeActivatedLicense(
      resolved: resolved,
      organizationName: normalizedOrganizationName,
      organizationCode: normalizedOrganizationCode,
      now: activation,
    );
  }

  static Future<LicenseSnapshot> activateFromActivationCode(
    String organizationName,
    String organizationCode,
    String activationCode, {
    DateTime? now,
  }) async {
    final activation = now ?? DateTime.now();
    final normalizedOrganizationName = _readText(organizationName);
    final normalizedOrganizationCode = _normalizeOrganizationCode(
      organizationCode,
    );

    if (normalizedOrganizationName == null ||
        normalizedOrganizationCode == null ||
        activationCode.trim().isEmpty) {
      throw const FormatException(_msgRequiredFields);
    }

    // 1. Try to resolve with the entered organization code
    var resolved = resolveActivationCodeForOrganizationCode(
      organizationCode: normalizedOrganizationCode,
      activationCode: activationCode,
      now: activation,
    );

    // 2. If it fails, check if the activationCode itself is a full key
    resolved ??= LicenseKeyCodec.resolve(activationCode);

    // 3. If we found a license but the organization code doesn't match the field, it's a mismatch
    if (resolved != null) {
      if (resolved.organizationCode != normalizedOrganizationCode) {
        throw const FormatException(_msgOrgCodeMismatch);
      }
    }

    // 4. If still null, investigate why by trying other candidate organization codes (for 6-char codes)
    if (resolved == null) {
      final prefs = await SharedPreferences.getInstance();
      final storedOrgCode = _normalizeOrganizationCode(
        prefs.getString(_schoolNumberKey),
      );
      final derivedOrgCode = _normalizeOrganizationCode(
        deriveOrganizationCode(normalizedOrganizationName),
      );

      final candidates = <String>{
        if (storedOrgCode != null) storedOrgCode,
        if (derivedOrgCode != null) derivedOrgCode,
      };

      for (final candidateCode in candidates) {
        if (candidateCode == normalizedOrganizationCode) continue;

        final resolvedCandidate = resolveActivationCodeForOrganizationCode(
          organizationCode: candidateCode,
          activationCode: activationCode,
          now: activation,
        );

        if (resolvedCandidate != null) {
          throw const FormatException(_msgOrgCodeMismatch);
        }
      }

      throw const FormatException(_msgInvalidLicense);
    }

    // 5. Validate hardening rules for the resolved license
    await _validateLicenseHardening(resolved, now: activation);

    return _storeActivatedLicense(
      resolved: resolved,
      organizationName: normalizedOrganizationName,
      organizationCode: normalizedOrganizationCode,
      now: activation,
    );
  }

  static Future<bool> requiresValidLicense({
    DateTime? now,
    String? currentOrganizationName,
    String? currentOrganizationCode,
  }) async {
    final snapshot = await getSnapshot(
      currentOrganizationName: currentOrganizationName,
      currentOrganizationCode: currentOrganizationCode,
    );
    final current = now ?? DateTime.now();
    return !snapshot.isLicensed(now: current);
  }

  static String? normalizeLicenceType(String? raw) {
    return LicenseKeyCodec.normalizeLicenceType(raw);
  }

  static bool isProLicenceType(String? raw) {
    return normalizeLicenceType(raw) == proLicenceType;
  }

  static bool isPilotLicenceType(String? raw) {
    return normalizeLicenceType(raw) == pilotLicenceType;
  }

  static bool hasProMessagingAccess(LicenseSnapshot snapshot, {DateTime? now}) {
    return snapshot.isLicensed(now: now) &&
        isProLicenceType(snapshot.licenceType);
  }

  static int nextLicenceYear({DateTime? now}) {
    final current = now ?? DateTime.now();
    return current.year + 1;
  }

  static String deriveOrganizationCode(String organizationName) {
    final words = organizationName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    String lettersOnly(String value) =>
        value.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();

    if (words.isEmpty) return '';
    if (words.length == 1) {
      final word = lettersOnly(words.first);
      if (word.length >= 2) return word.substring(0, 2);
      if (word.length == 1) return '${word}X';
      return '';
    }

    final first = lettersOnly(words.first);
    final second = lettersOnly(words[1]);

    final a = first.isNotEmpty ? first[0] : 'O';
    final b = second.isNotEmpty ? second[0] : 'R';
    return '$a$b';
  }

  static String deriveSchoolCode(String schoolName) {
    return deriveOrganizationCode(schoolName);
  }

  static ResolvedLicenseKey? resolveActivationCodeForOrganization({
    required String organizationName,
    required String activationCode,
    DateTime? now,
  }) {
    final normalizedOrganizationName = _readText(organizationName);
    if (normalizedOrganizationName == null) {
      return null;
    }

    final organizationCode = deriveOrganizationCode(normalizedOrganizationName);
    return resolveActivationCodeForOrganizationCode(
      organizationCode: organizationCode,
      activationCode: activationCode,
      now: now,
    );
  }

  static ResolvedLicenseKey? resolveActivationCodeForOrganizationCode({
    required String organizationCode,
    required String activationCode,
    DateTime? now,
  }) {
    final normalizedOrganizationCode = sanitizeOrganizationCode(
      organizationCode,
    );
    final sanitizedValidation = LicenseKeyCodec.sanitizeValidationCode(
      activationCode,
    );
    if (normalizedOrganizationCode.length < 2 ||
        sanitizedValidation.length != LicenseKeyCodec.validationCodeLength) {
      return null;
    }

    final current = now ?? DateTime.now();
    final candidateYears = <int>[nextLicenceYear(now: current), current.year];
    for (final licenceYear in candidateYears) {
      for (final licenceType in LicenseKeyCodec.supportedLicenceTypes) {
        final tierMarker = LicenseKeyCodec.tierMarkerForLicenceType(
          licenceType,
        );
        final resolved = LicenseKeyCodec.resolve(
          '$productIdentifier-$tierMarker-$normalizedOrganizationCode-$licenceYear-$sanitizedValidation',
        );
        if (resolved != null) {
          return resolved;
        }
      }

      final tierlessResolved = LicenseKeyCodec.resolve(
        '$productIdentifier-$normalizedOrganizationCode-$licenceYear-$sanitizedValidation',
      );
      if (tierlessResolved != null) {
        return tierlessResolved;
      }
    }

    return null;
  }

  static ResolvedLicenseKey? resolveActivationCodeForSchool({
    required String schoolName,
    required String activationCode,
    DateTime? now,
  }) {
    return resolveActivationCodeForOrganization(
      organizationName: schoolName,
      activationCode: activationCode,
      now: now,
    );
  }

  static bool isValidLicenseKey(String value) {
    return LicenseKeyCodec.isValidLicenseKey(value);
  }

  static ResolvedLicenseKey? resolveLicenseKey(String value) {
    return LicenseKeyCodec.resolve(value);
  }

  static String sanitizeUserEntry(String value) {
    return LicenseKeyCodec.sanitizeUserEntry(value);
  }

  static String sanitizeLicenceEntry(String value) {
    return LicenseKeyCodec.sanitizeLicenceEntry(value);
  }

  static String sanitizeOrganizationCode(String value) {
    return LicenseKeyCodec.sanitizeOrganizationCode(value);
  }

  static String sanitizeSchoolInitials(String value) {
    return sanitizeOrganizationCode(value);
  }

  static String formatActivationCode(String value) {
    return LicenseKeyCodec.formatActivationCode(value);
  }

  static String activationCodeFromLicence(String code) {
    return LicenseKeyCodec.activationCodeFromLicence(code);
  }

  static String displayActivationCodeFromLicence(String code) {
    return LicenseKeyCodec.displayActivationCodeFromLicence(code);
  }

  static String tierMarkerForLicenceType(String licenceType) {
    return LicenseKeyCodec.tierMarkerForLicenceType(licenceType);
  }

  static String tierLabelForLicenceType(String licenceType) {
    return LicenseKeyCodec.tierLabelForLicenceType(licenceType);
  }

  static String generateLicenceId({
    String? organizationCode,
    String? schoolInitials,
    required int expiryYear,
    required String licenceType,
    DateTime? now,
    DateTime? pilotExpiryDate,
  }) {
    return LicenseKeyCodec.generateLicenceId(
      organizationCode: organizationCode,
      schoolInitials: schoolInitials,
      expiryYear: expiryYear,
      licenceType: licenceType,
      now: now,
      pilotExpiryDate: pilotExpiryDate,
    );
  }

  static String generateLicenceKey({
    String? organizationCode,
    String? schoolInitials,
    required int expiryYear,
    required String licenceType,
    DateTime? now,
    DateTime? pilotExpiryDate,
  }) {
    return LicenseKeyCodec.generateLicenceKey(
      organizationCode: organizationCode,
      schoolInitials: schoolInitials,
      expiryYear: expiryYear,
      licenceType: licenceType,
      now: now,
      pilotExpiryDate: pilotExpiryDate,
    );
  }

  static String displayLicenceId(String code) {
    return LicenseKeyCodec.displayLicenceId(code);
  }

  static String maskLicenceCode(String code, {int visibleChars = 2}) {
    return LicenseKeyCodec.maskLicenceCode(code, visibleChars: visibleChars);
  }

  static String maskLicenceCodeForStatus(
    String code, {
    int visibleChars = LicenseKeyCodec.validationCodeLength,
    int hiddenChars = 8,
  }) {
    final normalized = sanitizeLicenceEntry(code);
    if (normalized.isEmpty) return normalized;
    final visibleCount = visibleChars.clamp(0, normalized.length);
    return '${List.filled(hiddenChars, '*').join()}${normalized.substring(normalized.length - visibleCount)}';
  }

  static DateTime fixedPilotExpiryFromIssueDate(DateTime issuedAt) {
    return LicenseKeyCodec.fixedPilotExpiryFromIssueDate(issuedAt);
  }

  static Future<LicenseSnapshot> _storeActivatedLicense({
    required ResolvedLicenseKey resolved,
    required DateTime? now,
    String? organizationName,
    String? organizationCode,
  }) async {
    final activation = now ?? DateTime.now();
    final normalizedOrganizationName = _readText(organizationName);
    final normalizedOrganizationCode =
        _normalizeOrganizationCode(organizationCode) ??
        _normalizeOrganizationCode(resolved.organizationCode);
    final expiry = resolved.expiryDateForActivation(activation);
    final proof = _buildIntegrityProof(
      code: resolved.normalizedCode,
      activation: activation,
      expiry: expiry,
      organizationName: normalizedOrganizationName,
      organizationCode: normalizedOrganizationCode,
      licenceType: resolved.licenceType,
    );

    final prefs = await SharedPreferences.getInstance();

    // 1. Record in history
    final history = await _getUsedLicenses();
    history[resolved.normalizedCode] = expiry.toIso8601String();
    await prefs.setString(_usedLicensesKey, jsonEncode(history));

    // 2. Update highest tier ever activated
    if (resolved.licenceType != pilotLicenceType) {
      await prefs.setString(_highestTierKey, resolved.licenceType);
    }

    await prefs.setString(_licenceCodeKey, resolved.normalizedCode);
    await prefs.setString(_activationDateKey, activation.toIso8601String());
    await prefs.setString(_expiryDateKey, expiry.toIso8601String());
    await prefs.setString(_licenceTypeKey, resolved.licenceType);
    await prefs.setString(_licenceProofKey, proof);

    if (normalizedOrganizationName == null) {
      await prefs.remove(_schoolNameKey);
    } else {
      await prefs.setString(_schoolNameKey, normalizedOrganizationName);
    }

    if (normalizedOrganizationCode == null) {
      await prefs.remove(_schoolNumberKey);
    } else {
      await prefs.setString(_schoolNumberKey, normalizedOrganizationCode);
    }

    return LicenseSnapshot(
      licenceCode: resolved.normalizedCode,
      activationDate: activation,
      expiryDate: expiry,
      schoolName: normalizedOrganizationName,
      schoolNumber: normalizedOrganizationCode,
      licenceType: resolved.licenceType,
    );
  }

  static Future<void> _validateLicenseHardening(
    ResolvedLicenseKey resolved, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // 1. Used/Expired list check -> always reject (no exceptions)
    final history = await _getUsedLicenses();
    if (history.containsKey(resolved.normalizedCode)) {
      throw const FormatException(_msgAlreadyUsed);
    }

    // 2. Prevent Pilot after Core/Pro (Tier Progression)
    final highestTier = prefs.getString(_highestTierKey);
    if (resolved.licenceType == pilotLicenceType &&
        (highestTier == coreLicenceType || highestTier == proLicenceType)) {
      throw const FormatException(_msgPilotBlocked);
    }

    // 3. Date/Time expiry check
    // Check against the encoded expiry date (fixed window)
    if (current.isAfter(resolved.encodedExpiryDate)) {
      throw const FormatException(_msgExpiredReuse);
    }

    // Check against what would be the expiry if activated now
    final calculatedExpiry = resolved.expiryDateForActivation(current);
    if (current.isAfter(calculatedExpiry)) {
      throw const FormatException(_msgExpiredReuse);
    }
  }

  static Future<Map<String, String>> _getUsedLicenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usedLicensesKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  static DateTime? _readDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String? _readText(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  static String? _normalizeOrganizationCode(String? raw) {
    if (raw == null) return null;
    final normalized = sanitizeOrganizationCode(raw);
    return normalized.isEmpty ? null : normalized;
  }

  static String? _normalizeOrganizationNameForComparison(String? raw) {
    final normalized = _readText(raw);
    if (normalized == null) {
      return null;
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String _buildIntegrityProof({
    required String code,
    required DateTime activation,
    required DateTime expiry,
    required String? organizationName,
    required String? organizationCode,
    required String licenceType,
  }) {
    final normalizedName =
        _normalizeOrganizationNameForComparison(organizationName) ?? '';
    final normalizedCode = _normalizeOrganizationCode(organizationCode) ?? '';
    final source =
        '${code.trim()}|'
        '${activation.toIso8601String()}|'
        '${expiry.toIso8601String()}|'
        '$normalizedName|'
        '$normalizedCode|'
        '${licenceType.trim()}|'
        '$_licenseValidationSecret';
    return sha256.convert(utf8.encode(source)).toString();
  }

  static Future<void> _clearStoredLicense(SharedPreferences prefs) async {
    await prefs.remove(_licenceCodeKey);
    await prefs.remove(_activationDateKey);
    await prefs.remove(_expiryDateKey);
    await prefs.remove(_licenceProofKey);
    await prefs.remove(_schoolNameKey);
    await prefs.remove(_schoolNumberKey);
    await prefs.remove(_licenceTypeKey);
  }
}
