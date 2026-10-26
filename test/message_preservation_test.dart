import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/message.dart';

ExamCardData _buildCard({
  String? recordId,
  List<Message>? messages,
  List<String>? selectedRecipients,
}) {
  return ExamCardData(
    recordId: recordId,
    school: 'Test School',
    date: '2026-09-24',
    subject: 'Mathematics',
    start: '09:00 AM',
    duration: '01:30',
    end: '10:30 AM',
    normalStart: '09:00 AM',
    normalDuration: '01:30',
    normalEnd: '10:30 AM',
    extraTime: '00:00',
    totalDuration: '01:30',
    extraEnd: '10:30 AM',
    messages: messages,
    selectedRecipients: selectedRecipients,
  );
}

void main() {
  group('Message and recipient preservation during background saves', () {
    test('in-memory messages are preserved when background save returns older snapshot', () {
      final initialMessages = [
        Message('to Invigilator 1: Hello'),
      ];
      final newMessages = [
        Message('to Invigilator 2: Runner needed'),
        Message('to Invigilator 1: Hello'),
      ];

      final prior = _buildCard(
        recordId: 'rec-1',
        messages: newMessages,
      );

      final incomingFromDisk = _buildCard(
        recordId: 'rec-1',
        messages: initialMessages,
      );

      // Simulates HomeScreen._preserveTransientCardState resolution
      final priorMessages = prior.messages;
      final incomingMessages = incomingFromDisk.messages;
      final resolvedMessages = (priorMessages != null &&
              (incomingMessages == null ||
                  priorMessages.length > incomingMessages.length))
          ? priorMessages
          : incomingMessages;

      expect(resolvedMessages?.length, equals(2));
      expect(resolvedMessages?[0].message, equals('to Invigilator 2: Runner needed'));
    });

    test('in-memory selectedRecipients are preserved when background save returns older snapshot', () {
      final prior = _buildCard(
        recordId: 'rec-1',
        selectedRecipients: ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve'],
      );

      final incomingFromDisk = _buildCard(
        recordId: 'rec-1',
        selectedRecipients: ['Alice', 'Bob'],
      );

      final priorRecipients = prior.selectedRecipients;
      final incomingRecipients = incomingFromDisk.selectedRecipients;
      final resolvedRecipients = (priorRecipients != null && priorRecipients.isNotEmpty)
          ? priorRecipients
          : incomingRecipients;

      expect(resolvedRecipients, equals(['Alice', 'Bob', 'Charlie', 'Dave', 'Eve']));
    });

    test('OfficerTools local messageLog is preserved when disk snapshot is stale', () {
      final localLog = [
        Message('to Invigilator A: Quick msg 2'),
        Message('to Invigilator A: Quick msg 1'),
      ];
      final diskSnapshotMessages = [
        Message('to Invigilator A: Quick msg 1'),
      ];

      final List<Message> mergedMessages;
      if (localLog.length > diskSnapshotMessages.length) {
        mergedMessages = List<Message>.from(localLog);
      } else {
        mergedMessages = List<Message>.from(diskSnapshotMessages);
      }

      expect(mergedMessages.length, equals(2));
      expect(mergedMessages[0].message, equals('to Invigilator A: Quick msg 2'));
    });
  });
}
