class ScheduleData {
  final String time;
  final String room;
  final List<String> invigilators;
  final String notes;

  ScheduleData({
    required this.time,
    required this.room,
    required this.invigilators,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'room': room,
    'notes': notes,
    'invigilators': invigilators
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(),
  };

  static List<String> _splitNames(String raw) {
    final parts = raw
        .replaceAll('\r', '\n')
        .split(RegExp(r'[\s,;]+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty);
    final ordered = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      if (seen.add(part)) {
        ordered.add(part);
      }
    }
    return ordered;
  }

  static List<String> _parseInvigilators(dynamic raw) {
    if (raw is String) {
      return _splitNames(raw);
    }
    if (raw is List) {
      final names = <String>[];
      for (final item in raw) {
        if (item == null) continue;
        if (item is String) {
          names.addAll(_splitNames(item));
          continue;
        }
        final text = item.toString().trim();
        if (text.isNotEmpty) {
          names.add(text);
        }
      }
      final ordered = <String>[];
      final seen = <String>{};
      for (final name in names) {
        if (seen.add(name)) {
          ordered.add(name);
        }
      }
      return ordered;
    }
    return const <String>[];
  }

  static ScheduleData fromJson(Map<String, dynamic> m) => ScheduleData(
    time: (m['time'] ?? '').toString(),
    room: (m['room'] ?? '').toString(),
    notes: (m['notes'] ?? '').toString(),
    invigilators: _parseInvigilators(m['invigilators']),
  );
}
