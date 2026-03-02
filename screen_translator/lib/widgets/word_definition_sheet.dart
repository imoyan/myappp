import 'package:flutter/material.dart';

import '../models/word_definition.dart';
import '../services/word_lookup_service.dart';

/// Bottom sheet that displays the definition of a tapped word.
class WordDefinitionSheet extends StatefulWidget {
  const WordDefinitionSheet({
    super.key,
    required this.word,
    required this.sentenceContext,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  final String word;
  final String sentenceContext;
  final String sourceLanguage;
  final String targetLanguage;

  @override
  State<WordDefinitionSheet> createState() => _WordDefinitionSheetState();
}

class _WordDefinitionSheetState extends State<WordDefinitionSheet> {
  WordDefinition? _definition;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDefinition();
  }

  Future<void> _loadDefinition() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final definition = await WordLookupService.instance.lookupWord(
        word: widget.word,
        sentenceContext: widget.sentenceContext,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );
      if (mounted) {
        setState(() {
          _definition = definition;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '「${widget.word}」を検索中...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ] else if (_error != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error),
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _loadDefinition,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          ] else if (_definition != null) ...[
            _buildDefinitionContent(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildDefinitionContent(ThemeData theme) {
    final def = _definition!;

    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Word + Part of Speech
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  def.word,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (def.partOfSpeech.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      def.partOfSpeech,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Reading
            if (def.reading != null && def.reading!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                def.reading!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Meaning
            Text(
              def.meaning,
              style: theme.textTheme.bodyLarge,
            ),

            // Examples
            if (def.examples.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '例文',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...def.examples.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final ex = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$idx. ${ex.sentence}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        '   → ${ex.translation}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper to show the word definition bottom sheet.
void showWordDefinitionSheet(
  BuildContext context, {
  required String word,
  required String sentenceContext,
  required String sourceLanguage,
  required String targetLanguage,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => WordDefinitionSheet(
      word: word,
      sentenceContext: sentenceContext,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    ),
  );
}
