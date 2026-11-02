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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: kThemeFadeDuration,
          curve: kThemeFadeCurve,
          width: double.infinity,
          height: 0.75,
          color: VigiloUiColors.line(dark),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              _actionCell(
                dark,
                Icons.admin_panel_settings,
                'Officer Tools',
                color: VigiloUiColors.blue(dark),
                onTap: widget.onOfficerTools,
              ),
              _actionCell(
                dark,
                Icons.vibration,
                'Vibrate',
                color: widget.isVibrateOn
                    ? VigiloUiColors.blue(dark)
                    : (dark ? Colors.grey : VigiloUiColors.textFaint(dark)),
                onTap: widget.onVibrate,
              ),
              _actionCell(
                dark,
                Icons.archive_outlined,
                'Archive',
                color: widget.isArchiveMode
                    ? VigiloUiColors.green(dark)
                    : VigiloUiColors.blue(dark),
                pulse: true,
                onTap: () {
                  widget.onArchive();
                  if (!widget.isArchiveMode) _pulseController.forward();
                },
              ),
              _actionCell(
                dark,
                Icons.description,
                'Briefings',
                color: VigiloUiColors.blue(dark),
                onTap: widget.onBriefings,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _actionCell(
    bool dark,
    IconData icon,
    String label, {
    required Color color,
    bool pulse = false,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );

    return Expanded(
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Center(
            child: pulse
                ? ScaleTransition(scale: _scale, child: content)
                : content,
          ),
        ),
      ),
    );
  }
}

