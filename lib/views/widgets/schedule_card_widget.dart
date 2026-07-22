import 'package:flutter/material.dart';

import '../../models/schedule.dart';
import '../../utils/constants.dart';

class ScheduleCard extends StatelessWidget {
  final ScheduleData data;
  final VoidCallback onEdit;
  final bool isExamCompleted;

  const ScheduleCard({
    super.key,
    required this.data,
    required this.onEdit,
    this.isExamCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.schedule),
          title: Text(data.time),
          subtitle: Text(
            "Room: ${data.room}\n"
            "Invigilators: ${data.invigilators.join(', ')}\n"
            "Notes: ${data.notes}",
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.edit,
              color: isExamCompleted ? Colors.grey : VigiloUiColors.blue(!isLight),
            ),
            onPressed: onEdit,
          ),
        ),
      ),
    );
  }
}
