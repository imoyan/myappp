import 'dart:convert';

class ExampleSentence {
  const ExampleSentence({
    required this.sentence,
    required this.translation,
  });

  final String sentence;
  final String translation;

  factory ExampleSentence.fromJson(Map<String, dynamic> json) {
    return ExampleSentence(
      sentence: (json['sentence'] ?? '').toString(),
      translation: (json['translation'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sentence': sentence,
        'translation': translation,
      };
}

class WordDefinition {
  const WordDefinition({
    required this.word,
    this.reading,
    required this.partOfSpeech,
    required this.meaning,
    required this.examples,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  final String word;
  final String? reading;
  final String partOfSpeech;
  final String meaning;
  final List<ExampleSentence> examples;
  final String sourceLanguage;
  final String targetLanguage;

  factory WordDefinition.fromJson(Map<String, dynamic> json,
      {String sourceLanguage = '', String targetLanguage = ''}) {
    final examplesRaw = json['examples'];
    final examples = <ExampleSentence>[];
    if (examplesRaw is List) {
      for (final e in examplesRaw) {
        if (e is Map<String, dynamic>) {
          examples.add(ExampleSentence.fromJson(e));
        }
      }
    }

    return WordDefinition(
      word: (json['word'] ?? '').toString(),
      reading: json['reading']?.toString(),
      partOfSpeech: (json['part_of_speech'] ?? '').toString(),
      meaning: (json['meaning'] ?? '').toString(),
      examples: examples,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  String toJsonString() {
    return jsonEncode({
      'word': word,
      'reading': reading,
      'part_of_speech': partOfSpeech,
      'meaning': meaning,
      'examples': examples.map((e) => e.toJson()).toList(),
    });
  }

  factory WordDefinition.fromJsonString(String jsonString,
      {String sourceLanguage = '', String targetLanguage = ''}) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return WordDefinition.fromJson(json,
        sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
  }

  /// Fallback when LLM response fails to parse.
  factory WordDefinition.fallback(String word,
      {String sourceLanguage = '', String targetLanguage = ''}) {
    return WordDefinition(
      word: word,
      partOfSpeech: '',
      meaning: '定義を取得できませんでした',
      examples: const [],
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}
