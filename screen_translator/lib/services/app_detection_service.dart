import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_analysis_result.dart';
import 'restriction_service.dart';
import 'settings_service.dart';

/// Detects which app is shown in a screenshot.
///
/// Two detection methods:
/// 1. **Shortcut**: iOS Shortcut passes the app name directly (confidence 1.0).
/// 2. **OCR heuristic**: Analyse the OCR text for known keywords.
class AppDetectionService {
  AppDetectionService._();
  static final AppDetectionService instance = AppDetectionService._();

  // ── Known AI-service keywords ──
  static const _aiServiceKeywords = <String, String>{
    'chatgpt': 'ChatGPT',
    'openai': 'ChatGPT',
    'gpt-4': 'ChatGPT',
    'claude': 'Claude',
    'anthropic': 'Claude',
    'gemini': 'Gemini',
    'google ai': 'Gemini',
    'bard': 'Gemini',
    'copilot': 'Copilot',
    'perplexity': 'Perplexity',
    'midjourney': 'Midjourney',
    'dall-e': 'DALL-E',
    'stable diffusion': 'Stable Diffusion',
  };

  // ── Restriction-signal keywords ──
  static const _restrictionKeywords = [
    'rate limit',
    'rate_limit',
    'try again',
    'usage limit',
    'too many requests',
    'limit reached',
    'exceeded',
    'unavailable',
    'wait',
    'cooldown',
    '制限',
    '上限',
    '利用できません',
    'available in',
    'available at',
    'come back',
  ];

  // ── Ingress keywords ──
  static const _ingressKeywords = [
    'ingress',
    'glyph',
    'hack',
    'portal',
    'xm',
    'niantic',
    'enlightened',
    'resistance',
    'resonator',
  ];

  /// Analyse a screenshot using the provided [ocrText].
  ///
  /// If [shortcutAppName] is provided (from iOS Shortcut), it takes priority.
  Future<AppAnalysisResult> analyse({
    required String ocrText,
    String? shortcutAppName,
    String? imagePath,
  }) async {
    // 1. Shortcut-provided app name
    if (shortcutAppName != null && shortcutAppName.isNotEmpty) {
      final category = _categoriseByName(shortcutAppName);
      RestrictionInfo? restriction;
      if (category == AppCategory.aiService) {
        restriction = RestrictionService.instance.analyse(ocrText,
            serviceName: shortcutAppName);
      }
      return AppAnalysisResult(
        appName: shortcutAppName,
        confidence: 1.0,
        category: category,
        detectionMethod: 'shortcut',
        restriction: restriction,
        rawOcrText: ocrText,
      );
    }

    // 2. OCR heuristic detection
    final lower = ocrText.toLowerCase();

    // Check AI services
    for (final entry in _aiServiceKeywords.entries) {
      if (lower.contains(entry.key)) {
        final hasRestriction =
            _restrictionKeywords.any((kw) => lower.contains(kw));
        RestrictionInfo? restriction;
        if (hasRestriction) {
          restriction = RestrictionService.instance
              .analyse(ocrText, serviceName: entry.value);
        }
        return AppAnalysisResult(
          appName: entry.value,
          confidence: hasRestriction ? 0.9 : 0.75,
          category: AppCategory.aiService,
          detectionMethod: 'ocr_heuristic',
          restriction: restriction,
          rawOcrText: ocrText,
        );
      }
    }

    // Check Ingress
    final ingressScore =
        _ingressKeywords.where((kw) => lower.contains(kw)).length;
    if (ingressScore >= 2) {
      return AppAnalysisResult(
        appName: 'Ingress',
        confidence: (ingressScore / _ingressKeywords.length).clamp(0.5, 0.95),
        category: AppCategory.ingress,
        detectionMethod: 'ocr_heuristic',
        rawOcrText: ocrText,
      );
    }

    // Fallback: guess app name from first lines
    final appName = _guessAppName(ocrText);
    return AppAnalysisResult(
      appName: appName,
      confidence: 0.4,
      category: AppCategory.translation,
      detectionMethod: 'ocr_heuristic',
      rawOcrText: ocrText,
    );
  }

  /// Use Cloud API (LLM) for more accurate app detection.
  Future<AppAnalysisResult> analyseWithLlm({
    required String ocrText,
    String? imagePath,
  }) async {
    final settings = SettingsService.instance;
    if (settings.cloudApiUrl.isEmpty || settings.cloudApiKey.isEmpty) {
      return analyse(ocrText: ocrText);
    }

    const prompt = '''
Analyze the following OCR text from a mobile app screenshot.
Identify the app name and category. Respond ONLY with valid JSON:

{
  "app_name": "the app name",
  "category": "translation|ingress|aiService|unknown",
  "confidence": 0.0-1.0,
  "has_restriction": true/false,
  "restriction_type": "rate_limit|daily_cap|temporary_block|none"
}

OCR text:
''';

    final url = Uri.parse(settings.cloudApiUrl);
    final isAnthropic = settings.cloudApiUrl.contains('anthropic');

    final headers = <String, String>{'Content-Type': 'application/json'};
    late final String body;

    if (isAnthropic) {
      headers['x-api-key'] = settings.cloudApiKey;
      headers['anthropic-version'] = '2023-06-01';
      body = jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 256,
        'messages': [
          {'role': 'user', 'content': '$prompt$ocrText'},
        ],
      });
    } else {
      headers['Authorization'] = 'Bearer ${settings.cloudApiKey}';
      body = jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': '$prompt$ocrText'},
        ],
        'temperature': 0.1,
      });
    }

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return analyse(ocrText: ocrText);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      String content;
      if (isAnthropic) {
        content =
            (json['content'] as List<dynamic>?)?.first['text']?.toString() ??
                '';
      } else {
        content = (json['choices'] as List<dynamic>?)
                ?.first['message']?['content']
                ?.toString() ??
            '';
      }

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch == null) return analyse(ocrText: ocrText);

      final result = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final appName = result['app_name']?.toString() ?? 'unknown';
      final categoryStr = result['category']?.toString() ?? 'unknown';
      final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.5;
      final hasRestriction = result['has_restriction'] == true;

      final category = AppCategory.values.firstWhere(
        (c) => c.name == categoryStr,
        orElse: () => AppCategory.unknown,
      );

      RestrictionInfo? restriction;
      if (hasRestriction && category == AppCategory.aiService) {
        restriction =
            RestrictionService.instance.analyse(ocrText, serviceName: appName);
      }

      return AppAnalysisResult(
        appName: appName,
        confidence: confidence,
        category: category,
        detectionMethod: 'llm',
        restriction: restriction,
        rawOcrText: ocrText,
      );
    } catch (_) {
      return analyse(ocrText: ocrText);
    }
  }

  /// Categorise a known app name.
  AppCategory _categoriseByName(String name) {
    final lower = name.toLowerCase();
    for (final key in _aiServiceKeywords.keys) {
      if (lower.contains(key)) return AppCategory.aiService;
    }
    if (_ingressKeywords.any((kw) => lower.contains(kw))) {
      return AppCategory.ingress;
    }
    return AppCategory.translation;
  }

  /// Simple heuristic: pick the first reasonably-sized line from OCR text.
  String _guessAppName(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final line in lines.take(6)) {
      if (line.length >= 2 && line.length <= 40) {
        return line;
      }
    }
    return 'unknown';
  }
}
