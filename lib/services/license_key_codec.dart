import 'dart:convert';

import 'package:crypto/crypto.dart';

class ResolvedLicenseKey {
  const ResolvedLicenseKey({
    required this.normalizedCode,
    required this.licenceId,
    required this.organizationCode,
    required this.expiryYear,
    required this.validationCode,
    required this.licenceType,
    required this.tierMarker,
    required this.usesLegacySignature,
    this.fixedExpiryDate,
  });

  final String normalizedCode;
  final String licenceId;
  final String organizationCode;
  final int expiryYear;
  final String validationCode;
  final String licenceType;
  final String tierMarker;
  final bool usesLegacySignature;
  final DateTime? fixedExpiryDate;

  String get schoolInitials => organizationCode;

  DateTime get encodedExpiryDate =>
      fixedExpiryDate ?? LicenseKeyCodec.expiryFromYear(expiryYear);

  DateTime expiryDateForActivation(DateTime activationDate) {
    return LicenseKeyCodec.expiryForResolvedKey(
      this,
      activationDate: activationDate,
    );
  }
}

class LicenseKeyCodec {
  static const String productIdentifier = 'VIGILO-ERC';
  static const String legacySchoolLicenceType = 'School licence';
  static const String pilotLicenceType = 'Pilot';
  static const String coreLicenceType = 'Core';
  static const String proLicenceType = 'Pro';
  static const String trialTierLabel = 'Trial';
  static const String trialTierMarker = 'TR';
  static const String coreTierMarker = 'CR';
  static const String proTierMarker = 'PR';
  static const int organizationCodeMinLength = 2;
  static const int organizationCodeMaxLength = 8;
  static const int pilotDurationDays = 30;
  static const int validationCodeLength = 6;
  static const int legacyValidationCodeLength = 5;
  static const List<String> supportedLicenceTypes = <String>[
    pilotLicenceType,
    coreLicenceType,
    proLicenceType,
  ];
  static const Map<String, String> tierMarkerByLicenceType = <String, String>{
    pilotLicenceType: trialTierMarker,
    coreLicenceType: coreTierMarker,
    proLicenceType: proTierMarker,
  };
  static const Map<String, String> licenceTypeByTierMarker = <String, String>{
    trialTierMarker: pilotLicenceType,
    coreTierMarker: coreLicenceType,
    proTierMarker: proLicenceType,
  };
  static const String validationAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const String validationSecret = String.fromEnvironment(
    'VIGILO_LICENSE_VALIDATION_SECRET',
    defaultValue: 'vigilo-r41y-license-validation',
  );

  static final RegExp _licenceCodePattern = RegExp(
    '^$productIdentifier-(TR|CR|PR)-([A-Z0-9]{$organizationCodeMinLength,$organizationCodeMaxLength})-(\\d{4})-([$validationAlphabet]{$validationCodeLength})\$',
  );
  static final RegExp _compactLicenceCodePattern = RegExp(
    '^VIGILOERC(TR|CR|PR)([A-Z0-9]{$organizationCodeMinLength,$organizationCodeMaxLength})(\\d{4})([$validationAlphabet]{$validationCodeLength})\$',
  );
  static final RegExp _tierlessLicenceCodePattern = RegExp(
    '^$productIdentifier-([A-Z0-9]{$organizationCodeMinLength,$organizationCodeMaxLength})-(\\d{4})-([$validationAlphabet]{$validationCodeLength})\$',
  );
  static final RegExp _tierlessCompactLicenceCodePattern = RegExp(
    '^VIGILOERC([A-Z0-9]{$organizationCodeMinLength,$organizationCodeMaxLength})(\\d{4})([$validationAlphabet]{$validationCodeLength})\$',
  );
  static final RegExp _legacyLicenceCodePattern = RegExp(
    '^$productIdentifier-([A-Z0-9]{$organizationCodeMinLength,$organizationCodeMaxLength})(\\d{4})-([A-Z0-9]{$legacyValidationCodeLength})\$',
  );
  static final RegExp _legacyCompactLicenceCodePattern = RegExp(
    '^VIGILOERC([A-Z0-9]{$organizationCodeMinLength,$organizationCodeMaxLength})(\\d{4})([A-Z0-9]{$legacyValidationCodeLength})\$',
  );

  static String sanitizeUserEntry(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  }

  static String sanitizeLicenceEntry(String value) {
    final normalized = sanitizeUserEntry(
      value,
    ).replaceAll(RegExp(r'-{2,}'), '-');
    final compact = normalized.replaceAll('-', '');

    final match = _compactLicenceCodePattern.firstMatch(compact);
    if (match != null) {
      final tierMarker = match.group(1)!;
      final organizationCode = match.group(2)!;
      final expiryYear = match.group(3)!;
      final validationCode = match.group(4)!;
      return '$productIdentifier-$tierMarker-$organizationCode-$expiryYear-$validationCode';
    }

    final tierlessMatch = _tierlessCompactLicenceCodePattern.firstMatch(
      compact,
    );
    if (tierlessMatch != null) {
      final organizationCode = tierlessMatch.group(1)!;
      final expiryYear = tierlessMatch.group(2)!;
      final validationCode = tierlessMatch.group(3)!;
      return '$productIdentifier-$organizationCode-$expiryYear-$validationCode';
    }

    final legacyMatch = _legacyCompactLicenceCodePattern.firstMatch(compact);
    if (legacyMatch != null) {
      final organizationCode = legacyMatch.group(1)!;
      final expiryYear = legacyMatch.group(2)!;
      final validationCode = legacyMatch.group(3)!;
      return '$productIdentifier-$organizationCode$expiryYear-$validationCode';
    }

    return normalized;
  }

  static String sanitizeOrganizationCode(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String sanitizeSchoolInitials(String value) {
    return sanitizeOrganizationCode(value);
  }

  static String sanitizeValidationCode(String value) {
    final output = StringBuffer();
    for (final rune in value.toUpperCase().runes) {
      final character = String.fromCharCode(rune);
      if (validationAlphabet.contains(character)) {
        output.write(character);
      }
    }
    return output.toString();
  }

  static String formatActivationCode(String value) {
    final normalized = sanitizeValidationCode(value);
    final clipped = normalized.length <= validationCodeLength
        ? normalized
        : normalized.substring(0, validationCodeLength);
    if (clipped.length <= 3) {
      return clipped;
    }
    return '${clipped.substring(0, 3)}-${clipped.substring(3)}';
  }

  static String activationCodeFromLicence(String value) {
    final normalized = sanitizeLicenceEntry(value);
    final parts = normalized.split('-');
    return parts.isEmpty ? '' : parts.last;
  }

  static String displayActivationCodeFromLicence(String value) {
    return formatActivationCode(activationCodeFromLicence(value));
  }

  static String? normalizeLicenceType(String? raw) {
    final value = _readText(raw);
    if (value == null) return null;

    switch (value.toLowerCase()) {
      case 'trial':
      case 'trial (pilot)':
      case 'pilot':
      case 'tr':
        return pilotLicenceType;
      case 'core':
      case 'cr':
      case 'school licence':
        return coreLicenceType;
      case 'pro':
      case 'pr':
        return proLicenceType;
    }

    return null;
  }

  static String tierLabelForLicenceType(String licenceType) {
    final normalizedType = normalizeLicenceType(licenceType);
    if (normalizedType == null) {
      throw const FormatException('Licence type must be Trial, Core or Pro.');
    }
    return normalizedType == pilotLicenceType ? trialTierLabel : normalizedType;
  }

  static String tierMarkerForLicenceType(String licenceType) {
    final normalizedType = normalizeLicenceType(licenceType);
    final tierMarker = normalizedType == null
        ? null
        : tierMarkerByLicenceType[normalizedType];
    if (tierMarker == null) {
      throw const FormatException('Licence type must be Trial, Core or Pro.');
    }
    return tierMarker;
  }

  static String? licenceTypeFromTierMarker(String? raw) {
    final value = _readText(raw);
    if (value == null) return null;
    return licenceTypeByTierMarker[value.toUpperCase()];
  }

  static String generateLicenceId({
    String? organizationCode,
    String? schoolInitials,
    required int expiryYear,
    required String licenceType,
    DateTime? now,
    DateTime? pilotExpiryDate,
  }) {
    final normalizedType = normalizeLicenceType(licenceType);
    if (normalizedType == null) {
      throw const FormatException('Licence type must be Trial, Core or Pro.');
    }

    final normalizedOrganizationCode = sanitizeOrganizationCode(
      organizationCode ?? schoolInitials ?? '',
    );
    if (normalizedOrganizationCode.length < organizationCodeMinLength ||
        normalizedOrganizationCode.length > organizationCodeMaxLength) {
      throw const FormatException(
        'Organisation code must contain between 2 and 8 letters or numbers.',
      );
    }
    final encodedPilotExpiry = _resolveGeneratedPilotExpiry(
      expiryYear: expiryYear,
      licenceType: normalizedType,
      now: now,
      pilotExpiryDate: pilotExpiryDate,
    );
    final effectiveExpiryYear = encodedPilotExpiry?.year ?? expiryYear;

    if (effectiveExpiryYear < 1000 || effectiveExpiryYear > 9999) {
      throw const FormatException('Expiry year must be a 4-digit year.');
    }

    final tierMarker = tierMarkerForLicenceType(normalizedType);
    return '$productIdentifier-$tierMarker-$normalizedOrganizationCode-$effectiveExpiryYear';
  }

  static String generateLicenceKey({
    String? organizationCode,
    String? schoolInitials,
    required int expiryYear,
    required String licenceType,
    DateTime? now,
    DateTime? pilotExpiryDate,
  }) {
    final normalizedType = normalizeLicenceType(licenceType);
    if (normalizedType == null) {
      throw const FormatException('Licence type must be Trial, Core or Pro.');
    }

    final encodedPilotExpiry = _resolveGeneratedPilotExpiry(
      expiryYear: expiryYear,
      licenceType: normalizedType,
      now: now,
      pilotExpiryDate: pilotExpiryDate,
    );

    final licenceId = generateLicenceId(
      organizationCode: organizationCode,
      schoolInitials: schoolInitials,
      expiryYear: expiryYear,
      licenceType: normalizedType,
      now: now,
      pilotExpiryDate: pilotExpiryDate,
    );
    final validationCode = encodedPilotExpiry != null
        ? _derivePilotValidationCode(
            fixedExpiryDate: encodedPilotExpiry,
            validationLength: validationCodeLength,
          )
        : _deriveValidationCode(
            expiryYear: expiryYear,
            licenceType: normalizedType,
            validationLength: validationCodeLength,
          );
    return '$licenceId-$validationCode';
  }

  static ResolvedLicenseKey? resolve(String value) {
    final normalized = sanitizeLicenceEntry(value);
    return _resolveTieredFormat(normalized) ??
        _resolveTierlessFormat(normalized) ??
        _resolveLegacyFormat(normalized);
  }

  static bool isValidLicenseKey(String value) => resolve(value) != null;

  static String displayLicenceId(String code) {
    final normalized = sanitizeLicenceEntry(code);
    final parts = normalized.split('-');
    if (parts.length >= 4) {
      return parts.take(parts.length - 1).join('-');
    }
    return normalized;
  }

  static String maskLicenceCode(String code, {int visibleChars = 2}) {
    final normalized = sanitizeLicenceEntry(code);
    final parts = normalized.split('-');
    if (parts.length < 4) return normalized;

    final validationCode = parts.last;
    final visibleCount = visibleChars.clamp(0, validationCode.length);
    final hiddenCount = validationCode.length - visibleCount;
    final maskedCode =
        '${List.filled(hiddenCount, '*').join()}${validationCode.substring(validationCode.length - visibleCount)}';

    return '${parts.take(parts.length - 1).join('-')}-$maskedCode';
  }

  static DateTime expiryFromYear(int expiryYear) {
    return DateTime(expiryYear, 12, 31, 23, 59, 59, 999);
  }

  static DateTime fixedPilotExpiryFromIssueDate(DateTime issuedAt) {
    return _normalizePilotExpiryDate(
      issuedAt.add(const Duration(days: pilotDurationDays)),
    );
  }

  static DateTime expiryForResolvedKey(
    ResolvedLicenseKey resolved, {
    required DateTime activationDate,
  }) {
    return expiryForLicence(
      expiryYear: resolved.expiryYear,
      licenceType: resolved.licenceType,
      activationDate: activationDate,
      fixedPilotExpiryDate: resolved.fixedExpiryDate,
    );
  }

  static DateTime expiryForLicence({
    required int expiryYear,
    required String licenceType,
    required DateTime activationDate,
    DateTime? fixedPilotExpiryDate,
  }) {
    final normalizedType = normalizeLicenceType(licenceType);
    if (normalizedType == null) {
      throw const FormatException('Licence type must be Trial, Core or Pro.');
    }
    if (normalizedType == pilotLicenceType) {
      return fixedPilotExpiryDate ??
          activationDate.add(const Duration(days: pilotDurationDays));
    }
    return _oneYearFromActivation(activationDate);
  }

  static DateTime _oneYearFromActivation(DateTime activationDate) {
    final targetYear = activationDate.year + 1;
    final lastDayOfTargetMonth = DateTime(
      targetYear,
      activationDate.month + 1,
      0,
    ).day;
    final targetDay = activationDate.day <= lastDayOfTargetMonth
        ? activationDate.day
        : lastDayOfTargetMonth;
    return DateTime(
      targetYear,
      activationDate.month,
      targetDay,
      activationDate.hour,
      activationDate.minute,
      activationDate.second,
      activationDate.millisecond,
      activationDate.microsecond,
    );
  }

  static ResolvedLicenseKey? _resolveTieredFormat(String normalized) {
    final match = _licenceCodePattern.firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final tierMarker = match.group(1)!;
    final organizationCode = match.group(2)!;
    final expiryYear = int.parse(match.group(3)!);
    final validationCode = match.group(4)!;
    final licenceType = licenceTypeFromTierMarker(tierMarker);
    if (licenceType == null) {
      return null;
    }

    final licenceId =
        '$productIdentifier-$tierMarker-$organizationCode-$expiryYear';
    if (licenceType == pilotLicenceType) {
      final fixedPilotKey = _resolveFixedExpiryPilotKey(
        normalizedCode: normalized,
        licenceId: licenceId,
        organizationCode: organizationCode,
        expiryYear: expiryYear,
        validationCode: validationCode,
        validationLength: validationCodeLength,
        tierMarker: tierMarker,
        usesLegacySignature: false,
      );
      if (fixedPilotKey != null) {
        return fixedPilotKey;
      }
    }
    if (validationCode ==
            _deriveValidationCode(
              expiryYear: expiryYear,
              licenceType: licenceType,
              validationLength: validationCodeLength,
            ) ||
        validationCode ==
            _deriveOrganizationBoundValidationCode(
              licenceId,
              licenceType,
              validationLength: validationCodeLength,
            )) {
      return ResolvedLicenseKey(
        normalizedCode: normalized,
        licenceId: licenceId,
        organizationCode: organizationCode,
        expiryYear: expiryYear,
        validationCode: validationCode,
        licenceType: licenceType,
        tierMarker: tierMarker,
        usesLegacySignature: false,
      );
    }

    return null;
  }

  static ResolvedLicenseKey? _resolveTierlessFormat(String normalized) {
    final match = _tierlessLicenceCodePattern.firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final organizationCode = match.group(1)!;
    final expiryYear = int.parse(match.group(2)!);
    final validationCode = match.group(3)!;
    final licenceId = '$productIdentifier-$organizationCode-$expiryYear';

    for (final licenceType in supportedLicenceTypes) {
      if (licenceType == pilotLicenceType) {
        final fixedPilotKey = _resolveFixedExpiryPilotKey(
          normalizedCode: normalized,
          licenceId: licenceId,
          organizationCode: organizationCode,
          expiryYear: expiryYear,
          validationCode: validationCode,
          validationLength: validationCodeLength,
          tierMarker: tierMarkerForLicenceType(licenceType),
          usesLegacySignature: false,
        );
        if (fixedPilotKey != null) {
          return fixedPilotKey;
        }
      }

      if (validationCode ==
              _deriveValidationCode(
                expiryYear: expiryYear,
                licenceType: licenceType,
                validationLength: validationCodeLength,
              ) ||
          validationCode ==
              _deriveOrganizationBoundValidationCode(
                licenceId,
                licenceType,
                validationLength: validationCodeLength,
              )) {
        return ResolvedLicenseKey(
          normalizedCode: normalized,
          licenceId: licenceId,
          organizationCode: organizationCode,
          expiryYear: expiryYear,
          validationCode: validationCode,
          licenceType: licenceType,
          tierMarker: tierMarkerForLicenceType(licenceType),
          usesLegacySignature: false,
        );
      }
    }

    if (validationCode ==
        _deriveLegacyValidationCode(
          licenceId,
          validationLength: validationCodeLength,
        )) {
      return ResolvedLicenseKey(
        normalizedCode: normalized,
        licenceId: licenceId,
        organizationCode: organizationCode,
        expiryYear: expiryYear,
        validationCode: validationCode,
        licenceType: coreLicenceType,
        tierMarker: coreTierMarker,
        usesLegacySignature: true,
      );
    }

    return null;
  }

  static ResolvedLicenseKey? _resolveLegacyFormat(String normalized) {
    final match = _legacyLicenceCodePattern.firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final organizationCode = match.group(1)!;
    final expiryYear = int.parse(match.group(2)!);
    final validationCode = match.group(3)!;
    final legacyLicenceId = '$productIdentifier-$organizationCode$expiryYear';

    for (final licenceType in supportedLicenceTypes) {
      if (licenceType == pilotLicenceType) {
        final fixedPilotKey = _resolveFixedExpiryPilotKey(
          normalizedCode: normalized,
          licenceId: legacyLicenceId,
          organizationCode: organizationCode,
          expiryYear: expiryYear,
          validationCode: validationCode,
          validationLength: legacyValidationCodeLength,
          tierMarker: tierMarkerForLicenceType(licenceType),
          usesLegacySignature: false,
        );
        if (fixedPilotKey != null) {
          return fixedPilotKey;
        }
      }

      if (validationCode ==
          _deriveOrganizationBoundValidationCode(
            legacyLicenceId,
            licenceType,
            validationLength: legacyValidationCodeLength,
          )) {
        return ResolvedLicenseKey(
          normalizedCode: normalized,
          licenceId: legacyLicenceId,
          organizationCode: organizationCode,
          expiryYear: expiryYear,
          validationCode: validationCode,
          licenceType: licenceType,
          tierMarker: tierMarkerForLicenceType(licenceType),
          usesLegacySignature: false,
        );
      }
    }

    if (validationCode ==
        _deriveLegacyValidationCode(
          legacyLicenceId,
          validationLength: legacyValidationCodeLength,
        )) {
      return ResolvedLicenseKey(
        normalizedCode: normalized,
        licenceId: legacyLicenceId,
        organizationCode: organizationCode,
        expiryYear: expiryYear,
        validationCode: validationCode,
        licenceType: coreLicenceType,
        tierMarker: coreTierMarker,
        usesLegacySignature: true,
      );
    }

    return null;
  }

  static String _deriveValidationCode({
    required int expiryYear,
    required String licenceType,
    required int validationLength,
  }) {
    final normalizedType = normalizeLicenceType(licenceType);
    if (normalizedType == null) {
      throw const FormatException('Licence type must be Trial, Core or Pro.');
    }
    if (expiryYear < 1000 || expiryYear > 9999) {
      throw const FormatException('Expiry year must be a 4-digit year.');
    }

    final hmac = Hmac(sha256, utf8.encode(validationSecret));
    final digest = hmac.convert(
      utf8.encode('$productIdentifier|$expiryYear|$normalizedType'),
    );
    return _mapDigestToValidationCode(
      digest.bytes,
      validationLength: validationLength,
    );
  }

  static String _derivePilotValidationCode({
    required DateTime fixedExpiryDate,
    required int validationLength,
  }) {
    final hmac = Hmac(sha256, utf8.encode(validationSecret));
    final digest = hmac.convert(
      utf8.encode(
        '$productIdentifier|$pilotLicenceType|${_pilotExpirySignatureValue(fixedExpiryDate)}',
      ),
    );
    return _mapDigestToValidationCode(
      digest.bytes,
      validationLength: validationLength,
    );
  }

  static String _deriveOrganizationBoundValidationCode(
    String licenceId,
    String licenceType, {
    required int validationLength,
  }) {
    final normalizedType = normalizeLicenceType(licenceType);
    if (normalizedType == null) {
      throw const FormatException('Licence type must be Trial, Core or Pro.');
    }

    final hmac = Hmac(sha256, utf8.encode(validationSecret));
    final digest = hmac.convert(utf8.encode('$licenceId|$normalizedType'));
    return _mapDigestToValidationCode(
      digest.bytes,
      validationLength: validationLength,
    );
  }

  static String _deriveOrganizationBoundPilotValidationCode(
    String licenceId,
    DateTime fixedExpiryDate, {
    required int validationLength,
  }) {
    final hmac = Hmac(sha256, utf8.encode(validationSecret));
    final digest = hmac.convert(
      utf8.encode(
        '$licenceId|$pilotLicenceType|${_pilotExpirySignatureValue(fixedExpiryDate)}',
      ),
    );
    return _mapDigestToValidationCode(
      digest.bytes,
      validationLength: validationLength,
    );
  }

  static String _deriveLegacyValidationCode(
    String licenceId, {
    required int validationLength,
  }) {
    final hmac = Hmac(sha256, utf8.encode(validationSecret));
    final digest = hmac.convert(utf8.encode(licenceId));
    return _mapDigestToValidationCode(
      digest.bytes,
      validationLength: validationLength,
    );
  }

  static String _mapDigestToValidationCode(
    List<int> bytes, {
    required int validationLength,
  }) {
    final output = StringBuffer();
    for (var i = 0; i < validationLength; i++) {
      output.write(validationAlphabet[bytes[i] % validationAlphabet.length]);
    }
    return output.toString();
  }

  static DateTime? _resolveGeneratedPilotExpiry({
    required int expiryYear,
    required String licenceType,
    DateTime? now,
    DateTime? pilotExpiryDate,
  }) {
    if (licenceType != pilotLicenceType) {
      return null;
    }

    final encodedExpiry = _normalizePilotExpiryDate(
      pilotExpiryDate ?? fixedPilotExpiryFromIssueDate(now ?? DateTime.now()),
    );
    if (encodedExpiry.year != expiryYear) {
      throw FormatException(
        'Pilot expiry year must match the encoded fixed expiry year (${encodedExpiry.year}).',
      );
    }
    return encodedExpiry;
  }

  static ResolvedLicenseKey? _resolveFixedExpiryPilotKey({
    required String normalizedCode,
    required String licenceId,
    required String organizationCode,
    required int expiryYear,
    required String validationCode,
    required int validationLength,
    required String tierMarker,
    required bool usesLegacySignature,
  }) {
    for (final fixedExpiryDate in _pilotExpiryCandidatesForYear(expiryYear)) {
      final genericValidation = _derivePilotValidationCode(
        fixedExpiryDate: fixedExpiryDate,
        validationLength: validationLength,
      );
      final organizationBoundValidation =
          _deriveOrganizationBoundPilotValidationCode(
            licenceId,
            fixedExpiryDate,
            validationLength: validationLength,
          );

      if (validationCode != genericValidation &&
          validationCode != organizationBoundValidation) {
        continue;
      }

      return ResolvedLicenseKey(
        normalizedCode: normalizedCode,
        licenceId: licenceId,
        organizationCode: organizationCode,
        expiryYear: expiryYear,
        validationCode: validationCode,
        licenceType: pilotLicenceType,
        tierMarker: tierMarker,
        usesLegacySignature: usesLegacySignature,
        fixedExpiryDate: fixedExpiryDate,
      );
    }

    return null;
  }

  static Iterable<DateTime> _pilotExpiryCandidatesForYear(
    int expiryYear,
  ) sync* {
    var current = DateTime(expiryYear, 1, 1);
    while (current.year == expiryYear) {
      yield _normalizePilotExpiryDate(current);
      current = current.add(const Duration(days: 1));
    }
  }

  static DateTime _normalizePilotExpiryDate(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  static String _pilotExpirySignatureValue(DateTime fixedExpiryDate) {
    final normalizedDate = _normalizePilotExpiryDate(fixedExpiryDate);
    final year = normalizedDate.year.toString().padLeft(4, '0');
    final month = normalizedDate.month.toString().padLeft(2, '0');
    final day = normalizedDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String? _readText(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
}
