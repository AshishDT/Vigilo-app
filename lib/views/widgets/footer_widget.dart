import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class FooterWidget extends StatefulWidget {
  final VoidCallback onOfficerTools;
  final VoidCallback onVibrate;
  final VoidCallback onArchive;
  final VoidCallback onBriefings;
  final bool isVibrateOn;
  final bool isArchiveMode;

  const FooterWidget({
    required this.onOfficerTools,
    required this.onVibrate,
    required this.onArchive,
    required this.onBriefings,
    required this.isVibrateOn,
    required this.isArchiveMode,
    this.isDark,
    super.key,
  });

  final bool? isDark;

  @override
  State<FooterWidget> createState() => _FooterWidgetState();
}

class _FooterWidgetState extends State<FooterWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _pulseController.reverse();
      });

  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 1.15,
  ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    return AnimatedContainer(
      duration: kThemeFadeDuration,
      curve: kThemeFadeCurve,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: VigiloUiColors.panel(dark).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: VigiloUiColors.blue(dark).withValues(alpha: dark ? 0.30 : 0.26),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: VigiloUiColors.blue(dark).withValues(alpha: dark ? 0.07 : 0.10),
            blurRadius: dark ? 10 : 12,
            offset: Offset(0, dark ? 3 : 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.22 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _footerAction(
            dark,
            Icons.admin_panel_settings,
            'Officer Tools',
            color: VigiloUiColors.blue(dark),
            onTap: widget.onOfficerTools,
          ),
          _footerAction(
            dark,
            Icons.vibration,
            'Vibrate',
            color: widget.isVibrateOn
                ? VigiloUiColors.blue(dark)
                : (dark ? Colors.grey : VigiloUiColors.textFaint(dark)),
            onTap: widget.onVibrate,
          ),
          ScaleTransition(
            scale: _scale,
            child: _footerAction(
              dark,
              Icons.archive_outlined,
              'Archive',
              color: widget.isArchiveMode
                  ? VigiloUiColors.green(dark)
                  : VigiloUiColors.blue(dark),
              onTap: () {
                widget.onArchive();
                if (!widget.isArchiveMode) _pulseController.forward();
              },
            ),
          ),
          _footerAction(
            dark,
            Icons.description,
            'Briefings',
            color: VigiloUiColors.blue(dark),
            onTap: widget.onBriefings,
          ),
        ],
      ),
    );
  }

  Widget _footerAction(
    bool dark,
    IconData icon,
    String label, {
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<Color?>(
              duration: kThemeFadeDuration,
              curve: kThemeFadeCurve,
              tween: ColorTween(end: color),
              builder: (context, animatedColor, child) {
                return Icon(icon, color: animatedColor, size: 28);
              },
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: kThemeFadeDuration,
              curve: kThemeFadeCurve,
              style: TextStyle(
                color: VigiloUiColors.textSoft(dark),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

