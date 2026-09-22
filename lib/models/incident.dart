class Incident {
  Incident(
    this.message, {
    this.eventType = "incident",
    this.incidentType = "",
    this.studentID = "",
    this.duration = "",
    this.detail = "",
    this.room = "",
    this.staffMember = "",
    this.action = "",
    this.updatedDuration = "",
    this.supervisionTime = "",
    this.actualStartTime = "",
    this.actualFinishTime = "",
    this.reason = "",
    this.candidateWarnedScriptMayNotBeAccepted = "",
    this.actionsTaken = "",
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final String message;
  final String eventType;
  final String incidentType;
  final DateTime time;
  final String studentID;
  final String duration;
  final String detail;
  final String room;
  final String staffMember;
  final String action;
  final String updatedDuration;
  final String supervisionTime;
  final String actualStartTime;
  final String actualFinishTime;
  final String reason;
  final String candidateWarnedScriptMayNotBeAccepted;
  final String actionsTaken;

  Map<String, dynamic> toJson() => {
    'message': message,
    'eventType': eventType,
    'incidentType': incidentType,
    'time': time.millisecondsSinceEpoch,
    'studentID': studentID,
    'duration': duration,
    'detail': detail,
    'room': room,
    'staffMember': staffMember,
    'action': action,
    'updatedDuration': updatedDuration,
    'supervisionTime': supervisionTime,
    'actualStartTime': actualStartTime,
    'actualFinishTime': actualFinishTime,
    'reason': reason,
    'candidateWarnedScriptMayNotBeAccepted':
        candidateWarnedScriptMayNotBeAccepted,
    'actionsTaken': actionsTaken,
  };

  static Incident fromJson(Map<String, dynamic> m) {
    final detail = (m['detail'] ?? "") as String;
    String supervisionTime = (m['supervisionTime'] ?? "") as String;
    String actualStartTime = (m['actualStartTime'] ??
        m['candidateActualStartTime'] ??
        "") as String;
    String actualFinishTime = (m['actualFinishTime'] ??
        m['candidateActualFinishTime'] ??
        "") as String;
    String reason = (m['reason'] ?? "") as String;
    String candidateWarnedScriptMayNotBeAccepted =
        (m['candidateWarnedScriptMayNotBeAccepted'] ??
            m['candidateWarned'] ??
            m['warningGiven'] ??
            "") as String;
    String actionsTaken = (m['actionsTaken'] ?? m['actions'] ?? "") as String;

    // Backward compatibility: extract from detail if individual keys are missing
    if (detail.isNotEmpty) {
      if (supervisionTime.isEmpty && detail.contains('Supervision time:')) {
        final match = RegExp(
          r'Supervision time:\s*([^.]+?)(?=\.\s*[A-Z]|\.?$)',
        ).firstMatch(detail);
        if (match != null) supervisionTime = match.group(1)?.trim() ?? '';
      }
      if (actualStartTime.isEmpty && detail.contains('Actual start:')) {
        final match = RegExp(
          r'Actual start:\s*([^.]+?)(?=\.\s*[A-Z]|\.?$)',
        ).firstMatch(detail);
        if (match != null) actualStartTime = match.group(1)?.trim() ?? '';
      }
      if (actualFinishTime.isEmpty && detail.contains('finish time:')) {
        final match = RegExp(
          r'(?:Candidate actual )?finish time:\s*([^.]+?)(?=\.\s*[A-Z]|\.?$)',
        ).firstMatch(detail);
        if (match != null) actualFinishTime = match.group(1)?.trim() ?? '';
      }
      if (reason.isEmpty && detail.contains('Reason:')) {
        final match = RegExp(
          r'Reason:\s*([^.]+?)(?=\.\s*[A-Z]|\.?$)',
        ).firstMatch(detail);
        if (match != null) reason = match.group(1)?.trim() ?? '';
      }
      if (candidateWarnedScriptMayNotBeAccepted.isEmpty &&
          detail.contains('Warned Script May Not Be Accepted?:')) {
        final match = RegExp(
          r'Warned Script May Not Be Accepted\?:\s*([^.]+?)(?=\.\s*[A-Z]|\.?$)',
        ).firstMatch(detail);
        if (match != null) {
          candidateWarnedScriptMayNotBeAccepted = match.group(1)?.trim() ?? '';
        }
      }
      if (actionsTaken.isEmpty && detail.contains('Actions:')) {
        final match = RegExp(r'Actions:\s*(.*)$').firstMatch(detail);
        if (match != null) actionsTaken = match.group(1)?.trim() ?? '';
      }
    }

    return Incident(
      m['message'],
      eventType: (m['eventType'] ?? "incident") as String,
      incidentType: (m['incidentType'] ?? "") as String,
      time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
      studentID: (m['studentID'] ?? "") as String,
      duration: (m['duration'] ?? "") as String,
      detail: detail,
      room: (m['room'] ?? "") as String,
      staffMember: (m['staffMember'] ?? "") as String,
      action: (m['action'] ?? "") as String,
      updatedDuration: (m['updatedDuration'] ?? "") as String,
      supervisionTime: supervisionTime,
      actualStartTime: actualStartTime,
      actualFinishTime: actualFinishTime,
      reason: reason,
      candidateWarnedScriptMayNotBeAccepted:
          candidateWarnedScriptMayNotBeAccepted,
      actionsTaken: actionsTaken,
    );
  }
}
