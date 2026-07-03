import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/enums/exam_phase.dart';
import 'package:vigilo/models/schedule.dart';

void main() {
  group('Invigilator Name Parsing Tests', () {
    test('Should parse comma-separated without space', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': 'Allan,Basil,Steve',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve']));
    });

    test('Should parse comma-separated with space', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': 'Allan, Basil, Steve',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve']));
    });

    test('Should parse newline-separated', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': 'Allan\nBasil\nSteve',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve']));
    });

    test('Should parse semicolon-separated', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': 'Allan;Basil;Steve',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve']));
    });

    test('Should parse pipe-separated', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': 'Allan|Basil|Steve',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve']));
    });

    test('Should parse dot-separated', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': 'Allan.Basil.Steve',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve']));
    });

    test('Should parse mixed separators and trim spaces', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': '  Allan ,  Basil ; Steve | Dave \n John ',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve', 'Dave', 'John']));
    });

    test('Should deduplicate identical names within the same exam', () {
      final schedule = ScheduleData.fromJson({
        'invigilators': 'Allan, Basil, Allan, Steve, Basil',
      });
      expect(schedule.invigilators, equals(['Allan', 'Basil', 'Steve']));
    });
  });

  group('Home Screen Invigilator Counting Logic (No Global Deduplication)', () {
    // Helper to simulate getUniqueInvigilators logic
    List<String> getUniqueInvigilators(ExamCardData s) {
      if (s.scheduleList != null && s.scheduleList!.isNotEmpty) {
        final names = s.scheduleList!
            .expand((p) => p.invigilators)
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return names;
      }
      if (s.invigilatorsSnapshot.trim().isNotEmpty) {
        final names = s.invigilatorsSnapshot
            .replaceAll('\r', '\n')
            .split(RegExp(r'[\n,;|.]+'))
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return names;
      }
      return const [];
    }

    int countAllInvigilators(List<ExamCardData> cards) {
      int total = 0;
      for (final s in cards) {
        if (s.phase != ExamPhase.finished) {
          total += getUniqueInvigilators(s).length;
        }
      }
      return total;
    }

    test('Should count invigilators on a single active exam', () {
      final card = ExamCardData(
        recordId: '1',
        school: 'School A',
        centreNumber: '12345',
        date: '03/07/2026',
        subject: 'Maths',
        start: '09:00',
        duration: '02:00',
        end: '11:00',
        normalStart: '09:00',
        normalDuration: '02:00',
        normalEnd: '11:00',
        extraTime: '00:15',
        totalDuration: '02:15',
        extraEnd: '11:15',
        phase: ExamPhase.normal,
        scheduleList: [
          ScheduleData(
            time: '09:00 - 11:00',
            room: 'Gym',
            invigilators: ['Allan', 'Basil', 'Steve'],
            notes: '',
          )
        ],
      );

      expect(countAllInvigilators([card]), equals(3));
    });

    test('Should sum unique invigilators across multiple active exams (no global cross-exam deduplication)', () {
      final exam1 = ExamCardData(
        recordId: '1',
        school: 'School A',
        centreNumber: '12345',
        date: '03/07/2026',
        subject: 'Maths',
        start: '09:00',
        duration: '02:00',
        end: '11:00',
        normalStart: '09:00',
        normalDuration: '02:00',
        normalEnd: '11:00',
        extraTime: '00:15',
        totalDuration: '02:15',
        extraEnd: '11:15',
        phase: ExamPhase.normal,
        scheduleList: [
          ScheduleData(
            time: '09:00 - 11:00',
            room: 'Gym',
            invigilators: ['Allan', 'Basil', 'Steve'],
            notes: '',
          )
        ],
      );

      final exam2 = ExamCardData(
        recordId: '2',
        school: 'School A',
        centreNumber: '12345',
        date: '03/07/2026',
        subject: 'English',
        start: '09:00',
        duration: '02:30',
        end: '11:30',
        normalStart: '09:00',
        normalDuration: '02:30',
        normalEnd: '11:30',
        extraTime: '00:15',
        totalDuration: '02:45',
        extraEnd: '11:45',
        phase: ExamPhase.normal,
        scheduleList: [
          ScheduleData(
            time: '09:00 - 11:30',
            room: 'Hall',
            invigilators: ['Allan', 'Basil', 'Dave', 'John', 'Mary', 'Jack'],
            notes: '',
          )
        ],
      );

      // Exam 1: 3 unique invigilators (Allan, Basil, Steve)
      // Exam 2: 6 unique invigilators (Allan, Basil, Dave, John, Mary, Jack)
      // Expected sum: 3 + 6 = 9.
      expect(countAllInvigilators([exam1, exam2]), equals(9));
    });

    test('Should ignore invigilators on finished exams', () {
      final activeExam = ExamCardData(
        recordId: '1',
        school: 'School A',
        centreNumber: '12345',
        date: '03/07/2026',
        subject: 'Maths',
        start: '09:00',
        duration: '02:00',
        end: '11:00',
        normalStart: '09:00',
        normalDuration: '02:00',
        normalEnd: '11:00',
        extraTime: '00:15',
        totalDuration: '02:15',
        extraEnd: '11:15',
        phase: ExamPhase.normal,
        scheduleList: [
          ScheduleData(
            time: '09:00 - 11:00',
            room: 'Gym',
            invigilators: ['Allan', 'Basil', 'Steve'],
            notes: '',
          )
        ],
      );

      final finishedExam = ExamCardData(
        recordId: '2',
        school: 'School A',
        centreNumber: '12345',
        date: '03/07/2026',
        subject: 'English',
        start: '09:00',
        duration: '02:30',
        end: '11:30',
        normalStart: '09:00',
        normalDuration: '02:30',
        normalEnd: '11:30',
        extraTime: '00:15',
        totalDuration: '02:45',
        extraEnd: '11:45',
        phase: ExamPhase.finished,
        scheduleList: [
          ScheduleData(
            time: '09:00 - 11:30',
            room: 'Hall',
            invigilators: ['Dave', 'John', 'Mary'],
            notes: '',
          )
        ],
      );

      expect(countAllInvigilators([activeExam, finishedExam]), equals(3));
    });
  });
}
