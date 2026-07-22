import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../utils/app_config.dart';
import '../utils/notifications.dart';
import '../services/license_key_codec.dart';
import '../services/license_service.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() =>
      _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  static const String _privacyNoticeText =
      'Vigilo ERC stores exam data locally on the device and does not transmit it to any external server.\n\n'
      'The organisation is responsible for the retention, export, archiving, and deletion of records in accordance with its own policies, relevant examination regulations (such as JCQ where applicable), and applicable data protection requirements.\n\n'
      'This application should only be used by authorised staff during examinations.';

  static const String _termsOfUseText =
      'Vigilo ERC is intended for use by authorised examination staff within an organisation or examination centre.\n\n'
      'Use of the application is subject to the Vigilo licence agreement and the organisation’s own examination, data protection, and device management policies.\n\n'
      'The organisation is responsible for ensuring that local devices and any exported records are kept secure.';

  static const String _aboutText =
      'Vigilo ERC is a digital exam room control system for exam officers and invigilators. '
      'It supports live timing, structured event logging, incident capture, and exportable records while remaining offline-first for core operation.';
  static const String _aboutLegalText =
      'Copyright © 2026 Vigilo\u00A0Platforms\u00A0Ltd. All rights reserved. Vigilo® is a registered trademark of Vigilo\u00A0Platforms\u00A0Ltd.';
  static const String _segmentedLicenceMessage =
      'Enter the organisation name, organisation code, and 6-character activation code issued by Vigilo.';

  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolNumberController = TextEditingController();
  late final FocusNode _schoolNameFocus = FocusNode();
  late final FocusNode _schoolNumberFocus = FocusNode();
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
    _schoolNameFocus.dispose();
    _schoolNumberFocus.dispose();
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
        _activationMessage = 'Licence activated successfully.';
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

    NotificationService.show(
      context,
      title: "Error",
      subtitle: 'No email app is available on this device',
      icon: Icons.error_outline_rounded,
      type: NotificationType.error,
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
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (dialogContext) {
        final media = MediaQuery.of(context);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: media.size.height * 0.82,
                    ),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VigiloUiColors.panel(isDark),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: VigiloUiColors.line(isDark)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ──────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            left: 8,
                            right: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: VigiloUiColors.blue(
                                    isDark,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: VigiloUiColors.blue(
                                      isDark,
                                    ).withValues(alpha: 0.70),
                                    width: .7,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.description_outlined,
                                  color: VigiloUiColors.blue(isDark),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: VigiloUiColors.text(isDark),
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Inline close button
                              Tooltip(
                                message: 'Close',
                                child: InkWell(
                                  onTap: () =>
                                      Navigator.of(dialogContext).pop(),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: VigiloUiColors.panel3(isDark),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: VigiloUiColors.lineSoft(isDark),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 24,
                                      color: VigiloUiColors.textSoft(isDark),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ── Scrollable body ──────────────────────────────
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < paragraphs.length; i++) ...[
                                  Text(
                                    paragraphs[i],
                                    style: TextStyle(
                                      color: VigiloUiColors.textSoft(isDark),
                                      fontSize: 15,
                                      height: 1.6,
                                    ),
                                  ),
                                  if (i < paragraphs.length - 1)
                                    const SizedBox(height: 14),
                                ],
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        return 'Licence activated successfully.';
      case _LicenceDisplayState.expired:
        return 'Enter a new licence to continue using the app.';
      case _LicenceDisplayState.required:
        return 'No active licence is currently stored on this device.';
    }
  }

  Color get _statusColor {
    switch (_displayState) {
      case _LicenceDisplayState.active:
        return VigiloUiColors.green(isDark);
      case _LicenceDisplayState.expired:
      // return VigiloUiColors.red(isDark);
      case _LicenceDisplayState.required:
        return VigiloUiColors.amber(isDark);
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

  Widget _buildActivationFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel3(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VigiloUiColors.line(isDark)),
      ),
      child: Text(
        _activationMessage!,
        style: TextStyle(
          color: _activationError
              ? VigiloUiColors.red(isDark)
              : VigiloUiColors.green(isDark),
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
                  style: TextStyle(
                    color: VigiloUiColors.text(isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: VigiloUiColors.panel3(isDark),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: VigiloUiColors.line(isDark),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: VigiloUiColors.line(isDark),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: VigiloUiColors.blue(isDark),
                        width: 1.4,
                      ),
                    ),
                  ),
                  onChanged: (value) => _handleValidationChanged(index, value),
                  onSubmitted: (_) {
                    if (index == LicenseKeyCodec.validationCodeLength - 1) {
                      _activateLicence();
                    } else {
                      _validationFocusNodes[index + 1].requestFocus();
                    }
                  },
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
                child: Text(
                  '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VigiloUiColors.blueSoft(isDark),
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
      return Scaffold(
        body: _GradientScaffold(
          child: SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: VigiloUiColors.blue(isDark),
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
                      color: VigiloUiColors.text(isDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vigilo ERC',
                            style: TextStyle(
                              color: VigiloUiColors.text(isDark),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Licence & Information',
                            style: TextStyle(
                              color: VigiloUiColors.textSoft(isDark),
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
                      title: 'Licence Type',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LicenceTypePanel(
                            title: LicenseService.pilotLicenceType,
                            subtitle: Text(
                              '30-day evaluation licence for organisation testing Vigilo ERC.',
                              style: TextStyle(
                                color: VigiloUiColors.textSoft(isDark),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            features: LicenseService.pilotFeatures,
                          ),
                          const SizedBox(height: 16),
                          _LicenceTypePanel(
                            title: LicenseService.coreLicenceType,
                            subtitle: Text(
                              'Full operational licence for organisation running examinations.',
                              style: TextStyle(
                                color: VigiloUiColors.textSoft(isDark),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            features: LicenseService.coreFeatures,
                          ),
                          const SizedBox(height: 16),
                          _LicenceTypePanel(
                            title: 'Pro',
                            subtitle: Text(
                              'Includes everything in Core plus additional coordination features.\n(Pro features will be introduced in Version 1.1)',
                              style: TextStyle(
                                color: VigiloUiColors.textSoft(isDark),
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
                                          style: TextStyle(
                                            color: VigiloUiColors.text(isDark),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        _statusSupportText,
                                        style: TextStyle(
                                          color: VigiloUiColors.textSoft(
                                            isDark,
                                          ),
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
                              color: VigiloUiColors.panel3(isDark),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: VigiloUiColors.line(isDark),
                              ),
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
                            _InfoRow('Users', _usersValue, paddingBottom: 0),
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
                                color: VigiloUiColors.textSoft(isDark),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Codes are displayed as XXX-XXX for readability.',
                              style: TextStyle(
                                color: VigiloUiColors.textFaint(isDark),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('Organisation Name'),
                            const SizedBox(height: 6),
                            _InputField(
                              controller: _schoolNameController,
                              focusNode: _schoolNameFocus,
                              hintText: 'Enter organisation name',
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                _schoolNumberFocus.requestFocus();
                              },
                              onChanged: _handleInputChanged,
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel('Organisation Code'),
                            const SizedBox(height: 6),
                            _InputField(
                              controller: _schoolNumberController,
                              focusNode: _schoolNumberFocus,
                              hintText: 'Enter organisation code',
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                if (_validationFocusNodes.isNotEmpty) {
                                  _validationFocusNodes[0].requestFocus();
                                }
                              },
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
                                  backgroundColor: VigiloUiColors.blue(isDark),
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
                      title: 'App Information',
                      child: Column(
                        children: [
                          _StaticInfoRow('App Version', _appVersion),
                          _StaticInfoRow('Build', _buildNumber),
                          const _StaticInfoRow(
                            'Release Date',
                            AppConfig.releaseDate,
                          ),
                          const _StaticInfoRow(
                            'Storage',
                            'Local Device',
                            paddingBottom: 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Data & Privacy',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All exam session data is stored locally on this device. Data is not transmitted to any external server.',
                            style: TextStyle(
                              color: VigiloUiColors.textSoft(isDark),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Data & Export',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exam session data is stored locally on this device.',
                            style: TextStyle(
                              color: VigiloUiColors.textSoft(isDark),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _StaticInfoRow(
                            'Data Storage',
                            'Local device only',
                          ),
                          const _StaticInfoRow(
                            'Export Responsibility',
                            'User must export required records',
                          ),
                          const _StaticInfoRow(
                            'Recommended Action',
                            'Export logs after each exam session',
                          ),
                          const _StaticInfoRow(
                            'Licence Changes',
                            'Data remains after upgrade, but access may be affected if the licence expires or the app is removed',
                          ),
                          const _StaticInfoRow(
                            'Important',
                            'Export logs required for reporting or compliance before licence expiry or device changes',
                            paddingBottom: 0,
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
                    _SectionCard(
                      title: 'About Vigilo ERC',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _aboutText,
                            style: TextStyle(
                              color: VigiloUiColors.textSoft(isDark),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              _aboutLegalText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: VigiloUiColors.textFaint(isDark),
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

class _GradientScaffold extends StatelessWidget {
  const _GradientScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [VigiloUiColors.bg(isDark), VigiloUiColors.bg2(isDark)],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _BlueprintPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: VigiloUiColors.blueSoft(isDark),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: VigiloUiColors.lineSoft(isDark).withValues(alpha: 0.8),
            thickness: 1.0,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel(isDark).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: VigiloUiColors.line(isDark)),
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
    this.paddingBottom = 14.0,
  });

  final String label;
  final String value;
  final bool singleLine;
  final bool scaleDownValue;
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: paddingBottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                color: VigiloUiColors.textSoft(isDark),
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
                      style: TextStyle(
                        color: VigiloUiColors.text(isDark),
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
                    style: TextStyle(
                      color: VigiloUiColors.text(isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VigiloUiColors.line(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: VigiloUiColors.text(isDark),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[const SizedBox(height: 10), subtitle!],
          const SizedBox(height: 14),
          ...List.generate(features.length, (index) {
            return _FeatureBullet(
              features[index],
              paddingBottom: index == features.length - 1 ? 0 : 10.0,
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet(this.label, {this.paddingBottom = 10.0});

  final String label;
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: paddingBottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 8,
              color: VigiloUiColors.blueSoft(isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: VigiloUiColors.text(isDark),
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
    this.paddingBottom = 14.0,
  });

  final String label;
  final String value;
  final bool singleLine;
  final bool scaleDownValue;
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      label,
      value,
      singleLine: singleLine,
      scaleDownValue: scaleDownValue,
      paddingBottom: paddingBottom,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: VigiloUiColors.textSoft(isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel3(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VigiloUiColors.line(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: VigiloUiColors.textSoft(isDark),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: VigiloUiColors.text(isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: VigiloUiColors.text(isDark),
          side: BorderSide(color: VigiloUiColors.line(isDark)),
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
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(
        color: VigiloUiColors.text(isDark),
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: VigiloUiColors.textFaint(isDark),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: VigiloUiColors.panel3(isDark),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: VigiloUiColors.line(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: VigiloUiColors.line(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: VigiloUiColors.blue(isDark),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
