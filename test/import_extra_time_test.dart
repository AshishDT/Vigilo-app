import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';

ExamCardData recompute(ExamCardData c) {
  int toMin(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  String m2s(int m) {
    final h = (m ~/ 60) % 24;
    final mm = m % 60;
    return "${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}";
  }

  final startM = toMin(c.normalStart);
  final normM = toMin(c.normalDuration);
  final extraM = toMin(c.extraTime);
  final endM = startM + normM;
  final totalM = normM + extraM;
  final extraEndM = startM + totalM;

  return c.copyWith(
    start: c.normalStart,
    duration: c.normalDuration,
    end: m2s(endM),
    normalEnd: m2s(endM),
    totalDuration: m2s(totalM),
    extraEnd: m2s(extraEndM),
  );
}

void main() {
  test('test recompute logic for imported sessions', () {
    final card = ExamCardData(
      recordId: 'test_id',
      school: 'Test School',
      centreNumber: '12345',
      date: '30/07/2026',
      subject: 'Maths (AQA)',
      examLevel: 'GCSE',
      start: '09:00',
      duration: '01:30',
      end: '09:00',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '09:00',
      extraTime: '00:15',
      totalDuration: '00:00',
      extraEnd: '09:00',
      roomsSnapshot: 'Gym',
      notes: 'Test notes',
    );

    final recomputed = recompute(card);

    expect(recomputed.extraTime, '00:15');
    expect(recomputed.duration, '01:30');
    expect(recomputed.totalDuration, '01:45');
    expect(recomputed.end, '10:30');
    expect(recomputed.extraEnd, '10:45');
  });
}
