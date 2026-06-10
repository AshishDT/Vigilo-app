import 'dart:io';

import 'package:vigilo/services/license_key_codec.dart';

void main(List<String> arguments) {
  if (arguments.length != 4 && arguments.length != 3) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final hasOrganizationName = arguments.length == 4;
  final organizationName = hasOrganizationName ? arguments[0] : arguments[0];
  final organizationCode = hasOrganizationName ? arguments[1] : arguments[0];
  final expiryYear = int.tryParse(arguments[hasOrganizationName ? 2 : 1]);
  final licenceType = LicenseKeyCodec.normalizeLicenceType(
    arguments[hasOrganizationName ? 3 : 2],
  );

  if (expiryYear == null) {
    stderr.writeln('Expiry year must be a 4-digit number.');
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  if (licenceType == null) {
    stderr.writeln('Licence type must be Trial, Core or Pro.');
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  if (!hasOrganizationName) {
    stderr.writeln(
      'No organisation name supplied. The register entry will use the organisation code as the organisation name.',
    );
  }

  try {
    final normalizedOrganizationCode = LicenseKeyCodec.sanitizeOrganizationCode(
      organizationCode,
    );
    final issuedAt = DateTime.now();
    final licenceId = LicenseKeyCodec.generateLicenceId(
      organizationCode: normalizedOrganizationCode,
      expiryYear: expiryYear,
      licenceType: licenceType,
      now: issuedAt,
    );
    final licenceKey = LicenseKeyCodec.generateLicenceKey(
      organizationCode: normalizedOrganizationCode,
      expiryYear: expiryYear,
      licenceType: licenceType,
      now: issuedAt,
    );
    final activationCode = LicenseKeyCodec.displayActivationCodeFromLicence(
      licenceKey,
    );
    final issuedOn = issuedAt.toIso8601String().split('T').first;
    final registerFile = File(
      '${File.fromUri(Platform.script).parent.path}${Platform.pathSeparator}license_register.csv',
    );
    final effectiveYear = int.parse(licenceId.split('-')[4]);
    final pilotExpiry = licenceType == LicenseKeyCodec.pilotLicenceType
        ? LicenseKeyCodec.fixedPilotExpiryFromIssueDate(issuedAt)
        : null;

    _appendRegisterEntry(
      registerFile: registerFile,
      organizationName: organizationName,
      organizationCode: normalizedOrganizationCode,
      tier: LicenseKeyCodec.tierLabelForLicenceType(licenceType),
      year: effectiveYear,
      licenceKey: licenceKey,
      issuedOn: issuedOn,
    );

    stdout.writeln('Organisation: $organizationName');
    stdout.writeln('Organisation Code: $normalizedOrganizationCode');
    stdout.writeln(
      'Tier: ${LicenseKeyCodec.tierLabelForLicenceType(licenceType)}',
    );
    stdout.writeln(
      'Tier Marker: ${LicenseKeyCodec.tierMarkerForLicenceType(licenceType)}',
    );
    stdout.writeln('Expiry Year: $effectiveYear');
    if (pilotExpiry != null) {
      stdout.writeln('Pilot Fixed Expiry: ${_displayDate(pilotExpiry)}');
    }
    stdout.writeln('Activation Code: $activationCode');
    stdout.writeln('Licence ID: $licenceId');
    stdout.writeln('Licence Key: $licenceKey');
    stdout.writeln('Register: ${registerFile.path}');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on FileSystemException catch (error) {
    stderr.writeln(
      'Unable to update the licence register: ${error.message} (${error.path ?? 'unknown path'})',
    );
    exitCode = 74;
  }
}

void _appendRegisterEntry({
  required File registerFile,
  required String organizationName,
  required String organizationCode,
  required String tier,
  required int year,
  required String licenceKey,
  required String issuedOn,
}) {
  if (!registerFile.parent.existsSync()) {
    registerFile.parent.createSync(recursive: true);
  }

  final buffer = StringBuffer();
  if (!registerFile.existsSync() || registerFile.lengthSync() == 0) {
    buffer.writeln('Organisation,Code,Tier,Year,Licence,Issued');
  }
  buffer.writeln(
    [
      organizationName,
      organizationCode,
      tier,
      year.toString(),
      licenceKey,
      issuedOn,
    ].map(_csvCell).join(','),
  );

  registerFile.writeAsStringSync(buffer.toString(), mode: FileMode.append);
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

void _printUsage([IOSink? sink]) {
  final output = sink ?? stdout;
  output.writeln(
    'Usage: dart run tool/generate_license.dart <organisationName> <organisationCode> <expiryYear> <Trial|Pilot|Core|Pro>',
  );
  output.writeln(
    'Example: dart run tool/generate_license.dart "Battersea Academy" BA 2026 Pilot',
  );
  output.writeln(
    'Optional shared secret: dart run -DVIGILO_LICENSE_VALIDATION_SECRET=your-secret tool/generate_license.dart "Battersea Academy" BA 2027 Pilot',
  );
  output.writeln(
    'Pilot licences encode a fixed expiry date based on the issue date, so the supplied year must match that encoded expiry year.',
  );
}

String _displayDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}
