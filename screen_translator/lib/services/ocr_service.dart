import 'dart:io';

import 'package:flutter/services.dart';

class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  static const _channel = MethodChannel('screen_translator/ocr');

  /// Extract text from an image file using iOS Vision OCR.
  ///
  /// Returns the recognized text as a single string with lines separated by
  /// newline characters.
  ///
  /// Throws an [Exception] if OCR is not available on the current platform or
  /// if text extraction fails.
  Future<String> extractText(String imagePath) async {
    if (!Platform.isIOS) {
      throw Exception('OCRは現在iOSのみ対応しています。');
    }

    try {
      final text = await _channel.invokeMethod<String>(
        'extractTextFromImage',
        {'path': imagePath},
      );

      if (text == null || text.trim().isEmpty) {
        throw Exception('画像からテキストを抽出できませんでした。');
      }

      return text;
    } on PlatformException catch (e) {
      throw Exception('OCRエラー: ${e.message}');
    }
  }
}
