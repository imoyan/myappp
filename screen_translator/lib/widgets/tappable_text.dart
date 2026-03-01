import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders text where each word is individually tappable.
///
/// Tapping a word calls [onWordTap] with the clean word and the surrounding
/// sentence for context.
class TappableText extends StatelessWidget {
  const TappableText({
    super.key,
    required this.text,
    required this.onWordTap,
    this.style,
  });

  final String text;
  final void Function(String word, String sentenceContext) onWordTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);

    final sentences = _splitSentences(text);
    final spans = <InlineSpan>[];

    for (final sentence in sentences) {
      final tokens = _tokenize(sentence);
      for (final token in tokens) {
        final cleanWord = _cleanWord(token);

        if (cleanWord.isEmpty) {
          // Whitespace or pure punctuation — not tappable
          spans.add(TextSpan(text: token, style: baseStyle));
        } else {
          spans.add(
            TextSpan(
              text: token,
              style: baseStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onWordTap(cleanWord, sentence.trim()),
            ),
          );
        }
      }
    }

    return SelectionArea(
      child: Text.rich(
        TextSpan(children: spans),
      ),
    );
  }

  /// Splits text into sentence-level chunks while preserving separators.
  List<String> _splitSentences(String text) {
    final result = <String>[];
    final pattern = RegExp(r'[^.!?\n]+[.!?\n]*');
    for (final match in pattern.allMatches(text)) {
      result.add(match.group(0)!);
    }
    if (result.isEmpty) result.add(text);
    return result;
  }

  /// Splits a sentence into tokens (words + separators).
  ///
  /// For Latin scripts: splits on whitespace boundaries.
  /// For CJK: each character becomes a separate token.
  List<String> _tokenize(String sentence) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool lastWasCjk = false;

    for (int i = 0; i < sentence.length; i++) {
      final char = sentence[i];
      final isCjk = _isCjkChar(char);
      final isWhitespace = char.trim().isEmpty;

      if (isWhitespace) {
        // Flush buffer
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
        lastWasCjk = false;
      } else if (isCjk) {
        // Flush any Latin buffer
        if (buffer.isNotEmpty && !lastWasCjk) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        // Each CJK character is a separate tappable token
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
        lastWasCjk = true;
      } else {
        // Latin character — accumulate into a word
        if (lastWasCjk && buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(char);
        lastWasCjk = false;
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// Returns the word with surrounding punctuation removed.
  String _cleanWord(String token) {
    return token.replaceAll(RegExp(r'^[^\w\u3000-\u9FFF\uF900-\uFAFF]+'), '')
        .replaceAll(RegExp(r'[^\w\u3000-\u9FFF\uF900-\uFAFF]+$'), '');
  }

  /// Checks if a character is in the CJK Unified Ideographs range or common
  /// Japanese/Korean ranges.
  bool _isCjkChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x3000 && code <= 0x9FFF) ||
        (code >= 0xF900 && code <= 0xFAFF) ||
        (code >= 0xAC00 && code <= 0xD7AF) || // Korean Syllables
        (code >= 0x1100 && code <= 0x11FF); // Korean Jamo
  }
}
