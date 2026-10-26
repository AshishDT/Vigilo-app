import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/services/session_service.dart';

void main() {
  group('Home Screen Exam Session Sorting Tests', () {
    test('sorts by date, then time, then subject, then room using SessionService.compareExamCards', () {
      // 4 English Literature rooms and 1 Geography room sharing 03/08/2026 at 09:00
      final cardEngRoomA = ExamCardData(
        recordId: '1',
        school: 'Test School',
        date: '03/08/2026',
        subject: 'English Literature',
        start: '09:00',
        duration: '01:30',
        end: '10:30',
        normalStart: '09:00',
        normalDuration: '01:30',
        normalEnd: '10:30',
        extraTime: '00:00',
        totalDuration: '01:30',
        extraEnd: '10:30',
        roomsSnapshot: 'Room A',
      );

      final cardEngRoomC = ExamCardData(
        recordId: '2',
        school: 'Test School',
        date: '03/08/2026',
        subject: 'English Literature',
        start: '09:00',
        duration: '01:30',
        end: '10:30',
        normalStart: '09:00',
        normalDuration: '01:30',
        normalEnd: '10:30',
        extraTime: '00:00',
        totalDuration: '01:30',
        extraEnd: '10:30',
        roomsSnapshot: 'Room C',
      );

      final cardEngRoomD = ExamCardData(
        recordId: '3',
        school: 'Test School',
        date: '03/08/2026',
        subject: 'English Literature',
        start: '09:00',
        duration: '01:30',
        end: '10:30',
        normalStart: '09:00',
        normalDuration: '01:30',
        normalEnd: '10:30',
        extraTime: '00:00',
        totalDuration: '01:30',
        extraEnd: '10:30',
        roomsSnapshot: 'Room D',
      );

      final cardGeoRoomB = ExamCardData(
        recordId: '4',
        school: 'Test School',
        date: '03/08/2026',
        subject: 'Geography',
        start: '09:00',
        duration: '01:30',
        end: '10:30',
        normalStart: '09:00',
        normalDuration: '01:30',
        normalEnd: '10:30',
        extraTime: '00:00',
        totalDuration: '01:30',
        extraEnd: '10:30',
        roomsSnapshot: 'Room B',
      );

      final list = [cardEngRoomC, cardGeoRoomB, cardEngRoomA, cardEngRoomD];
      list.sort(SessionService.compareExamCards);

      expect(list.map((c) => '${c.subject} (${c.roomsSnapshot})').toList(), [
        'English Literature (Room A)',
        'English Literature (Room C)',
        'English Literature (Room D)',
        'Geography (Room B)',
      ]);
    });

    test('in-session edit preserves list position; restart sort repositions earlier exam to top', () {
      final exam0 = ExamCardData(
        recordId: '100',
        school: 'School',
        date: '12/10/2026',
        subject: 'Maths',
        start: '14:00',
        duration: '01:00',
        end: '15:00',
        normalStart: '14:00',
        normalDuration: '01:00',
        normalEnd: '15:00',
        extraTime: '00:00',
        totalDuration: '01:00',
        extraEnd: '15:00',
      );

      final exam1 = ExamCardData(
        recordId: '101',
        school: 'School',
        date: '12/10/2026',
        subject: 'Physics',
        start: '15:00',
        duration: '01:00',
        end: '16:00',
        normalStart: '15:00',
        normalDuration: '01:00',
        normalEnd: '16:00',
        extraTime: '00:00',
        totalDuration: '01:00',
        extraEnd: '16:00',
      );

      final exam2 = ExamCardData(
        recordId: '102',
        school: 'School',
        date: '12/10/2026',
        subject: 'Chemistry',
        start: '16:00',
        duration: '01:00',
        end: '17:00',
        normalStart: '16:00',
        normalDuration: '01:00',
        normalEnd: '17:00',
        extraTime: '00:00',
        totalDuration: '01:00',
        extraEnd: '17:00',
      );

      // Initial loaded list
      final inSessionList = [exam0, exam1, exam2];
      expect(inSessionList[2].subject, 'Chemistry');

      // Mid-session edit: User starts Chemistry early or edits start time to 10:30 AM
      final updatedExam2 = exam2.copyWith(normalStart: '10:30');
      inSessionList[2] = updatedExam2;

      // In-session stability: Without re-sort, Chemistry remains strictly at index 2 (under user's thumb)
      expect(inSessionList[0].subject, 'Maths');
      expect(inSessionList[1].subject, 'Physics');
      expect(inSessionList[2].subject, 'Chemistry');

      // On restart/reload: Full chronological re-sort runs
      final onRestartList = List<ExamCardData>.from(inSessionList);
      onRestartList.sort(SessionService.compareExamCards);

      // Chemistry (10:30) is now chronologically first on app launch/restart
      expect(onRestartList[0].subject, 'Chemistry');
      expect(onRestartList[1].subject, 'Maths');
      expect(onRestartList[2].subject, 'Physics');
    });
  });
}
