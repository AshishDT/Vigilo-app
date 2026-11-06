import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class FooterWidget extends StatelessWidget {
  final VoidCallback onOfficerTools;
  final VoidCallback onVibrate;
  final VoidCallback onArchive;
  final VoidCallback onBriefings;
  final bool isVibrateOn;
  final bool isArchiveMode;
  final bool? isDark;

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

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

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
              _FooterCell(
                dark: dark,
                icon: Icons.admin_panel_settings,
                label: 'Officer Tools',
                color: VigiloUiColors.blue(dark),
                onTap: onOfficerTools,
              ),
              _FooterCell(
                dark: dark,
                icon: Icons.vibration,
                label: 'Vibrate',
                color: isVibrateOn
                    ? VigiloUiColors.blue(dark)
                    : (dark ? Colors.grey : VigiloUiColors.textFaint(dark)),
                onTap: onVibrate,
              ),
              _FooterCell(
                dark: dark,
                icon: Icons.archive_outlined,
                label: 'Archive',
                color: isArchiveMode
                    ? VigiloUiColors.green(dark)
                    : VigiloUiColors.blue(dark),
                onTap: onArchive,
              ),
              _FooterCell(
                dark: dark,
                icon: Icons.description,
                label: 'Briefings',
                color: VigiloUiColors.blue(dark),
                onTap: onBriefings,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FooterCell extends StatefulWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _FooterCell({
    required this.dark,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_FooterCell> createState() => _FooterCellState();
}

class _FooterCellState extends State<_FooterCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reverse();
    });

  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 1.15,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _controller.forward(from: 0);
          widget.onTap?.call();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<Color?>(
                    duration: kThemeFadeDuration,
                    curve: kThemeFadeCurve,
                    tween: ColorTween(end: widget.color),
                    builder: (context, animatedColor, child) {
                      return Icon(widget.icon, color: animatedColor, size: 28);
                    },
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: kThemeFadeDuration,
                    curve: kThemeFadeCurve,
                    style: TextStyle(
                      color: VigiloUiColors.textSoft(widget.dark),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

