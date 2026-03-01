import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(text: _settings.cloudApiUrl);
    _apiKeyController = TextEditingController(text: _settings.cloudApiKey);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _settings.cloudApiUrl = _apiUrlController.text.trim();
    _settings.cloudApiKey = _apiKeyController.text.trim();
    await _settings.save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Translation Engine ──
          Text(
            '翻訳エンジン',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'apple',
                label: Text('Apple翻訳'),
                icon: Icon(Icons.phone_iphone),
              ),
              ButtonSegment(
                value: 'cloud',
                label: Text('Cloud API'),
                icon: Icon(Icons.cloud),
              ),
            ],
            selected: {_settings.translationEngine},
            onSelectionChanged: (selected) {
              setState(() => _settings.translationEngine = selected.first);
              _settings.save();
            },
          ),

          const SizedBox(height: 8),
          Text(
            _settings.translationEngine == 'apple'
                ? 'iOS 17.4以上で利用可能。オフライン対応、無料。'
                : 'OpenAI / Claude API を使用。API URL と API Key が必要。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),

          const SizedBox(height: 24),

          // ── Default Languages ──
          Text(
            'デフォルト言語',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            initialValue: _settings.sourceLanguage,
            decoration: const InputDecoration(
              labelText: '翻訳元',
              border: OutlineInputBorder(),
            ),
            items: kSupportedLanguages.map((lang) {
              return DropdownMenuItem(
                value: lang.code,
                child: Text(lang.name),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _settings.sourceLanguage = value);
                _settings.save();
              }
            },
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: _settings.targetLanguage,
            decoration: const InputDecoration(
              labelText: '翻訳先',
              border: OutlineInputBorder(),
            ),
            items: kTargetLanguages.map((lang) {
              return DropdownMenuItem(
                value: lang.code,
                child: Text(lang.name),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _settings.targetLanguage = value);
                _settings.save();
              }
            },
          ),

          const SizedBox(height: 24),

          // ── Cloud API Settings ──
          Text(
            'Cloud API 設定',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'OpenAI API または Anthropic API のエンドポイントを入力してください。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _apiUrlController,
            decoration: const InputDecoration(
              labelText: 'API URL',
              hintText: 'https://api.openai.com/v1/chat/completions',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),

          const SizedBox(height: 32),

          // ── Info ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '使い方',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. iPhoneの「設定 > アクセシビリティ > タッチ > 背面タップ」で'
                    'ショートカットを割り当てます。\n\n'
                    '2. ショートカットでスクリーンショットを撮影し、このアプリの'
                    '写真ライブラリに保存するよう設定します。\n\n'
                    '3. 翻訳タブで画像を選択すると、OCR → 翻訳 → 単語検索が利用できます。',
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
