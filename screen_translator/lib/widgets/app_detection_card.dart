import 'package:flutter/material.dart';

import '../models/app_analysis_result.dart';

/// Card showing the detected app name, category, and confidence.
class AppDetectionCard extends StatelessWidget {
  const AppDetectionCard({
    super.key,
    required this.analysis,
    this.onTranslate,
    this.onCheckRestriction,
  });

  final AppAnalysisResult analysis;
  final VoidCallback? onTranslate;
  final VoidCallback? onCheckRestriction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysis.appName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _confidenceColor(theme),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(analysis.confidence * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    analysis.categoryLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  analysis.detectionMethod == 'shortcut'
                      ? 'ショートカット経由'
                      : analysis.detectionMethod == 'llm'
                          ? 'AI判定'
                          : 'OCR推定',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onTranslate != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTranslate,
                      icon: const Icon(Icons.translate, size: 18),
                      label: const Text('翻訳する'),
                    ),
                  ),
                if (onTranslate != null &&
                    onCheckRestriction != null &&
                    analysis.category == AppCategory.aiService)
                  const SizedBox(width: 8),
                if (onCheckRestriction != null &&
                    analysis.category == AppCategory.aiService)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCheckRestriction,
                      icon: const Icon(Icons.timer, size: 18),
                      label: const Text('制限を確認'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData get _categoryIcon {
    switch (analysis.category) {
      case AppCategory.translation:
        return Icons.translate;
      case AppCategory.ingress:
        return Icons.games;
      case AppCategory.aiService:
        return Icons.smart_toy;
      case AppCategory.unknown:
        return Icons.help_outline;
    }
  }

  Color _confidenceColor(ThemeData theme) {
    if (analysis.confidence >= 0.8) return Colors.green;
    if (analysis.confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
