import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages with display names.
class SupportedLanguage {
  const SupportedLanguage(this.code, this.name);
  final String code;
  final String name;
}

const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage('auto', '自動検出'),
  SupportedLanguage('en', 'English'),
  SupportedLanguage('ja', '日本語'),
  SupportedLanguage('zh', '中文'),
  SupportedLanguage('ko', '한국어'),
  SupportedLanguage('es', 'Español'),
  SupportedLanguage('fr', 'Français'),
  SupportedLanguage('de', 'Deutsch'),
  SupportedLanguage('pt', 'Português'),
  SupportedLanguage('it', 'Italiano'),
  SupportedLanguage('ru', 'Русский'),
  SupportedLanguage('ar', 'العربية'),
  SupportedLanguage('hi', 'हिन्दी'),
  SupportedLanguage('th', 'ไทย'),
  SupportedLanguage('vi', 'Tiếng Việt'),
];

/// Languages available as translation targets (excludes 'auto').
List<SupportedLanguage> get kTargetLanguages =>
    kSupportedLanguages.where((l) => l.code != 'auto').toList();

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _keySourceLanguage = 'source_language';
  static const _keyTargetLanguage = 'target_language';
  static const _keyTranslationEngine = 'translation_engine';
  static const _keyCloudApiUrl = 'cloud_api_url';
  static const _keyCloudApiKey = 'cloud_api_key';

  SharedPreferences? _prefs;

  String sourceLanguage = 'auto';
  String targetLanguage = 'ja';
  String translationEngine = 'apple'; // 'apple' or 'cloud'
  String cloudApiUrl = '';
  String cloudApiKey = '';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    sourceLanguage = _prefs!.getString(_keySourceLanguage) ?? 'auto';
    targetLanguage = _prefs!.getString(_keyTargetLanguage) ?? 'ja';
    translationEngine = _prefs!.getString(_keyTranslationEngine) ?? 'apple';
    cloudApiUrl = _prefs!.getString(_keyCloudApiUrl) ?? '';
    cloudApiKey = _prefs!.getString(_keyCloudApiKey) ?? '';
  }

  Future<void> save() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_keySourceLanguage, sourceLanguage);
    await prefs.setString(_keyTargetLanguage, targetLanguage);
    await prefs.setString(_keyTranslationEngine, translationEngine);
    await prefs.setString(_keyCloudApiUrl, cloudApiUrl);
    await prefs.setString(_keyCloudApiKey, cloudApiKey);
  }

  /// Name for a language code.
  String languageName(String code) {
    for (final lang in kSupportedLanguages) {
      if (lang.code == code) return lang.name;
    }
    return code.toUpperCase();
  }
}
