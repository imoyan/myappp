class TranslationHistoryEntry {
  const TranslationHistoryEntry({
    this.id,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translationEngine,
    this.screenshotPath,
    required this.createdAt,
  });

  final int? id;
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String translationEngine;
  final String? screenshotPath;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'original_text': originalText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'translation_engine': translationEngine,
      'screenshot_path': screenshotPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TranslationHistoryEntry.fromMap(Map<String, dynamic> map) {
    return TranslationHistoryEntry(
      id: map['id'] as int?,
      originalText: map['original_text'] as String,
      translatedText: map['translated_text'] as String,
      sourceLanguage: map['source_language'] as String,
      targetLanguage: map['target_language'] as String,
      translationEngine: map['translation_engine'] as String,
      screenshotPath: map['screenshot_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Display label for the language pair (e.g. "EN → JA").
  String get languagePairLabel =>
      '${sourceLanguage.toUpperCase()} → ${targetLanguage.toUpperCase()}';

  /// Short preview of the original text for list display.
  String get previewText {
    final text = originalText.replaceAll('\n', ' ');
    if (text.length <= 60) return text;
    return '${text.substring(0, 57)}...';
  }

  /// Relative time string for display.
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${createdAt.month}/${createdAt.day}';
  }
}
