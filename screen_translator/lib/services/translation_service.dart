import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/translation_result.dart';
import 'settings_service.dart';

// ── Abstract interface ──

abstract class TranslationService {
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });

  Future<bool> get isAvailable;
  String get engineName;
}

// ── Apple Translation (iOS 17.4+) ──

class AppleTranslationService implements TranslationService {
  static const _channel = MethodChannel('screen_translator/translation');

  @override
  String get engineName => 'apple';

  @override
  Future<bool> get isAvailable async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('translate', {
        'text': text,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
      });

      if (result == null) {
        throw Exception('Apple翻訳から結果が返りませんでした。');
      }

      final translatedText = result['translatedText'] as String? ?? '';
      final detectedSource =
          result['sourceLanguage'] as String? ?? sourceLanguage;

      return TranslationResult(
        originalText: text,
        translatedText: translatedText,
        sourceLanguage: detectedSource,
        targetLanguage: targetLanguage,
        engine: engineName,
      );
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED_OS') {
        throw UnsupportedError(
          'Apple翻訳はiOS 17.4以上が必要です。Cloud APIをお使いください。',
        );
      }
      throw Exception('Apple翻訳エラー: ${e.message}');
    }
  }
}

// ── Cloud Translation (OpenAI / Claude API) ──

class CloudTranslationService implements TranslationService {
  CloudTranslationService({required this.settings});

  final SettingsService settings;

  @override
  String get engineName => 'cloud';

  @override
  Future<bool> get isAvailable async {
    return settings.cloudApiUrl.isNotEmpty && settings.cloudApiKey.isNotEmpty;
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (settings.cloudApiUrl.isEmpty || settings.cloudApiKey.isEmpty) {
      throw Exception('Cloud APIのURLまたはAPIキーが未設定です。設定画面で入力してください。');
    }

    final sourceName = settings.languageName(sourceLanguage);
    final targetName = settings.languageName(targetLanguage);

    final prompt = sourceLanguage == 'auto'
        ? 'Translate the following text to $targetName. '
            'Return ONLY the translated text, no explanations.\n\n'
            'Text:\n$text'
        : 'Translate the following text from $sourceName to $targetName. '
            'Return ONLY the translated text, no explanations.\n\n'
            'Text:\n$text';

    final url = Uri.parse(settings.cloudApiUrl);
    final isAnthropic = settings.cloudApiUrl.contains('anthropic');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    late final String body;

    if (isAnthropic) {
      headers['x-api-key'] = settings.cloudApiKey;
      headers['anthropic-version'] = '2023-06-01';
      body = jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 4096,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      });
    } else {
      // OpenAI-compatible API
      headers['Authorization'] = 'Bearer ${settings.cloudApiKey}';
      body = jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
      });
    }

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final preview = response.body.length > 200
          ? '${response.body.substring(0, 200)}...'
          : response.body;
      throw Exception('APIエラー (${response.statusCode}): $preview');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    String translatedText;

    if (isAnthropic) {
      final content = json['content'] as List<dynamic>?;
      translatedText = content?.first['text']?.toString() ?? '';
    } else {
      final choices = json['choices'] as List<dynamic>?;
      translatedText =
          choices?.first['message']?['content']?.toString() ?? '';
    }

    if (translatedText.isEmpty) {
      throw Exception('翻訳結果が空です。');
    }

    return TranslationResult(
      originalText: text,
      translatedText: translatedText.trim(),
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      engine: engineName,
    );
  }
}

// ── Factory ──

/// Returns the appropriate [TranslationService] based on current settings.
///
/// If the user selected Apple and it's available, returns [AppleTranslationService].
/// Otherwise falls back to [CloudTranslationService].
Future<TranslationService> resolveTranslationService(
    SettingsService settings) async {
  if (settings.translationEngine == 'apple') {
    final apple = AppleTranslationService();
    if (await apple.isAvailable) {
      return apple;
    }
  }
  return CloudTranslationService(settings: settings);
}
