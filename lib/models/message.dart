class Message {
  Message(this.message, {this.isMe = true, DateTime? time})
    : time = time ?? DateTime.now();
  final String message;
  final DateTime time;
  final bool isMe;

  Map<String, dynamic> toJson() => {
    'message': message,
    'time': time.millisecondsSinceEpoch,
    'isMe': isMe,
  };

  static Message fromJson(Map<String, dynamic> m) => Message(
    m['message'],
    isMe: (m['isMe'] ?? true) as bool,
    time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
  );
}
