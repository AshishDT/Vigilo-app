import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/schedule.dart';

void main() {
  group('ScheduleData invigilators preservation', () {
    test('preserves names with initials and periods', () {
      final input = 'B. Smith, Ba. Jones, Dr. Bob';
      final schedule = ScheduleData(
        time: '09:00 - 11:00',
        room: 'Hall A',
        invigilators: ScheduleData.fromJson({
          'time': '09:00 - 11:00',
          'room': 'Hall A',
          'notes': '',
          'invigilators': input,
        }).invigilators,
        notes: '',
      );

      expect(schedule.invigilators, equals(['B. Smith', 'Ba. Jones', 'Dr. Bob']));
    });

    test('does not re-split names containing dots on repeated json serialization/deserialization', () {
      final initial = ScheduleData(
        time: '09:00 - 11:00',
        room: 'Hall A',
        invigilators: ['B. Smith', 'Ba. Jones', 'C. D. Miller'],
        notes: '',
      );

      final json = initial.toJson();
      final restored = ScheduleData.fromJson(json);

      expect(restored.invigilators, equals(['B. Smith', 'Ba. Jones', 'C. D. Miller']));
    });

    test('supports newlines, semicolons, and commas as delimiters without splitting dots', () {
      final input = "B. Smith\nBa. Jones; Dr. Bob, Jane Doe";
      final parsed = ScheduleData.fromJson({
        'time': '09:00 - 11:00',
        'room': 'Hall A',
        'notes': '',
        'invigilators': input,
      });

      expect(parsed.invigilators, equals(['B. Smith', 'Ba. Jones', 'Dr. Bob', 'Jane Doe']));
    });

    test('preserves user-entered order without alphabetical sorting', () {
      // User types non-alphabetical names line by line (e.g. Lead invigilator first)
      const input = "James Bond\nDonald Duck\nMickey Mouse\nAllan Key";
      final parsed = ScheduleData.fromJson({
        'time': '09:00 - 11:00',
        'room': 'Hall A',
        'notes': '',
        'invigilators': input,
      });

      // Must strictly preserve typed order, never sorted alphabetically
      expect(
        parsed.invigilators,
        equals(['James Bond', 'Donald Duck', 'Mickey Mouse', 'Allan Key']),
      );

      // Comma-separated single line conversion
      final singleLine = parsed.invigilators.join(', ');
      expect(
        singleLine,
        equals('James Bond, Donald Duck, Mickey Mouse, Allan Key'),
      );

      // Deserialization from comma-separated string preserves the exact same order
      final reloaded = ScheduleData.fromJson({
        'time': '09:00 - 11:00',
        'room': 'Hall A',
        'notes': '',
        'invigilators': singleLine,
      });
      expect(
        reloaded.invigilators,
        equals(['James Bond', 'Donald Duck', 'Mickey Mouse', 'Allan Key']),
      );
    });
  });
}
