import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';

void main() {
  group('Home Screen Exam Session Sorting Tests', () {
    test('sorts by date, then time, then subject, then room', () {
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

      list.sort((a, b) {
        // Date comparison
        DateTime? da, db;
        try {
          final pa = a.date.split('/');
          da = DateTime(int.parse(pa[2]), int.parse(pa[1]), int.parse(pa[0]));
        } catch (_) {}
        try {
          final pb = b.date.split('/');
          db = DateTime(int.parse(pb[2]), int.parse(pb[1]), int.parse(pb[0]));
        } catch (_) {}

        if (da != null && db != null) {
          final cmp = da.compareTo(db);
          if (cmp != 0) return cmp;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }

        // Start time comparison
        final sa = a.normalStart;
        final sb = b.normalStart;
        final cmpTime = sa.compareTo(sb);
        if (cmpTime != 0) return cmpTime;

        // Subject alphabetically
        final subA = a.subject;
        final subB = b.subject;
        final cmpSub = subA.toLowerCase().compareTo(subB.toLowerCase());
        if (cmpSub != 0) return cmpSub;

        // Room alphabetically
        final ra = a.roomsSnapshot;
        final rb = b.roomsSnapshot;
        return ra.toLowerCase().compareTo(rb.toLowerCase());
      });

      expect(list.map((c) => '${c.subject} (${c.roomsSnapshot})').toList(), [
        'English Literature (Room A)',
        'English Literature (Room C)',
        'English Literature (Room D)',
        'Geography (Room B)',
      ]);
    });
  });
}
