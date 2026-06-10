import 'package:flutter/material.dart';

class TimingTile extends StatelessWidget {
  const TimingTile({
    super.key,
    required this.color,
    required this.label,
    required this.onTap,
    required this.disabled,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? Colors.grey : color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(0, 60), // uniform height
      ),
      onPressed: disabled ? null : onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
