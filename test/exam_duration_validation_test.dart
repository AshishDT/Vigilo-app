import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/enums/exam_phase.dart';
import 'package:vigilo/models/exam_card_data.dart';

// Simulated validation logic matching home_screen.dart
String? validateNormalDurationUpdate(ExamCardData c, int newNormalSec) {
  int elapsedSec = (c.progress * c.totalSeconds).round();
  if (c.phase == ExamPhase.normal && newNormalSec < elapsedSec) {
    return "Cannot reduce duration below elapsed time.";
  } else if (c.phase == ExamPhase.extra && newNormalSec + c.extraSeconds < elapsedSec) {
    return "Cannot reduce total time below elapsed time.";
  }
  return null; // Valid
}

String? validateExtraTimeUpdate(ExamCardData c, int newExtraSec) {
  int elapsedSec = (c.progress * c.totalSeconds).round();
  if (c.phase == ExamPhase.extra && c.normalSeconds + newExtraSec < elapsedSec) {
    return "Cannot reduce total time below elapsed time.";
  }
  return null; // Valid
}

void main() {
  group('Exam Duration Validation Tests', () {
    
    setUp(() {
      print('\n========================================');
    });

    test('Normal Phase: Reduce normal time but keeping it above elapsed time -> Success', () {
      print('TEST 1: Normal Phase - Valid Reduction');
      final c = ExamCardData(
        school: '', date: '', subject: '', start: '', duration: '', end: '', normalStart: '', normalEnd: '', totalDuration: '', extraEnd: '', extraTime: '00:00',
        phase: ExamPhase.normal,
        normalDuration: "01:00", // 3600s
        progress: 10 / 60, // 10 mins elapsed
      );
      
      int newNormalSec = 30 * 60; // 30 mins
      final error = validateNormalDurationUpdate(c, newNormalSec);
      
      if (error == null) {
        print('SUCCESS: The change was accepted because 30m > 10m elapsed.');
      } else {
        print('FAILURE: $error');
      }
      expect(error, isNull);
    });

    test('Normal Phase: Reduce normal time below elapsed time -> Failure', () {
      print('TEST 2: Normal Phase - Invalid Reduction');
      final c = ExamCardData(
        school: '', date: '', subject: '', start: '', duration: '', end: '', normalStart: '', normalEnd: '', totalDuration: '', extraEnd: '', extraTime: '00:00',
        phase: ExamPhase.normal,
        normalDuration: "01:00", // 3600s
        progress: 45 / 60, // 45 mins elapsed
      );
      
      int newNormalSec = 30 * 60; // 30 mins
      final error = validateNormalDurationUpdate(c, newNormalSec);
      
      if (error == null) {
        print('SUCCESS: The change was accepted incorrectly.');
      } else {
        print('FAILURE (Expected): The change was rejected -> $error');
        print('EXPLANATION: We cannot set normal duration to 30m because 45m has already elapsed!');
      }
      expect(error, isNotNull);
    });

    test('Extra Phase: Reduce normal time safely -> Success', () {
      print('TEST 3: Extra Phase - Valid Normal Time Reduction');
      final c = ExamCardData(
        school: '', date: '', subject: '', start: '', duration: '', end: '', normalStart: '', normalEnd: '', totalDuration: '', extraEnd: '', 
        phase: ExamPhase.extra,
        normalDuration: "01:00", // 3600s
        extraTime: "00:30", // 1800s
        progress: 75 / 90, // 75 mins elapsed
      );
      
      int newNormalSec = 50 * 60; // 50 mins
      final error = validateNormalDurationUpdate(c, newNormalSec);
      
      if (error == null) {
        print('SUCCESS: The change was accepted because new total time (80m) > elapsed time (75m).');
      } else {
        print('FAILURE: $error');
      }
      expect(error, isNull);
    });

    test('Extra Phase: Reduce extra time below elapsed extra time -> Failure', () {
      print('TEST 4: Extra Phase - Invalid Extra Time Reduction');
      final c = ExamCardData(
        school: '', date: '', subject: '', start: '', duration: '', end: '', normalStart: '', normalEnd: '', totalDuration: '', extraEnd: '', 
        phase: ExamPhase.extra,
        normalDuration: "01:00",
        extraTime: "00:30",
        progress: 75 / 90,
      );
      
      int newExtraSec = 10 * 60; // 10 mins
      final error = validateExtraTimeUpdate(c, newExtraSec);
      
      if (error == null) {
        print('SUCCESS: The change was accepted incorrectly.');
      } else {
        print('FAILURE (Expected): The change was rejected -> $error');
        print('EXPLANATION: We cannot set extra time to 10m because 15m of extra time has already elapsed (total 75m > 70m).');
      }
      expect(error, isNotNull);
    });

  });
}
