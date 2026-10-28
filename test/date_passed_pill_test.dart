import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';

void main() {
  test('isDatePassed returns true for past scheduled exams that have not started', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final dateStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

    final card = ExamCardData(
      recordId: 'past_test',
      school: 'Test Academy',
      centreNumber: '12345',
      date: dateStr,
      subject: 'Maths',
      start: '09:00',
      duration: '01:30',
      end: '10:30',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '10:30',
      extraTime: '00:15',
      totalDuration: '01:45',
      extraEnd: '10:45',
      epochStart: null,
    );

    expect(card.isDatePassed, isTrue);
  });

  test('isDatePassed returns false for future scheduled exams', () {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final dateStr = "${tomorrow.day.toString().padLeft(2, '0')}/${tomorrow.month.toString().padLeft(2, '0')}/${tomorrow.year}";

    final card = ExamCardData(
      recordId: 'future_test',
      school: 'Test Academy',
      centreNumber: '12345',
      date: dateStr,
      subject: 'Maths',
      start: '09:00',
      duration: '01:30',
      end: '10:30',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '10:30',
      extraTime: '00:15',
      totalDuration: '01:45',
      extraEnd: '10:45',
      epochStart: null,
    );

    expect(card.isDatePassed, isFalse);
  });

  test('isDatePassed returns false for past exams that have already started', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final dateStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

    final card = ExamCardData(
      recordId: 'started_test',
      school: 'Test Academy',
      centreNumber: '12345',
      date: dateStr,
      subject: 'Maths',
      start: '09:00',
      duration: '01:30',
      end: '10:30',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '10:30',
      extraTime: '00:15',
      totalDuration: '01:45',
      extraEnd: '10:45',
      running: true, // exam is actively running
    );

    expect(card.isDatePassed, isFalse);
  });

  test('isDatePassed returns false for reset exams with wasEverStarted=true', () {
    // Exam was started, then reset back to idle — wasEverStarted stays true.
    // Even if the date has passed it should remain accessible (not DATE PASSED).
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final dateStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

    final card = ExamCardData(
      recordId: 'reset_test',
      school: 'Test Academy',
      centreNumber: '12345',
      date: dateStr,
      subject: 'Maths',
      start: '09:00',
      duration: '01:30',
      end: '10:30',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '10:30',
      extraTime: '00:15',
      totalDuration: '01:45',
      extraEnd: '10:45',
      running: false,       // reset → no longer running
      isPaused: false,
      wasEverStarted: true, // persisted from before the reset
    );

    expect(card.isDatePassed, isFalse);
  });

  test('isDatePassed supports YYYY-MM-DD and DD-MM-YYYY formats', () {

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final dmyDash = "${yesterday.day.toString().padLeft(2, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.year}";
    final ymdDash = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    final card1 = ExamCardData(
      recordId: 'dmy_dash_test',
      school: 'Test Academy',
      centreNumber: '12345',
      date: dmyDash,
      subject: 'Maths',
      start: '09:00',
      duration: '01:30',
      end: '10:30',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '10:30',
      extraTime: '00:15',
      totalDuration: '01:45',
      extraEnd: '10:45',
      epochStart: null,
    );

    final card2 = ExamCardData(
      recordId: 'ymd_dash_test',
      school: 'Test Academy',
      centreNumber: '12345',
      date: ymdDash,
      subject: 'Maths',
      start: '09:00',
      duration: '01:30',
      end: '10:30',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '10:30',
      extraTime: '00:15',
      totalDuration: '01:45',
      extraEnd: '10:45',
      epochStart: null,
    );

    expect(card1.isDatePassed, isTrue);
    expect(card2.isDatePassed, isTrue);
  });

  test('isDatePassed supports verbal D MMM YYYY formats', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final monthsAbbr = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final verbalDate = "${yesterday.day} ${monthsAbbr[yesterday.month - 1]} ${yesterday.year}";

    final card = ExamCardData(
      recordId: 'verbal_test',
      school: 'Test Academy',
      centreNumber: '12345',
      date: verbalDate,
      subject: 'Maths',
      start: '09:00',
      duration: '01:30',
      end: '10:30',
      normalStart: '09:00',
      normalDuration: '01:30',
      normalEnd: '10:30',
      extraTime: '00:15',
      totalDuration: '01:45',
      extraEnd: '10:45',
      epochStart: null,
    );

    expect(card.isDatePassed, isTrue);
  });
}
