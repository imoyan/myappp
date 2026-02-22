import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiTarget { onDevice, localApi, cloudApi }

class AnalysisResult {
  const AnalysisResult({
    required this.appName,
    required this.timeText,
    required this.timeType,
    required this.confidence,
    required this.rawText,
  });

  final String appName;
  final String timeText;
  final String timeType;
  final double confidence;
  final String rawText;
}

void main() {
  runApp(const BacktapAnalyzerApp());
}

class BacktapAnalyzerApp extends StatelessWidget {
  const BacktapAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backtap Analyzer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6B50)),
      ),
      home: const AnalyzerHomePage(),
    );
  }
}

class AnalyzerHomePage extends StatefulWidget {
  const AnalyzerHomePage({super.key});

  @override
  State<AnalyzerHomePage> createState() => _AnalyzerHomePageState();
}

class _AnalyzerHomePageState extends State<AnalyzerHomePage> {
  static const MethodChannel _ocrChannel = MethodChannel('backtap_analyzer/ocr');

  final TextEditingController _localApiController =
      TextEditingController(text: 'http://192.168.0.10:8000/analyze');
  final TextEditingController _cloudApiController =
      TextEditingController(text: 'https://example.com/v1/analyze');
  final TextEditingController _cloudApiKeyController = TextEditingController();

  AiTarget _target = AiTarget.onDevice;
  bool _saveScreenshot = false;
  bool _isAnalyzing = false;
  String? _selectedImagePath;
  AnalysisResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _localApiController.dispose();
    _cloudApiController.dispose();
    _cloudApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final targetIndex = prefs.getInt('ai_target') ?? AiTarget.onDevice.index;
    if (targetIndex >= 0 && targetIndex < AiTarget.values.length) {
      _target = AiTarget.values[targetIndex];
    }
    _saveScreenshot = prefs.getBool('save_screenshot') ?? false;
    _localApiController.text = prefs.getString('local_api_url') ?? _localApiController.text;
    _cloudApiController.text = prefs.getString('cloud_api_url') ?? _cloudApiController.text;
    _cloudApiKeyController.text = prefs.getString('cloud_api_key') ?? '';

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_target', _target.index);
    await prefs.setBool('save_screenshot', _saveScreenshot);
    await prefs.setString('local_api_url', _localApiController.text.trim());
    await prefs.setString('cloud_api_url', _cloudApiController.text.trim());
    await prefs.setString('cloud_api_key', _cloudApiKeyController.text.trim());
  }

  Future<void> _pickAndAnalyzeImage() async {
    setState(() {
      _error = null;
      _result = null;
    });

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedImagePath = picked.path;
      _isAnalyzing = true;
    });

    try {
      final ocrText = await _extractText(picked.path);
      final result = await _analyzeText(ocrText, picked.path);
      setState(() {
        _result = result;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }

    await _saveSettings();
  }

  Future<String> _extractText(String imagePath) async {
    if (!Platform.isIOS) {
      throw Exception('MVPではOCRはiOS実装です。');
    }

    final text = await _ocrChannel.invokeMethod<String>('extractTextFromImage', {
      'path': imagePath,
    });

    if (text == null || text.trim().isEmpty) {
      throw Exception('文字抽出に失敗しました。');
    }

    return text;
  }

  Future<AnalysisResult> _analyzeText(String ocrText, String imagePath) async {
    switch (_target) {
      case AiTarget.onDevice:
        return _analyzeOnDevice(ocrText);
      case AiTarget.localApi:
        return _analyzeViaHttp(_localApiController.text.trim(), '', ocrText, imagePath);
      case AiTarget.cloudApi:
        return _analyzeViaHttp(
          _cloudApiController.text.trim(),
          _cloudApiKeyController.text.trim(),
          ocrText,
          imagePath,
        );
    }
  }

  AnalysisResult _analyzeOnDevice(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final appName = _guessAppName(lines);
    final time = _guessTime(lines);

    return AnalysisResult(
      appName: appName,
      timeText: time.$1,
      timeType: time.$2,
      confidence: time.$3,
      rawText: text,
    );
  }

  Future<AnalysisResult> _analyzeViaHttp(
    String url,
    String apiKey,
    String text,
    String imagePath,
  ) async {
    if (url.isEmpty) {
      throw Exception('API URLが未設定です。');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'text': text,
        'save_screenshot': _saveScreenshot,
        'image_path': imagePath,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('APIエラー: ${response.statusCode} ${response.body}');
    }

    final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
    return AnalysisResult(
      appName: (json['app_name'] ?? 'unknown').toString(),
      timeText: (json['time_text'] ?? 'unknown').toString(),
      timeType: (json['time_type'] ?? 'unknown').toString(),
      confidence: ((json['confidence'] ?? 0.5) as num).toDouble(),
      rawText: text,
    );
  }

  String _guessAppName(List<String> lines) {
    for (final line in lines.take(6)) {
      if (line.length >= 2 && line.length <= 40) {
        return line;
      }
    }
    return 'unknown';
  }

  (String, String, double) _guessTime(List<String> lines) {
    final combined = lines.join(' ');

    final hhmm = RegExp(r'\b([01]?\d|2[0-3]):[0-5]\d\b');
    final countdown = RegExp(r'(残り\s*\d+\s*(分|時間|秒)|\b\d+\s*(m|min|h|s)\b)', caseSensitive: false);
    final availableAt = RegExp(r'(from|available|open|解禁|開始)\s*[:：]?\s*([\d:/\-\sAPMapm]+)');

    final hhmmMatch = hhmm.firstMatch(combined);
    if (hhmmMatch != null) {
      return (hhmmMatch.group(0)!, 'clock', 0.85);
    }

    final countdownMatch = countdown.firstMatch(combined);
    if (countdownMatch != null) {
      return (countdownMatch.group(0)!, 'countdown', 0.8);
    }

    final availableAtMatch = availableAt.firstMatch(combined);
    if (availableAtMatch != null) {
      return (availableAtMatch.group(0)!, 'available_at', 0.7);
    }

    return ('not_found', 'unknown', 0.2);
  }

  String _targetLabel(AiTarget target) {
    switch (target) {
      case AiTarget.onDevice:
        return 'On-device (iPhone内)';
      case AiTarget.localApi:
        return 'Local LLM API';
      case AiTarget.cloudApi:
        return 'Cloud API';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backtap Analyzer MVP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'iPhoneの「背面タップ」は設定アプリでショートカットに割り当て、'
            'そのショートカットからこのアプリに画像を渡す構成を想定しています。',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AiTarget>(
            initialValue: _target,
            decoration: const InputDecoration(
              labelText: '解析先',
              border: OutlineInputBorder(),
            ),
            items: AiTarget.values
                .map(
                  (t) => DropdownMenuItem<AiTarget>(
                    value: t,
                    child: Text(_targetLabel(t)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _target = value;
              });
              _saveSettings();
            },
          ),
          const SizedBox(height: 12),
          if (_target == AiTarget.localApi) ...[
            TextField(
              controller: _localApiController,
              decoration: const InputDecoration(
                labelText: 'Local API URL',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveSettings(),
            ),
            const SizedBox(height: 12),
          ],
          if (_target == AiTarget.cloudApi) ...[
            TextField(
              controller: _cloudApiController,
              decoration: const InputDecoration(
                labelText: 'Cloud API URL',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveSettings(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cloudApiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Cloud API Key',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveSettings(),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile(
            title: const Text('スクショを保存する'),
            value: _saveScreenshot,
            onChanged: (value) {
              setState(() {
                _saveScreenshot = value;
              });
              _saveSettings();
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _isAnalyzing ? null : _pickAndAnalyzeImage,
            icon: const Icon(Icons.photo_library),
            label: Text(_isAnalyzing ? '解析中...' : 'スクショ画像を選んで解析'),
          ),
          const SizedBox(height: 16),
          if (_selectedImagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_selectedImagePath!), height: 240, fit: BoxFit.cover),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App: ${_result!.appName}'),
                    Text('Time: ${_result!.timeText}'),
                    Text('Type: ${_result!.timeType}'),
                    Text('Confidence: ${_result!.confidence.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    const Text('OCR Raw Text:'),
                    const SizedBox(height: 4),
                    Text(_result!.rawText),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
