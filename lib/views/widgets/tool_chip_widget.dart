import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class ToolChip extends StatelessWidget {
  const ToolChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isExamCompleted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isExamCompleted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isExamCompleted ? Colors.grey : VigiloUiColors.blue(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(0, 60),
      ),
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
