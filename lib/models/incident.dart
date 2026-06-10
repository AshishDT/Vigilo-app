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
  };

  static Incident fromJson(Map<String, dynamic> m) => Incident(
    m['message'],
    eventType: (m['eventType'] ?? "incident") as String,
    incidentType: (m['incidentType'] ?? "") as String,
    time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
    studentID: (m['studentID'] ?? "") as String,
    duration: (m['duration'] ?? "") as String,
    detail: (m['detail'] ?? "") as String,
    room: (m['room'] ?? "") as String,
    staffMember: (m['staffMember'] ?? "") as String,
    action: (m['action'] ?? "") as String,
    updatedDuration: (m['updatedDuration'] ?? "") as String,
  );
}
