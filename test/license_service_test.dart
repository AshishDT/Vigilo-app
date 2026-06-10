import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigilo/services/license_key_codec.dart';
import 'package:vigilo/services/license_service.dart';

void main() {
  String generatedKey({
    required String organizationCode,
    required int expiryYear,
    required String licenceType,
    DateTime? now,
  }) {
    return LicenseService.generateLicenceKey(
      organizationCode: organizationCode,
      expiryYear: expiryYear,
      licenceType: licenceType,
      now: now,
    );
  }

  DateTime fixedPilotExpiry(DateTime issuedAt) {
    return LicenseService.fixedPilotExpiryFromIssueDate(issuedAt);
  }

  Future<void> resetPrefs() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  }

  String buildProof({
    required String code,
    required DateTime activation,
    required DateTime expiry,
    required String? organizationName,
    required String? organizationCode,
    required String licenceType,
  }) {
    final normalizedOrganizationName =
        organizationName
            ?.trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .toLowerCase() ??
        '';
    final normalizedOrganizationCode = organizationCode == null
        ? ''
        : LicenseService.sanitizeOrganizationCode(organizationCode);
    final source =
        '${code.trim()}|'
        '${activation.toIso8601String()}|'
        '${expiry.toIso8601String()}|'
        '$normalizedOrganizationName|'
        '$normalizedOrganizationCode|'
        '${licenceType.trim()}|'
        '${LicenseKeyCodec.validationSecret}';
    return sha256.convert(utf8.encode(source)).toString();
  }

  group('LicenseService', () {
    setUp(() async {
      await resetPrefs();
    });

    test('generates tiered licence keys with visible tier markers', () {
      final pilotIssuedAt = DateTime(2026, 3, 12, 10, 15);
      final pilotExpiry = fixedPilotExpiry(pilotIssuedAt);
      final trialKey = generatedKey(
        organizationCode: 'BA',
        expiryYear: pilotExpiry.year,
        licenceType: LicenseService.pilotLicenceType,
        now: pilotIssuedAt,
      );
      final coreKey = generatedKey(
        organizationCode: 'BA',
        expiryYear: 2027,
        licenceType: LicenseService.coreLicenceType,
      );
      final proKey = generatedKey(
        organizationCode: 'BA',
        expiryYear: 2027,
        licenceType: LicenseService.proLicenceType,
      );

      expect(
        trialKey,
        matches(
          RegExp(
            r'^VIGILO-ERC-TR-BA-2026-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
          ),
        ),
      );
      expect(
        coreKey,
        matches(
          RegExp(
            r'^VIGILO-ERC-CR-BA-2027-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
          ),
        ),
      );
      expect(
        proKey,
        matches(
          RegExp(
            r'^VIGILO-ERC-PR-BA-2027-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
          ),
        ),
      );
    });

    test('supports numeric and mixed organisation codes', () {
      final numericKey = generatedKey(
        organizationCode: '28213',
        expiryYear: 2027,
        licenceType: LicenseService.coreLicenceType,
      );
      final mixedKey = generatedKey(
        organizationCode: 'BA01',
        expiryYear: 2027,
        licenceType: LicenseService.proLicenceType,
      );

      expect(
        numericKey,
        matches(
          RegExp(
            r'^VIGILO-ERC-CR-28213-2027-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
          ),
        ),
      );
      expect(
        mixedKey,
        matches(
          RegExp(
            r'^VIGILO-ERC-PR-BA01-2027-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
          ),
        ),
      );
    });

    test('builds a visible licence id without the validation segment', () {
      expect(
        LicenseService.displayLicenceId('VIGILO-ERC-CR-BA-2027-A7K9QF'),
        'VIGILO-ERC-CR-BA-2027',
      );
    });

    test('formats activation codes as XXX-XXX for display', () {
      expect(
        LicenseService.displayActivationCodeFromLicence(
          'VIGILO-ERC-CR-BA-2027-A7K9QF',
        ),
        'A7K-9QF',
      );
      expect(LicenseService.formatActivationCode('m7p3qf'), 'M7P-3QF');
    });

    test(
      'accepts a full tiered licence key and stores organisation metadata',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        final snapshot = await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        expect(snapshot.licenceCode, code);
        expect(snapshot.activationDate, activationDate);
        expect(snapshot.expiryDate, DateTime(2027, 2, 23, 9));
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
        expect(snapshot.licenceType, LicenseService.coreLicenceType);
      },
    );

    test(
      'uses the activation anniversary for core expiry when it falls beyond the encoded year-end',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2027, 11, 10, 9);

        final snapshot = await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        expect(snapshot.expiryDate, DateTime(2028, 11, 10, 9));
      },
    );

    test(
      'uses the activation anniversary for pro expiry when it falls beyond the encoded year-end',
      () {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.proLicenceType,
        );
        final activationDate = DateTime(2027, 11, 10, 9);

        final resolved = LicenseService.resolveLicenseKey(code);

        expect(resolved, isNotNull);
        expect(
          resolved!.expiryDateForActivation(activationDate),
          DateTime(2028, 11, 10, 9),
        );
      },
    );

    test(
      'rejects a full key when the entered organisation code does not match',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );

        expect(
          LicenseService.activate('Clapham Academy', 'BA', code),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'This licence does not match the Organisation Code for this device.',
            ),
          ),
        );
      },
    );

    test(
      'accepts a pilot activation code using organisation name and code',
      () async {
        final issuedAt = DateTime(2026, 3, 11, 9, 30);
        final encodedExpiry = fixedPilotExpiry(issuedAt);
        final code = generatedKey(
          organizationCode: 'BA',
          expiryYear: encodedExpiry.year,
          licenceType: LicenseService.pilotLicenceType,
          now: issuedAt,
        );

        final snapshot = await LicenseService.activateFromActivationCode(
          'Battersea Academy',
          'BA',
          LicenseService.activationCodeFromLicence(code),
          now: issuedAt,
        );

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Battersea Academy');
        expect(snapshot.organizationCode, 'BA');
        expect(snapshot.licenceType, LicenseService.pilotLicenceType);
        expect(snapshot.expiryDate, encodedExpiry);
      },
    );

    test(
      'keeps the same fixed pilot expiry when the same key is reactivated later',
      () async {
        final issuedAt = DateTime(2026, 3, 12, 8, 45);
        final encodedExpiry = fixedPilotExpiry(issuedAt);
        final code = generatedKey(
          organizationCode: 'BA',
          expiryYear: encodedExpiry.year,
          licenceType: LicenseService.pilotLicenceType,
          now: issuedAt,
        );

        final firstSnapshot = await LicenseService.activate(
          'Battersea Academy',
          'BA',
          code,
          now: issuedAt,
        );

        await resetPrefs();

        final reactivatedSnapshot = await LicenseService.activate(
          'Battersea Academy',
          'BA',
          code,
          now: DateTime(2026, 3, 28, 14, 10),
        );

        expect(firstSnapshot.expiryDate, encodedExpiry);
        expect(reactivatedSnapshot.expiryDate, encodedExpiry);
      },
    );

    test(
      'keeps the same fixed pilot expiry when the same activation code is reused after a reinstall-style reset',
      () async {
        final issuedAt = DateTime(2026, 3, 12, 8, 45);
        final encodedExpiry = fixedPilotExpiry(issuedAt);
        final code = generatedKey(
          organizationCode: 'BA',
          expiryYear: encodedExpiry.year,
          licenceType: LicenseService.pilotLicenceType,
          now: issuedAt,
        );
        final activationCode = LicenseService.activationCodeFromLicence(code);

        final firstSnapshot = await LicenseService.activateFromActivationCode(
          'Battersea Academy',
          'BA',
          activationCode,
          now: issuedAt,
        );

        await resetPrefs();

        final reactivatedSnapshot =
            await LicenseService.activateFromActivationCode(
              'Battersea Academy',
              'BA',
              activationCode,
              now: DateTime(2026, 3, 28, 14, 10),
            );

        expect(firstSnapshot.licenceCode, code);
        expect(firstSnapshot.expiryDate, encodedExpiry);
        expect(reactivatedSnapshot.licenceCode, code);
        expect(reactivatedSnapshot.expiryDate, encodedExpiry);
      },
    );

    test(
      'uses the same activation code for different organisations in the same year and tier',
      () async {
        final springKey = generatedKey(
          organizationCode: 'SA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final batterseaKey = generatedKey(
          organizationCode: 'BA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );

        expect(springKey, isNot(batterseaKey));
        expect(
          LicenseService.activationCodeFromLicence(springKey),
          LicenseService.activationCodeFromLicence(batterseaKey),
        );

        final springSnapshot = await LicenseService.activateFromActivationCode(
          'Spring Academy',
          'SA',
          LicenseService.activationCodeFromLicence(springKey),
          now: DateTime(2026, 3, 11, 9),
        );
        final batterseaSnapshot =
            await LicenseService.activateFromActivationCode(
              'Battersea Academy',
              'BA',
              LicenseService.activationCodeFromLicence(springKey),
              now: DateTime(2026, 3, 11, 9, 30),
            );

        expect(springSnapshot.licenceCode, springKey);
        expect(batterseaSnapshot.licenceCode, batterseaKey);
      },
    );

    test(
      'resolves a 6-character activation code against the organisation code and year',
      () {
        final now = DateTime(2026, 3, 11);
        final code = generatedKey(
          organizationCode: 'BA',
          expiryYear: now.year + 1,
          licenceType: LicenseService.coreLicenceType,
        );

        final resolved =
            LicenseService.resolveActivationCodeForOrganizationCode(
              organizationCode: 'BA',
              activationCode: LicenseService.activationCodeFromLicence(code),
              now: now,
            );

        expect(resolved?.normalizedCode, code);
        expect(resolved?.expiryYear, 2027);
        expect(resolved?.organizationCode, 'BA');
        expect(resolved?.tierMarker, 'CR');
      },
    );

    test(
      'resolves a 6-character activation code for the current licence year when needed',
      () {
        final now = DateTime(2027, 11, 10);
        final code = generatedKey(
          organizationCode: 'BA',
          expiryYear: now.year,
          licenceType: LicenseService.coreLicenceType,
        );

        final resolved =
            LicenseService.resolveActivationCodeForOrganizationCode(
              organizationCode: 'BA',
              activationCode: LicenseService.activationCodeFromLicence(code),
              now: now,
            );

        expect(resolved?.normalizedCode, code);
        expect(resolved?.expiryYear, 2027);
        expect(resolved?.organizationCode, 'BA');
        expect(resolved?.tierMarker, 'CR');
      },
    );

    test(
      'activates correctly from segmented licence id and validation parts',
      () async {
        final code = generatedKey(
          organizationCode: 'SA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final parts = code.split('-');

        final snapshot = await LicenseService.activateFromParts(
          '${parts[2]}${parts[3]}${parts[4]}',
          parts[5],
          organizationName: 'Spring Academy',
          organizationCode: 'SA',
        );

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Spring Academy');
        expect(snapshot.organizationCode, 'SA');
        expect(snapshot.licenceType, LicenseService.coreLicenceType);
      },
    );

    test(
      'normalizes compact and display-formatted keys before validation',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final compactCode = code.toLowerCase().replaceAll('-', '');
        final formattedCode =
            '${LicenseService.displayLicenceId(code)}-${LicenseService.displayActivationCodeFromLicence(code)}';

        final compactSnapshot = await LicenseService.activate(
          'Clapham Academy',
          'CA',
          compactCode,
        );
        await resetPrefs();
        final formattedSnapshot = await LicenseService.activate(
          'Clapham Academy',
          'CA',
          formattedCode,
        );

        expect(compactSnapshot.licenceCode, code);
        expect(formattedSnapshot.licenceCode, code);
      },
    );

    test(
      'keeps legacy tierless keys valid after the tiered format upgrade',
      () {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final parts = code.split('-');
        final legacyTierlessCode =
            'VIGILO-ERC-${parts[3]}-${parts[4]}-${parts[5]}';

        expect(LicenseService.isValidLicenseKey(legacyTierlessCode), isTrue);
        expect(
          LicenseService.resolveLicenseKey(legacyTierlessCode)?.licenceType,
          LicenseService.coreLicenceType,
        );
      },
    );

    test(
      'refreshes stored proof drift when the licence code still resolves',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        SharedPreferences.setMockInitialValues({
          'vigilo_licence_code': code,
          'vigilo_licence_activation_date': activationDate.toIso8601String(),
          'vigilo_licence_expiry_date': DateTime(
            2027,
            12,
            31,
            23,
            59,
            59,
            999,
          ).toIso8601String(),
          'vigilo_licence_school_name': 'Clapham Academy',
          'vigilo_licence_school_number': 'CA',
          'vigilo_licence_type': LicenseService.coreLicenceType,
          'vigilo_licence_proof': 'tampered-proof',
        });

        final snapshot = await LicenseService.getSnapshot();
        final prefs = await SharedPreferences.getInstance();
        final refreshedExpiry = DateTime(2027, 2, 23, 9);

        expect(snapshot.licenceCode, code);
        expect(snapshot.activationDate, activationDate);
        expect(snapshot.expiryDate, refreshedExpiry);
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
        expect(snapshot.licenceType, LicenseService.coreLicenceType);
        expect(prefs.getString('vigilo_licence_code'), code);
        expect(
          prefs.getString('vigilo_licence_activation_date'),
          activationDate.toIso8601String(),
        );
        expect(
          prefs.getString('vigilo_licence_proof'),
          buildProof(
            code: code,
            activation: activationDate,
            expiry: refreshedExpiry,
            organizationName: 'Clapham Academy',
            organizationCode: 'CA',
            licenceType: LicenseService.coreLicenceType,
          ),
        );
      },
    );

    test(
      'refreshes stored core licences that used the previous year-end-only expiry',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2027, 11, 10, 9);
        final previousExpiry = DateTime(2027, 12, 31, 23, 59, 59, 999);
        final refreshedExpiry = DateTime(2028, 11, 10, 9);

        SharedPreferences.setMockInitialValues({
          'vigilo_licence_code': code,
          'vigilo_licence_activation_date': activationDate.toIso8601String(),
          'vigilo_licence_expiry_date': previousExpiry.toIso8601String(),
          'vigilo_licence_school_name': 'Clapham Academy',
          'vigilo_licence_school_number': 'CA',
          'vigilo_licence_type': LicenseService.coreLicenceType,
          'vigilo_licence_proof': buildProof(
            code: code,
            activation: activationDate,
            expiry: previousExpiry,
            organizationName: 'Clapham Academy',
            organizationCode: 'CA',
            licenceType: LicenseService.coreLicenceType,
          ),
        });

        final snapshot = await LicenseService.getSnapshot();
        final prefs = await SharedPreferences.getInstance();

        expect(snapshot.licenceCode, code);
        expect(snapshot.expiryDate, refreshedExpiry);
        expect(
          prefs.getString('vigilo_licence_expiry_date'),
          refreshedExpiry.toIso8601String(),
        );
        expect(
          prefs.getString('vigilo_licence_proof'),
          buildProof(
            code: code,
            activation: activationDate,
            expiry: refreshedExpiry,
            organizationName: 'Clapham Academy',
            organizationCode: 'CA',
            licenceType: LicenseService.coreLicenceType,
          ),
        );
      },
    );

    test(
      'keeps a stored licence when the current organisation matches after normalization',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        final snapshot = await LicenseService.getSnapshot(
          currentOrganizationName: '  clapham   academy  ',
          currentOrganizationCode: 'ca',
        );

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
      },
    );

    test(
      'keeps a stored licence when only the current organisation code is available and it matches',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        final snapshot = await LicenseService.getSnapshot(
          currentOrganizationCode: 'ca',
        );

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
      },
    );

    test(
      'keeps a stored licence when only the current organisation name is available and it matches',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        final snapshot = await LicenseService.getSnapshot(
          currentOrganizationName: '  clapham   academy  ',
        );

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
      },
    );

    test(
      'keeps a stored licence when the current organisation differs from the stored activation context',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        final snapshot = await LicenseService.getSnapshot(
          currentOrganizationName: 'Spring Academy',
          currentOrganizationCode: 'SA',
        );
        final prefs = await SharedPreferences.getInstance();

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
        expect(prefs.getString('vigilo_licence_code'), code);
        expect(
          prefs.getString('vigilo_licence_school_name'),
          'Clapham Academy',
        );
        expect(prefs.getString('vigilo_licence_school_number'), 'CA');
      },
    );

    test(
      'keeps a stored licence when only the current organisation code differs',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        final snapshot = await LicenseService.getSnapshot(
          currentOrganizationCode: 'SA',
        );
        final prefs = await SharedPreferences.getInstance();

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
        expect(prefs.getString('vigilo_licence_code'), code);
      },
    );

    test(
      'keeps a stored licence when only the current organisation name differs',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);

        await LicenseService.activate(
          'Clapham Academy',
          'CA',
          code,
          now: activationDate,
        );

        final snapshot = await LicenseService.getSnapshot(
          currentOrganizationName: 'Spring Academy',
        );
        final prefs = await SharedPreferences.getInstance();

        expect(snapshot.licenceCode, code);
        expect(snapshot.organizationName, 'Clapham Academy');
        expect(snapshot.organizationCode, 'CA');
        expect(prefs.getString('vigilo_licence_code'), code);
      },
    );

    test(
      'clears a stored licence when the stored organisation code does not match the resolved licence code',
      () async {
        final code = generatedKey(
          organizationCode: 'CA',
          expiryYear: 2027,
          licenceType: LicenseService.coreLicenceType,
        );
        final activationDate = DateTime(2026, 2, 23, 9);
        final expiryDate = DateTime(2027, 2, 23, 9);

        SharedPreferences.setMockInitialValues({
          'vigilo_licence_code': code,
          'vigilo_licence_activation_date': activationDate.toIso8601String(),
          'vigilo_licence_expiry_date': expiryDate.toIso8601String(),
          'vigilo_licence_school_name': 'Clapham Academy',
          'vigilo_licence_school_number': 'SA',
          'vigilo_licence_type': LicenseService.coreLicenceType,
          'vigilo_licence_proof': buildProof(
            code: code,
            activation: activationDate,
            expiry: expiryDate,
            organizationName: 'Clapham Academy',
            organizationCode: 'SA',
            licenceType: LicenseService.coreLicenceType,
          ),
        });

        final snapshot = await LicenseService.getSnapshot();
        final prefs = await SharedPreferences.getInstance();

        expect(snapshot.licenceCode, isNull);
        expect(snapshot.organizationName, isNull);
        expect(snapshot.organizationCode, isNull);
        expect(prefs.getString('vigilo_licence_code'), isNull);
        expect(prefs.getString('vigilo_licence_school_number'), isNull);
      },
    );

    test('masks the stored licence code for status display', () {
      expect(
        LicenseService.maskLicenceCode('VIGILO-ERC-CR-CA-2027-A7K9QF'),
        'VIGILO-ERC-CR-CA-2027-****QF',
      );
      expect(
        LicenseService.maskLicenceCodeForStatus('VIGILO-ERC-CR-CA-2027-A7K9QF'),
        '********A7K9QF',
      );
    });

    test('normalizes trial and legacy school labels', () {
      expect(
        LicenseService.normalizeLicenceType('Trial'),
        LicenseService.pilotLicenceType,
      );
      expect(
        LicenseService.normalizeLicenceType('School licence'),
        LicenseService.coreLicenceType,
      );
      expect(
        LicenseService.tierMarkerForLicenceType('Pilot'),
        LicenseKeyCodec.trialTierMarker,
      );
      expect(
        LicenseService.tierLabelForLicenceType('Pilot'),
        LicenseKeyCodec.trialTierLabel,
      );
    });

    test('derives an organisation code from the organisation name', () {
      expect(LicenseService.deriveOrganizationCode('Spring Academy'), 'SA');
      expect(LicenseService.deriveOrganizationCode('Battersea Academy'), 'BA');
      expect(LicenseService.deriveOrganizationCode('Beacon'), 'BE');
    });

    test('recognizes pro access from the stored licence type', () {
      final snapshot = LicenseSnapshot(
        licenceCode: 'VIGILO-ERC-PR-CA-2027-A7K9QF',
        expiryDate: DateTime(2027, 2, 23, 9),
        licenceType: LicenseService.proLicenceType,
      );

      expect(LicenseService.hasProMessagingAccess(snapshot), isTrue);
    });
  });
}
