import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_analysis_result.dart';
import '../models/translation_history_entry.dart';
import '../services/action_routing_service.dart';
import '../services/app_detection_service.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../widgets/app_detection_card.dart';
import '../widgets/restriction_card.dart';
import '../widgets/tappable_text.dart';
import '../widgets/word_definition_sheet.dart';

class SmartCaptureScreen extends StatefulWidget {
  const SmartCaptureScreen({super.key});

  @override
  State<SmartCaptureScreen> createState() => _SmartCaptureScreenState();
}

class _SmartCaptureScreenState extends State<SmartCaptureScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';
  String? _selectedImagePath;
  AppAnalysisResult? _appAnalysis;
  ActionResult? _actionResult;
  String? _error;
  bool _showOriginal = false;

  Future<void> _pickAndAnalyse() async {
    setState(() {
      _error = null;
      _appAnalysis = null;
      _actionResult = null;
      _isProcessing = true;
      _statusMessage = '画像を選択中...';
    });

    try {
      // 1. Pick image
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        _selectedImagePath = picked.path;
        _statusMessage = 'テキストを抽出中 (OCR)...';
      });

      // 2. OCR
      final ocrText = await OcrService.instance.extractText(picked.path);

      setState(() => _statusMessage = 'アプリを判定中...');

      // 3. App detection
      final analysis =
          await AppDetectionService.instance.analyse(ocrText: ocrText);

      setState(() {
        _appAnalysis = analysis;
        _statusMessage = 'アクションを実行中...';
      });

      // 4. Auto-route action
      final result = await ActionRoutingService.instance.route(
        analysis: analysis,
        ocrText: ocrText,
        imagePath: picked.path,
      );

      // 5. Save to translation history if translated
      if (result.translationResult != null) {
        await DatabaseService.instance.insertTranslation(
          TranslationHistoryEntry(
            originalText: result.translationResult!.originalText,
            translatedText: result.translationResult!.translatedText,
            sourceLanguage: result.translationResult!.sourceLanguage,
            targetLanguage: result.translationResult!.targetLanguage,
            translationEngine: result.translationResult!.engine,
            screenshotPath: picked.path,
            createdAt: DateTime.now(),
          ),
        );
      }

      setState(() {
        _actionResult = result;
        _isProcessing = false;
        _statusMessage = '';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  void _onWordTap(String word, String sentenceContext) {
    final tr = _actionResult?.translationResult;
    if (tr == null) return;
    showWordDefinitionSheet(
      context,
      word: word,
      sentenceContext: sentenceContext,
      sourceLanguage: tr.sourceLanguage,
      targetLanguage: tr.targetLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Action button
        FilledButton.icon(
          onPressed: _isProcessing ? null : _pickAndAnalyse,
          icon: Icon(
              _isProcessing ? Icons.hourglass_top : Icons.photo_camera),
          label: Text(_isProcessing ? _statusMessage : '画像を選んで解析'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
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
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // App detection result
        if (_appAnalysis != null) ...[
          AppDetectionCard(
            analysis: _appAnalysis!,
            onTranslate: _actionResult?.translationResult != null
                ? null
                : () {
                    // Re-run as translation
                  },
            onCheckRestriction: _appAnalysis!.restriction != null
                ? () {
                    // Already showing restriction below
                  }
                : null,
          ),
          const SizedBox(height: 8),
        ],

        // Action result message
        if (_actionResult?.message != null) ...[
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _actionResult!.type == ActionType.restrictionDetected
                        ? Icons.warning_amber
                        : _actionResult!.type == ActionType.ingressGlyph
                            ? Icons.games
                            : Icons.info_outline,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _actionResult!.message!,
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Restriction card
        if (_actionResult?.restriction != null)
          RestrictionCard(restriction: _actionResult!.restriction!),

        // Translation result
        if (_actionResult?.translationResult != null) ...[
          const SizedBox(height: 8),

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
                      _actionResult!.translationResult!.originalText,
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
                    text: _actionResult!.translationResult!.translatedText,
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
