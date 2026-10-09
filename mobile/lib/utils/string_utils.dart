// ABOUTME: String utility functions for formatting and sanitization
// ABOUTME: Provides compact-number formatting and UTF-16 sanitization

import 'package:count_formatter/count_formatter.dart';
import 'package:text_sanitizer/text_sanitizer.dart' as text_sanitizer;

/// Utility functions for string formatting and sanitization.
class StringUtils {
  /// Format a number to a compact, locale-aware string.
  ///
  /// Delegates to [CountFormatter.formatCompact] for consistent,
  /// locale-aware number formatting across the app.
  static String formatCompactNumber(int number, {String? locale}) =>
      CountFormatter.formatCompact(number, locale: locale);

  /// Render a compact-formatted count through an ICU plural lookup.
  ///
  /// [plural] is a generated `AppLocalizations` getter whose first parameter
  /// selects the plural form and whose second is the displayed numeral, so the
  /// grammar follows the raw [value] while the display stays compact (`1.2K`).
  /// Evaluating [value] once keeps the two provably consistent.
  static String compactPlural(
    int value,
    String Function(int, String) plural,
  ) => plural(value, formatCompactNumber(value));

  /// Strip unpaired UTF-16 surrogate code units from [input].
  ///
  /// Flutter's text rendering asserts that strings are well-formed UTF-16.
  /// Sender-controlled content reaching the app via JSON `\uXXXX` escapes
  /// (notably NIP-17 DM rumor bodies after `jsonDecode`) can carry
  /// unpaired surrogates that survive transport and crash the renderer
  /// with `Invalid argument(s): string is not well-formed UTF-16`. Apply
  /// this at render boundaries that display untrusted text.
  ///
  /// Returns [input] unchanged when it is already well-formed.
  static String sanitizeUtf16(String input) =>
      text_sanitizer.sanitizeUtf16(input);

  /// Removes every line of [input] that renders as empty.
  ///
  /// Compact surfaces cap text at a few lines, so a blank line there spends
  /// a whole line on nothing and reads as stray spacing. A line counts as
  /// blank when it holds only whitespace or invisible filler such as a
  /// zero-width space, which captions pasted from other apps use as spacers.
  static String removeBlankLines(String input) => input
      .split(_lineBreak)
      .where((line) => !_blankLine.hasMatch(line))
      .join('\n');

  /// Every hard break Flutter's text layout honours, not only `\n`.
  static final _lineBreak = RegExp(
    r'\r\n|[\n\r\u{B}\u{C}\u{85}\u{2028}\u{2029}]',
    unicode: true,
  );

  /// U+2800 (braille blank) draws nothing but Unicode does not mark it
  /// ignorable.
  static final _blankLine = RegExp(
    r'^[\p{White_Space}\p{Default_Ignorable_Code_Point}\u{2800}]*$',
    unicode: true,
  );
}
