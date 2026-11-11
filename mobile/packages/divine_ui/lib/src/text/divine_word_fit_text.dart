// ABOUTME: Text that follows the system text size until its widest word would
// ABOUTME: no longer fit on a line, so large text never splits a word.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A [Text] that never splits a word across two lines.
///
/// Text wraps between words, but a word wider than the line is cut wherever
/// it reaches the edge. Large system text sizes run into this first, and
/// languages with long compound words run into it hardest: at the largest iOS
/// size on a small phone, German "Berechtigungsfehler" broke into
/// "Berechtigu" and "ngsfehler".
///
/// This scales with the system text size like any [Text] until the widest word
/// would no longer fit on one line, and stops growing there. A word that is
/// already too wide at the normal size keeps the normal size; it does not
/// shrink below it.
class DivineWordFitText extends StatelessWidget {
  /// Creates text that keeps each of its words on one line.
  const DivineWordFitText(this.data, {this.style, this.textAlign, super.key});

  /// The text to display.
  final String data;

  /// The style, merged with the ambient [DefaultTextStyle] as in [Text].
  final TextStyle? style;

  /// How the lines are aligned horizontally.
  final TextAlign? textAlign;

  static const _boldText = TextStyle(fontWeight: FontWeight.bold);

  /// Letters and digits. Two touching segments that both contain them are
  /// separate words even without a space between them, which is how Chinese
  /// and Japanese are written. Punctuation and symbols stay with the word
  /// they touch, since a line cannot break right before a closing bracket or
  /// a hyphen.
  static final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Hyphens a line can break after, so the part of a hyphenated compound
  /// after one is a word of its own: "6-Sekunden-Format" wraps as
  /// "6-Sekunden-" and "Format".
  static final _hyphen = RegExp('^[-\u2010\u2013]\$');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        data,
        style: style,
        textAlign: textAlign,
        textScaler: _textScaler(context, constraints.maxWidth),
      ),
    );
  }

  TextScaler _textScaler(BuildContext context, double maxWidth) {
    // Measured in the style the [Text] below will draw, including the weight
    // it switches to when the platform asks for bold text.
    final effectiveStyle = DefaultTextStyle.of(context).style
        .merge(style)
        .merge(MediaQuery.boldTextOf(context) ? _boldText : null);
    final widestWord = _widestWordWidth(
      effectiveStyle,
      Directionality.of(context),
      Localizations.maybeLocaleOf(context),
    );
    // Width grows with the font size, and the theme's letter spacing does not
    // scale, so the ratio at the normal size is a safe upper bound. The pixel
    // of slack keeps rounding from putting the widest word a hair over.
    // Infinite with no words or no width limit, which leaves the scale as is.
    final maxScaleFactor = (maxWidth - 1) / widestWord;
    return MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: math.max(1, maxScaleFactor));
  }

  /// Width at the normal text size of the widest run of text that cannot be
  /// broken across lines.
  double _widestWordWidth(
    TextStyle style,
    TextDirection textDirection,
    Locale? locale,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: data, style: style),
      textDirection: textDirection,
      locale: locale,
    )..layout();

    var widest = 0.0;
    int? wordStart;
    var wordEnd = 0;
    var previousIsLetters = false;

    void endWord() {
      if (wordStart case final start?) {
        final boxes = painter.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: wordEnd),
        );
        final width = boxes.fold<double>(
          0,
          (sum, box) => sum + box.right - box.left,
        );
        widest = math.max(widest, width);
      }
      wordStart = null;
    }

    var offset = 0;
    while (offset < data.length) {
      final segment = painter.getWordBoundary(TextPosition(offset: offset));
      final text = segment.textInside(data);
      final isLetters = _wordCharacter.hasMatch(text);
      if (text.trim().isEmpty || (isLetters && previousIsLetters)) endWord();
      if (text.trim().isNotEmpty) {
        wordStart ??= segment.start;
        wordEnd = segment.end;
      }
      if (_hyphen.hasMatch(text)) endWord();
      previousIsLetters = isLetters;
      offset = math.max(segment.end, offset + 1);
    }
    endWord();
    painter.dispose();
    return widest;
  }
}
