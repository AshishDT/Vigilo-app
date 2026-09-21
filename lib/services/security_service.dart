import 'dart:async';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:app_settings/app_settings.dart';
import 'package:url_launcher/url_launcher.dart';

/// Singleton service managing application security, device lock verification,
/// biometric/PIN authentication, and background idle timeout tracking.
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Configured idle timeout duration after which app lock is enforced upon background resume.
  /// Production threshold: `Duration(minutes: 15)`.
  static const Duration idleTimeout = Duration(minutes: 15);

  DateTime? _lastPausedTime;

  /// Flag indicating whether the native OS biometric/PIN prompt is actively being presented.
  bool isAuthenticating = false;

  /// Records the timestamp when the app enters background or inactive lifecycle states.
  /// Preserves the initial pause timestamp and ignores lifecycle changes during active authentication.
  void recordPause() {
    if (isAuthenticating) return;
    _lastPausedTime ??= DateTime.now();
  }

  /// Clears recorded pause time when the app is active or successfully authenticated.
  void clearPause() {
    _lastPausedTime = null;
  }

  /// Evaluates whether the time elapsed since the app went into the background has exceeded [idleTimeout].
  bool hasIdleTimedOut() {
    if (_lastPausedTime == null) return false;
    final elapsed = DateTime.now().difference(_lastPausedTime!);
    return elapsed >= idleTimeout;
  }

  /// Verifies whether the device has a lock configured (biometrics, PIN, pattern, or password).
  /// Returns `true` if device security is configured, `false` otherwise.
  Future<bool> isDeviceLockConfigured() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();

      if (!isSupported) {
        return false;
      }

      if (canCheck || available.isNotEmpty) {
        return true;
      }

      return isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Triggers the native OS biometric/PIN prompt using [LocalAuthentication].
  /// Allows OS automatic fallback to device PIN/pattern/password if biometrics fail or are unconfigured.
  /// Returns `true` if authentication succeeds, `false` if cancelled or failed.
  Future<bool> authenticate() async {
    if (isAuthenticating) return false;
    isAuthenticating = true;
    try {
      final authenticated = await _auth.authenticate(
        localizedReason:
            'Authentication required to access exam sessions and candidate data.',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows fallback to device PIN/pattern/password
          useErrorDialogs: true,
        ),
      );
      return authenticated;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.passcodeNotSet ||
          e.code == auth_error.notEnrolled) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      isAuthenticating = false;
    }
  }

  /// Deep-links directly to the device's Settings > Security page to configure a device lock.
  Future<void> openSecuritySettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.security);
    } catch (_) {
      try {
        final Uri settingsUri = Uri.parse('app-settings:');
        if (await canLaunchUrl(settingsUri)) {
          await launchUrl(settingsUri);
        }
      } catch (_) {}
    }
  }
}
