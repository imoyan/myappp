import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 1,
      onCreate: (db, version) async {
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
      },
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
}
