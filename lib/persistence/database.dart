import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/exam_record.dart';
import '../models/export_artifact.dart';
import '../models/license_state.dart';
import '../models/session_event.dart';
import '../models/session_snapshot.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;
  static bool _factoryInitialized = false;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    await _ensureDatabaseFactory();
    final path = join(await getDatabasesPath(), 'vigilo_exam_logger.db');
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      singleInstance: true,
    );
  }

  Future<void> _ensureDatabaseFactory() async {
    if (_factoryInitialized) {
      return;
    }

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      _factoryInitialized = true;
      return;
    }

    try {
      await getDatabasesPath();
      _factoryInitialized = true;
      return;
    } catch (_) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _factoryInitialized = true;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(db);
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_record (
        exam_record_id TEXT PRIMARY KEY,
        exam_name TEXT NOT NULL,
        exam_center TEXT,
        created_by TEXT,
        created_at_utc TEXT NOT NULL,
        closed_at_utc TEXT,
        record_status TEXT NOT NULL,
        schema_version INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_snapshot (
        exam_record_id TEXT PRIMARY KEY,
        session_status TEXT NOT NULL,
        started_at_utc TEXT NOT NULL,
        pause_started_at_utc TEXT,
        total_paused_ms INTEGER NOT NULL,
        planned_duration_ms INTEGER NOT NULL,
        ended_at_utc TEXT,
        last_checkpoint_at_utc TEXT,
        last_known_now_utc TEXT,
        integrity_flag TEXT,
        FOREIGN KEY (exam_record_id)
          REFERENCES exam_record(exam_record_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_event (
        event_id TEXT PRIMARY KEY,
        exam_record_id TEXT NOT NULL,
        seq_no INTEGER NOT NULL,
        type TEXT NOT NULL,
        occurred_at_utc TEXT NOT NULL,
        payload_json TEXT,
        persisted_at_utc TEXT NOT NULL,
        FOREIGN KEY (exam_record_id)
          REFERENCES exam_record(exam_record_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS export_artifact (
        export_id TEXT PRIMARY KEY,
        exam_record_id TEXT NOT NULL,
        format TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_hash TEXT NOT NULL,
        event_count_at_export INTEGER NOT NULL,
        exported_at_utc TEXT NOT NULL,
        FOREIGN KEY (exam_record_id)
          REFERENCES exam_record(exam_record_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS license_state (
        exam_record_id TEXT PRIMARY KEY,
        activation_status TEXT NOT NULL,
        activation_code_hash TEXT,
        activated_at_utc TEXT,
        expires_at_utc TEXT,
        device_binding_id TEXT,
        FOREIGN KEY (exam_record_id)
          REFERENCES exam_record(exam_record_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_metadata (
        exam_record_id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (exam_record_id)
          REFERENCES exam_record(exam_record_id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_state (
        state_key TEXT PRIMARY KEY,
        state_value TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exam_record_status '
      'ON exam_record(record_status)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_session_event_seq '
      'ON session_event(exam_record_id, seq_no)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_session_event_occurred '
      'ON session_event(exam_record_id, occurred_at_utc)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_metadata_archived '
      'ON exam_metadata(is_archived)',
    );
  }

  Future<ExamRecord?> getRecord(String examRecordId) async {
    final db = await database;
    final maps = await db.query(
      'exam_record',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ExamRecord.fromMap(maps.first);
  }

  Future<List<ExamRecord>> getAllExamRecords() async {
    final db = await database;
    final maps = await db.query('exam_record', orderBy: 'created_at_utc DESC');
    return maps.map((map) => ExamRecord.fromMap(map)).toList();
  }

  Future<ExamRecord?> getLatestExamRecord() async {
    final db = await database;
    final maps = await db.query(
      'exam_record',
      orderBy: 'created_at_utc DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ExamRecord.fromMap(maps.first);
  }

  Future<SessionSnapshot?> getSnapshot(String examRecordId) async {
    final db = await database;
    final maps = await db.query(
      'session_snapshot',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SessionSnapshot.fromMap(maps.first);
  }

  Future<List<SessionSnapshot>> getActiveSnapshots() async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT s.* FROM session_snapshot s
      INNER JOIN exam_record r
      ON r.exam_record_id = s.exam_record_id
      WHERE r.record_status = ?
      AND s.session_status IN (?, ?)
      ORDER BY r.created_at_utc DESC
      ''',
      [
        RecordStatus.open.code,
        SessionStatus.running.code,
        SessionStatus.paused.code,
      ],
    );
    return maps.map((map) => SessionSnapshot.fromMap(map)).toList();
  }

  Future<List<SessionEvent>> getEvents(String examRecordId) async {
    final db = await database;
    final maps = await db.query(
      'session_event',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
      orderBy: 'seq_no ASC',
    );
    return maps.map((map) => SessionEvent.fromMap(map)).toList();
  }

  Future<int> getEventCount(String examRecordId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM session_event WHERE exam_record_id = ?',
      [examRecordId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> getMetadata(String examRecordId) async {
    final db = await database;
    final maps = await db.query(
      'exam_metadata',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getRecordsWithMetadata({
    required bool archived,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT
        r.exam_record_id,
        r.exam_name,
        r.exam_center,
        r.created_by,
        r.created_at_utc,
        r.closed_at_utc,
        r.record_status,
        r.schema_version,
        s.session_status,
        s.started_at_utc,
        s.pause_started_at_utc,
        s.total_paused_ms,
        s.planned_duration_ms,
        s.ended_at_utc,
        s.last_checkpoint_at_utc,
        s.last_known_now_utc,
        s.integrity_flag,
        m.payload_json,
        m.is_archived
      FROM exam_metadata m
      INNER JOIN exam_record r
      ON r.exam_record_id = m.exam_record_id
      INNER JOIN session_snapshot s
      ON s.exam_record_id = r.exam_record_id
      WHERE m.is_archived = ?
      ORDER BY r.created_at_utc DESC
      ''',
      [archived ? 1 : 0],
    );
  }

  Future<int> getNextEventSeq(DatabaseExecutor db, String examRecordId) async {
    final result = await db.rawQuery(
      'SELECT MAX(seq_no) as max_seq FROM session_event WHERE exam_record_id = ?',
      [examRecordId],
    );
    final maxSeq = Sqflite.firstIntValue(result) ?? 0;
    return maxSeq + 1;
  }

  Future<void> insertExamRecord(DatabaseExecutor db, ExamRecord record) async {
    await db.insert(
      'exam_record',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateExamRecord(DatabaseExecutor db, ExamRecord record) async {
    await db.update(
      'exam_record',
      record.toMap(),
      where: 'exam_record_id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> insertSnapshot(
    DatabaseExecutor db,
    SessionSnapshot snapshot,
  ) async {
    await db.insert(
      'session_snapshot',
      snapshot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSnapshot(
    DatabaseExecutor db,
    SessionSnapshot snapshot,
  ) async {
    await db.update(
      'session_snapshot',
      snapshot.toMap(),
      where: 'exam_record_id = ?',
      whereArgs: [snapshot.examRecordId],
    );
  }

  Future<void> insertEvent(DatabaseExecutor db, SessionEvent event) async {
    await db.insert(
      'session_event',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertExportArtifact(
    DatabaseExecutor db,
    ExportArtifact artifact,
  ) async {
    await db.insert(
      'export_artifact',
      artifact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertLicenseState(
    DatabaseExecutor db,
    LicenseState state,
  ) async {
    await db.insert(
      'license_state',
      state.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMetadata(
    DatabaseExecutor db, {
    required String examRecordId,
    required String payloadJson,
    required bool archived,
  }) async {
    await db.insert('exam_metadata', {
      'exam_record_id': examRecordId,
      'payload_json': payloadJson,
      'is_archived': archived ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setArchiveFlag(
    DatabaseExecutor db, {
    required String examRecordId,
    required bool archived,
  }) async {
    await db.update(
      'exam_metadata',
      {'is_archived': archived ? 1 : 0},
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
    );
  }

  Future<void> setAppState(
    DatabaseExecutor db, {
    required String key,
    String? value,
  }) async {
    await db.insert('app_state', {
      'state_key': key,
      'state_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getAppState(String key) async {
    final db = await database;
    final maps = await db.query(
      'app_state',
      where: 'state_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['state_value'] as String?;
  }

  Future<void> clearLogsForRecord(DatabaseExecutor db, String examRecordId) async {
    await db.delete(
      'session_event',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
    );
    await db.delete(
      'export_artifact',
      where: 'exam_record_id = ?',
      whereArgs: [examRecordId],
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('session_event');
    await db.delete('session_snapshot');
    await db.delete('export_artifact');
    await db.delete('license_state');
    await db.delete('exam_metadata');
    await db.delete('app_state');
    await db.delete('exam_record');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
