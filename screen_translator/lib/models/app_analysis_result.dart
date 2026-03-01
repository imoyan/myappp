/// Category of the detected app, determining which action to execute.
enum AppCategory {
  /// Foreign language content → translate.
  translation,

  /// Ingress → glyph analysis.
  ingress,

  /// AI service (ChatGPT, Claude, Gemini, etc.) → rate-limit tracking.
  aiService,

  /// Unknown app → present choices to the user.
  unknown,
}

/// Information about a detected AI-service rate limit.
class RestrictionInfo {
  const RestrictionInfo({
    required this.serviceName,
    required this.restrictionType,
    this.availableAtUtc,
    this.availableAtLocal,
    this.remainingDuration,
    this.sourceTimezone,
  });

  final String serviceName;
  final String restrictionType; // rate_limit, daily_cap, temporary_block
  final DateTime? availableAtUtc;
  final String? availableAtLocal;
  final Duration? remainingDuration;
  final String? sourceTimezone;

  /// Human-readable remaining time.
  String get remainingLabel {
    if (remainingDuration == null) return '不明';
    final d = remainingDuration!;
    if (d.inMinutes < 1) return '${d.inSeconds}秒';
    if (d.inHours < 1) return '${d.inMinutes}分';
    return '${d.inHours}時間${d.inMinutes % 60}分';
  }

  /// Human-readable restriction type.
  String get typeLabel {
    switch (restrictionType) {
      case 'rate_limit':
        return 'Rate Limit';
      case 'daily_cap':
        return '日次上限';
      case 'temporary_block':
        return '一時ブロック';
      default:
        return restrictionType;
    }
  }

  Map<String, dynamic> toMap() => {
        'service_name': serviceName,
        'restriction_type': restrictionType,
        'available_at_utc': availableAtUtc?.toIso8601String(),
        'available_at_local': availableAtLocal,
        'remaining_seconds': remainingDuration?.inSeconds,
        'source_timezone': sourceTimezone,
        'detected_at': DateTime.now().toIso8601String(),
        'resolved': 0,
      };

  factory RestrictionInfo.fromMap(Map<String, dynamic> map) {
    final remainingSec = map['remaining_seconds'] as int?;
    final availableStr = map['available_at_utc'] as String?;

    return RestrictionInfo(
      serviceName: map['service_name'] as String,
      restrictionType: map['restriction_type'] as String,
      availableAtUtc:
          availableStr != null ? DateTime.tryParse(availableStr) : null,
      availableAtLocal: map['available_at_local'] as String?,
      remainingDuration:
          remainingSec != null ? Duration(seconds: remainingSec) : null,
      sourceTimezone: map['source_timezone'] as String?,
    );
  }
}

/// Result of app detection analysis.
class AppAnalysisResult {
  const AppAnalysisResult({
    required this.appName,
    required this.confidence,
    required this.category,
    required this.detectionMethod,
    this.restriction,
    this.rawOcrText,
  });

  final String appName;
  final double confidence;
  final AppCategory category;
  final String detectionMethod; // 'shortcut' or 'ocr_heuristic'
  final RestrictionInfo? restriction;
  final String? rawOcrText;

  /// Whether a special action (non-translation) is available.
  bool get hasSpecialAction =>
      category == AppCategory.aiService || category == AppCategory.ingress;

  String get categoryLabel {
    switch (category) {
      case AppCategory.translation:
        return '翻訳';
      case AppCategory.ingress:
        return 'Ingress';
      case AppCategory.aiService:
        return 'AIサービス';
      case AppCategory.unknown:
        return '不明';
    }
  }
}
