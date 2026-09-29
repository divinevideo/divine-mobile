// ABOUTME: Groups word-level transcription segments into caption cues.
// ABOUTME: Splits on silence gaps, character limits, and cue duration limits.

import 'package:caption_generator/src/caption_word_timing.dart';
import 'package:caption_generator/src/models/caption_segment.dart';

/// Merges word-level [segments] into display-ready caption cues.
///
/// Words are joined with single spaces into one cue until a boundary starts
/// a new cue:
///
/// * [maxCharactersPerCaption] — cue text length ceiling. A single word
///   longer than the ceiling still becomes its own cue.
/// * [maxCaptionDuration] — how long one cue may span on the timeline.
/// * [maxSilenceGap] — a pause between words longer than this starts a new
///   cue, so captions do not linger across silence.
/// * [splitAtSentenceEnd] — start a new cue after a word ending in
///   sentence-final punctuation (`.` `!` `?` `…`). Recognizer word timings
///   often smear speech pauses away, so punctuation is the more reliable
///   break signal on punctuated transcripts; unpunctuated transcripts are
///   unaffected.
///
/// Input order does not matter; segments are sorted by start time first, with
/// caller order preserved for words that share a start (the sort is stable).
///
/// Each cue keeps its words with their own timings in
/// [CaptionSegment.words]. An input segment holding several words, such as a
/// cue from a server transcript, is split with [captionWordsOf].
///
/// Throws an [ArgumentError] when a limit is not positive.
List<CaptionSegment> groupCaptionSegments(
  List<CaptionSegment> segments, {
  int maxCharactersPerCaption = 42,
  Duration maxCaptionDuration = const Duration(seconds: 5),
  Duration maxSilenceGap = const Duration(milliseconds: 800),
  bool splitAtSentenceEnd = true,
}) {
  if (maxCharactersPerCaption < 1) {
    throw ArgumentError.value(
      maxCharactersPerCaption,
      'maxCharactersPerCaption',
      'must be positive',
    );
  }
  if (maxCaptionDuration <= Duration.zero) {
    throw ArgumentError.value(
      maxCaptionDuration,
      'maxCaptionDuration',
      'must be positive',
    );
  }
  if (maxSilenceGap <= Duration.zero) {
    throw ArgumentError.value(
      maxSilenceGap,
      'maxSilenceGap',
      'must be positive',
    );
  }
  if (segments.isEmpty) return const [];

  // Dart's List.sort is not stable, so decorate with the original index and
  // use it as a tie-break to keep equal-start words in caller order.
  final indexed =
      [
        for (var i = 0; i < segments.length; i++)
          (index: i, segment: segments[i]),
      ]..sort((a, b) {
        final byStart = a.segment.start.compareTo(b.segment.start);
        return byStart != 0 ? byStart : a.index.compareTo(b.index);
      });
  final sorted = [for (final entry in indexed) entry.segment];
  final cues = <CaptionSegment>[];
  final text = StringBuffer(sorted.first.text);
  final words = [...captionWordsOf(sorted.first)];
  var cueStart = sorted.first.start;
  var cueEnd = sorted.first.end;
  var previousEndsSentence = _endsSentence(sorted.first.text);

  for (final segment in sorted.skip(1)) {
    final gap = segment.start - cueEnd;
    final mergedLength = text.length + 1 + segment.text.length;
    final mergedDuration = segment.end - cueStart;
    final startsNewCue =
        (splitAtSentenceEnd && previousEndsSentence) ||
        gap > maxSilenceGap ||
        mergedLength > maxCharactersPerCaption ||
        mergedDuration > maxCaptionDuration;
    if (startsNewCue) {
      cues.add(
        CaptionSegment(
          text: text.toString(),
          start: cueStart,
          end: cueEnd,
          words: List.unmodifiable(words),
        ),
      );
      text
        ..clear()
        ..write(segment.text);
      words
        ..clear()
        ..addAll(captionWordsOf(segment));
      cueStart = segment.start;
      cueEnd = segment.end;
    } else {
      text
        ..write(' ')
        ..write(segment.text);
      words.addAll(captionWordsOf(segment));
      cueEnd = segment.end > cueEnd ? segment.end : cueEnd;
    }
    previousEndsSentence = _endsSentence(segment.text);
  }
  cues.add(
    CaptionSegment(
      text: text.toString(),
      start: cueStart,
      end: cueEnd,
      words: List.unmodifiable(words),
    ),
  );
  return cues;
}

/// Whether [text] ends a sentence: sentence-final punctuation, optionally
/// followed by closing quotes or brackets.
bool _endsSentence(String text) {
  const closers = {'"', "'", '”', '’', '»', '“', ')', ']'};
  const sentenceEnders = {'.', '!', '?', '…'};
  var index = text.length - 1;
  while (index >= 0 && closers.contains(text[index])) {
    index--;
  }
  return index >= 0 && sentenceEnders.contains(text[index]);
}
