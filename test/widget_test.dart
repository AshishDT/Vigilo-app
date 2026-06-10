import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_record.dart';
import 'package:vigilo/models/session_event.dart';
import 'package:vigilo/models/session_snapshot.dart';

void main() {
  group('parity model smoke tests', () {
    test('record status codes remain stable', () {
      expect(RecordStatus.open.code, 'open');
      expect(RecordStatus.closed.code, 'closed');
      expect(RecordStatus.exported.code, 'exported');
      expect(RecordStatusExtension.fromCode('closed'), RecordStatus.closed);
    });

    test('session status code parsing is deterministic', () {
      expect(SessionStatus.running.code, 'running');
      expect(SessionStatusExtension.fromCode('paused'), SessionStatus.paused);
      expect(SessionStatusExtension.fromCode('unexpected'), SessionStatus.idle);
    });

    test('event type codes remain append-only compatible', () {
      expect(SessionEventType.start.code, 'start');
      expect(SessionEventType.recoveryAutoEnd.code, 'recovery_auto_end');
      expect(
        SessionEventTypeExtension.fromCode('control_action'),
        SessionEventType.controlAction,
      );
    });
  });
}
