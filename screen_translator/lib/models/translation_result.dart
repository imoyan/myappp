class TranslationResult {
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.engine,
  });

  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String engine; // 'apple' or 'cloud'
}
