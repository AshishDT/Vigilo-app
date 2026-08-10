import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/services/import_service.dart';

void main() {
  group('ImportService Duration Normalization & Conversion Tests', () {
    test('normalizeDuration - valid formats', () {
      expect(ImportService.normalizeDuration('01:30'), '01:30');
      expect(ImportService.normalizeDuration('90'), '01:30');
      expect(ImportService.normalizeDuration('1.5'), '00:02'); // double tryParse mins -> 2 mins
      expect(ImportService.normalizeDuration(''), isNull);
      expect(ImportService.normalizeDuration(null), isNull);
    });

    test('normalizeDuration - negative formats', () {
      expect(ImportService.normalizeDuration('-01:00'), '-01:00');
      expect(ImportService.normalizeDuration('-60'), '-01:00');
      expect(ImportService.normalizeDuration('-1.5'), '-00:02');
    });

    test('durationToMinutes - conversion', () {
      expect(ImportService.durationToMinutes('01:30'), 90);
      expect(ImportService.durationToMinutes('00:00'), 0);
      expect(ImportService.durationToMinutes('-01:00'), -60);
      expect(ImportService.durationToMinutes('-00:30'), -30);
      expect(ImportService.durationToMinutes('00:-30'), -30);
    });
  });
}
