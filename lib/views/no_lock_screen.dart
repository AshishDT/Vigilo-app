import 'dart:async';
import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../utils/constants.dart';

/// Mandatory fallback screen displayed when a device has no lock (biometrics, PIN, pattern, or password) configured.
/// Explains security requirements and deep-links directly to the device's Settings > Security page.
class NoLockScreen extends StatefulWidget {
  /// Creates a [NoLockScreen] instance.
  const NoLockScreen({
    super.key,
    required this.dark,
    required this.onToggleTheme,
    required this.onLockDetected,
  });

  /// Whether dark mode theme is currently active.
  final bool dark;

  /// Callback triggered when user toggles theme (light/dark).
  final VoidCallback onToggleTheme;

  /// Callback triggered when a valid device lock is detected, admitting the user into the app.
  final VoidCallback onLockDetected;

  @override
  State<NoLockScreen> createState() => _NoLockScreenState();
}

class _NoLockScreenState extends State<NoLockScreen>
    with WidgetsBindingObserver {
  /// Whether a valid device lock has been detected.
  bool lockConfigured = false;

  /// Indicates whether a lock verification check is currently in progress.
  bool checking = false;

  bool get d => widget.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Automatically re-evaluate device lock state whenever the app resumes from background or settings
    if (state == AppLifecycleState.resumed) {
      _checkLockStatus();
    }
  }

  /// Queries [SecurityService] to verify if a device lock is configured.
  /// Automatically calls [onLockDetected] if a lock is present.
  Future<void> _checkLockStatus() async {
    if (!mounted) return;
    setState(() => checking = true);
    final configured = await SecurityService().isDeviceLockConfigured();
    if (!mounted) return;
    setState(() {
      checking = false;
      if (configured) {
        lockConfigured = true;
      }
    });
    if (configured) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) widget.onLockDetected();
    }
  }

  /// Deep-links to the native OS Security settings page and triggers a re-check upon returning.
  void _openSettings() async {
    setState(() => checking = true);
    await SecurityService().openSecuritySettings();
    _checkLockStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VigiloUiColors.bg(d),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          InkWell(
            onTap: widget.onToggleTheme,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VigiloUiColors.panel(d),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: VigiloUiColors.line(d),
                  width: 1,
                ),
              ),
              child: Icon(
                d ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                color: VigiloUiColors.textSoft(d),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: lockConfigured
                    ? _admitted()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: VigiloUiColors.amber(
                                  d,
                                ).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: VigiloUiColors.amber(
                                    d,
                                  ).withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                color: VigiloUiColors.amber(d),
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Device Lock Required',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: VigiloUiColors.text(d),
                              fontWeight: FontWeight.bold,
                              fontSize: 21,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Vigilo ERC requires a device lock (fingerprint, face, PIN, or pattern) to protect exam and candidate data. Set one up in your phone\'s security settings to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: VigiloUiColors.textSoft(d),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          GestureDetector(
                            onTap: checking ? null : _openSettings,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: VigiloUiColors.blue(d),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (checking)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.settings_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    checking
                                        ? 'Checking...'
                                        : 'Open Settings > Security',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No skip option - this can\'t be bypassed. The app re-checks and lets you in automatically once a lock is set.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: VigiloUiColors.textFaint(d),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
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
  }

  /// Temporary success view rendered when a valid device lock is detected before transitioning into the app.
  Widget _admitted() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          color: VigiloUiColors.blue(d),
          size: 56,
        ),
        const SizedBox(height: 20),
        Text(
          'Lock detected -- continuing to Vigilo ERC',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: VigiloUiColors.text(d),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Admitting user automatically...',
          textAlign: TextAlign.center,
          style: TextStyle(color: VigiloUiColors.textFaint(d), fontSize: 12),
        ),
      ],
    );
  }
}
