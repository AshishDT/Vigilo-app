import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class LicenseRequiredView extends StatelessWidget {
  const LicenseRequiredView({super.key, this.dark});

  /// Optional explicit dark mode flag to ensure immediate, synchronous theme switching
  /// without Flutter's ThemeData.lerp thresholding delay.
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? (Theme.of(context).brightness == Brightness.dark);
    final colors = _LicenseRequiredColors(context, isDark);
    final textTheme = Theme.of(context).textTheme;

    return _BlueprintGateScaffold(
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _BlueprintGatePanel(
                isDark: isDark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: kThemeFadeDuration,
                          curve: kThemeFadeCurve,
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.red.withValues(alpha: 0.35),
                            ),
                          ),
                          child: TweenAnimationBuilder<Color?>(
                            duration: kThemeFadeDuration,
                            curve: kThemeFadeCurve,
                            tween: ColorTween(end: colors.red),
                            builder: (_, iconColor, _) => Icon(
                              Icons.lock_outline_rounded,
                              color: iconColor,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: kThemeFadeDuration,
                            curve: kThemeFadeCurve,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFamily: textTheme.bodyMedium?.fontFamily,
                            ),
                            child: const Text('Licence Required'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AnimatedContainer(
                      duration: kThemeFadeDuration,
                      curve: kThemeFadeCurve,
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
                          AnimatedDefaultTextStyle(
                            duration: kThemeFadeDuration,
                            curve: kThemeFadeCurve,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: textTheme.bodyMedium?.fontFamily,
                            ),
                            child: const Text('No active licence is installed.'),
                          ),
                          const SizedBox(height: 10),
                          AnimatedDefaultTextStyle(
                            duration: kThemeFadeDuration,
                            curve: kThemeFadeCurve,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: textTheme.bodyMedium?.fontFamily,
                            ),
                            child: const Text(
                              'A valid Pilot, Core, or Pro licence is required to continue.',
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedDefaultTextStyle(
                            duration: kThemeFadeDuration,
                            curve: kThemeFadeCurve,
                            style: TextStyle(
                              color: colors.signalBlueSoft,
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: textTheme.bodyMedium?.fontFamily,
                            ),
                            child: const Text(
                              'Tap "Vigilo ERC" in the app bar to open the licence screen.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: kThemeFadeDuration,
                      curve: kThemeFadeCurve,
                      height: 1,
                      color: colors.lineSoft,
                    ),
                    const SizedBox(height: 12),
                    AnimatedDefaultTextStyle(
                      duration: kThemeFadeDuration,
                      curve: kThemeFadeCurve,
                      style: TextStyle(
                        color: colors.textSoft,
                        height: 1.5,
                        fontSize: 14,
                        fontFamily: textTheme.bodyMedium?.fontFamily,
                      ),
                      child: const Text(
                        'Exam creation and exam management are unavailable until a valid licence is activated.',
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
  final bool isDark;
  _LicenseRequiredColors(this.context, this.isDark);

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
    return child;
  }
}

class _BlueprintGatePanel extends StatelessWidget {
  const _BlueprintGatePanel({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = _LicenseRequiredColors(context, isDark);
    return AnimatedContainer(
      duration: kThemeFadeDuration,
      curve: kThemeFadeCurve,
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
