// ABOUTME: Splits timed caption text into words with their own timings.
// ABOUTME: Spreads a segment's duration over its words by character count.

import 'package:caption_generator/src/models/caption_segment.dart';

/// Splits [text] into its whitespace-separated words and spreads the time
/// from [start] to [end] over them.
///
/// Each word gets a share of the time proportional to its length, so a long
/// word lasts longer than a short one — a rough stand-in for speech when the
/// recognizer reported no per-word timing (a server transcript only times
/// whole cues). The words follow each other without gaps; the last one ends
/// exactly at [end]. Timings are whole milliseconds.
///
/// Returns an empty list when [text] has no words.
List<CaptionSegment> spreadCaptionWords(
  String text, {
  required Duration start,
  required Duration end,
}) {
  final words = splitCaptionWords(text);
  if (words.isEmpty) return const [];

  final totalChars = words.fold<int>(0, (sum, word) => sum + word.length);
  final startMs = start.inMilliseconds;
  final spanMs = end.inMilliseconds - startMs;
  final spread = <CaptionSegment>[];
  var charsBefore = 0;
  var wordStartMs = startMs;
  for (final word in words) {
    charsBefore += word.length;
    final wordEndMs = startMs + (spanMs * charsBefore / totalChars).round();
    spread.add(
      CaptionSegment(
        text: word,
        start: Duration(milliseconds: wordStartMs),
        end: Duration(milliseconds: wordEndMs),
      ),
    );
    wordStartMs = wordEndMs;
  }
  return spread;
}

/// The single words of [segment] with their timings: its own
/// [CaptionSegment.words] when it
/// has them, itself when it is one word, or [spreadCaptionWords] otherwise.
List<CaptionSegment> captionWordsOf(CaptionSegment segment) {
  if (segment.words.isNotEmpty) return segment.words;
  final text = segment.text.trim();
  if (text.isNotEmpty && !text.contains(_whitespace)) {
    return [
      CaptionSegment(text: text, start: segment.start, end: segment.end),
    ];
  }
  return spreadCaptionWords(text, start: segment.start, end: segment.end);
}

/// The whitespace-separated words of [text], in order.
///
/// Punctuation stays attached to its word, the way it is highlighted.
List<String> splitCaptionWords(String text) =>
    text.split(_whitespace).where((word) => word.isNotEmpty).toList();

final _whitespace = RegExp(r'\s+');
