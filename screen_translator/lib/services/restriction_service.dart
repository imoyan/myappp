import '../models/app_analysis_result.dart';

/// Analyses OCR text for AI-service rate-limit / restriction messages
/// and normalises time information.
class RestrictionService {
  RestrictionService._();
  static final RestrictionService instance = RestrictionService._();

  // ── Timezone offsets from UTC (hours) ──
  static const _timezoneOffsets = <String, int>{
    'UTC': 0,
    'GMT': 0,
    'JST': 9,
    'PT': -8,
    'PST': -8,
    'PDT': -7,
    'ET': -5,
    'EST': -5,
    'EDT': -4,
    'CT': -6,
    'CST': -6,
    'CDT': -5,
    'MT': -7,
    'MST': -7,
    'MDT': -6,
    'CET': 1,
    'CEST': 2,
    'KST': 9,
    'CST_CN': 8, // China Standard Time
    'IST': 5, // +5:30 simplified
  };

  /// Analyse [ocrText] for restriction info.
  RestrictionInfo? analyse(String ocrText, {required String serviceName}) {
    final lower = ocrText.toLowerCase();

    // Determine restriction type
    String restrictionType = 'rate_limit';
    if (lower.contains('daily') ||
        lower.contains('日次') ||
        lower.contains('上限')) {
      restrictionType = 'daily_cap';
    } else if (lower.contains('block') ||
        lower.contains('ban') ||
        lower.contains('suspend')) {
      restrictionType = 'temporary_block';
    }

    // Try to extract time info
    final timeResult = _extractAvailableTime(ocrText);
    final durationResult = _extractDuration(ocrText);

    if (timeResult == null && durationResult == null) {
      // Only keywords matched, no concrete time info
      if (!_hasRestrictionKeywords(lower)) return null;

      return RestrictionInfo(
        serviceName: serviceName,
        restrictionType: restrictionType,
      );
    }

    DateTime? availableAtUtc;
    String? availableAtLocal;
    Duration? remainingDuration;
    String? sourceTimezone;

    if (timeResult != null) {
      availableAtUtc = timeResult.utcTime;
      sourceTimezone = timeResult.detectedTimezone;
      availableAtLocal = _formatLocalTime(availableAtUtc);
    }

    if (durationResult != null) {
      remainingDuration = durationResult;
      availableAtUtc ??= DateTime.now().toUtc().add(durationResult);
      availableAtLocal ??= _formatLocalTime(availableAtUtc);
    }

    return RestrictionInfo(
      serviceName: serviceName,
      restrictionType: restrictionType,
      availableAtUtc: availableAtUtc,
      availableAtLocal: availableAtLocal,
      remainingDuration: remainingDuration,
      sourceTimezone: sourceTimezone,
    );
  }

  bool _hasRestrictionKeywords(String lower) {
    const keywords = [
      'rate limit',
      'try again',
      'usage limit',
      'too many',
      'exceeded',
      'limit reached',
      '制限',
      '上限',
      '利用できません',
    ];
    return keywords.any((kw) => lower.contains(kw));
  }

  /// Extract an absolute time like "15:30 UTC" or "3:30 PM JST".
  _TimeResult? _extractAvailableTime(String text) {
    // Pattern: HH:MM with optional AM/PM and timezone
    final patterns = [
      // "Try again at 15:30 UTC"
      RegExp(
          r'(?:at|after|from)\s+(\d{1,2}):(\d{2})\s*(AM|PM)?\s*(UTC|GMT|JST|PT|PST|PDT|ET|EST|EDT|CT|CST|CDT|MT|MST|MDT|CET|CEST|KST)?',
          caseSensitive: false),
      // "available 15:30" (no timezone)
      RegExp(r'(?:available|解禁|開始|再開)\s*[:：]?\s*(\d{1,2}):(\d{2})\s*(AM|PM)?',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      var hour = int.tryParse(match.group(1) ?? '') ?? 0;
      final minute = int.tryParse(match.group(2) ?? '') ?? 0;
      final ampm = match.group(3)?.toUpperCase();
      final tz = match.groupCount >= 4 ? match.group(4)?.toUpperCase() : null;

      // Convert 12-hour to 24-hour
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;

      final offset = _timezoneOffsets[tz] ?? _localUtcOffset;

      // Build UTC time for today
      final now = DateTime.now().toUtc();
      var utcTime = DateTime.utc(now.year, now.month, now.day, hour - offset, minute);

      // If the time is in the past, assume it's tomorrow
      if (utcTime.isBefore(now)) {
        utcTime = utcTime.add(const Duration(days: 1));
      }

      return _TimeResult(utcTime: utcTime, detectedTimezone: tz);
    }

    return null;
  }

  /// Extract a relative duration like "in 30 minutes" or "残り2時間".
  Duration? _extractDuration(String text) {
    final patterns = [
      // "in 30 minutes", "in 2 hours"
      RegExp(r'in\s+(\d+)\s*(minute|min|hour|hr|second|sec)s?',
          caseSensitive: false),
      // "wait 5 minutes"
      RegExp(r'wait\s+(\d+)\s*(minute|min|hour|hr|second|sec)s?',
          caseSensitive: false),
      // "available in 30m"
      RegExp(r'(?:available|ready)\s+in\s+(\d+)\s*(m|h|s)\b',
          caseSensitive: false),
      // "残り30分", "残り2時間"
      RegExp(r'残り\s*(\d+)\s*(分|時間|秒)'),
      // "あと30分"
      RegExp(r'あと\s*(\d+)\s*(分|時間|秒)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      final value = int.tryParse(match.group(1) ?? '') ?? 0;
      final unit = (match.group(2) ?? '').toLowerCase();

      if (unit.startsWith('hour') ||
          unit.startsWith('hr') ||
          unit == 'h' ||
          unit == '時間') {
        return Duration(hours: value);
      }
      if (unit.startsWith('min') || unit == 'm' || unit == '分') {
        return Duration(minutes: value);
      }
      if (unit.startsWith('sec') || unit == 's' || unit == '秒') {
        return Duration(seconds: value);
      }
    }

    return null;
  }

  /// Format a UTC [DateTime] to user's local time string.
  String _formatLocalTime(DateTime utc) {
    final local = utc.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Get the user's local UTC offset in hours.
  int get _localUtcOffset => DateTime.now().timeZoneOffset.inHours;
}

class _TimeResult {
  const _TimeResult({required this.utcTime, this.detectedTimezone});
  final DateTime utcTime;
  final String? detectedTimezone;
}
