import 'package:flutter/material.dart';

import '../../models/incident.dart';

bool _isDurationAdjustmentMessage(String message) {
  final msg = message.trim().toLowerCase();
  return msg.startsWith('normal time updated') ||
      msg.startsWith('extra time updated') ||
      msg.startsWith('normal time increased') ||
      msg.startsWith('normal time reduced') ||
      msg.startsWith('extra time increased') ||
      msg.startsWith('extra time reduced');
}

String _formatMinutesDescription(int minutes) {
  final absMinutes = minutes.abs();
  if (absMinutes == 0) return '0 minutes';
  final hours = absMinutes ~/ 60;
  final remainingMinutes = absMinutes % 60;

  String hoursStr = '';
  if (hours > 0) {
    hoursStr = '$hours ${hours == 1 ? "hour" : "hours"}';
  }

  String minsStr = '';
  if (remainingMinutes > 0) {
    minsStr = '$remainingMinutes ${remainingMinutes == 1 ? "minute" : "minutes"}';
  }

  if (hoursStr.isNotEmpty && minsStr.isNotEmpty) {
    return '$hoursStr and $minsStr';
  } else if (hoursStr.isNotEmpty) {
    return hoursStr;
  } else {
    return minsStr;
  }
}

String _formatDurationWording(String message) {
  final normalMatch = RegExp(
    r'Normal\s+Time\s+Updated\s*\((?:.*\s*,\s*)?([+-]?\d+)m\)',
    caseSensitive: false,
  ).firstMatch(message);
  if (normalMatch != null) {
    final diff = int.tryParse(normalMatch.group(1) ?? '0') ?? 0;
    final durationText = _formatMinutesDescription(diff);
    if (diff >= 0) {
      return 'Normal Time increased by $durationText';
    } else {
      return 'Normal Time reduced by $durationText';
    }
  }
  final extraMatch = RegExp(
    r'Extra\s+Time\s+updated\s*\((?:.*\s*,\s*)?([+-]?\d+)m\)',
    caseSensitive: false,
  ).firstMatch(message);
  if (extraMatch != null) {
    final diff = int.tryParse(extraMatch.group(1) ?? '0') ?? 0;
    final durationText = _formatMinutesDescription(diff);
    if (diff >= 0) {
      return 'Extra Time increased by $durationText';
    } else {
      return 'Extra Time reduced by $durationText';
    }
  }
  return message;
}

class _CandidateInfo {
  final List<String> list;
  final bool isMultiple;
  final String joined;
  final String label;
  final String idLabel;

  const _CandidateInfo({
    required this.list,
    required this.isMultiple,
    required this.joined,
    required this.label,
    required this.idLabel,
  });
}

_CandidateInfo _formatCandidates(String s) {
  s = s.trim();
  if (s.isEmpty) {
    return const _CandidateInfo(
      list: [],
      isMultiple: false,
      joined: '',
      label: 'Student',
      idLabel: 'Student ID',
    );
  }
  final lines = s
      .split(RegExp(r'[\r\n]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  List<String> result;
  if (lines.length > 1) {
    result = lines;
  } else if (lines.isNotEmpty && lines.first.contains(',')) {
    result = lines.first
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  } else {
    result = lines;
  }

  final isMulti = result.length > 1;
  return _CandidateInfo(
    list: result,
    isMultiple: isMulti,
    joined: result.join(', '),
    label: isMulti ? 'Students' : 'Student',
    idLabel: isMulti ? 'Students' : 'Student ID',
  );
}

String _formatStudentID(String s) {
  return _formatCandidates(s).joined;
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

    String message = _formatDurationWording(incident.message);
    IconData icon = Icons.schedule;
    final isMalpracticeConcern =
        message == 'Malpractice' ||
        message == 'Suspected malpractice' ||
        message == 'Malpractice concern' ||
        message == 'Cheating concern';
    final isDurationAdjustment = _isDurationAdjustmentMessage(message);

    if (message == 'Toilet break') {
      final cand = _formatCandidates(incident.studentID);
      final durationStr = incident.duration.isEmpty ? '' : '\nDuration:\n${incident.duration} min';
      message = 'Toilet Visit\n${cand.label}: ${cand.joined}$durationStr';
      icon = Icons.wc;
    } else if (isMalpracticeConcern) {
      final cand = _formatCandidates(incident.studentID);
      final displayMsg = message == 'Suspected malpractice' 
          ? 'Malpractice' 
          : message;
      message = '$displayMsg\n${cand.label}: ${cand.joined}';
      icon = Icons.warning_amber;
    } else if (message == 'Medical incident') {
      final cand = _formatCandidates(incident.studentID);
      final actionStr = incident.action.isEmpty ? '' : '\nAction:\n${incident.action}';
      message = 'Medical Incident\n${cand.label}: ${cand.joined}$actionStr';
      icon = Icons.medical_services;
    } else if (isDurationAdjustment && incident.updatedDuration.isNotEmpty) {
      message = '$message - ${incident.updatedDuration} min';
    } else if (message == 'Invigilator list updated') {
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
                    Text(
                      '${_formatCandidates(incident.studentID).idLabel}: ${_formatCandidates(incident.studentID).joined}',
                    ),
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
                    Text(
                      '${_formatCandidates(incident.studentID).idLabel}: ${_formatCandidates(incident.studentID).joined}',
                    ),
                    const SizedBox(height: 4),
                    Text('Invigilator(s): ${incident.staffMember}'),
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
                    Text(
                      '${_formatCandidates(incident.studentID).idLabel}: ${_formatCandidates(incident.studentID).joined}',
                    ),
                    const SizedBox(height: 4),
                    Text('Invigilator(s): ${incident.staffMember}'),
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
