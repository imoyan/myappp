import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/word_definition.dart';
import 'database_service.dart';
import 'settings_service.dart';

class WordLookupService {
  WordLookupService._();
  static final WordLookupService instance = WordLookupService._();

  DatabaseService get _db => DatabaseService.instance;
  SettingsService get _settings => SettingsService.instance;

  /// Look up the definition of [word] appearing in [sentenceContext].
  ///
  /// Returns a cached result if available, otherwise queries the cloud API and
  /// caches the response.
  Future<WordDefinition> lookupWord({
    required String word,
    required String sentenceContext,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // 1. Check cache
    final cached = await _db.getCachedWordDefinition(
      word: word,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    if (cached != null) return cached;

    // 2. Fetch from cloud API
    final definition = await _fetchFromCloud(
      word: word,
      sentenceContext: sentenceContext,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    // 3. Cache result
    await _db.cacheWordDefinition(definition);

    return definition;
  }

  Future<WordDefinition> _fetchFromCloud({
    required String word,
    required String sentenceContext,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (_settings.cloudApiUrl.isEmpty || _settings.cloudApiKey.isEmpty) {
      return WordDefinition.fallback(word,
          sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
    }

    final targetName = _settings.languageName(targetLanguage);

    final prompt = '''
The user is reading text and tapped the word "$word".
The sentence context is: "$sentenceContext"

Provide a JSON response with the word definition. Respond with ONLY valid JSON, no markdown or explanation.

{
  "word": "$word",
  "reading": "(pronunciation or reading if applicable, e.g. furigana for Japanese, IPA for English)",
  "part_of_speech": "(noun/verb/adjective/adverb/etc. in $targetName)",
  "meaning": "(concise definition in $targetName)",
  "examples": [
    {"sentence": "(example sentence using the word)", "translation": "(translation in $targetName)"},
    {"sentence": "(another example)", "translation": "(translation in $targetName)"}
  ]
}
''';

    final url = Uri.parse(_settings.cloudApiUrl);
    final isAnthropic = _settings.cloudApiUrl.contains('anthropic');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    late final String body;

    if (isAnthropic) {
      headers['x-api-key'] = _settings.cloudApiKey;
      headers['anthropic-version'] = '2023-06-01';
      body = jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 1024,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      });
    } else {
      headers['Authorization'] = 'Bearer ${_settings.cloudApiKey}';
      body = jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
      });
    }

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return WordDefinition.fallback(word,
            sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      String content;

      if (isAnthropic) {
        final contentList = json['content'] as List<dynamic>?;
        content = contentList?.first['text']?.toString() ?? '';
      } else {
        final choices = json['choices'] as List<dynamic>?;
        content = choices?.first['message']?['content']?.toString() ?? '';
      }

      // Try to extract JSON from the response (LLMs sometimes wrap in markdown)
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch == null) {
        return WordDefinition.fallback(word,
            sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
      }

      final defJson =
          jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      return WordDefinition.fromJson(
        defJson,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    } catch (_) {
      return WordDefinition.fallback(word,
          sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
    }
  }
}
