import 'package:flutter/material.dart';

class LicenseRequiredView extends StatelessWidget {
  const LicenseRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    return _BlueprintGateScaffold(
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _BlueprintGatePanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _LicenseRequiredPalette.red.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _LicenseRequiredPalette.red.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: _LicenseRequiredPalette.red,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Licence Required',
                            style: TextStyle(
                              color: _LicenseRequiredPalette.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _LicenseRequiredPalette.panel2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _LicenseRequiredPalette.lineSoft,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active licence is installed.',
                            style: TextStyle(
                              color: _LicenseRequiredPalette.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'A valid Pilot, Core, or Pro licence is required to continue.',
                            style: TextStyle(
                              color: _LicenseRequiredPalette.textSoft,
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Tap "Vigilo ERC" in the app bar to open the licence screen.',
                            style: TextStyle(
                              color: _LicenseRequiredPalette.signalBlueSoft,
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: _LicenseRequiredPalette.lineSoft),
                    const SizedBox(height: 12),
                    const Text(
                      'Exam creation and exam management are unavailable until a valid licence is activated.',
                      style: TextStyle(
                        color: _LicenseRequiredPalette.textSoft,
                        height: 1.5,
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

class _LicenseRequiredPalette {
  static const Color bg = Color(0xFF081A2B);
  static const Color bg2 = Color(0xFF0B2135);
  static const Color panel = Color(0xFF10263D);
  static const Color panel2 = Color(0xFF16314D);
  static const Color line = Color(0xFF284867);
  static const Color lineSoft = Color(0xFF1B3853);

  static const Color signalBlueSoft = Color(0xFF8FD4FF);
  static const Color red = Color(0xFFE85D75);

  static const Color text = Color(0xFFF3F7FC);
  static const Color textSoft = Color(0xFFB6C7D8);
}

class _BlueprintGateScaffold extends StatelessWidget {
  const _BlueprintGateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_LicenseRequiredPalette.bg, _LicenseRequiredPalette.bg2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

class _BlueprintGatePanel extends StatelessWidget {
  const _BlueprintGatePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _LicenseRequiredPalette.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LicenseRequiredPalette.line),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}
