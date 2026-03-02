import '../models/app_analysis_result.dart';
import '../models/translation_result.dart';
import 'database_service.dart';
import 'restriction_service.dart';
import 'settings_service.dart';
import 'translation_service.dart';

/// Result of an action performed after app detection.
class ActionResult {
  const ActionResult({
    required this.type,
    this.translationResult,
    this.restriction,
    this.message,
  });

  final ActionType type;
  final TranslationResult? translationResult;
  final RestrictionInfo? restriction;
  final String? message;
}

enum ActionType {
  translated,
  restrictionDetected,
  ingressGlyph,
  choicePresented,
}

/// Routes detected apps to the appropriate action handler.
class ActionRoutingService {
  ActionRoutingService._();
  static final ActionRoutingService instance = ActionRoutingService._();

  final _settings = SettingsService.instance;
  final _db = DatabaseService.instance;

  /// Route to the appropriate handler based on [analysis].
  Future<ActionResult> route({
    required AppAnalysisResult analysis,
    required String ocrText,
    required String imagePath,
  }) async {
    switch (analysis.category) {
      case AppCategory.aiService:
        return _handleAiRestriction(analysis, ocrText, imagePath);
      case AppCategory.ingress:
        return _handleIngress(analysis, ocrText, imagePath);
      case AppCategory.translation:
        return _handleTranslation(ocrText, imagePath);
      case AppCategory.unknown:
        return _handleDefault(ocrText, imagePath);
    }
  }

  /// Handle AI-service restriction detection.
  Future<ActionResult> _handleAiRestriction(
    AppAnalysisResult analysis,
    String ocrText,
    String imagePath,
  ) async {
    // Analyse restrictions (may already be in analysis.restriction)
    var restriction = analysis.restriction;
    restriction ??= RestrictionService.instance
        .analyse(ocrText, serviceName: analysis.appName);

    // Save to database
    if (restriction != null) {
      await _db.insertRestriction(restriction, screenshotPath: imagePath);
    }

    // Also translate the text for learning purposes
    TranslationResult? translationResult;
    try {
      final service = await resolveTranslationService(_settings);
      translationResult = await service.translate(
        text: ocrText,
        sourceLanguage: _settings.sourceLanguage,
        targetLanguage: _settings.targetLanguage,
      );
    } catch (_) {
      // Translation is optional for AI restriction flow
    }

    return ActionResult(
      type: ActionType.restrictionDetected,
      restriction: restriction,
      translationResult: translationResult,
      message: restriction != null
          ? '${analysis.appName}: ${restriction.typeLabel} を検出しました'
          : '${analysis.appName}: 制限情報を検出できませんでした',
    );
  }

  /// Handle Ingress screenshot.
  Future<ActionResult> _handleIngress(
    AppAnalysisResult analysis,
    String ocrText,
    String imagePath,
  ) async {
    // MVP: save the glyph-related text + attempt translation
    // Full glyph recognition via AI is future work (spec Section 10)
    TranslationResult? translationResult;
    try {
      final service = await resolveTranslationService(_settings);
      translationResult = await service.translate(
        text: ocrText,
        sourceLanguage: _settings.sourceLanguage,
        targetLanguage: _settings.targetLanguage,
      );
    } catch (_) {
      // Translation optional
    }

    return ActionResult(
      type: ActionType.ingressGlyph,
      translationResult: translationResult,
      message: 'Ingress の画面を検出しました',
    );
  }

  /// Handle regular translation.
  Future<ActionResult> _handleTranslation(
    String ocrText,
    String imagePath,
  ) async {
    final service = await resolveTranslationService(_settings);
    final result = await service.translate(
      text: ocrText,
      sourceLanguage: _settings.sourceLanguage,
      targetLanguage: _settings.targetLanguage,
    );

    return ActionResult(
      type: ActionType.translated,
      translationResult: result,
    );
  }

  /// Handle unknown app — present choices.
  Future<ActionResult> _handleDefault(
    String ocrText,
    String imagePath,
  ) async {
    // Default: translate anyway
    return _handleTranslation(ocrText, imagePath);
  }
}
