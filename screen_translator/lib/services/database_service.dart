import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_analysis_result.dart';
import '../models/translation_history_entry.dart';
import '../models/word_definition.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'screen_translator.db');

    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await _createV1Tables(db);
        await _createV2Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
      },
    );
  }

  Future<void> _createV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE translation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_text TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        source_language TEXT NOT NULL,
        target_language TEXT NOT NULL,
        translation_engine TEXT NOT NULL,
        screenshot_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE word_lookup_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        source_language TEXT NOT NULL,
        target_language TEXT NOT NULL,
        definition_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(word, source_language, target_language)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_history_created ON translation_history(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_word_cache_lookup ON word_lookup_cache(word, source_language, target_language)',
    );
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_restrictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_name TEXT NOT NULL,
        restriction_type TEXT NOT NULL,
        available_at_utc TEXT,
        available_at_local TEXT,
        remaining_seconds INTEGER,
        source_timezone TEXT,
        screenshot_path TEXT,
        detected_at TEXT NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_fingerprints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_name TEXT NOT NULL,
        keywords TEXT NOT NULL,
        category TEXT NOT NULL,
        confidence REAL NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(app_name)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingress_glyphs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        glyph_id TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL,
        meaning TEXT,
        confidence REAL NOT NULL DEFAULT 0.5,
        image_path TEXT,
        source TEXT NOT NULL,
        learned_at TEXT NOT NULL,
        last_reviewed_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_restrictions_detected ON ai_restrictions(detected_at DESC)',
    );
  }

  // ── Translation History ──

  Future<int> insertTranslation(TranslationHistoryEntry entry) async {
    final db = await database;
    return db.insert('translation_history', entry.toMap());
  }

  Future<List<TranslationHistoryEntry>> getTranslationHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.query(
      'translation_history',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(TranslationHistoryEntry.fromMap).toList();
  }

  Future<int> getTranslationHistoryCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM translation_history');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> deleteTranslation(int id) async {
    final db = await database;
    await db.delete('translation_history', where: 'id = ?', whereArgs: [id]);
  }

  // ── Word Lookup Cache ──

  Future<WordDefinition?> getCachedWordDefinition({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final db = await database;
    final rows = await db.query(
      'word_lookup_cache',
      where: 'word = ? AND source_language = ? AND target_language = ?',
      whereArgs: [word.toLowerCase(), sourceLanguage, targetLanguage],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    try {
      return WordDefinition.fromJsonString(
        row['definition_json'] as String,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheWordDefinition(WordDefinition definition) async {
    final db = await database;
    await db.insert(
      'word_lookup_cache',
      {
        'word': definition.word.toLowerCase(),
        'source_language': definition.sourceLanguage,
        'target_language': definition.targetLanguage,
        'definition_json': definition.toJsonString(),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── AI Restrictions ──

  Future<int> insertRestriction(RestrictionInfo restriction,
      {String? screenshotPath}) async {
    final db = await database;
    final map = restriction.toMap();
    if (screenshotPath != null) {
      map['screenshot_path'] = screenshotPath;
    }
    return db.insert('ai_restrictions', map);
  }

  Future<List<RestrictionInfo>> getActiveRestrictions() async {
    final db = await database;
    final rows = await db.query(
      'ai_restrictions',
      where: 'resolved = 0',
      orderBy: 'detected_at DESC',
    );
    return rows.map(RestrictionInfo.fromMap).toList();
  }

  Future<List<RestrictionInfo>> getAllRestrictions({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.query(
      'ai_restrictions',
      orderBy: 'detected_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(RestrictionInfo.fromMap).toList();
  }

  Future<void> resolveRestriction(int id) async {
    final db = await database;
    await db.update(
      'ai_restrictions',
      {'resolved': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
