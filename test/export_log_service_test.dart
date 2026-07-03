import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/models/exam_card_data.dart';
import 'package:vigilo/models/incident.dart';
import 'package:vigilo/persistence/database.dart';
import 'package:vigilo/services/csv_export_service.dart';
import 'package:vigilo/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Export log format', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late SessionService sessionService;
    late CsvExportService exportService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp('vigilo_export_log_');
      dbDir = Directory(path.join(sandboxRoot.path, 'db'));
      await dbDir.create(recursive: true);

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(dbDir.path);

      final databaseFile = File(path.join(dbDir.path, 'vigilo_exam_logger.db'));
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      sessionService = SessionService();
      exportService = CsvExportService();
      await AppDatabase().clearAllData();
    });

    test('builds the structured ERC-LOG-V1 export log', () async {
      const recordId = 'record-export-log-1';
      final card = ExamCardData(
        recordId: recordId,
        school: 'Battersea Academy',
        centreNumber: '12345',
        date: '06/03/2026',
        subject: 'DT GCSE (AQA)',
        start: '22:42',
        duration: '00:02',
        end: '22:45',
        normalStart: '22:42',
        normalDuration: '00:02',
        normalEnd: '22:44',
        extraTime: '00:01',
        totalDuration: '00:03',
        extraEnd: '22:45',
        roomsSnapshot: 'H1',
        invigilatorsSnapshot: 'Angela, Anthony, Bas',
        setUpBy: 'Basil',
        setUpRole: 'Exam Officer',
      );

      await sessionService.persistHomeState(
        cards: [card],
        archiveCards: const [],
        lastUsed: _emptyLastUsed(),
      );

      final startLocal = DateTime(2026, 3, 6, 22, 42, 0);
      await sessionService.startSession(
        examRecordId: recordId,
        startedAt: startLocal.toUtc(),
      );

      await sessionService.appendIncident(
        examRecordId: recordId,
        incident: Incident(
          'Toilet break',
          incidentType: 'Toilet',
          room: 'H1',
          studentID: '123',
          staffMember: 'Angela',
          duration: '5',
          time: DateTime(2026, 3, 6, 22, 43, 0),
        ),
      );
      await sessionService.autoEndIfNeeded();

      final text = await exportService.buildRecordCsvText(
        examRecordId: recordId,
      );

      expect(text, contains('Vigilo ERC – Exam Session Export Log'));
      expect(text, contains('Log Format: ERC-LOG-V1'));
      expect(
        RegExp(
          r'Export Reference: EXP-ERC-20260306-H1-\d{3}-\d{8}-\d{6}',
        ).hasMatch(text),
        isTrue,
      );
      expect(
        RegExp(r'Exam Session ID: ERC-20260306-H1-\d{3}').hasMatch(text),
        isTrue,
      );
      expect(text, contains('Organisation Name: Battersea Academy'));
      expect(text, contains('Centre Number: 12345'));
      expect(text, contains('Exported By: Basil (Exam Officer)'));
      expect(text, isNot(contains('User Role:')));
      expect(text, contains('Organisation\n\nOrganisation Name:'));
      expect(text, contains('Exam Session\n\nExam Session ID:'));
      expect(text, contains('Timing\n\nScheduled Start Time:'));
      expect(text, contains('Session Summary\n\nSession Status: Completed'));
      expect(
        text,
        contains(
          'Event Log\n\nDate/Time,Category,Phase,Description,Room,Student ID,Invigilator(s),Details',
        ),
      );
      expect(
        text,
        contains(
          'Export Integrity\n\nExport Location: Generated locally by Vigilo ERC',
        ),
      );
      expect(text, contains('Exam Name: DT GCSE'));
      expect(text, contains('Exam Board: AQA'));
      expect(text, contains('Exam Date: 2026-03-06'));
      expect(text, contains('Room(s): H1'));
      expect(text, contains('Invigilator(s): Angela, Anthony, Bas'));
      expect(text, contains('Set Up By: Basil'));
      expect(text, contains('Set Up Role: Exam Officer'));
      expect(text, contains('Pre-Exam Briefings Issued: None'));
      expect(text, contains('Scheduled Start Time: 22:42:00'));
      expect(text, contains('Actual Start Time: 22:42:00'));
      expect(text, contains('Start Type: Manual'));
      expect(text, contains('Normal Time Duration: 00:02:00'));
      expect(text, contains('Extra Time Duration: 00:01:00'));
      expect(text, contains('Actual End Time: 22:45:00'));
      expect(text, contains('Session Status: Completed'));
      expect(text, isNot(contains('Terminated')));
      expect(text, contains('Total Logged Events: 5'));
      expect(text, contains('Total Incidents: 1'));
      expect(text, contains('Total Control Actions: 0'));
      expect(text, contains('Normal Time Ended: 22:44:00'));
      expect(text, contains('Extra Time Started: 22:44:00'));
      expect(text, contains('Exam Ended: 22:45:00'));
      expect(
        text,
        contains(
          'Date/Time,Category,Phase,Description,Room,Student ID,Invigilator(s),Details',
        ),
      );
      expect(
        text,
        contains(
          '2026-03-06 22:42:00,Core,Normal Time,Exam started,H1,,Angela / Anthony / Bas,',
        ),
      );
      expect(
        text,
        contains(
          '2026-03-06 22:43:00,Incident,Normal Time,Toilet visit,H1,123,Angela,Duration: 5 minutes',
        ),
      );
      expect(
        text,
        contains(
          '2026-03-06 22:44:00,Core,Normal Time,Normal time ended,H1,,,',
        ),
      );
      expect(
        text,
        contains(
          '2026-03-06 22:44:00,Core,Extra Time,Extra time started,H1,,,',
        ),
      );
      expect(
        text,
        contains('2026-03-06 22:45:00,Core,Extra Time,Exam ended,H1,,,'),
      );
      expect(
        text,
        contains('Export Location: Generated locally by Vigilo ERC'),
      );
      expect(text, contains('Record Type: Exam session event log'));
      expect(text, contains('Integrity Status: Complete local audit record'));
      expect(
        text,
        contains(
          'This record reflects the complete event log captured during the exam session.',
        ),
      );
    });

    test(
      'splits control action detail text out of the description column',
      () async {
        const recordId = 'record-export-log-control-detail';
        final card = ExamCardData(
          recordId: recordId,
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '08/03/2026',
          subject: 'Maths GCSE (AQA)',
          start: '10:00',
          duration: '01:00',
          end: '11:15',
          normalStart: '10:00',
          normalDuration: '01:00',
          normalEnd: '11:00',
          extraTime: '00:15',
          totalDuration: '01:15',
          extraEnd: '11:15',
          roomsSnapshot: 'H1',
        );

        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: const [],
          lastUsed: _emptyLastUsed(),
        );

        await sessionService.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        );
        await sessionService.updatePlannedDuration(
          examRecordId: recordId,
          normalDurationMs: const Duration(hours: 1).inMilliseconds,
          extraTimeMs: const Duration(minutes: 17).inMilliseconds,
          reason: 'Extra time updated (+2m)',
          detail: 'Adjustment entered before extra time',
        );

        final text = await exportService.buildRecordCsvText(
          examRecordId: recordId,
        );

        expect(
          text,
          contains(
            ',Control,Normal Time,Extra Time increased by 2 minutes,H1,,,Adjustment entered before extra time',
          ),
        );
        expect(
          text,
          isNot(
            contains(
              'Extra Time increased by 2 minutes - Adjustment entered before extra time',
            ),
          ),
        );

        final snapshot = await sessionService.getSnapshotForRecord(recordId);
        expect(
          snapshot?.plannedDurationMs,
          const Duration(hours: 1, minutes: 17).inMilliseconds,
        );
      },
    );

    test(
      'preserves detailed extra time update wording in the export log',
      () async {
        const recordId = 'record-export-log-extra-time-wording';
        final card = ExamCardData(
          recordId: recordId,
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '08/03/2026',
          subject: 'Maths GCSE (AQA)',
          start: '10:00',
          duration: '01:00',
          end: '11:25',
          normalStart: '10:00',
          normalDuration: '01:00',
          normalEnd: '11:00',
          extraTime: '00:25',
          totalDuration: '01:25',
          extraEnd: '11:25',
          roomsSnapshot: 'H1',
        );

        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: const [],
          lastUsed: _emptyLastUsed(),
        );

        await sessionService.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        );
        await sessionService.updatePlannedDuration(
          examRecordId: recordId,
          normalDurationMs: const Duration(hours: 1).inMilliseconds,
          extraTimeMs: const Duration(minutes: 30).inMilliseconds,
          reason: 'Extra Time Updated (25m -> 30m, +5m)',
          detail: 'Adjustment entered before extra time',
        );

        final text = await exportService.buildRecordCsvText(
          examRecordId: recordId,
        );

        expect(
          text,
          contains(
            ',Control,Normal Time,Extra Time increased by 5 minutes,H1,,,Adjustment entered before extra time',
          ),
        );
      },
    );

    test(
      'uses Normal Time Updated wording for duration button control actions',
      () async {
        const recordId = 'record-export-log-normal-duration-wording';
        final card = ExamCardData(
          recordId: recordId,
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '08/03/2026',
          subject: 'Maths GCSE (AQA)',
          start: '10:00',
          duration: '01:00',
          end: '11:15',
          normalStart: '10:00',
          normalDuration: '01:00',
          normalEnd: '11:00',
          extraTime: '00:15',
          totalDuration: '01:15',
          extraEnd: '11:15',
          roomsSnapshot: 'H1',
        );

        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: const [],
          lastUsed: _emptyLastUsed(),
        );

        await sessionService.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        );
        await sessionService.updatePlannedDuration(
          examRecordId: recordId,
          normalDurationMs: const Duration(hours: 1, minutes: 2).inMilliseconds,
          extraTimeMs: const Duration(minutes: 15).inMilliseconds,
          reason: 'Normal Time Updated (+2m)',
          detail: 'Adjustment entered before extra time',
        );

        final text = await exportService.buildRecordCsvText(
          examRecordId: recordId,
        );

        expect(
          text,
          contains(
            ',Control,Normal Time,Normal Time increased by 2 minutes,H1,,,Adjustment entered before extra time',
          ),
        );
      },
    );

    test(
      'formats duration updates to natural hour/minute description',
      () async {
        const recordId = 'record-export-log-hour-minute-formatting';
        final card = ExamCardData(
          recordId: recordId,
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '08/03/2026',
          subject: 'Maths GCSE (AQA)',
          start: '10:00',
          duration: '01:00',
          end: '11:15',
          normalStart: '10:00',
          normalDuration: '01:00',
          normalEnd: '11:00',
          extraTime: '00:15',
          totalDuration: '01:15',
          extraEnd: '11:15',
          roomsSnapshot: 'H1',
        );

        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: const [],
          lastUsed: _emptyLastUsed(),
        );

        await sessionService.startSession(
          examRecordId: recordId,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        );
        
        // Update 1: Normal Time Updated (-120m) -> 2 hours
        await sessionService.updatePlannedDuration(
          examRecordId: recordId,
          normalDurationMs: const Duration(minutes: 60).inMilliseconds,
          extraTimeMs: const Duration(minutes: 15).inMilliseconds,
          reason: 'Normal Time Updated (-120m)',
          detail: 'Adjustment 1',
        );

        // Update 2: Extra Time Updated (25m -> 30m, +90m) -> 1 hour and 30 minutes
        await sessionService.updatePlannedDuration(
          examRecordId: recordId,
          normalDurationMs: const Duration(minutes: 60).inMilliseconds,
          extraTimeMs: const Duration(minutes: 15).inMilliseconds,
          reason: 'Extra Time Updated (25m -> 30m, +90m)',
          detail: 'Adjustment 2',
        );

        // Update 3: Normal Time Updated (+60m) -> 1 hour
        await sessionService.updatePlannedDuration(
          examRecordId: recordId,
          normalDurationMs: const Duration(minutes: 60).inMilliseconds,
          extraTimeMs: const Duration(minutes: 15).inMilliseconds,
          reason: 'Normal Time Updated (+60m)',
          detail: 'Adjustment 3',
        );

        final text = await exportService.buildRecordCsvText(
          examRecordId: recordId,
        );

        expect(text, contains('Normal Time reduced by 2 hours'));
        expect(text, contains('Extra Time increased by 1 hour and 30 minutes'));
        expect(text, contains('Normal Time increased by 1 hour'));
      },
    );

    test('marks manual early finishes as completed', () async {
      const recordId = 'record-export-log-manual-end';
      final card = ExamCardData(
        recordId: recordId,
        school: 'Battersea Academy',
        centreNumber: '12345',
        date: '09/03/2026',
        subject: 'English GCSE (AQA)',
        start: '09:00',
        duration: '01:30',
        end: '10:45',
        normalStart: '09:00',
        normalDuration: '01:30',
        normalEnd: '10:30',
        extraTime: '00:15',
        totalDuration: '01:45',
        extraEnd: '10:45',
      );

      await sessionService.persistHomeState(
        cards: [card],
        archiveCards: const [],
        lastUsed: _emptyLastUsed(),
      );

      await sessionService.startSession(
        examRecordId: recordId,
        startedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      await sessionService.endSession(
        recordId,
        manual: true,
        reason: 'manual_end',
      );

      final text = await exportService.buildRecordCsvText(
        examRecordId: recordId,
      );

      expect(text, contains('Session Status: Completed'));
      expect(text, isNot(contains('Terminated')));
    });

    test(
      'omits the room segment from the session id when no room is set',
      () async {
        const recordId = 'record-export-log-no-room';
        final card = ExamCardData(
          recordId: recordId,
          school: 'Battersea Academy',
          centreNumber: '12345',
          date: '07/03/2026',
          subject: 'English GCSE (AQA)',
          start: '09:00',
          duration: '01:30',
          end: '10:30',
          normalStart: '09:00',
          normalDuration: '01:30',
          normalEnd: '10:30',
          extraTime: '00:00',
          totalDuration: '01:30',
          extraEnd: '10:30',
        );

        await sessionService.persistHomeState(
          cards: [card],
          archiveCards: const [],
          lastUsed: _emptyLastUsed(),
        );

        await sessionService.startSession(
          examRecordId: recordId,
          startedAt: DateTime(2026, 3, 7, 9, 0).toUtc(),
        );

        final text = await exportService.buildRecordCsvText(
          examRecordId: recordId,
        );

        expect(
          RegExp(
            r'Export Reference: EXP-ERC-20260307-\d{3}-\d{8}-\d{6}',
          ).hasMatch(text),
          isTrue,
        );
        expect(
          RegExp(r'Exam Session ID: ERC-20260307-\d{3}').hasMatch(text),
          isTrue,
        );
        expect(text, isNot(contains('Exam Session ID: ERC-20260307-ROOM-')));
        expect(text, contains('Room(s): None'));
      },
    );

    test('handles exam restarts properly in export summary and timing calculations', () async {
      const recordId = 'record-restart-test';
      final card = ExamCardData(
        recordId: recordId,
        school: 'Battersea Academy',
        centreNumber: '12345',
        date: '10/03/2026',
        subject: 'Maths GCSE (AQA)',
        start: '09:00',
        duration: '01:00',
        end: '10:00',
        normalStart: '09:00',
        normalDuration: '01:00',
        normalEnd: '10:00',
        extraTime: '00:00',
        totalDuration: '01:00',
        extraEnd: '10:00',
        roomsSnapshot: 'Room A',
      );

      await sessionService.persistHomeState(
        cards: [card],
        archiveCards: const [],
        lastUsed: _emptyLastUsed(),
      );

      // 1. Initial Start at 09:00
      final initialStart = DateTime(2026, 3, 10, 9, 0, 0);
      await sessionService.startSession(
        examRecordId: recordId,
        startedAt: initialStart.toUtc(),
      );

      // 2. Incident during initial session at 09:02
      await sessionService.appendIncident(
        examRecordId: recordId,
        incident: Incident(
          'Toilet break',
          incidentType: 'Toilet',
          room: 'Room A',
          studentID: 'Student-1',
          time: DateTime(2026, 3, 10, 9, 2, 0),
        ),
      );

      // 3. Restart at 09:10
      final restartStart = DateTime(2026, 3, 10, 9, 10, 0);
      await sessionService.startSession(
        examRecordId: recordId,
        startedAt: restartStart.toUtc(),
        restart: true,
      );

      // 4. Incident during restarted session at 09:12
      await sessionService.appendIncident(
        examRecordId: recordId,
        incident: Incident(
          'Medical incident',
          incidentType: 'Medical',
          room: 'Room A',
          studentID: 'Student-2',
          time: DateTime(2026, 3, 10, 9, 12, 0),
        ),
      );

      // 5. Complete exam manually
      await sessionService.endSession(
        recordId,
        manual: true,
        reason: 'manual_end',
      );

      final text = await exportService.buildRecordCsvText(
        examRecordId: recordId,
      );

      // Verify header summary: Actual Start Time must be 09:10:00 (restart time)
      expect(text, contains('Actual Start Time: 09:10:00'));
      expect(text, contains('Exam Ended:'));
      
      // Verify Event Log contains ALL events (original, restart, incidents, restarts)
      expect(text, contains('09:00:00,Core,Normal Time,Exam started'));
      expect(text, contains('09:02:00,Incident,Normal Time,Toilet visit'));
      expect(text, contains('09:10:00,Control,Normal Time,Exam restarted'));
      expect(text, contains('09:10:00,Core,Normal Time,Exam started'));
      expect(text, contains('09:12:00,Incident,Normal Time,Medical incident'));
      expect(text, contains(',Core,Normal Time,Exam ended'));
    });
  });
}

Map<String, String?> _emptyLastUsed() {
  return {
    'school': null,
    'centre': null,
    'subject': null,
    'board': null,
    'start': null,
    'duration': null,
    'extra': null,
  };
}
