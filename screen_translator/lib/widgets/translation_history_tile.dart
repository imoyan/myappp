import 'dart:io';

import 'package:flutter/material.dart';

import '../models/translation_history_entry.dart';

/// A list tile for a single translation history entry.
class TranslationHistoryTile extends StatefulWidget {
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
  State<TranslationHistoryTile> createState() =>
      _TranslationHistoryTileState();
}

class _TranslationHistoryTileState extends State<TranslationHistoryTile> {
  bool _screenshotExists = false;

  @override
  void initState() {
    super.initState();
    _checkScreenshot();
  }

  Future<void> _checkScreenshot() async {
    if (widget.entry.screenshotPath == null) return;
    final exists = await File(widget.entry.screenshotPath!).exists();
    if (!mounted) return;
    setState(() => _screenshotExists = exists);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tile = ListTile(
      leading: _buildLeading(theme),
      title: Text(
        widget.entry.previewText,
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
              widget.entry.languagePairLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.entry.relativeTime,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.onTap,
    );

    if (widget.onDismissed != null) {
      return Dismissible(
        key: ValueKey(widget.entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: theme.colorScheme.error,
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
        onDismissed: (_) => widget.onDismissed!(),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildLeading(ThemeData theme) {
    if (_screenshotExists) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(widget.entry.screenshotPath!),
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
