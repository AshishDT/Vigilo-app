import 'package:flutter/material.dart';

import '../../models/incident.dart';

bool _isDurationAdjustmentMessage(String message) {
  return message.startsWith('Normal Time Updated') ||
      message.startsWith('Extra time updated') ||
      message.startsWith('Extra Time Updated');
}

String _formatStudentID(String s) {
  s = s.trim();
  if (s.isEmpty) return s;
  if (s.contains('(') && s.contains(')')) return s;
  final parts = s.split(' ');
  if (parts.length > 1) {
    final last = parts.last;
    if (RegExp(r'^\d+$').hasMatch(last)) {
      return '${parts.sublist(0, parts.length - 1).join(' ')} ($last)';
    }
  }
  return s;
}

class LogsItemWidget extends StatelessWidget {
  final Incident incident;
  final bool isExpanded;
  final VoidCallback onTap;

  const LogsItemWidget({
    super.key,
    required this.incident,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        "${incident.time.hour.toString().padLeft(2, '0')}:${incident.time.minute.toString().padLeft(2, '0')}:${incident.time.second.toString().padLeft(2, '0')}";

    String message = incident.message;
    IconData icon = Icons.schedule;
    final isMalpracticeConcern =
        incident.message == 'Malpractice' ||
        incident.message == 'Suspected malpractice' ||
        incident.message == 'Malpractice concern' ||
        incident.message == 'Cheating concern';
    final isDurationAdjustment = _isDurationAdjustmentMessage(incident.message);

    if (incident.message == 'Toilet break') {
      final student = _formatStudentID(incident.studentID);
      final durationStr = incident.duration.isEmpty ? '' : '\nDuration:\n${incident.duration} min';
      message = 'Toilet Visit\nStudent: $student$durationStr';
      icon = Icons.wc;
    } else if (isMalpracticeConcern) {
      final student = _formatStudentID(incident.studentID);
      final displayMsg = incident.message == 'Suspected malpractice' 
          ? 'Malpractice' 
          : incident.message;
      message = '$displayMsg\nStudent: $student';
      icon = Icons.warning_amber;
    } else if (incident.message == 'Medical incident') {
      final student = _formatStudentID(incident.studentID);
      final actionStr = incident.action.isEmpty ? '' : '\nAction:\n${incident.action}';
      message = 'Medical Incident\nStudent: $student$actionStr';
      icon = Icons.medical_services;
    } else if (isDurationAdjustment && incident.updatedDuration.isNotEmpty) {
      message = '$message - ${incident.updatedDuration} min';
    } else if (incident.message == 'Invigilator list updated') {
      icon = Icons.group;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              trailing: Icon(icon),
              title: Text(message),
              leading: Text(
                time,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                  fontSize: 12,
                ),
              ),
            ),
            if (incident.message == 'Toilet break' && isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident.message),
                    const SizedBox(height: 4),
                    Text('Time: $time'),
                    const SizedBox(height: 4),
                    Text('Room: ${incident.room}'),
                    const SizedBox(height: 4),
                    Text('Student ID: ${incident.studentID}'),
                    const SizedBox(height: 4),
                    Text('Duration: ${incident.duration} minutes'),
                  ],
                ),
              ),
            if (isMalpracticeConcern && isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident.message),
                    const SizedBox(height: 4),
                    Text('Time: $time'),
                    const SizedBox(height: 4),
                    Text('Room: ${incident.room}'),
                    const SizedBox(height: 4),
                    Text('Student ID: ${incident.studentID}'),
                    const SizedBox(height: 4),
                    Text('Staff member: ${incident.staffMember}'),
                    const SizedBox(height: 4),
                    Text('Details: ${incident.detail}'),
                    const SizedBox(height: 4),
                    Text('Action taken: ${incident.action}'),
                  ],
                ),
              ),
            if (incident.message == 'Medical incident' && isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident.message),
                    const SizedBox(height: 4),
                    Text('Time: $time'),
                    const SizedBox(height: 4),
                    Text('Room: ${incident.room}'),
                    const SizedBox(height: 4),
                    Text('Student ID: ${incident.studentID}'),
                    const SizedBox(height: 4),
                    Text('Staff member: ${incident.staffMember}'),
                    const SizedBox(height: 4),
                    Text('Details: ${incident.detail}'),
                    const SizedBox(height: 4),
                    Text('Action taken: ${incident.action}'),
                  ],
                ),
              ),
            if (isDurationAdjustment && isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident.message),
                    const SizedBox(height: 4),
                    Text('Time: $time'),
                    if (incident.updatedDuration.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Updated Duration: ${incident.updatedDuration} minutes',
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text('Details: ${incident.detail}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
