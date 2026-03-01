import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// A row with source language dropdown, swap button, and target language
/// dropdown.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onSwap,
  });

  final String sourceLanguage;
  final String targetLanguage;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Source language
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: sourceLanguage,
            decoration: const InputDecoration(
              labelText: '翻訳元',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true,
            items: kSupportedLanguages.map((lang) {
              return DropdownMenuItem(
                value: lang.code,
                child: Text(lang.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) onSourceChanged(value);
            },
          ),
        ),

        // Swap button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IconButton(
            onPressed: sourceLanguage == 'auto' ? null : onSwap,
            icon: const Icon(Icons.swap_horiz),
            tooltip: '言語を入れ替え',
          ),
        ),

        // Target language
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: targetLanguage,
            decoration: const InputDecoration(
              labelText: '翻訳先',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true,
            items: kTargetLanguages.map((lang) {
              return DropdownMenuItem(
                value: lang.code,
                child: Text(lang.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) onTargetChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
