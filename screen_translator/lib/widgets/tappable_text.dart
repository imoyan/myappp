import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders text where each word is individually tappable.
///
/// Tapping a word calls [onWordTap] with the clean word and the surrounding
/// sentence for context.
class TappableText extends StatefulWidget {
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
  State<TappableText> createState() => _TappableTextState();
}

class _TappableTextState extends State<TappableText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dispose old recognizers before rebuilding.
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);

    final sentences = _splitSentences(widget.text);
    final spans = <InlineSpan>[];

    for (final sentence in sentences) {
      final tokens = _tokenize(sentence);
      for (final token in tokens) {
        final cleanWord = _cleanWord(token);

        if (cleanWord.isEmpty) {
          // Whitespace or pure punctuation — not tappable
          spans.add(TextSpan(text: token, style: baseStyle));
        } else {
          final recognizer = TapGestureRecognizer()
            ..onTap = () => widget.onWordTap(cleanWord, sentence.trim());
          _recognizers.add(recognizer);
          spans.add(
            TextSpan(
              text: token,
              style: baseStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              recognizer: recognizer,
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
  /// Uses runes to avoid splitting surrogate pairs (emoji, etc.).
  List<String> _tokenize(String sentence) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool lastWasCjk = false;

    for (final rune in sentence.runes) {
      final char = String.fromCharCode(rune);
      final isCjk = _isCjkCodePoint(rune);
      final isWhitespace = char.trim().isEmpty;

      if (isWhitespace) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
        lastWasCjk = false;
      } else if (isCjk) {
        if (buffer.isNotEmpty && !lastWasCjk) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
        lastWasCjk = true;
      } else {
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
    return token
        .replaceAll(RegExp(r'^[^\w\u3000-\u9FFF\uF900-\uFAFF]+'), '')
        .replaceAll(RegExp(r'[^\w\u3000-\u9FFF\uF900-\uFAFF]+$'), '');
  }

  /// Checks if a code point is in the CJK Unified Ideographs range or common
  /// Japanese/Korean ranges.
  bool _isCjkCodePoint(int code) {
    return (code >= 0x3000 && code <= 0x9FFF) ||
        (code >= 0xF900 && code <= 0xFAFF) ||
        (code >= 0xAC00 && code <= 0xD7AF) || // Korean Syllables
        (code >= 0x1100 && code <= 0x11FF); // Korean Jamo
  }
}
