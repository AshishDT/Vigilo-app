import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigilo/services/license_service.dart';
import 'package:vigilo/views/license_activation_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool resetPrefs = true,
    bool scrollToActivation = true,
  }) async {
    PackageInfo.setMockInitialValues(
      appName: 'vigilo',
      packageName: 'com.example.vigilo',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'buildSignature',
    );
    if (resetPrefs) {
      SharedPreferences.setMockInitialValues({});
    }
    await tester.pumpWidget(const MaterialApp(home: LicenseActivationScreen()));
    await tester.pumpAndSettle();
    if (scrollToActivation) {
      try {
        await tester.scrollUntilVisible(
          find.text('Activate Licence'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      } catch (_) {}
    }
  }

  Finder inputByHint(String hintText) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == hintText,
    );
  }

  String boxText(WidgetTester tester, int index) {
    final field = tester.widget<TextField>(
      find.byKey(Key('validation-box-$index')),
    );
    return field.controller?.text ?? '';
  }

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

  testWidgets(
    'shows licence required with organisation wording when no licence is stored',
    (tester) async {
      await pumpScreen(tester, scrollToActivation: false);

      await tester.scrollUntilVisible(
        find.text('Licence Required'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Licence Required'), findsOneWidget);
      expect(
        find.text(
          'Activate a Pilot, Core, or Pro licence to continue using Vigilo ERC.',
        ),
        findsOneWidget,
      );
      expect(find.text('Activation Needed'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Activate Licence'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(inputByHint('Enter organisation name'), findsOneWidget);
      expect(
        inputByHint('Enter organisation code'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders equal-width activation code boxes with the centred dash layout',
    (tester) async {
      await pumpScreen(tester);

      final firstBox = find.byKey(const Key('validation-box-0'));
      final secondBox = find.byKey(const Key('validation-box-1'));
      final fourthBox = find.byKey(const Key('validation-box-3'));

      await tester.ensureVisible(firstBox);
      await tester.pumpAndSettle();

      final firstSize = tester.getSize(firstBox);
      final secondSize = tester.getSize(secondBox);
      final fourthSize = tester.getSize(fourthBox);

      expect(firstSize.height, 64);
      expect(firstSize.width, secondSize.width);
      expect(secondSize.width, fourthSize.width);
      expect(find.text('-'), findsOneWidget);
    },
  );

  testWidgets(
    'validation boxes uppercase input, reject confusing characters, and auto-advance',
    (tester) async {
      await pumpScreen(tester);

      final firstBox = find.byKey(const Key('validation-box-0'));
      await tester.scrollUntilVisible(
        firstBox,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(firstBox, warnIfMissed: false);
      await tester.pump();

      tester.testTextInput.enterText('o');
      await tester.pump();
      expect(boxText(tester, 0), isEmpty);

      tester.testTextInput.enterText('a');
      await tester.pump();
      expect(boxText(tester, 0), 'A');

      tester.testTextInput.enterText('7');
      await tester.pump();
      expect(boxText(tester, 1), '7');

      tester.testTextInput.enterText('k');
      await tester.pump();
      expect(boxText(tester, 2), 'K');
    },
  );

  testWidgets(
    'pasting a full tiered key into the first validation box distributes the activation code',
    (tester) async {
      await pumpScreen(tester);
      final expiryYear = DateTime.now().year + 1;
      final fullKey = generatedKey(
        organizationCode: 'SA',
        expiryYear: expiryYear,
        licenceType: LicenseService.coreLicenceType,
      );

      final firstBox = find.byKey(const Key('validation-box-0'));
      final lastBox = find.byKey(const Key('validation-box-5'));

      await tester.scrollUntilVisible(
        firstBox,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(firstBox, warnIfMissed: false);
      await tester.pump();
      tester.testTextInput.enterText(fullKey);
      await tester.pump();

      final activationCode = LicenseService.activationCodeFromLicence(fullKey);
      for (var index = 0; index < activationCode.length; index++) {
        expect(boxText(tester, index), activationCode[index]);
      }

      await tester.tap(lastBox, warnIfMissed: false);
      await tester.pump();
      tester.testTextInput.enterText('');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(boxText(tester, 4), isEmpty);
    },
  );

  testWidgets(
    'shows the corrected licence type wording on the licence information screen',
    (tester) async {
      await pumpScreen(tester, scrollToActivation: false);

      await tester.scrollUntilVisible(
        find.text('Multi-device coordination'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('30-day evaluation licence for organisation testing Vigilo ERC.'),
        findsOneWidget,
      );
      expect(find.text('Officer Tools'), findsOneWidget);
      expect(find.text('Basic exam session export'), findsOneWidget);
      expect(
        find.text('Full operational licence for organisation running examinations.'),
        findsOneWidget,
      );
      expect(find.text('Exam session export'), findsOneWidget);
      expect(
        find.text(
          'Includes everything in Core plus additional coordination features.\n(Pro features will be introduced in Version 1.1)',
        ),
        findsOneWidget,
      );
      expect(find.text('Invigilator messaging'), findsOneWidget);
      expect(find.text('Multi-device coordination'), findsOneWidget);
    },
  );

  testWidgets(
    'builds the tiered preview from organisation code and activates successfully',
    (tester) async {
      await pumpScreen(tester);
      final expiryYear = DateTime.now().year + 1;
      final fullKey = generatedKey(
        organizationCode: 'SA',
        expiryYear: expiryYear,
        licenceType: LicenseService.coreLicenceType,
      );
      final activationCode = LicenseService.activationCodeFromLicence(fullKey);

      await tester.enterText(
        inputByHint('Enter organisation name'),
        'Spring Academy',
      );
      await tester.enterText(
        inputByHint('Enter organisation code'),
        'sa',
      );
      await tester.pumpAndSettle();

      expect(find.text('VIGILO-ERC-XX-SA-$expiryYear-______'), findsOneWidget);
      expect(find.text('--- ---'), findsOneWidget);

      final firstBox = find.byKey(const Key('validation-box-0'));
      await tester.ensureVisible(firstBox);
      await tester.tap(firstBox, warnIfMissed: false);
      await tester.pump();
      tester.testTextInput.enterText(activationCode);
      await tester.pumpAndSettle();

      expect(
        find.text(LicenseService.formatActivationCode(activationCode)),
        findsOneWidget,
      );
      expect(find.text(fullKey), findsOneWidget);

      await tester.tap(find.text('Activate Licence'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(LicenseService.maskLicenceCodeForStatus(fullKey)),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(LicenseService.maskLicenceCodeForStatus(fullKey)),
        findsOneWidget,
      );
      expect(find.text(fullKey), findsNothing);
      expect(
        find.text(LicenseService.formatActivationCode(activationCode)),
        findsNothing,
      );
      expect(find.byType(TextField), findsNothing);
      expect(inputByHint('Enter organisation name'), findsNothing);
      expect(inputByHint('Enter organisation code'), findsNothing);

      final snapshot = await LicenseService.getSnapshot();
      expect(snapshot.licenceCode, fullKey);
      expect(snapshot.organizationName, 'Spring Academy');
      expect(snapshot.organizationCode, 'SA');
    },
  );

  testWidgets(
    'activates a current-year licence from the 6-character activation code',
    (tester) async {
      await pumpScreen(tester);
      final expiryYear = DateTime.now().year;
      final fullKey = generatedKey(
        organizationCode: 'SA',
        expiryYear: expiryYear,
        licenceType: LicenseService.coreLicenceType,
      );
      final activationCode = LicenseService.activationCodeFromLicence(fullKey);

      await tester.enterText(
        inputByHint('Enter organisation name'),
        'Spring Academy',
      );
      await tester.enterText(
        inputByHint('Enter organisation code'),
        'sa',
      );
      await tester.pumpAndSettle();

      final firstBox = find.byKey(const Key('validation-box-0'));
      await tester.ensureVisible(firstBox);
      await tester.tap(firstBox, warnIfMissed: false);
      await tester.pump();
      tester.testTextInput.enterText(activationCode);
      await tester.pumpAndSettle();

      expect(find.text(fullKey), findsOneWidget);

      await tester.tap(find.text('Activate Licence'));
      await tester.pumpAndSettle();

      final snapshot = await LicenseService.getSnapshot();
      expect(snapshot.licenceCode, fullKey);
      expect(snapshot.organizationName, 'Spring Academy');
      expect(snapshot.organizationCode, 'SA');
    },
  );

  testWidgets('hides the activation form when a valid stored licence exists', (
    tester,
  ) async {
    final activationDate = DateTime(2026, 3, 11, 9, 30);
    final expiryYear = activationDate.year + 1;
    final coreKey = generatedKey(
      organizationCode: 'SA',
      expiryYear: expiryYear,
      licenceType: LicenseService.coreLicenceType,
    );

    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    await LicenseService.activate(
      'Spring Academy',
      'SA',
      coreKey,
      now: activationDate,
    );

    await pumpScreen(tester, resetPrefs: false, scrollToActivation: false);
    await tester.scrollUntilVisible(
      find.text('Licence Active'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Licence Active'), findsOneWidget);
    expect(find.text('Licence Reference'), findsOneWidget);
    expect(find.text('Licence ID'), findsNothing);
    expect(find.text('Licence Key'), findsNothing);
    expect(
      find.text(LicenseService.maskLicenceCodeForStatus(coreKey)),
      findsOneWidget,
    );
    expect(find.text(coreKey), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(inputByHint('Enter organisation name'), findsNothing);
    expect(inputByHint('Enter organisation code'), findsNothing);
  });

  testWidgets(
    'shows the activation form when an expired licence is stored',
    (tester) async {
      final activationDate = DateTime.now().subtract(
        const Duration(days: LicenseService.pilotTrialDurationDays + 5),
      );
      final expiryYear = fixedPilotExpiry(activationDate).year;
      final pilotKey = generatedKey(
        organizationCode: 'SA',
        expiryYear: expiryYear,
        licenceType: LicenseService.pilotLicenceType,
        now: activationDate,
      );

      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      await LicenseService.activate(
        'Spring Academy',
        'SA',
        pilotKey,
        now: activationDate,
      );

      await pumpScreen(tester, resetPrefs: false, scrollToActivation: false);
      await tester.scrollUntilVisible(
        find.text('Licence Expired'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Licence Expired'), findsOneWidget);
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
      expect(inputByHint('Enter organisation name'), findsOneWidget);
      expect(inputByHint('Enter organisation code'), findsOneWidget);
    },
  );

  testWidgets('displays Pilot as the stored licence tier in the status card', (
    tester,
  ) async {
    final activationDate = DateTime.now();
    final expiryYear = fixedPilotExpiry(activationDate).year;
    final pilotKey = generatedKey(
      organizationCode: 'SA',
      expiryYear: expiryYear,
      licenceType: LicenseService.pilotLicenceType,
      now: activationDate,
    );

    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    await LicenseService.activate(
      'Spring Academy',
      'SA',
      pilotKey,
      now: activationDate,
    );

    await pumpScreen(tester, resetPrefs: false, scrollToActivation: false);
    await tester.scrollUntilVisible(
      find.text('Licence Active'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Licence Active'), findsOneWidget);
    expect(find.text('Pilot'), findsAtLeastNWidgets(1));
    expect(
      find.text(LicenseService.maskLicenceCodeForStatus(pilotKey)),
      findsOneWidget,
    );
    expect(find.text(pilotKey), findsNothing);
    expect(
      find.text(LicenseService.displayActivationCodeFromLicence(pilotKey)),
      findsNothing,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows the corrected privacy notice closing sentence', (
    tester,
  ) async {
    await pumpScreen(tester, scrollToActivation: false);

    await tester.scrollUntilVisible(
      find.text('Privacy Notice'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Notice').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This application should only be used by authorised staff during examinations.',
      ),
      findsOneWidget,
    );
  });
}
