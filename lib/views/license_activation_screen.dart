import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/license_key_codec.dart';
import '../services/license_service.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() =>
      _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  static const String _privacyNoticeText =
      'Vigilo ERC stores exam data locally on the device and does not send it to any external server.\n\n'
      'The organisation remains responsible for the retention, export, archiving, and deletion of records in line with its own policies, JCQ guidance, and applicable data protection requirements.\n\n'
      'This application should only be used by authorised staff during examinations.';

  static const String _termsOfUseText =
      'Vigilo ERC is intended for use by authorised examination staff within an organisation or examination centre.\n\n'
      'Use of the application is subject to the Vigilo licence agreement and the organisation\'s own examination, data protection, and device management policies.\n\n'
      'The organisation is responsible for keeping local devices and any exported records secure.';

  static const String _aboutText =
      'Vigilo ERC is a digital exam room control system for exam officers and invigilators. '
      'It supports live timing, structured event logging, incident capture, and exportable records while remaining offline-first for core operation.';
  static const String _aboutLegalText =
      'Vigilo® is a registered trademark of Vigilo.\n'
      'Copyright © 2026 Vigilo. All rights reserved.';
  static const String _segmentedLicenceMessage =
      'Enter the organisation name, organisation code, and 6-character activation code issued by Vigilo.';

  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolNumberController = TextEditingController();
  late final List<TextEditingController> _validationControllers;
  late final List<FocusNode> _validationFocusNodes;

  LicenseSnapshot _snapshot = const LicenseSnapshot();
  bool _loading = true;
  String? _activationMessage;
  bool _activationError = false;
  String _appVersion = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _validationControllers = List<TextEditingController>.generate(
      LicenseKeyCodec.validationCodeLength,
      (_) => TextEditingController(),
    );
    _validationFocusNodes = List<FocusNode>.generate(
      LicenseKeyCodec.validationCodeLength,
      (_) => FocusNode(),
    );
    _load();
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _schoolNumberController.dispose();
    for (final controller in _validationControllers) {
      controller.dispose();
    }
    for (final focusNode in _validationFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final snapshot = await LicenseService.getSnapshot();
    if (!mounted) return;
    _displayState;
    final isExpired =
        snapshot.licenceCode != null &&
        snapshot.licenceCode!.isNotEmpty &&
        !snapshot.isLicensed();
    if (!isExpired) {
      _applySnapshotToForm(snapshot);
    }
    String version = '1.0.0';
    String build = '1';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
      build = packageInfo.buildNumber;
    } catch (_) {}
    setState(() {
      _snapshot = snapshot;
      _appVersion = version;
      _buildNumber = build;
      _loading = false;
    });
  }

  String get _validationBlock =>
      _validationControllers.map((controller) => controller.text).join();

  String get _organizationCodeInput =>
      LicenseService.sanitizeOrganizationCode(_schoolNumberController.text);

  ResolvedLicenseKey? get _resolvedPreviewKey {
    if (_organizationCodeInput.length < 2 ||
        _validationBlock.length != LicenseKeyCodec.validationCodeLength) {
      return null;
    }
    return LicenseService.resolveActivationCodeForOrganizationCode(
      organizationCode: _organizationCodeInput,
      activationCode: _validationBlock,
      now: DateTime.now(),
    );
  }

  int get _derivedLicenceYear =>
      _resolvedPreviewKey?.expiryYear ?? LicenseService.nextLicenceYear();

  String get _displayActivationCodePreview {
    if (_validationBlock.isEmpty) {
      return '--- ---';
    }
    final rawValue = _validationBlock.padRight(
      LicenseKeyCodec.validationCodeLength,
      '_',
    );
    return '${rawValue.substring(0, 3)}-${rawValue.substring(3)}';
  }

  bool get _canActivate =>
      _schoolNameController.text.trim().isNotEmpty &&
      _schoolNumberController.text.trim().isNotEmpty &&
      _validationBlock.length == LicenseKeyCodec.validationCodeLength;

  String get _licencePreviewValue {
    if (_displayState == _LicenceDisplayState.active &&
        _hasStoredLicence &&
        _validationBlock.isEmpty) {
      return _snapshot.licenceCode!;
    }
    final resolved = _resolvedPreviewKey;
    final organizationCode = _organizationCodeInput.isEmpty
        ? 'ORG'
        : _organizationCodeInput;
    final tierMarker = resolved?.tierMarker ?? 'XX';
    final expiryYear = (resolved?.expiryYear ?? _derivedLicenceYear).toString();
    final validationCode = _validationBlock.isEmpty
        ? List.filled(LicenseKeyCodec.validationCodeLength, '_').join()
        : _validationBlock.padRight(LicenseKeyCodec.validationCodeLength, '_');
    return '${LicenseService.productIdentifier}-$tierMarker-$organizationCode-$expiryYear-$validationCode';
  }

  void _applySnapshotToForm(LicenseSnapshot snapshot) {
    _setControllerText(_schoolNameController, snapshot.organizationName ?? '');
    _setControllerText(
      _schoolNumberController,
      snapshot.organizationCode ?? '',
    );
    _clearValidationBlock();
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _clearValidationBlock() {
    for (final controller in _validationControllers) {
      controller.clear();
    }
  }

  void _clearActivationFeedback() {
    _activationMessage = null;
    _activationError = false;
  }

  void _applyValidationBlock(String rawValue) {
    final normalizedEntry = LicenseService.sanitizeLicenceEntry(rawValue);
    final parts = normalizedEntry.split('-');
    final sanitizedValue =
        parts.length >= 4 && parts[0] == 'VIGILO' && parts[1] == 'ERC'
        ? LicenseKeyCodec.sanitizeValidationCode(parts.last)
        : LicenseKeyCodec.sanitizeValidationCode(rawValue);

    final clipped =
        sanitizedValue.length <= LicenseKeyCodec.validationCodeLength
        ? sanitizedValue
        : sanitizedValue.substring(0, LicenseKeyCodec.validationCodeLength);

    for (var i = 0; i < LicenseKeyCodec.validationCodeLength; i++) {
      _setControllerText(
        _validationControllers[i],
        i < clipped.length ? clipped[i] : '',
      );
    }

    final nextIndex = clipped.length >= LicenseKeyCodec.validationCodeLength
        ? LicenseKeyCodec.validationCodeLength - 1
        : clipped.length.clamp(0, LicenseKeyCodec.validationCodeLength - 1);
    _validationFocusNodes[nextIndex].requestFocus();
    _clearActivationFeedback();
    setState(() {});
  }

  void _handleInputChanged(String _) {
    _clearActivationFeedback();
    setState(() {});
  }

  void _handleOrganizationCodeChanged(String value) {
    final sanitized = LicenseService.sanitizeOrganizationCode(value);
    if (_schoolNumberController.text != sanitized) {
      _setControllerText(_schoolNumberController, sanitized);
    }
    _clearActivationFeedback();
    setState(() {});
  }

  void _handleValidationChanged(int index, String value) {
    if (value.length > 1) {
      _applyValidationBlock(value);
      return;
    }

    final sanitized = LicenseKeyCodec.sanitizeValidationCode(value);
    final character = sanitized.isEmpty ? '' : sanitized[sanitized.length - 1];
    if (_validationControllers[index].text != character) {
      _setControllerText(_validationControllers[index], character);
    }

    if (character.isNotEmpty &&
        index < LicenseKeyCodec.validationCodeLength - 1) {
      _validationFocusNodes[index + 1].requestFocus();
    }

    _clearActivationFeedback();
    setState(() {});
  }

  KeyEventResult _handleValidationKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }

    if (_validationControllers[index].text.isEmpty && index > 0) {
      _setControllerText(_validationControllers[index - 1], '');
      _validationFocusNodes[index - 1].requestFocus();
      _clearActivationFeedback();
      setState(() {});
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _activateLicence() async {
    final organizationName = _schoolNameController.text.trim();
    final organizationCode = _schoolNumberController.text.trim();
    final validationBlock = _validationBlock;

    if (organizationName.isEmpty ||
        organizationCode.isEmpty ||
        validationBlock.length != LicenseKeyCodec.validationCodeLength) {
      setState(() {
        _activationError = true;
        _activationMessage = _segmentedLicenceMessage;
      });
      return;
    }

    try {
      final snapshot = await LicenseService.activateFromActivationCode(
        organizationName,
        organizationCode,
        validationBlock,
        now: DateTime.now(),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _clearValidationBlock();
      setState(() {
        _snapshot = snapshot;
        _activationError = false;
        _activationMessage = 'Licence successfully activated.';
      });
    } on FormatException catch (error) {
      setState(() {
        _activationError = true;
        _activationMessage = error.message;
      });
    } on StateError catch (error) {
      setState(() {
        _activationError = true;
        _activationMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _activationError = true;
        _activationMessage = 'Unable to activate licence right now.';
      });
    }
  }

  Future<void> _reportIssue() async {
    final uri = Uri(scheme: 'mailto', path: 'support@vigiloapp.co.uk');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted || launched) return;
    } catch (_) {
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No email app is available on this device.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showInfo(String title) async {
    var content = '';

    if (title == 'Licence Agreement') {
      try {
        content = await rootBundle.loadString('assets/LICENSE');
      } catch (_) {
        content = 'Could not load licence agreement.';
      }
    } else if (title == 'Privacy Notice') {
      content = _privacyNoticeText;
    } else if (title == 'Terms of Use') {
      content = _termsOfUseText;
    }

    if (!mounted) return;
    final paragraphs = _dialogParagraphs(content);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < paragraphs.length; index++) ...[
                Text(paragraphs[index], style: const TextStyle(height: 1.6)),
                if (index < paragraphs.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<String> _dialogParagraphs(String content) {
    return content
        .split(RegExp(r'\r?\n+'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
  }

  _LicenceDisplayState get _displayState {
    final now = DateTime.now();
    if (_snapshot.isLicensed(now: now)) {
      return _LicenceDisplayState.active;
    }
    if (_hasStoredLicence) {
      return _LicenceDisplayState.expired;
    }
    return _LicenceDisplayState.required;
  }

  bool get _hasStoredLicence =>
      _snapshot.licenceCode != null && _snapshot.licenceCode!.isNotEmpty;

  bool get _isPilotLicence =>
      LicenseService.isPilotLicenceType(_snapshot.licenceType);

  bool get _isPilotExpired =>
      _displayState == _LicenceDisplayState.expired && _isPilotLicence;

  bool get _isLicenceExpired => _displayState == _LicenceDisplayState.expired;

  String get _statusText {
    switch (_displayState) {
      case _LicenceDisplayState.active:
        return 'Licence Active';
      case _LicenceDisplayState.expired:
        return 'Licence Expired';
      case _LicenceDisplayState.required:
        return 'Licence Required';
    }
  }

  String get _statusSupportText {
    switch (_displayState) {
      case _LicenceDisplayState.active:
        return 'This device is authorised to operate under the stored Vigilo licence.';
      case _LicenceDisplayState.expired:
        if (_isPilotExpired) {
          return 'The stored Pilot licence has expired. Enter a new Pilot, Core, or Pro licence to continue using Vigilo ERC.';
        }
        return 'The stored Pilot licence has expired. Enter a new Pilot, Core or Pro licence below to continue using Vigilo ERC.';
      case _LicenceDisplayState.required:
        return 'Activate a Pilot, Core, or Pro licence to continue using Vigilo ERC.';
    }
  }

  String? get _statusLabelText {
    switch (_displayState) {
      case _LicenceDisplayState.active:
        return 'Licence Verified';
      case _LicenceDisplayState.expired:
        return 'Action Required';
      case _LicenceDisplayState.required:
        return null;
    }
  }

  String get _statusBannerText {
    switch (_displayState) {
      case _LicenceDisplayState.active:
        return 'Licence successfully activated.';
      case _LicenceDisplayState.expired:
        return 'Enter a new licence to continue using the app.';
      case _LicenceDisplayState.required:
        return 'No active licence is currently stored on this device.';
    }
  }

  Color get _statusColor {
    switch (_displayState) {
      case _LicenceDisplayState.active:
        return _VigiloPalette.green;
      case _LicenceDisplayState.expired:
      // return _VigiloPalette.red;
      case _LicenceDisplayState.required:
        return _VigiloPalette.amber;
    }
  }

  IconData get _statusIcon {
    switch (_displayState) {
      case _LicenceDisplayState.active:
        return Icons.verified;
      case _LicenceDisplayState.expired:
        return Icons.warning_amber_rounded;
      case _LicenceDisplayState.required:
        return Icons.lock_outline_rounded;
    }
  }

  String get _organizationNameValue => _snapshot.organizationName ?? '--';

  String get _organizationCodeValue => _snapshot.organizationCode ?? '--';

  String get _licenceTypeValue {
    switch (_displayState) {
      case _LicenceDisplayState.active:
      case _LicenceDisplayState.expired:
        return _snapshot.licenceType ?? LicenseService.organizationLicenceType;
      case _LicenceDisplayState.required:
        return 'Not activated';
    }
  }

  String get _licenceReferenceValue {
    if (_hasStoredLicence) {
      return LicenseService.maskLicenceCodeForStatus(_snapshot.licenceCode!);
    }
    return '--';
  }

  String get _issuedByValue => LicenseService.issuerName;

  String get _validUntilValue {
    if (_snapshot.expiryDate == null) {
      return '--';
    }
    return _formatDate(_snapshot.expiryDate!);
  }

  String get _devicesValue => LicenseService.deviceAllowance;

  String get _usersValue => LicenseService.userAllowance;

  String get _platformLabel {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  Widget _buildActivationFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _VigiloPalette.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _VigiloPalette.line),
      ),
      child: Text(
        _activationMessage!,
        style: TextStyle(
          color: _activationError ? _VigiloPalette.red : _VigiloPalette.green,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildValidationInputs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const boxHeight = 64.0;
        const maxBoxWidth = 56.0;
        final gap = constraints.maxWidth < 360 ? 6.0 : 8.0;
        final dashWidth = constraints.maxWidth < 360 ? 14.0 : 18.0;
        final rawBoxWidth =
            (constraints.maxWidth - (gap * 6) - dashWidth) /
            LicenseKeyCodec.validationCodeLength;
        final boxWidth = rawBoxWidth.clamp(42.0, maxBoxWidth);
        final rowWidth =
            (boxWidth * LicenseKeyCodec.validationCodeLength) +
            (gap * 6) +
            dashWidth;
        final children = <Widget>[];

        for (
          var index = 0;
          index < LicenseKeyCodec.validationCodeLength;
          index++
        ) {
          children.add(
            SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: Focus(
                onKeyEvent: (node, event) =>
                    _handleValidationKeyEvent(index, event),
                child: TextField(
                  key: Key('validation-box-$index'),
                  controller: _validationControllers[index],
                  focusNode: _validationFocusNodes[index],
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction:
                      index == LicenseKeyCodec.validationCodeLength - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(index == 0 ? 32 : 1),
                  ],
                  style: const TextStyle(
                    color: _VigiloPalette.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: _VigiloPalette.panel2,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _VigiloPalette.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _VigiloPalette.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _VigiloPalette.signalBlue,
                        width: 1.4,
                      ),
                    ),
                  ),
                  onChanged: (value) => _handleValidationChanged(index, value),
                  onSubmitted: index == LicenseKeyCodec.validationCodeLength - 1
                      ? (_) => _activateLicence()
                      : null,
                ),
              ),
            ),
          );

          if (index < LicenseKeyCodec.validationCodeLength - 1) {
            children.add(SizedBox(width: gap));
          }

          if (index == 2) {
            children.add(
              SizedBox(
                width: dashWidth,
                child: const Text(
                  '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _VigiloPalette.signalBlueSoft,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
            children.add(SizedBox(width: gap));
          }
        }

        return Center(
          child: SizedBox(
            width: rowWidth,
            child: Row(children: children),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: _GradientScaffold(
          child: SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: _VigiloPalette.signalBlue,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: _GradientScaffold(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: _VigiloPalette.text,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vigilo ERC',
                            style: TextStyle(
                              color: _VigiloPalette.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Licence & Information',
                            style: TextStyle(
                              color: _VigiloPalette.textSoft,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  children: [
                    _SectionCard(
                      title: 'Licence Types',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LicenceTypePanel(
                            title: LicenseService.pilotLicenceType,
                            subtitle: const Text(
                              '30-day evaluation licence for schools testing Vigilo ERC.',
                              style: TextStyle(
                                color: _VigiloPalette.textSoft,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            features: LicenseService.pilotFeatures,
                          ),
                          const SizedBox(height: 16),
                          _LicenceTypePanel(
                            title: LicenseService.coreLicenceType,
                            subtitle: const Text(
                              'Full operational licence for schools running examinations.',
                              style: TextStyle(
                                color: _VigiloPalette.textSoft,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            features: LicenseService.coreFeatures,
                          ),
                          const SizedBox(height: 16),
                          _LicenceTypePanel(
                            title: LicenseService.proLicenceType,
                            subtitle: const Text.rich(
                              TextSpan(
                                text:
                                    'Includes everything in Core plus additional coordination features ',
                                children: [
                                  TextSpan(
                                    text: '(coming soon)',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  TextSpan(text: '.'),
                                ],
                              ),
                              style: TextStyle(
                                color: _VigiloPalette.textSoft,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            features: LicenseService.proFeatureAdditions,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Licence Status',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: _statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: _statusColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Icon(
                                  _statusIcon,
                                  color: _statusColor,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _statusText,
                                        style: TextStyle(
                                          color: _statusColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (_statusLabelText != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _statusLabelText!,
                                          style: const TextStyle(
                                            color: _VigiloPalette.text,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        _statusSupportText,
                                        style: const TextStyle(
                                          color: _VigiloPalette.textSoft,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: _VigiloPalette.panel2,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _VigiloPalette.line),
                            ),
                            child: Text(
                              _hasStoredLicence && _activationMessage != null
                                  ? _activationMessage!
                                  : _statusBannerText,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (_displayState !=
                              _LicenceDisplayState.expired) ...[
                            const SizedBox(height: 22),
                            _InfoRow(
                              'Organisation Name',
                              _organizationNameValue,
                            ),
                            _InfoRow(
                              'Organisation Code',
                              _organizationCodeValue,
                            ),
                            _InfoRow('Licence Tier', _licenceTypeValue),
                            _InfoRow(
                              'Licence Reference',
                              _licenceReferenceValue,
                            ),
                            _InfoRow('Issued By', _issuedByValue),
                            _InfoRow('Valid Until', _validUntilValue),
                            _InfoRow('Devices', _devicesValue),
                            _InfoRow('Users', _usersValue),
                          ],
                        ],
                      ),
                    ),
                    if (!_hasStoredLicence || _isLicenceExpired) ...[
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Activate Licence',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLicenceExpired
                                  ? 'Your previous licence has expired. Enter your organisation details and a new activation code below.'
                                  : 'Enter your organisation details and the 6-character activation code issued by Vigilo.',
                              style: TextStyle(
                                color: _VigiloPalette.textSoft,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Codes are displayed as XXX-XXX for readability.',
                              style: TextStyle(
                                color: _VigiloPalette.textFaint,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Organisation Name'),
                            const SizedBox(height: 6),
                            _InputField(
                              controller: _schoolNameController,
                              hintText: 'Enter organisation name',
                              textInputAction: TextInputAction.next,
                              onChanged: _handleInputChanged,
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel('Organisation Code'),
                            const SizedBox(height: 6),
                            _InputField(
                              controller: _schoolNumberController,
                              hintText: 'Enter organisation code',
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  LicenseKeyCodec.organizationCodeMaxLength,
                                ),
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              onChanged: _handleOrganizationCodeChanged,
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel('Activation Code'),
                            const SizedBox(height: 8),
                            _buildValidationInputs(),
                            const SizedBox(height: 16),
                            _ReadOnlyField(
                              label: 'Activation Code Preview',
                              value: _displayActivationCodePreview,
                            ),
                            const SizedBox(height: 12),
                            _ReadOnlyField(
                              label: 'Generated Licence Key Preview',
                              value: _licencePreviewValue,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _VigiloPalette.signalBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: _canActivate
                                    ? _activateLicence
                                    : null,
                                child: const Text(
                                  'Activate Licence',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (_activationMessage != null) ...[
                              const SizedBox(height: 12),
                              _buildActivationFeedback(),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Application Information',
                      child: Column(
                        children: [
                          _StaticInfoRow('App Version', _appVersion),
                          _StaticInfoRow('Build', _buildNumber),
                          _StaticInfoRow('Platform', _platformLabel),
                          const _StaticInfoRow('Operation Mode', 'Offline-first'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Data & Privacy',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All exam session data is stored locally on this device.\nData is not transmitted to any external server.',
                            style: TextStyle(
                              color: _VigiloPalette.textSoft,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Data & Export',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exam session data is stored locally on this device.',
                            style: TextStyle(
                              color: _VigiloPalette.textSoft,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 12),
                          _StaticInfoRow('Data Storage', 'Local device only'),
                          _StaticInfoRow(
                            'Export Responsibility',
                            'User must export required records',
                          ),
                          _StaticInfoRow(
                            'Recommended Action',
                            'Export logs after each exam session',
                          ),
                          _StaticInfoRow(
                            'Licence Changes',
                            'Data remains after upgrade, but access may be affected if the licence expires or the app is removed',
                          ),
                          _StaticInfoRow(
                            'Important',
                            'Export logs required for reporting or compliance before licence expiry or device changes',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Legal',
                      child: Column(
                        children: [
                          _ActionButton(
                            label: 'Licence Agreement',
                            onPressed: () => _showInfo('Licence Agreement'),
                          ),
                          const SizedBox(height: 10),
                          _ActionButton(
                            label: 'Privacy Notice',
                            onPressed: () => _showInfo('Privacy Notice'),
                          ),
                          const SizedBox(height: 10),
                          _ActionButton(
                            label: 'Terms of Use',
                            onPressed: () => _showInfo('Terms of Use'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Support',
                      child: Column(
                        children: [
                          const _StaticInfoRow(
                            'Support Email',
                            'support@vigiloapp.co.uk',
                            singleLine: true,
                            scaleDownValue: true,
                          ),
                          const SizedBox(height: 10),
                          _ActionButton(
                            label: 'Report Issue',
                            onPressed: _reportIssue,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionCard(
                      title: 'About Vigilo ERC',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _aboutText,
                            style: TextStyle(
                              color: _VigiloPalette.textSoft,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 18),
                          Center(
                            child: Text(
                              _aboutLegalText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _VigiloPalette.textFaint,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    final month = months[date.month - 1];
    return '${date.day.toString().padLeft(2, '0')} $month ${date.year}';
  }
}

enum _LicenceDisplayState { required, active, expired }

class _VigiloPalette {
  static const Color bg = Color(0xFF081A2B);
  static const Color bg2 = Color(0xFF0B2135);
  static const Color panel = Color(0xFF10263D);
  static const Color panel2 = Color(0xFF16314D);
  static const Color line = Color(0xFF284867);
  static const Color lineSoft = Color(0xFF1B3853);

  static const Color signalBlue = Color(0xFF2EA7FF);
  static const Color signalBlueSoft = Color(0xFF8FD4FF);

  static const Color green = Color(0xFF2EAD66);
  static const Color amber = Color(0xFFFFC857);
  static const Color red = Color(0xFFE85D75);

  static const Color text = Color(0xFFF3F7FC);
  static const Color textSoft = Color(0xFFB6C7D8);
  static const Color textFaint = Color(0xFF7F9AB5);
}

class _GradientScaffold extends StatelessWidget {
  const _GradientScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_VigiloPalette.bg, _VigiloPalette.bg2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _BlueprintPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _VigiloPalette.signalBlueSoft,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: _VigiloPalette.lineSoft.withValues(alpha: 0.8),
            thickness: 2.0,
            height: 1,
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _BlueprintPanel extends StatelessWidget {
  const _BlueprintPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _VigiloPalette.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _VigiloPalette.line),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
    this.label,
    this.value, {
    this.singleLine = false,
    this.scaleDownValue = false,
  });

  final String label;
  final String value;
  final bool singleLine;
  final bool scaleDownValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(
                color: _VigiloPalette.textSoft,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: scaleDownValue
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      softWrap: false,
                      style: const TextStyle(
                        color: _VigiloPalette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.45,
                      ),
                    ),
                  )
                : Text(
                    value,
                    softWrap: !singleLine,
                    overflow: singleLine ? TextOverflow.fade : null,
                    style: const TextStyle(
                      color: _VigiloPalette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.45,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LicenceTypePanel extends StatelessWidget {
  const _LicenceTypePanel({
    required this.title,
    required this.features,
    this.subtitle,
  });

  final String title;
  final Widget? subtitle;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _VigiloPalette.panel2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _VigiloPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _VigiloPalette.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[const SizedBox(height: 10), subtitle!],
          const SizedBox(height: 14),
          ...features.map(_FeatureBullet.new),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 8,
              color: _VigiloPalette.signalBlueSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _VigiloPalette.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticInfoRow extends StatelessWidget {
  const _StaticInfoRow(
    this.label,
    this.value, {
    this.singleLine = false,
    this.scaleDownValue = false,
  });

  final String label;
  final String value;
  final bool singleLine;
  final bool scaleDownValue;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      label,
      value,
      singleLine: singleLine,
      scaleDownValue: scaleDownValue,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _VigiloPalette.textSoft,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _VigiloPalette.panel2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _VigiloPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _VigiloPalette.textSoft,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _VigiloPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _VigiloPalette.text,
          side: const BorderSide(color: _VigiloPalette.line),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hintText,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(
        color: _VigiloPalette.text,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: _VigiloPalette.textFaint,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: _VigiloPalette.panel2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _VigiloPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _VigiloPalette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _VigiloPalette.signalBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
