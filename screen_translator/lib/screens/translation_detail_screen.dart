import 'dart:io';

import 'package:flutter/material.dart';

import '../models/translation_history_entry.dart';
import '../widgets/tappable_text.dart';
import '../widgets/word_definition_sheet.dart';

/// Full-screen view of a translation history entry with tappable word lookup.
class TranslationDetailScreen extends StatefulWidget {
  const TranslationDetailScreen({super.key, required this.entry});

  final TranslationHistoryEntry entry;

  @override
  State<TranslationDetailScreen> createState() =>
      _TranslationDetailScreenState();
}

class _TranslationDetailScreenState extends State<TranslationDetailScreen> {
  bool _showOriginal = false;

  void _onWordTap(String word, String sentenceContext) {
    showWordDefinitionSheet(
      context,
      word: word,
      sentenceContext: sentenceContext,
      sourceLanguage: widget.entry.sourceLanguage,
      targetLanguage: widget.entry.targetLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.languagePairLabel),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metadata
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.translationEngine == 'apple'
                      ? 'Apple翻訳'
                      : 'Cloud API',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.relativeTime,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Screenshot
          if (entry.screenshotPath != null &&
              File(entry.screenshotPath!).existsSync()) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(entry.screenshotPath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Original text (collapsible)
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('原文'),
                  trailing: Icon(
                    _showOriginal ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () =>
                      setState(() => _showOriginal = !_showOriginal),
                ),
                if (_showOriginal)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SelectableText(
                      entry.originalText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Translated text (tappable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '翻訳結果',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    '単語をタップすると意味を確認できます',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TappableText(
                    text: entry.translatedText,
                    onWordTap: _onWordTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
