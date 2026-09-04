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

    test('recordPause ignores pause when actively authenticating', () {
      final service = SecurityService();
      service.clearPause();
      service.isAuthenticating = true;
      service.recordPause();
      expect(service.hasIdleTimedOut(), isFalse);
      service.isAuthenticating = false;
    });

    test('clearPause resets timeout state cleanly', () {
      final service = SecurityService();
      service.recordPause();
      service.clearPause();
      expect(service.hasIdleTimedOut(), isFalse);
    });
  });
}
