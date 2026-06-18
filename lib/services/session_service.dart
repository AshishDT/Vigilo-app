import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:sqflite/sqflite.dart';

import '../enums/exam_phase.dart';
import '../models/briefing_model.dart';
import '../models/exam_card_data.dart';
import '../models/exam_record.dart';
import '../models/incident.dart';
import '../models/session_event.dart';
import '../models/session_snapshot.dart';
import '../persistence/database.dart';
import '../utils/id_generator.dart';

const String _migrationStateKey = 'migration_hive_to_sqlite_v1';
const String _lastUsedStateKey = 'vigilo_last_json';
const String _briefingsLibraryStateKey = 'vigilo_briefings_library_v1';
const String _auditExamStartedMessage = 'Exam started';
const String _auditEndNormalTimeMessage = 'End of normal time';
const String _auditStartExtraTimeMessage = 'Start of extra time';
const String _auditExamEndedMessage = 'Exam ended';
const String _auditInvigilatorUpdateMessage = 'Invigilator list updated';

class HomeStateSnapshot {
  final List<ExamCardData> cards;
  final List<ExamCardData> archiveCards;
  final Map<String, String?> lastUsed;

  const HomeStateSnapshot({
    required this.cards,
    required this.archiveCards,
    required this.lastUsed,
  });
}

class SessionService {
  final AppDatabase _db = AppDatabase();

  Future<void> initialize() async {
    await _db.database;
    await migrateFromHiveIfNeeded();
    await recoverActiveSession();
  }

  Future<void> migrateFromHiveIfNeeded() async {
    final marker = await _db.getAppState(_migrationStateKey);
    if (marker == 'done') return;

    final existing = await _db.getAllExamRecords();
    if (existing.isNotEmpty) {
      final db = await _db.database;
      await db.transaction((txn) async {
        await _db.setAppState(txn, key: _migrationStateKey, value: 'done');
      });
      return;
    }

    final box = await Hive.openBox('vigilo_data');
    final rawCards = box.get('vigilo_cards');
    final rawArchiveCards = box.get('vigilo_archive_cards');
    final rawLastUsed = box.get('vigilo_last');

    final cards = _decodeCards(rawCards);
    final archiveCards = _decodeCards(rawArchiveCards);
    final lastUsed = _decodeLastUsed(rawLastUsed);

    await persistHomeState(
      cards: cards,
      archiveCards: archiveCards,
      lastUsed: lastUsed,
      markMigrated: true,
    );
  }

  Future<HomeStateSnapshot> loadHomeState() async {
    final cards = await _loadCardsByArchiveFlag(false);
    final archiveCards = await _loadCardsByArchiveFlag(true);
    final lastUsed = await loadLastUsed();
    return HomeStateSnapshot(
      cards: cards,
      archiveCards: archiveCards,
      lastUsed: lastUsed,
    );
  }

  Future<HomeStateSnapshot> persistHomeState({
    required List<ExamCardData> cards,
    required List<ExamCardData> archiveCards,
    required Map<String, String?> lastUsed,
    bool markMigrated = false,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final keepIds = <String>{};

      for (final card in cards) {
        final id = await _upsertCard(
          txn,
          card: card,
          archived: false,
          fromMigration: markMigrated,
        );
        keepIds.add(id);
      }

      for (final card in archiveCards) {
        final id = await _upsertCard(
          txn,
          card: card,
          archived: _isArchivableCard(card),
          fromMigration: markMigrated,
        );
        keepIds.add(id);
      }

      final existingMetadata = await txn.query(
        'exam_metadata',
        columns: ['exam_record_id'],
      );
      for (final row in existingMetadata) {
        final id = row['exam_record_id'] as String;
        if (!keepIds.contains(id)) {
          await txn.delete(
            'exam_record',
            where: 'exam_record_id = ?',
            whereArgs: [id],
          );
        }
      }

      await _db.setAppState(
        txn,
        key: _lastUsedStateKey,
        value: jsonEncode(lastUsed),
      );
      if (markMigrated) {
        await _db.setAppState(txn, key: _migrationStateKey, value: 'done');
      }
    });

    return await loadHomeState();
  }

  Future<Map<String, String?>> loadLastUsed() async {
    final raw = await _db.getAppState(_lastUsedStateKey);
    if (raw == null || raw.trim().isEmpty) {
      return _emptyLastUsed();
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'school': map['school'] as String?,
        'centre': map['centre'] as String?,
        'subject': map['subject'] as String?,
        'board': map['board'] as String?,
        'start': map['start'] as String?,
        'duration': map['duration'] as String?,
        'extra': map['extra'] as String?,
      };
    } catch (_) {
      return _emptyLastUsed();
    }
  }

  Future<List<BriefingItem>> loadGlobalBriefingsLibrary() async {
    final raw = await _db.getAppState(_briefingsLibraryStateKey);
    if (raw == null || raw.trim().isEmpty) return const <BriefingItem>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <BriefingItem>[];

      final items = <BriefingItem>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final item = BriefingItem.fromJson(map);
        final normalizedPath = File(item.path).absolute.path.trim();
        final normalizedTitle = item.title.trim();
        if (normalizedPath.isEmpty || normalizedTitle.isEmpty) continue;
        items.add(
          BriefingItem(
            type: item.type,
            title: normalizedTitle,
            path: normalizedPath,
            createdAt: item.createdAt,
            uploadedBy: item.uploadedBy,
          ),
        );
      }
      items.sort((a, b) {
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bCreated.compareTo(aCreated);
      });
      return items;
    } catch (_) {
      return const <BriefingItem>[];
    }
  }

  Future<void> saveGlobalBriefingsLibrary(List<BriefingItem> items) async {
    final deduplicated = <String, BriefingItem>{};
    for (final item in items) {
      final normalizedPath = File(item.path).absolute.path.trim();
      final normalizedTitle = item.title.trim();
      if (normalizedPath.isEmpty || normalizedTitle.isEmpty) continue;
      deduplicated[normalizedPath] = BriefingItem(
        type: item.type,
        title: normalizedTitle,
        path: normalizedPath,
        createdAt: item.createdAt ?? DateTime.now(),
        uploadedBy: item.uploadedBy,
      );
    }

    final ordered = deduplicated.values.toList()
      ..sort((a, b) {
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bCreated.compareTo(aCreated);
      });

    final db = await _db.database;
    await db.transaction((txn) async {
      await _db.setAppState(
        txn,
        key: _briefingsLibraryStateKey,
        value: jsonEncode(ordered.map((item) => item.toJson()).toList()),
      );
    });
  }

  Future<void> checkpoint() async {
    final active = await _db.getActiveSnapshots();
    if (active.isEmpty) return;

    final nowUtc = DateTime.now().toUtc();
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final snapshot in active) {
        final event = await _buildEvent(
          txn,
          examRecordId: snapshot.examRecordId,
          type: SessionEventType.checkpoint,
          occurredAtUtc: nowUtc,
          payloadJson: null,
        );
        await _db.insertEvent(txn, event);
        final updated = SessionSnapshot(
          examRecordId: snapshot.examRecordId,
          sessionStatus: snapshot.sessionStatus,
          startedAtUtc: snapshot.startedAtUtc,
          pauseStartedAtUtc: snapshot.pauseStartedAtUtc,
          totalPausedMs: snapshot.totalPausedMs,
          plannedDurationMs: snapshot.plannedDurationMs,
          endedAtUtc: snapshot.endedAtUtc,
          lastCheckpointAtUtc: nowUtc,
          lastKnownNowUtc: nowUtc,
          integrityFlag: snapshot.integrityFlag,
        );
        await _db.updateSnapshot(txn, updated);
      }
    });
  }

  Future<void> recoverActiveSession() async {
    final activeSnapshots = await _db.getActiveSnapshots();
    if (activeSnapshots.isEmpty) return;

    final nowUtc = DateTime.now().toUtc();
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final activeSnapshot in activeSnapshots) {
        final snapshot = await _realignPlannedDurationFromMetadata(
          txn,
          snapshot: activeSnapshot,
        );
        final recordMap = await _queryRecordMap(txn, snapshot.examRecordId);
        if (recordMap == null) continue;
        final record = ExamRecord.fromMap(recordMap);

        await _syncCoreTimeBoundaryEvents(
          txn,
          snapshot: snapshot,
          nowUtc: nowUtc,
        );

        final clockJumpDetected =
            snapshot.lastKnownNowUtc != null &&
            nowUtc.isBefore(snapshot.lastKnownNowUtc!);
        final remainingMs = _computeRemainingMs(snapshot, nowUtc);

        if (clockJumpDetected) {
          final jumpEvent = await _buildEvent(
            txn,
            examRecordId: record.id,
            type: SessionEventType.incident,
            occurredAtUtc: nowUtc,
            payloadJson: jsonEncode({
              'kind': 'clock_jump',
              'lastKnownNowUtc': snapshot.lastKnownNowUtc?.toIso8601String(),
              'nowUtc': nowUtc.toIso8601String(),
            }),
          );
          await _db.insertEvent(txn, jumpEvent);
        }

        if (remainingMs <= 0) {
          await _autoEndSnapshot(
            txn,
            record: record,
            snapshot: snapshot,
            nowUtc: nowUtc,
            reason: 'recovered_auto_end',
            integrityFlag: clockJumpDetected
                ? 'clock_jump'
                : snapshot.integrityFlag,
          );
          continue;
        }

        final recoveryEvent = await _buildEvent(
          txn,
          examRecordId: record.id,
          type: SessionEventType.recoveredAfterTermination,
          occurredAtUtc: nowUtc,
          payloadJson: jsonEncode({'reason': 'app_restart'}),
        );
        await _db.insertEvent(txn, recoveryEvent);

        final updatedSnapshot = SessionSnapshot(
          examRecordId: snapshot.examRecordId,
          sessionStatus: snapshot.sessionStatus,
          startedAtUtc: snapshot.startedAtUtc,
          pauseStartedAtUtc: snapshot.pauseStartedAtUtc,
          totalPausedMs: snapshot.totalPausedMs,
          plannedDurationMs: snapshot.plannedDurationMs,
          endedAtUtc: snapshot.endedAtUtc,
          lastCheckpointAtUtc: nowUtc,
          lastKnownNowUtc: nowUtc,
          integrityFlag: clockJumpDetected
              ? 'clock_jump'
              : snapshot.integrityFlag,
        );
        await _db.updateSnapshot(txn, updatedSnapshot);
      }
    });
  }

  Future<bool> autoEndIfNeeded() async {
    final activeSnapshots = await _db.getActiveSnapshots();
    if (activeSnapshots.isEmpty) return false;

    bool endedAny = false;
    final nowUtc = DateTime.now().toUtc();
    final db = await _db.database;

    await db.transaction((txn) async {
      for (final activeSnapshot in activeSnapshots) {
        final snapshot = await _realignPlannedDurationFromMetadata(
          txn,
          snapshot: activeSnapshot,
        );
        await _syncCoreTimeBoundaryEvents(
          txn,
          snapshot: snapshot,
          nowUtc: nowUtc,
        );

        final remainingMs = _computeRemainingMs(snapshot, nowUtc);
        if (remainingMs > 0) continue;

        final recordMap = await _queryRecordMap(txn, snapshot.examRecordId);
        if (recordMap == null) continue;
        final record = ExamRecord.fromMap(recordMap);

        await _autoEndSnapshot(
          txn,
          record: record,
          snapshot: snapshot,
          nowUtc: nowUtc,
          reason: 'duration_reached',
          integrityFlag: snapshot.integrityFlag,
        );
        endedAny = true;
      }
    });

    return endedAny;
  }

  Future<SessionSnapshot> _realignPlannedDurationFromMetadata(
    DatabaseExecutor txn, {
    required SessionSnapshot snapshot,
  }) async {
    if (snapshot.sessionStatus == SessionStatus.ended) {
      return snapshot;
    }

    final metadataPlannedDurationMs = await _metadataPlannedDurationMs(
      txn,
      snapshot.examRecordId,
    );
    if (metadataPlannedDurationMs <= 0 ||
        metadataPlannedDurationMs == snapshot.plannedDurationMs) {
      return snapshot;
    }

    final updatedSnapshot = SessionSnapshot(
      examRecordId: snapshot.examRecordId,
      sessionStatus: snapshot.sessionStatus,
      startedAtUtc: snapshot.startedAtUtc,
      pauseStartedAtUtc: snapshot.pauseStartedAtUtc,
      totalPausedMs: snapshot.totalPausedMs,
      plannedDurationMs: metadataPlannedDurationMs,
      endedAtUtc: snapshot.endedAtUtc,
      lastCheckpointAtUtc: snapshot.lastCheckpointAtUtc,
      lastKnownNowUtc: snapshot.lastKnownNowUtc,
      integrityFlag: snapshot.integrityFlag,
    );
    await _db.updateSnapshot(txn, updatedSnapshot);
    return updatedSnapshot;
  }

  Future<void> startSession({
    required String examRecordId,
    DateTime? startedAt,
    bool autoStart = false,
    bool restart = false,
    int? normalDurationMs,
    int? extraTimeMs,
  }) async {
    final nowUtc = (startedAt ?? DateTime.now()).toUtc();
    final db = await _db.database;

    await db.transaction((txn) async {
      final recordMap = await _queryRecordMap(txn, examRecordId);
      final snapshotMap = await _querySnapshotMap(txn, examRecordId);
      if (recordMap == null || snapshotMap == null) return;

      final record = ExamRecord.fromMap(recordMap);
      final snapshot = SessionSnapshot.fromMap(snapshotMap);

      if (!restart && snapshot.sessionStatus == SessionStatus.running) {
        return;
      }

      final metadataPlannedDurationMs = await _metadataPlannedDurationMs(
        txn,
        examRecordId,
      );
      final overridePlannedDurationMs =
          normalDurationMs != null && extraTimeMs != null
          ? normalDurationMs + extraTimeMs
          : null;
      final plannedDurationMs =
          (overridePlannedDurationMs != null && overridePlannedDurationMs > 0)
          ? overridePlannedDurationMs
          : metadataPlannedDurationMs > 0
          ? metadataPlannedDurationMs
          : snapshot.plannedDurationMs;

      // await _endAnyOpenSessions(txn, exceptExamRecordId: examRecordId);

      if (restart) {
        final restartEvent = await _buildEvent(
          txn,
          examRecordId: examRecordId,
          type: SessionEventType.controlAction,
          occurredAtUtc: nowUtc,
          payloadJson: jsonEncode({'message': 'Exam restarted'}),
        );
        await _db.insertEvent(txn, restartEvent);
      }

      final updatedSnapshot = SessionSnapshot(
        examRecordId: examRecordId,
        sessionStatus: SessionStatus.running,
        startedAtUtc: nowUtc,
        pauseStartedAtUtc: null,
        totalPausedMs: 0,
        plannedDurationMs: plannedDurationMs,
        endedAtUtc: null,
        lastCheckpointAtUtc: nowUtc,
        lastKnownNowUtc: nowUtc,
        integrityFlag: restart ? null : snapshot.integrityFlag,
      );

      final updatedRecord = ExamRecord(
        id: record.id,
        examName: record.examName,
        examCenter: record.examCenter,
        createdBy: record.createdBy,
        createdAtUtc: record.createdAtUtc,
        closedAtUtc: null,
        recordStatus: RecordStatus.open,
        schemaVersion: record.schemaVersion,
      );

      final event = await _buildEvent(
        txn,
        examRecordId: examRecordId,
        type: SessionEventType.start,
        occurredAtUtc: nowUtc,
        payloadJson: jsonEncode({
          'autoStart': autoStart,
          'restart': restart,
          'plannedDurationMs': plannedDurationMs,
          if (normalDurationMs != null) 'normalDurationMs': normalDurationMs,
          if (extraTimeMs != null) 'extraTimeMs': extraTimeMs,
        }),
      );

      await _db.insertEvent(txn, event);
      await _db.updateSnapshot(txn, updatedSnapshot);
      await _db.updateExamRecord(txn, updatedRecord);
    });
  }

  Future<void> pauseSession(String examRecordId) async {
    final nowUtc = DateTime.now().toUtc();
    final db = await _db.database;

    await db.transaction((txn) async {
      final snapshotMap = await _querySnapshotMap(txn, examRecordId);
      if (snapshotMap == null) return;
      final snapshot = SessionSnapshot.fromMap(snapshotMap);
      if (snapshot.sessionStatus != SessionStatus.running) return;

      final event = await _buildEvent(
        txn,
        examRecordId: examRecordId,
        type: SessionEventType.pause,
        occurredAtUtc: nowUtc,
        payloadJson: null,
      );
      await _db.insertEvent(txn, event);

      final updatedSnapshot = SessionSnapshot(
        examRecordId: examRecordId,
        sessionStatus: SessionStatus.paused,
        startedAtUtc: snapshot.startedAtUtc,
        pauseStartedAtUtc: nowUtc,
        totalPausedMs: snapshot.totalPausedMs,
        plannedDurationMs: snapshot.plannedDurationMs,
        endedAtUtc: snapshot.endedAtUtc,
        lastCheckpointAtUtc: nowUtc,
        lastKnownNowUtc: nowUtc,
        integrityFlag: snapshot.integrityFlag,
      );
      await _db.updateSnapshot(txn, updatedSnapshot);
    });
  }

  Future<void> resumeSession(String examRecordId) async {
    final nowUtc = DateTime.now().toUtc();
    final db = await _db.database;

    await db.transaction((txn) async {
      final snapshotMap = await _querySnapshotMap(txn, examRecordId);
      if (snapshotMap == null) return;
      final snapshot = SessionSnapshot.fromMap(snapshotMap);
      if (snapshot.sessionStatus != SessionStatus.paused) return;

      final additionalPausedMs = snapshot.pauseStartedAtUtc == null
          ? 0
          : nowUtc.difference(snapshot.pauseStartedAtUtc!).inMilliseconds;

      final event = await _buildEvent(
        txn,
        examRecordId: examRecordId,
        type: SessionEventType.resume,
        occurredAtUtc: nowUtc,
        payloadJson: null,
      );
      await _db.insertEvent(txn, event);

      final updatedSnapshot = SessionSnapshot(
        examRecordId: examRecordId,
        sessionStatus: SessionStatus.running,
        startedAtUtc: snapshot.startedAtUtc,
        pauseStartedAtUtc: null,
        totalPausedMs: snapshot.totalPausedMs + additionalPausedMs,
        plannedDurationMs: snapshot.plannedDurationMs,
        endedAtUtc: snapshot.endedAtUtc,
        lastCheckpointAtUtc: nowUtc,
        lastKnownNowUtc: nowUtc,
        integrityFlag: snapshot.integrityFlag,
      );
      await _db.updateSnapshot(txn, updatedSnapshot);
    });
  }

  Future<void> endSession(
    String examRecordId, {
    bool manual = true,
    String? reason,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final db = await _db.database;

    await db.transaction((txn) async {
      final recordMap = await _queryRecordMap(txn, examRecordId);
      final snapshotMap = await _querySnapshotMap(txn, examRecordId);
      if (recordMap == null || snapshotMap == null) return;

      final record = ExamRecord.fromMap(recordMap);
      final snapshot = SessionSnapshot.fromMap(snapshotMap);
      if (snapshot.sessionStatus == SessionStatus.ended) return;

      int totalPausedMs = snapshot.totalPausedMs;
      if (snapshot.sessionStatus == SessionStatus.paused &&
          snapshot.pauseStartedAtUtc != null) {
        totalPausedMs += nowUtc
            .difference(snapshot.pauseStartedAtUtc!)
            .inMilliseconds;
      }

      final endUtc = manual ? nowUtc : _deterministicEndUtc(snapshot);
      await _syncCoreTimeBoundaryEvents(
        txn,
        snapshot: snapshot,
        nowUtc: endUtc,
        latestCoreEventUtc: endUtc.subtract(const Duration(milliseconds: 1)),
        force: true,
      );

      final event = await _buildEvent(
        txn,
        examRecordId: examRecordId,
        type: manual ? SessionEventType.end : SessionEventType.recoveryAutoEnd,
        occurredAtUtc: endUtc,
        payloadJson: reason == null ? null : jsonEncode({'reason': reason}),
      );
      await _db.insertEvent(txn, event);

      final updatedSnapshot = SessionSnapshot(
        examRecordId: examRecordId,
        sessionStatus: SessionStatus.ended,
        startedAtUtc: snapshot.startedAtUtc,
        pauseStartedAtUtc: null,
        totalPausedMs: totalPausedMs,
        plannedDurationMs: snapshot.plannedDurationMs,
        endedAtUtc: endUtc,
        lastCheckpointAtUtc: nowUtc,
        lastKnownNowUtc: nowUtc,
        integrityFlag: snapshot.integrityFlag,
      );
      final updatedRecord = ExamRecord(
        id: record.id,
        examName: record.examName,
        examCenter: record.examCenter,
        createdBy: record.createdBy,
        createdAtUtc: record.createdAtUtc,
        closedAtUtc: endUtc,
        recordStatus: RecordStatus.closed,
        schemaVersion: record.schemaVersion,
      );

      await _db.updateSnapshot(txn, updatedSnapshot);
      await _db.updateExamRecord(txn, updatedRecord);
    });
  }

  Future<void> appendIncident({
    required String examRecordId,
    required Incident incident,
  }) async {
    final db = await _db.database;
    final occurredAtUtc = incident.time.toUtc();
    final eventType = _incidentToEventType(incident);
    await db.transaction((txn) async {
      final snapshotMap = await _querySnapshotMap(txn, examRecordId);
      if (snapshotMap == null) return;
      final snapshot = SessionSnapshot.fromMap(snapshotMap);
      if (snapshot.sessionStatus != SessionStatus.running &&
          snapshot.sessionStatus != SessionStatus.paused) {
        return;
      }

      final startEventUtc = await _firstStartEventUtc(txn, examRecordId);
      final recordedStartUtc = startEventUtc ?? snapshot.startedAtUtc;
      if (occurredAtUtc.isBefore(recordedStartUtc)) return;

      final event = await _buildEvent(
        txn,
        examRecordId: examRecordId,
        type: eventType,
        occurredAtUtc: occurredAtUtc,
        payloadJson: jsonEncode({'incident': incident.toJson()}),
      );
      await _db.insertEvent(txn, event);
    });
  }

  Future<void> logControlAction({
    required String examRecordId,
    required String message,
    String? detail,
  }) async {
    final db = await _db.database;
    final nowUtc = DateTime.now().toUtc();
    await db.transaction((txn) async {
      final event = await _buildEvent(
        txn,
        examRecordId: examRecordId,
        type: SessionEventType.controlAction,
        occurredAtUtc: nowUtc,
        payloadJson: jsonEncode({'message': message, 'detail': detail}),
      );
      await _db.insertEvent(txn, event);
    });
  }

  Future<void> deleteExamRecord(String examRecordId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'exam_record',
        where: 'exam_record_id = ?',
        whereArgs: [examRecordId],
      );
    });
  }

  Future<void> updatePlannedDuration({
    required String examRecordId,
    required int normalDurationMs,
    required int extraTimeMs,
    required String reason,
    String? detail,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final db = await _db.database;
    await db.transaction((txn) async {
      final snapshotMap = await _querySnapshotMap(txn, examRecordId);
      final recordMap = await _queryRecordMap(txn, examRecordId);
      if (snapshotMap == null || recordMap == null) return;
      final snapshot = SessionSnapshot.fromMap(snapshotMap);
      final record = ExamRecord.fromMap(recordMap);
      final newPlannedDurationMs = normalDurationMs + extraTimeMs;

      final controlEvent = await _buildEvent(
        txn,
        examRecordId: examRecordId,
        type: SessionEventType.controlAction,
        occurredAtUtc: nowUtc,
        payloadJson: jsonEncode({
          'message': reason,
          'detail': detail,
          'normalDurationMs': normalDurationMs,
          'extraTimeMs': extraTimeMs,
          'plannedDurationMs': newPlannedDurationMs,
        }),
      );
      await _db.insertEvent(txn, controlEvent);

      final updatedSnapshot = SessionSnapshot(
        examRecordId: snapshot.examRecordId,
        sessionStatus: snapshot.sessionStatus,
        startedAtUtc: snapshot.startedAtUtc,
        pauseStartedAtUtc: snapshot.pauseStartedAtUtc,
        totalPausedMs: snapshot.totalPausedMs,
        plannedDurationMs: newPlannedDurationMs,
        endedAtUtc: snapshot.endedAtUtc,
        lastCheckpointAtUtc: nowUtc,
        lastKnownNowUtc: nowUtc,
        integrityFlag: snapshot.integrityFlag,
      );
      await _db.updateSnapshot(txn, updatedSnapshot);

      if (snapshot.sessionStatus == SessionStatus.running ||
          snapshot.sessionStatus == SessionStatus.paused) {
        final remainingMs = _computeRemainingMs(updatedSnapshot, nowUtc);
        if (remainingMs <= 0) {
          await _autoEndSnapshot(
            txn,
            record: record,
            snapshot: updatedSnapshot,
            nowUtc: nowUtc,
            reason: 'duration_adjustment_elapsed_exceeded',
            integrityFlag: updatedSnapshot.integrityFlag,
          );
        }
      }
    });
  }

  Future<List<SessionEvent>> getEventsForRecord(String examRecordId) async {
    return await _db.getEvents(examRecordId);
  }

  Future<SessionSnapshot?> getSnapshotForRecord(String examRecordId) async {
    return await _db.getSnapshot(examRecordId);
  }

  Future<ExamRecord?> getRecord(String examRecordId) async {
    return await _db.getRecord(examRecordId);
  }

  Future<List<ExamCardData>> _loadCardsByArchiveFlag(bool archived) async {
    final rows = await _db.getRecordsWithMetadata(archived: archived);
    final db = await _db.database;
    final cards = <ExamCardData>[];
    for (final row in rows) {
      final id = row['exam_record_id'] as String;
      final payloadJson = row['payload_json'] as String;
      final payload = _safeJsonObject(payloadJson);
      final baseCard = ExamCardData.fromJson(payload).copyWith(recordId: id);
      final snapshot = SessionSnapshot.fromMap(row);

      if (snapshot.sessionStatus == SessionStatus.ended) {
        final endedAtUtc = snapshot.endedAtUtc ?? DateTime.now().toUtc();
        await db.transaction((txn) async {
          await _syncCoreTimeBoundaryEvents(
            txn,
            snapshot: snapshot,
            nowUtc: endedAtUtc,
            latestCoreEventUtc: endedAtUtc.subtract(
              const Duration(milliseconds: 1),
            ),
            force: true,
          );
        });
      }

      final events = await _db.getEvents(id);
      final logs = _eventsToIncidents(events);
      cards.add(
        _applyRuntime(baseCard.copyWith(logs: logs), snapshot, events: events),
      );
    }
    return cards;
  }

  Future<String> _upsertCard(
    DatabaseExecutor txn, {
    required ExamCardData card,
    required bool archived,
    required bool fromMigration,
  }) async {
    final id = card.recordId ?? generateId();
    final existingRecordMap = await _queryRecordMap(txn, id);
    final existingSnapshotMap = await _querySnapshotMap(txn, id);
    final nowUtc = DateTime.now().toUtc();
    final normalDurationMs = card.normalSeconds * 1000;
    final extraTimeMs = card.extraSeconds * 1000;
    final plannedDurationMs = normalDurationMs + extraTimeMs;
    final normalizedCard = card.copyWith(recordId: id);

    if (existingRecordMap == null || existingSnapshotMap == null) {
      final inferred = _inferLegacySnapshot(card, nowUtc);
      final record = ExamRecord(
        id: id,
        examName: card.subject,
        examCenter: card.school,
        createdAtUtc: inferred.createdAtUtc,
        closedAtUtc: inferred.closedAtUtc,
        recordStatus: inferred.recordStatus,
        schemaVersion: 1,
      );
      final snapshot = SessionSnapshot(
        examRecordId: id,
        sessionStatus: inferred.sessionStatus,
        startedAtUtc: inferred.startedAtUtc,
        pauseStartedAtUtc: inferred.pauseStartedAtUtc,
        totalPausedMs: inferred.totalPausedMs,
        plannedDurationMs: plannedDurationMs,
        endedAtUtc: inferred.endedAtUtc,
        lastCheckpointAtUtc: nowUtc,
        lastKnownNowUtc: nowUtc,
        integrityFlag: null,
      );

      await _db.insertExamRecord(txn, record);
      await _db.insertSnapshot(txn, snapshot);
      await _insertLegacyEventsIfNeeded(txn, normalizedCard, snapshot);
    } else {
      final snapshot = SessionSnapshot.fromMap(existingSnapshotMap);
      final scheduleAnchor = _scheduledDateTimeUtc(card);
      final desiredStatus = _statusFromCard(normalizedCard);
      final isTransitionFromIdleToEnded =
          snapshot.sessionStatus == SessionStatus.idle &&
          desiredStatus == SessionStatus.ended;

      final startedAtUtc = isTransitionFromIdleToEnded
          ? nowUtc
          : (desiredStatus == SessionStatus.idle && scheduleAnchor != null
                ? scheduleAnchor
                : snapshot.startedAtUtc);

      final endedAtUtc = desiredStatus == SessionStatus.ended
          ? (snapshot.endedAtUtc ??
                startedAtUtc.add(
                  Duration(
                    milliseconds: snapshot.totalPausedMs + plannedDurationMs,
                  ),
                ))
          : null;

      if (isTransitionFromIdleToEnded) {
        final startEvent = await _buildEvent(
          txn,
          examRecordId: id,
          type: SessionEventType.start,
          occurredAtUtc: startedAtUtc,
          payloadJson: jsonEncode({
            'autoStart': false,
            'restart': false,
            'plannedDurationMs': plannedDurationMs,
            'normalDurationMs': normalDurationMs,
            'extraTimeMs': extraTimeMs,
          }),
        );
        await _db.insertEvent(txn, startEvent);

        final endEvent = await _buildEvent(
          txn,
          examRecordId: id,
          type: SessionEventType.end,
          occurredAtUtc:
              endedAtUtc ??
              nowUtc.add(Duration(milliseconds: plannedDurationMs)),
          payloadJson: jsonEncode({'reason': 'manual_drag_complete'}),
        );
        await _db.insertEvent(txn, endEvent);
      }

      final updatedSnapshot = SessionSnapshot(
        examRecordId: snapshot.examRecordId,
        sessionStatus: desiredStatus,
        startedAtUtc: startedAtUtc,
        pauseStartedAtUtc: desiredStatus == SessionStatus.paused
            ? snapshot.pauseStartedAtUtc
            : null,
        totalPausedMs: snapshot.totalPausedMs,
        plannedDurationMs: plannedDurationMs,
        endedAtUtc: endedAtUtc,
        lastCheckpointAtUtc: nowUtc,
        lastKnownNowUtc: nowUtc,
        integrityFlag: snapshot.integrityFlag,
      );
      await _db.updateSnapshot(txn, updatedSnapshot);

      final updatedRecord = ExamRecord.fromMap(existingRecordMap).copyWith(
        examName: card.subject,
        examCenter: card.school,
        closedAtUtc: desiredStatus == SessionStatus.ended ? endedAtUtc : null,
        recordStatus: desiredStatus == SessionStatus.ended
            ? RecordStatus.closed
            : RecordStatus.open,
      );
      await _db.updateExamRecord(txn, updatedRecord);
    }

    await _db.upsertMetadata(
      txn,
      examRecordId: id,
      payloadJson: jsonEncode(normalizedCard.toJson()),
      archived: archived,
    );

    if (fromMigration) {
      await _db.setAppState(txn, key: _migrationStateKey, value: 'done');
    }

    return id;
  }

  Future<void> _insertLegacyEventsIfNeeded(
    DatabaseExecutor txn,
    ExamCardData card,
    SessionSnapshot snapshot,
  ) async {
    if (card.logs.isEmpty) {
      if (snapshot.sessionStatus == SessionStatus.running ||
          snapshot.sessionStatus == SessionStatus.paused ||
          snapshot.sessionStatus == SessionStatus.ended) {
        final startEvent = await _buildEvent(
          txn,
          examRecordId: card.recordId!,
          type: SessionEventType.start,
          occurredAtUtc: snapshot.startedAtUtc,
          payloadJson: jsonEncode({'migrated': true}),
        );
        await _db.insertEvent(txn, startEvent);
      }
      if (snapshot.sessionStatus == SessionStatus.ended) {
        final endEvent = await _buildEvent(
          txn,
          examRecordId: card.recordId!,
          type: SessionEventType.end,
          occurredAtUtc: snapshot.endedAtUtc ?? DateTime.now().toUtc(),
          payloadJson: jsonEncode({'migrated': true}),
        );
        await _db.insertEvent(txn, endEvent);
      }
      return;
    }

    final sortedLogs = [...card.logs]..sort((a, b) => a.time.compareTo(b.time));
    bool hasStart = false;
    bool hasEnd = false;
    for (final incident in sortedLogs) {
      final type = _incidentToEventType(incident);
      if (type == SessionEventType.start) hasStart = true;
      if (type == SessionEventType.end) hasEnd = true;

      final event = await _buildEvent(
        txn,
        examRecordId: card.recordId!,
        type: type,
        occurredAtUtc: incident.time.toUtc(),
        payloadJson: jsonEncode({'incident': incident.toJson()}),
      );
      await _db.insertEvent(txn, event);
    }

    if (!hasStart &&
        (snapshot.sessionStatus == SessionStatus.running ||
            snapshot.sessionStatus == SessionStatus.paused ||
            snapshot.sessionStatus == SessionStatus.ended)) {
      final startEvent = await _buildEvent(
        txn,
        examRecordId: card.recordId!,
        type: SessionEventType.start,
        occurredAtUtc: snapshot.startedAtUtc,
        payloadJson: jsonEncode({'migrated': true}),
      );
      await _db.insertEvent(txn, startEvent);
    }

    if (!hasEnd && snapshot.sessionStatus == SessionStatus.ended) {
      final endEvent = await _buildEvent(
        txn,
        examRecordId: card.recordId!,
        type: SessionEventType.end,
        occurredAtUtc: snapshot.endedAtUtc ?? DateTime.now().toUtc(),
        payloadJson: jsonEncode({'migrated': true}),
      );
      await _db.insertEvent(txn, endEvent);
    }
  }

  Future<void> _autoEndSnapshot(
    DatabaseExecutor txn, {
    required ExamRecord record,
    required SessionSnapshot snapshot,
    required DateTime nowUtc,
    required String reason,
    required String? integrityFlag,
  }) async {
    final endUtc = _deterministicEndUtc(snapshot);
    await _syncCoreTimeBoundaryEvents(
      txn,
      snapshot: snapshot,
      nowUtc: endUtc,
      latestCoreEventUtc: endUtc.subtract(const Duration(milliseconds: 1)),
      force: true,
    );
    final event = await _buildEvent(
      txn,
      examRecordId: record.id,
      type: SessionEventType.recoveryAutoEnd,
      occurredAtUtc: endUtc,
      payloadJson: jsonEncode({
        'reason': reason,
        'computedAtUtc': nowUtc.toIso8601String(),
      }),
    );
    await _db.insertEvent(txn, event);

    final updatedSnapshot = SessionSnapshot(
      examRecordId: snapshot.examRecordId,
      sessionStatus: SessionStatus.ended,
      startedAtUtc: snapshot.startedAtUtc,
      pauseStartedAtUtc: null,
      totalPausedMs: snapshot.totalPausedMs,
      plannedDurationMs: snapshot.plannedDurationMs,
      endedAtUtc: endUtc,
      lastCheckpointAtUtc: nowUtc,
      lastKnownNowUtc: nowUtc,
      integrityFlag: integrityFlag,
    );
    final updatedRecord = ExamRecord(
      id: record.id,
      examName: record.examName,
      examCenter: record.examCenter,
      createdBy: record.createdBy,
      createdAtUtc: record.createdAtUtc,
      closedAtUtc: endUtc,
      recordStatus: RecordStatus.closed,
      schemaVersion: record.schemaVersion,
    );

    await _db.updateSnapshot(txn, updatedSnapshot);
    await _db.updateExamRecord(txn, updatedRecord);
  }

  Future<void> _syncCoreTimeBoundaryEvents(
    DatabaseExecutor txn, {
    required SessionSnapshot snapshot,
    required DateTime nowUtc,
    DateTime? latestCoreEventUtc,
    bool force = false,
  }) async {
    if (snapshot.sessionStatus == SessionStatus.idle) return;

    final metadataMap = await _queryMetadataMap(txn, snapshot.examRecordId);
    final payloadJson = metadataMap?['payload_json'] as String?;
    if (payloadJson == null || payloadJson.isEmpty) return;

    final payload = _safeJsonObject(payloadJson);
    if (payload.isEmpty) return;

    ExamCardData card;
    try {
      card = ExamCardData.fromJson(payload);
    } catch (_) {
      return;
    }

    final normalMs = card.normalSeconds * 1000;
    final hasExtraPhase = card.extraSeconds > 0;
    if (normalMs <= 0) return;

    final elapsedMs = _computeElapsedMs(snapshot, nowUtc);
    if (elapsedMs < normalMs) return;

    final existingRows = await txn.query(
      'session_event',
      columns: ['type', 'occurred_at_utc'],
      where: 'exam_record_id = ? AND type IN (?, ?) AND occurred_at_utc >= ?',
      whereArgs: [
        snapshot.examRecordId,
        SessionEventType.endNormalTime.code,
        SessionEventType.startExtraTime.code,
        snapshot.startedAtUtc.toIso8601String(),
      ],
    );
    DateTime? existingNormalUtc;
    DateTime? existingExtraUtc;
    for (final row in existingRows) {
      final type = row['type'] as String?;
      final occurredRaw = row['occurred_at_utc'] as String?;
      if (type == null || occurredRaw == null) continue;
      final occurredAtUtc = DateTime.tryParse(occurredRaw);
      if (occurredAtUtc == null) continue;
      if (type == SessionEventType.endNormalTime.code) {
        existingNormalUtc = occurredAtUtc;
      } else if (type == SessionEventType.startExtraTime.code) {
        existingExtraUtc = occurredAtUtc;
      }
    }

    final boundaryAnchorUtc = latestCoreEventUtc ?? nowUtc;
    var normalMarkerUtc = await _resolveNormalBoundaryUtc(
      txn,
      snapshot: snapshot,
      normalDurationMs: normalMs,
      referenceNowUtc: nowUtc,
    );
    if (normalMarkerUtc.isAfter(boundaryAnchorUtc)) {
      normalMarkerUtc = boundaryAnchorUtc;
    }

    if (existingNormalUtc == null) {
      final normalEndEvent = await _buildEvent(
        txn,
        examRecordId: snapshot.examRecordId,
        type: SessionEventType.endNormalTime,
        occurredAtUtc: normalMarkerUtc,
        payloadJson: null,
      );
      await _db.insertEvent(txn, normalEndEvent);
      existingNormalUtc = normalMarkerUtc;
    }

    if (hasExtraPhase && existingExtraUtc == null) {
      final DateTime referenceUtc = existingNormalUtc;
      var extraMarkerUtc = referenceUtc.add(const Duration(milliseconds: 1));
      if (latestCoreEventUtc != null &&
          extraMarkerUtc.isAfter(latestCoreEventUtc)) {
        extraMarkerUtc = latestCoreEventUtc;
      }
      final extraStartEvent = await _buildEvent(
        txn,
        examRecordId: snapshot.examRecordId,
        type: SessionEventType.startExtraTime,
        occurredAtUtc: extraMarkerUtc,
        payloadJson: null,
      );
      await _db.insertEvent(txn, extraStartEvent);
    }
  }

  Future<DateTime> _resolveNormalBoundaryUtc(
    DatabaseExecutor txn, {
    required SessionSnapshot snapshot,
    required int normalDurationMs,
    required DateTime referenceNowUtc,
  }) async {
    final rows = await txn.query(
      'session_event',
      columns: ['type', 'occurred_at_utc', 'seq_no'],
      where: 'exam_record_id = ? AND type IN (?, ?)',
      whereArgs: [
        snapshot.examRecordId,
        SessionEventType.pause.code,
        SessionEventType.resume.code,
      ],
      orderBy: 'occurred_at_utc ASC, seq_no ASC',
    );

    final pauseWindows = _buildPauseWindows(
      rows,
      snapshot: snapshot,
      referenceNowUtc: referenceNowUtc,
    );

    return _resolveBoundaryUtcFromPauseWindows(
      startUtc: snapshot.startedAtUtc,
      activeDurationMs: normalDurationMs,
      pauseWindows: pauseWindows,
    );
  }

  DateTime _resolveBoundaryUtcFromPauseWindows({
    required DateTime startUtc,
    required int activeDurationMs,
    required List<_PauseWindow> pauseWindows,
  }) {
    var cursorUtc = startUtc;
    var remainingMs = activeDurationMs;

    for (final window in pauseWindows) {
      if (!window.endUtc.isAfter(cursorUtc)) continue;

      final pauseStartUtc = window.startUtc.isAfter(cursorUtc)
          ? window.startUtc
          : cursorUtc;
      final activeBeforePauseMs = pauseStartUtc
          .difference(cursorUtc)
          .inMilliseconds;

      if (activeBeforePauseMs >= remainingMs) {
        return cursorUtc.add(Duration(milliseconds: remainingMs));
      }

      remainingMs -= activeBeforePauseMs;
      if (window.endUtc.isAfter(cursorUtc)) {
        cursorUtc = window.endUtc;
      }
    }

    return cursorUtc.add(Duration(milliseconds: remainingMs));
  }

  List<_PauseWindow> _buildPauseWindows(
    List<Map<String, Object?>> rows, {
    required SessionSnapshot snapshot,
    required DateTime referenceNowUtc,
  }) {
    final windows = <_PauseWindow>[];
    DateTime? openPauseStart;

    for (final row in rows) {
      final type = row['type'] as String?;
      final occurredRaw = row['occurred_at_utc'] as String?;
      if (type == null || occurredRaw == null || occurredRaw.isEmpty) continue;

      final occurredAtUtc = DateTime.tryParse(occurredRaw);
      if (occurredAtUtc == null) continue;

      if (type == SessionEventType.pause.code) {
        openPauseStart ??= occurredAtUtc;
        continue;
      }

      if (type == SessionEventType.resume.code && openPauseStart != null) {
        final startUtc = openPauseStart;
        if (occurredAtUtc.isAfter(startUtc)) {
          windows.add(_PauseWindow(startUtc: startUtc, endUtc: occurredAtUtc));
        }
        openPauseStart = null;
      }
    }

    final snapshotPauseStart = snapshot.pauseStartedAtUtc;
    if (snapshot.sessionStatus == SessionStatus.paused &&
        snapshotPauseStart != null) {
      final openStart = openPauseStart ?? snapshotPauseStart;
      if (referenceNowUtc.isAfter(openStart)) {
        windows.add(_PauseWindow(startUtc: openStart, endUtc: referenceNowUtc));
      }
    } else if (openPauseStart != null &&
        referenceNowUtc.isAfter(openPauseStart)) {
      windows.add(
        _PauseWindow(startUtc: openPauseStart, endUtc: referenceNowUtc),
      );
    }

    windows.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    if (windows.length <= 1) return windows;

    final merged = <_PauseWindow>[windows.first];
    for (final window in windows.skip(1)) {
      final previous = merged.last;
      if (!window.startUtc.isAfter(previous.endUtc)) {
        final extendedEnd = window.endUtc.isAfter(previous.endUtc)
            ? window.endUtc
            : previous.endUtc;
        merged[merged.length - 1] = _PauseWindow(
          startUtc: previous.startUtc,
          endUtc: extendedEnd,
        );
        continue;
      }
      merged.add(window);
    }
    return merged;
  }

  Future<SessionEvent> _buildEvent(
    DatabaseExecutor txn, {
    required String examRecordId,
    required SessionEventType type,
    required DateTime occurredAtUtc,
    String? payloadJson,
  }) async {
    final seqNo = await _db.getNextEventSeq(txn, examRecordId);
    return SessionEvent(
      id: generateId(),
      examRecordId: examRecordId,
      seqNo: seqNo,
      type: type,
      occurredAtUtc: occurredAtUtc,
      persistedAtUtc: DateTime.now().toUtc(),
      payloadJson: payloadJson,
    );
  }

  _DisplayTimeline _resolveDisplayTimeline({
    required ExamCardData card,
    required SessionSnapshot snapshot,
    required List<SessionEvent> events,
    required DateTime referenceNowUtc,
  }) {
    if (card.normalSeconds <= 0 || card.totalSeconds <= 0) {
      return _DisplayTimeline(
        normalEnd: card.normalEnd,
        examEnd: card.extraEnd,
      );
    }

    final sortedEvents = [...events]
      ..sort((a, b) {
        final byOccurred = a.occurredAtUtc.compareTo(b.occurredAtUtc);
        if (byOccurred != 0) return byOccurred;
        return a.seqNo.compareTo(b.seqNo);
      });

    DateTime? startedAtUtc;
    for (final event in sortedEvents) {
      if (event.type == SessionEventType.start) {
        startedAtUtc = event.occurredAtUtc;
      }
    }
    startedAtUtc ??= snapshot.startedAtUtc;

    final pauseRows = <Map<String, Object?>>[];
    for (final event in sortedEvents) {
      if (event.occurredAtUtc.isBefore(startedAtUtc)) continue;
      if (event.type != SessionEventType.pause &&
          event.type != SessionEventType.resume) {
        continue;
      }
      pauseRows.add({
        'type': event.type.code,
        'occurred_at_utc': event.occurredAtUtc.toIso8601String(),
        'seq_no': event.seqNo,
      });
    }

    final pauseWindows = _buildPauseWindows(
      pauseRows,
      snapshot: snapshot,
      referenceNowUtc: referenceNowUtc,
    );

    final projectedNormalUtc = _resolveBoundaryUtcFromPauseWindows(
      startUtc: startedAtUtc,
      activeDurationMs: card.normalSeconds * 1000,
      pauseWindows: pauseWindows,
    );

    final effectivePausedMs = _effectivePausedMs(snapshot, referenceNowUtc);
    final projectedExamEndUtc = startedAtUtc.add(
      Duration(milliseconds: (card.totalSeconds * 1000) + effectivePausedMs),
    );

    return _DisplayTimeline(
      normalEnd: _formatLocalHms(projectedNormalUtc),
      examEnd: _formatLocalHms(projectedExamEndUtc),
    );
  }

  int _effectivePausedMs(SessionSnapshot snapshot, DateTime referenceNowUtc) {
    var pausedMs = snapshot.totalPausedMs;
    if (snapshot.sessionStatus == SessionStatus.paused &&
        snapshot.pauseStartedAtUtc != null &&
        referenceNowUtc.isAfter(snapshot.pauseStartedAtUtc!)) {
      pausedMs += referenceNowUtc
          .difference(snapshot.pauseStartedAtUtc!)
          .inMilliseconds;
    }
    return pausedMs;
  }

  String _formatLocalHms(DateTime utc) {
    final local = utc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  int _computeElapsedMs(SessionSnapshot snapshot, DateTime nowUtc) {
    if (snapshot.sessionStatus == SessionStatus.idle) {
      return 0;
    }

    DateTime effectiveEnd;
    switch (snapshot.sessionStatus) {
      case SessionStatus.running:
        effectiveEnd = nowUtc;
        break;
      case SessionStatus.paused:
        effectiveEnd = snapshot.pauseStartedAtUtc ?? nowUtc;
        break;
      case SessionStatus.ended:
        effectiveEnd = snapshot.endedAtUtc ?? nowUtc;
        break;
      case SessionStatus.idle:
        effectiveEnd = nowUtc;
        break;
    }

    final rawMs =
        effectiveEnd.difference(snapshot.startedAtUtc).inMilliseconds -
        snapshot.totalPausedMs;
    return rawMs < 0 ? 0 : rawMs;
  }

  int _computeRemainingMs(SessionSnapshot snapshot, DateTime nowUtc) {
    if (snapshot.sessionStatus == SessionStatus.ended) {
      return 0;
    }
    if (snapshot.sessionStatus == SessionStatus.idle) {
      return snapshot.plannedDurationMs;
    }

    final plannedEndUtc = snapshot.startedAtUtc.add(
      Duration(
        milliseconds:
            snapshot.plannedDurationMs + _effectivePausedMs(snapshot, nowUtc),
      ),
    );
    final remainingMs = plannedEndUtc.difference(nowUtc).inMilliseconds;
    return remainingMs < 0 ? 0 : remainingMs;
  }

  DateTime _deterministicEndUtc(SessionSnapshot snapshot) {
    return snapshot.startedAtUtc.add(
      Duration(
        milliseconds: snapshot.totalPausedMs + snapshot.plannedDurationMs,
      ),
    );
  }

  List<ExamCardData> _decodeCards(dynamic raw) {
    if (raw is! List) return const [];
    final cards = <ExamCardData>[];
    for (final item in raw) {
      if (item is Map) {
        cards.add(ExamCardData.fromJson(item.cast<String, dynamic>()));
      }
    }
    return cards;
  }

  Map<String, String?> _decodeLastUsed(dynamic raw) {
    if (raw is! Map) {
      return _emptyLastUsed();
    }
    return {
      'school': raw['school'] as String?,
      'centre': raw['centre'] as String?,
      'subject': raw['subject'] as String?,
      'board': raw['board'] as String?,
      'start': raw['start'] as String?,
      'duration': raw['duration'] as String?,
      'extra': raw['extra'] as String?,
    };
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

  Map<String, dynamic> _safeJsonObject(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }

  SessionEventType _incidentToEventType(Incident incident) {
    final incidentEventType = incident.eventType.trim().toLowerCase();
    if (incidentEventType == 'control') return SessionEventType.controlAction;
    if (incidentEventType == 'incident') return SessionEventType.incident;

    final normalizedMessage = _normalizeAuditMessage(incident.message);
    if (normalizedMessage ==
        _normalizeAuditMessage(_auditEndNormalTimeMessage)) {
      return SessionEventType.endNormalTime;
    }
    if (normalizedMessage ==
        _normalizeAuditMessage(_auditStartExtraTimeMessage)) {
      return SessionEventType.startExtraTime;
    }
    if (normalizedMessage == _normalizeAuditMessage(_auditExamStartedMessage)) {
      return SessionEventType.start;
    }
    if (normalizedMessage ==
        _normalizeAuditMessage('Auto-start at scheduled time')) {
      return SessionEventType.start;
    }
    if (normalizedMessage == _normalizeAuditMessage('Exam paused')) {
      return SessionEventType.pause;
    }
    if (normalizedMessage == _normalizeAuditMessage('Exam resumed')) {
      return SessionEventType.resume;
    }
    if (normalizedMessage == _normalizeAuditMessage(_auditExamEndedMessage)) {
      return SessionEventType.end;
    }
    if (normalizedMessage == _normalizeAuditMessage('Exam ended manually')) {
      return SessionEventType.end;
    }

    return SessionEventType.incident;
  }

  String _normalizeAuditMessage(String message) {
    return message.trim().toLowerCase();
  }

  bool _isInternalAuditEvent(SessionEventType type) {
    return type == SessionEventType.checkpoint ||
        type == SessionEventType.recoveredAfterTermination;
  }

  bool _isTerminationEvent(SessionEventType type) {
    return type == SessionEventType.end ||
        type == SessionEventType.recoveryAutoEnd;
  }

  String _payloadMessage(Map<String, dynamic> payload) {
    if (payload['incident'] is Map) {
      final incidentMap = (payload['incident'] as Map).cast<String, dynamic>();
      final incidentMessage = incidentMap['message'];
      if (incidentMessage is String) return incidentMessage;
    }
    final message = payload['message'];
    return message is String ? message : '';
  }

  bool _isInvigilatorUpdatePayload(Map<String, dynamic> payload) {
    final message = _payloadMessage(payload);
    if (message.isEmpty) return false;
    return _normalizeAuditMessage(message) ==
        _normalizeAuditMessage(_auditInvigilatorUpdateMessage);
  }

  bool _isRestartPayload(Map<String, dynamic> payload) {
    final message = _payloadMessage(payload);
    if (message.isEmpty) return false;
    return _normalizeAuditMessage(message) ==
        _normalizeAuditMessage('Exam restarted');
  }

  List<SessionEvent> _meaningfulAuditEvents(List<SessionEvent> events) {
    final sorted = [...events]
      ..sort((a, b) {
        final byOccurred = a.occurredAtUtc.compareTo(b.occurredAtUtc);
        if (byOccurred != 0) return byOccurred;
        return a.seqNo.compareTo(b.seqNo);
      });

    SessionEvent? anchor;
    for (final event in sorted) {
      final payload = event.payloadJson == null
          ? const <String, dynamic>{}
          : _safeJsonObject(event.payloadJson!);
      if (event.type == SessionEventType.start || _isRestartPayload(payload)) {
        anchor = event;
        break;
      }
    }
    if (anchor == null) {
      return const <SessionEvent>[];
    }
    final recordedStartUtc = anchor.occurredAtUtc;

    // Use the last session start as the reference for finding the active termination
    SessionEvent? lastSessionStart;
    for (final event in sorted) {
      final payloadData = event.payloadJson == null
          ? const <String, dynamic>{}
          : _safeJsonObject(event.payloadJson!);
      if (event.type == SessionEventType.start ||
          _isRestartPayload(payloadData)) {
        lastSessionStart = event;
      }
    }

    SessionEvent? manualEnd;
    SessionEvent? recoveryEnd;
    for (final event in sorted) {
      if (!_isTerminationEvent(event.type)) continue;
      if (event.occurredAtUtc.isBefore(recordedStartUtc)) {
        continue;
      }

      // If we have multiple sessions, only consider the termination for the most recent one
      if (lastSessionStart != null &&
          event.occurredAtUtc.isBefore(lastSessionStart.occurredAtUtc)) {
        continue;
      }

      if (event.type == SessionEventType.end) {
        manualEnd ??= event;
      } else {
        recoveryEnd ??= event;
      }
    }
    final chosenTermination = manualEnd ?? recoveryEnd;

    final filtered = <SessionEvent>[];
    bool keptStart = false;
    bool keptNormalBoundary = false;
    bool keptExtraBoundary = false;
    bool keptTermination = false;

    for (final event in sorted) {
      final payload = event.payloadJson == null
          ? const <String, dynamic>{}
          : _safeJsonObject(event.payloadJson!);

      if (_isInternalAuditEvent(event.type)) continue;
      if (_isInvigilatorUpdatePayload(payload)) continue;

      // Filter events before the very first start/restart or after the final termination
      if (event.occurredAtUtc.isBefore(recordedStartUtc)) continue;
      if (chosenTermination != null &&
          event.occurredAtUtc.isAfter(chosenTermination.occurredAtUtc)) {
        continue;
      }

      switch (event.type) {
        case SessionEventType.start:
          if (keptStart) continue;
          keptStart = true;
          filtered.add(event);
          continue;
        case SessionEventType.endNormalTime:
          if (!keptStart || keptNormalBoundary) continue;
          keptNormalBoundary = true;
          filtered.add(event);
          continue;
        case SessionEventType.startExtraTime:
          if (!keptStart || !keptNormalBoundary || keptExtraBoundary) continue;
          keptExtraBoundary = true;
          filtered.add(event);
          continue;
        case SessionEventType.end:
        case SessionEventType.recoveryAutoEnd:
          if (!keptStart || keptTermination) continue;
          if (chosenTermination == null || event.id != chosenTermination.id) {
            continue;
          }
          keptTermination = true;
          filtered.add(event);
          continue;
        default:
          final isRestart = _isRestartPayload(payload);
          if (!keptStart && !isRestart) continue;
          filtered.add(event);
          if (isRestart) {
            keptStart = true;
            keptNormalBoundary = false;
            keptExtraBoundary = false;
            keptTermination = false;
          }
          continue;
      }
    }

    return filtered;
  }

  List<Incident> _eventsToIncidents(List<SessionEvent> events) {
    final logs = <Incident>[];
    final filteredEvents = _meaningfulAuditEvents(events);
    for (final event in filteredEvents) {
      final payload = event.payloadJson == null
          ? const <String, dynamic>{}
          : _safeJsonObject(event.payloadJson!);

      Incident? embeddedIncident;
      if (payload['incident'] is Map) {
        try {
          embeddedIncident = Incident.fromJson(
            (payload['incident'] as Map).cast<String, dynamic>(),
          );
        } catch (_) {}
      }

      String message;
      String eventType;
      switch (event.type) {
        case SessionEventType.start:
          message = _auditExamStartedMessage;
          eventType = 'core';
          break;
        case SessionEventType.endNormalTime:
          message = _auditEndNormalTimeMessage;
          eventType = 'core';
          break;
        case SessionEventType.startExtraTime:
          message = _auditStartExtraTimeMessage;
          eventType = 'core';
          break;
        case SessionEventType.pause:
          message = 'Exam paused';
          eventType = 'control';
          break;
        case SessionEventType.resume:
          message = 'Exam resumed';
          eventType = 'control';
          break;
        case SessionEventType.end:
        case SessionEventType.recoveryAutoEnd:
          message = _auditExamEndedMessage;
          eventType = 'core';
          break;
        case SessionEventType.incident:
          message = _payloadMessage(payload);
          if (message.isEmpty) {
            message = 'Incident detected';
          }
          eventType = 'incident';
          break;
        case SessionEventType.controlAction:
          message = _payloadMessage(payload);
          if (message.isEmpty) {
            message = 'Control action';
          }
          eventType = 'control';
          break;
        case SessionEventType.recoveredAfterTermination:
        case SessionEventType.checkpoint:
          continue;
      }

      final payloadDetail = (payload['detail'] as String?) ?? '';
      final detail = (embeddedIncident?.detail ?? '').isNotEmpty
          ? embeddedIncident!.detail
          : payloadDetail;

      logs.add(
        Incident(
          message,
          eventType: eventType,
          incidentType: embeddedIncident?.incidentType ?? '',
          room: embeddedIncident?.room ?? '',
          studentID: embeddedIncident?.studentID ?? '',
          duration: embeddedIncident?.duration ?? '',
          staffMember: embeddedIncident?.staffMember ?? '',
          action: embeddedIncident?.action ?? '',
          updatedDuration: embeddedIncident?.updatedDuration ?? '',
          detail: detail,
          time: event.occurredAtUtc.toLocal(),
        ),
      );
    }

    return logs;
  }

  ExamCardData _applyRuntime(
    ExamCardData card,
    SessionSnapshot snapshot, {
    List<SessionEvent> events = const <SessionEvent>[],
  }) {
    final nowUtc = DateTime.now().toUtc();
    final timeline = _resolveDisplayTimeline(
      card: card,
      snapshot: snapshot,
      events: events,
      referenceNowUtc: snapshot.sessionStatus == SessionStatus.ended
          ? (snapshot.endedAtUtc ?? nowUtc)
          : nowUtc,
    );
    final totalSeconds = card.totalSeconds > 0
        ? card.totalSeconds
        : snapshot.plannedDurationMs ~/ 1000;

    if (snapshot.sessionStatus == SessionStatus.idle) {
      final clampedProgress = card.progress.clamp(0.0, 1.0);
      final elapsedSeconds = (clampedProgress * totalSeconds).round();
      final phase = _phaseFor(
        normalSeconds: card.normalSeconds,
        totalSeconds: totalSeconds,
        elapsedSeconds: elapsedSeconds,
        ended: clampedProgress >= 1.0,
      );

      return card.copyWith(
        running: false,
        isPaused: false,
        epochStart: snapshot.startedAtUtc.toLocal(),
        pausedSeconds: card.pausedSeconds,
        progress: clampedProgress,
        phase: phase,
        end: timeline.normalEnd,
        normalEnd: timeline.normalEnd,
        extraEnd: timeline.examEnd,
      );
    }

    final elapsedMs = _computeElapsedMs(snapshot, nowUtc);
    final effectivePausedMs = _effectivePausedMs(snapshot, nowUtc);
    final elapsedSeconds = elapsedMs ~/ 1000;
    final progress = totalSeconds <= 0
        ? 0.0
        : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);

    final phase = _phaseFor(
      normalSeconds: card.normalSeconds,
      totalSeconds: totalSeconds,
      elapsedSeconds: elapsedSeconds,
      ended: snapshot.sessionStatus == SessionStatus.ended,
    );

    return card.copyWith(
      running: snapshot.sessionStatus == SessionStatus.running,
      isPaused: snapshot.sessionStatus == SessionStatus.paused,
      epochStart: snapshot.startedAtUtc.toLocal(),
      pausedSeconds: effectivePausedMs ~/ 1000,
      progress: progress,
      phase: phase,
      end: timeline.normalEnd,
      normalEnd: timeline.normalEnd,
      extraEnd: timeline.examEnd,
    );
  }

  ExamPhase _phaseFor({
    required int normalSeconds,
    required int totalSeconds,
    required int elapsedSeconds,
    required bool ended,
  }) {
    if (ended) return ExamPhase.finished;
    if (totalSeconds <= 0) return ExamPhase.normal;
    if (elapsedSeconds < normalSeconds) return ExamPhase.normal;
    if (elapsedSeconds < totalSeconds) return ExamPhase.extra;
    return ExamPhase.finished;
  }

  _LegacySnapshotInference _inferLegacySnapshot(
    ExamCardData card,
    DateTime nowUtc,
  ) {
    final scheduled = _scheduledDateTimeUtc(card) ?? nowUtc;
    final totalPausedMs = card.pausedSeconds * 1000;
    final isEnded = card.phase == ExamPhase.finished || card.progress >= 1.0;
    final isPaused = card.isPaused && !isEnded;
    final isRunning = card.running && !isEnded && !isPaused;

    final status = isEnded
        ? SessionStatus.ended
        : isPaused
        ? SessionStatus.paused
        : isRunning
        ? SessionStatus.running
        : SessionStatus.idle;

    final startedAtUtc = card.epochStart?.toUtc() ?? scheduled;
    final endedAtUtc = isEnded
        ? startedAtUtc.add(
            Duration(milliseconds: totalPausedMs + (card.totalSeconds * 1000)),
          )
        : null;

    return _LegacySnapshotInference(
      startedAtUtc: startedAtUtc,
      pauseStartedAtUtc: isPaused ? nowUtc : null,
      totalPausedMs: totalPausedMs,
      endedAtUtc: endedAtUtc,
      closedAtUtc: endedAtUtc,
      sessionStatus: status,
      recordStatus: isEnded ? RecordStatus.closed : RecordStatus.open,
      createdAtUtc: startedAtUtc,
    );
  }

  SessionStatus _statusFromCard(ExamCardData card) {
    if (card.running) {
      return SessionStatus.running;
    }
    if (card.isPaused) {
      return SessionStatus.paused;
    }
    if (card.progress >= 1.0 || card.phase == ExamPhase.finished) {
      return SessionStatus.ended;
    }
    return SessionStatus.idle;
  }

  bool _isArchivableCard(ExamCardData card) {
    return _statusFromCard(card) == SessionStatus.ended;
  }

  DateTime? _scheduledDateTimeUtc(ExamCardData c) {
    try {
      final dp = c.date.split('/');
      final tp = c.normalStart.split(':');
      final d = int.parse(dp[0]);
      final m = int.parse(dp[1]);
      final y = int.parse(dp[2]);
      final hh = int.parse(tp[0]);
      final mm = int.parse(tp[1]);
      return DateTime(y, m, d, hh, mm).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> _firstStartEventUtc(
    DatabaseExecutor db,
    String examRecordId,
  ) async {
    final rows = await db.query(
      'session_event',
      columns: ['occurred_at_utc'],
      where: 'exam_record_id = ? AND type = ?',
      whereArgs: [examRecordId, SessionEventType.start.code],
      orderBy: 'seq_no ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final occurred = rows.first['occurred_at_utc'] as String?;
    if (occurred == null || occurred.isEmpty) return null;
    return DateTime.tryParse(occurred);
  }

  Future<Map<String, dynamic>?> _queryRecordMap(
    DatabaseExecutor db,
    String examRecordId,
  ) async {
    final rows = await db.query(
      'exam_record',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> _querySnapshotMap(
    DatabaseExecutor db,
    String examRecordId,
  ) async {
    final rows = await db.query(
      'session_snapshot',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> _queryMetadataMap(
    DatabaseExecutor db,
    String examRecordId,
  ) async {
    final rows = await db.query(
      'exam_metadata',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> _metadataPlannedDurationMs(
    DatabaseExecutor db,
    String examRecordId,
  ) async {
    final metadataMap = await _queryMetadataMap(db, examRecordId);
    final payloadJson = metadataMap?['payload_json'] as String?;
    if (payloadJson == null || payloadJson.isEmpty) {
      return 0;
    }

    final payload = _safeJsonObject(payloadJson);
    if (payload.isEmpty) return 0;

    try {
      final card = ExamCardData.fromJson(payload);
      final plannedDurationMs = card.totalSeconds * 1000;
      return plannedDurationMs > 0 ? plannedDurationMs : 0;
    } catch (_) {
      return 0;
    }
  }
}

class _LegacySnapshotInference {
  final DateTime startedAtUtc;
  final DateTime? pauseStartedAtUtc;
  final int totalPausedMs;
  final DateTime? endedAtUtc;
  final DateTime? closedAtUtc;
  final SessionStatus sessionStatus;
  final RecordStatus recordStatus;
  final DateTime createdAtUtc;

  const _LegacySnapshotInference({
    required this.startedAtUtc,
    required this.pauseStartedAtUtc,
    required this.totalPausedMs,
    required this.endedAtUtc,
    required this.closedAtUtc,
    required this.sessionStatus,
    required this.recordStatus,
    required this.createdAtUtc,
  });
}

class _PauseWindow {
  final DateTime startUtc;
  final DateTime endUtc;

  const _PauseWindow({required this.startUtc, required this.endUtc});
}

class _DisplayTimeline {
  final String normalEnd;
  final String examEnd;

  const _DisplayTimeline({required this.normalEnd, required this.examEnd});
}

extension on ExamRecord {
  ExamRecord copyWith({
    String? examName,
    String? examCenter,
    String? createdBy,
    DateTime? createdAtUtc,
    DateTime? closedAtUtc,
    RecordStatus? recordStatus,
    int? schemaVersion,
  }) {
    return ExamRecord(
      id: id,
      examName: examName ?? this.examName,
      examCenter: examCenter ?? this.examCenter,
      createdBy: createdBy ?? this.createdBy,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      closedAtUtc: closedAtUtc ?? this.closedAtUtc,
      recordStatus: recordStatus ?? this.recordStatus,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
