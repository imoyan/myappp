import 'dart:io';

import 'package:flutter/material.dart';

import '../models/translation_history_entry.dart';

/// A list tile for a single translation history entry.
class TranslationHistoryTile extends StatelessWidget {
  const TranslationHistoryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onDismissed,
  });

  final TranslationHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tile = ListTile(
      leading: _buildLeading(theme),
      title: Text(
        entry.previewText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.languagePairLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.relativeTime,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    if (onDismissed != null) {
      return Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: theme.colorScheme.error,
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
        onDismissed: (_) => onDismissed!(),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildLeading(ThemeData theme) {
    if (entry.screenshotPath != null &&
        File(entry.screenshotPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(entry.screenshotPath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.translate,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
