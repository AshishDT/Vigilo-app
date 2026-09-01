import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Opaque privacy shield widget displayed on app launch and background idle timeout.
/// Hides sensitive candidate and exam session data until native biometric/PIN authentication succeeds.
class SecurityPrivacyShield extends StatelessWidget {
  /// Creates a [SecurityPrivacyShield] instance.
  const SecurityPrivacyShield({
    super.key,
    required this.dark,
    required this.onToggleTheme,
    required this.onUnlockPressed,
    this.isAuthenticating = false,
  });

  /// Whether dark mode theme is currently active.
  final bool dark;

  /// Callback triggered when user toggles theme (light/dark).
  final VoidCallback onToggleTheme;

  /// Callback triggered when user taps the "Unlock App" button to invoke native authentication.
  final VoidCallback onUnlockPressed;

  /// Indicates whether native authentication prompt is actively in progress.
  final bool isAuthenticating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VigiloUiColors.bg(dark),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          InkWell(
            onTap: onToggleTheme,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VigiloUiColors.panel(dark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: VigiloUiColors.line(dark),
                  width: 1,
                ),
              ),
              child: Icon(
                dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                color: VigiloUiColors.textSoft(dark),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: VigiloUiColors.blue(
                            dark,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: VigiloUiColors.blue(
                              dark,
                            ).withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: VigiloUiColors.blue(dark),
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Vigilo ERC Locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VigiloUiColors.text(dark),
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Authentication required to access exam \nsessions and candidate data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VigiloUiColors.textSoft(dark),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VigiloUiColors.blue(dark),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isAuthenticating ? null : onUnlockPressed,
                      icon: isAuthenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.lock_open_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        isAuthenticating ? 'Authenticating...' : 'Unlock App',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
  }
}
