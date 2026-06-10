import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class ActionWidget extends StatelessWidget {
  const ActionWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(icon, size: 28, color: color ?? kBlue),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: t.bodySmall?.copyWith(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
