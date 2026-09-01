import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService Tests', () {
    test('hasIdleTimedOut checks 30-second timeout correctly', () async {
      final service = SecurityService();
      service.clearPause();
      expect(service.hasIdleTimedOut(), isFalse);

      // Record pause right now -> should not be timed out
      service.recordPause();
      expect(service.hasIdleTimedOut(), isFalse);

      service.clearPause();
    });
  });
}
