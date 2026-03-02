import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/translation_history_entry.dart';
import '../models/translation_result.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';
import '../widgets/language_selector.dart';
import '../widgets/tappable_text.dart';
import '../widgets/word_definition_sheet.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _settings = SettingsService.instance;

  late String _sourceLanguage;
  late String _targetLanguage;

  bool _isProcessing = false;
  String _statusMessage = '';
  String? _selectedImagePath;
  TranslationResult? _result;
  String? _error;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _sourceLanguage = _settings.sourceLanguage;
    _targetLanguage = _settings.targetLanguage;
  }

  Future<void> _pickAndTranslate() async {
    setState(() {
      _error = null;
      _result = null;
      _isProcessing = true;
      _statusMessage = '画像を選択中...';
    });

    try {
      // 1. Pick image
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedImagePath = picked.path;
        _statusMessage = 'テキストを抽出中 (OCR)...';
      });

      // 2. OCR
      final ocrText = await OcrService.instance.extractText(picked.path);

      if (!mounted) return;
      setState(() => _statusMessage = '翻訳中...');

      // 3. Translate
      final service = await resolveTranslationService(_settings);
      final result = await service.translate(
        text: ocrText,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _isProcessing = false;
        _statusMessage = '';
      });

      // 4. Save to history
      await DatabaseService.instance.insertTranslation(
        TranslationHistoryEntry(
          originalText: result.originalText,
          translatedText: result.translatedText,
          sourceLanguage: result.sourceLanguage,
          targetLanguage: result.targetLanguage,
          translationEngine: result.engine,
          screenshotPath: picked.path,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  void _swapLanguages() {
    if (_sourceLanguage == 'auto') return;
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
    });
    _settings.sourceLanguage = _sourceLanguage;
    _settings.targetLanguage = _targetLanguage;
    _settings.save();
  }

  void _onWordTap(String word, String sentenceContext) {
    if (_result == null) return;
    showWordDefinitionSheet(
      context,
      word: word,
      sentenceContext: sentenceContext,
      sourceLanguage: _result!.sourceLanguage,
      targetLanguage: _result!.targetLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Language selector
        LanguageSelector(
          sourceLanguage: _sourceLanguage,
          targetLanguage: _targetLanguage,
          onSourceChanged: (value) {
            setState(() => _sourceLanguage = value);
            _settings.sourceLanguage = value;
            _settings.save();
          },
          onTargetChanged: (value) {
            setState(() => _targetLanguage = value);
            _settings.targetLanguage = value;
            _settings.save();
          },
          onSwap: _swapLanguages,
        ),

        const SizedBox(height: 16),

        // Action button
        FilledButton.icon(
          onPressed: _isProcessing ? null : _pickAndTranslate,
          icon: Icon(_isProcessing ? Icons.hourglass_top : Icons.photo_library),
          label: Text(_isProcessing ? _statusMessage : '画像を選んで翻訳'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),

        const SizedBox(height: 16),

        // Processing indicator
        if (_isProcessing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),

        // Error
        if (_error != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Screenshot preview
        if (_selectedImagePath != null && !_isProcessing) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_selectedImagePath!),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Translation result
        if (_result != null) ...[
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
                      _result!.originalText,
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

          // Translated text (tappable words)
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
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _result!.engine == 'apple'
                              ? 'Apple翻訳'
                              : 'Cloud API',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 4),
                  Text(
                    '単語をタップすると意味を確認できます',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TappableText(
                    text: _result!.translatedText,
                    onWordTap: _onWordTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
