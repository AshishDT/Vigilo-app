import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import 'action_widget.dart';

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
    super.key,
  });

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
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? kDarkCard
            : kLightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBlue.withValues(alpha: 0.9), width: 1),
        boxShadow: [
          BoxShadow(
            color: kBlue.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ActionWidget(
            icon: Icons.admin_panel_settings,
            label: "Officer Tools",
            onTap: widget.onOfficerTools,
          ),
          ActionWidget(
            icon: Icons.vibration,
            label: "Vibrate",
            onTap: widget.onVibrate,
            color: widget.isVibrateOn ? kBlue : Colors.grey,
          ),
          ScaleTransition(
            scale: _scale,
            child: ActionWidget(
              icon: Icons.archive_outlined,
              label: "Archive",
              onTap: () {
                widget.onArchive();
                if (!widget.isArchiveMode) _pulseController.forward();
              },
              color: widget.isArchiveMode ? kGreen : kBlue,
            ),
          ),
          ActionWidget(
            icon: Icons.description,
            label: "Briefings",
            onTap: widget.onBriefings,
            color: kBlue,
          ),
        ],
      ),
    );
  }
}
