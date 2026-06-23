import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class LicenseRequiredView extends StatelessWidget {
  const LicenseRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _LicenseRequiredColors(context);
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
                            color: colors.red.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.red.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: colors.red,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Licence Required',
                            style: TextStyle(
                              color: colors.text,
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
                        color: colors.panel2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.lineSoft,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active licence is installed.',
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'A valid Pilot, Core, or Pro licence is required to continue.',
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tap "Vigilo ERC" in the app bar to open the licence screen.',
                            style: TextStyle(
                              color: colors.signalBlueSoft,
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: colors.lineSoft),
                    const SizedBox(height: 12),
                    Text(
                      'Exam creation and exam management are unavailable until a valid licence is activated.',
                      style: TextStyle(
                        color: colors.textSoft,
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

class _LicenseRequiredColors {
  final BuildContext context;
  _LicenseRequiredColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bg => VigiloUiColors.bg(isDark);
  Color get bg2 => VigiloUiColors.bg2(isDark);
  Color get panel => VigiloUiColors.panel(isDark);
  Color get panel2 => isDark ? const Color(0xFF16314D) : const Color(0xFFF1F5F9);
  Color get line => VigiloUiColors.line(isDark);
  Color get lineSoft => VigiloUiColors.lineSoft(isDark);

  Color get signalBlueSoft => VigiloUiColors.blueSoft(isDark);
  Color get red => isDark ? const Color(0xFFE85D75) : const Color(0xFFDC2626);

  Color get text => VigiloUiColors.text(isDark);
  Color get textSoft => VigiloUiColors.textSoft(isDark);
}

class _BlueprintGateScaffold extends StatelessWidget {
  const _BlueprintGateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _LicenseRequiredColors(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.bg, colors.bg2],
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
    final colors = _LicenseRequiredColors(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}
