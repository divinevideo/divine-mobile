// ABOUTME: Tests for grouping word-level segments into caption cues.
// ABOUTME: Covers gap, length, and duration splits plus input validation.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';

CaptionSegment _word(String text, int startMs, int endMs) => CaptionSegment(
  text: text,
  start: Duration(milliseconds: startMs),
  end: Duration(milliseconds: endMs),
);

/// [cues] without their words, for the tests about where cues split.
List<CaptionSegment> _withoutWords(List<CaptionSegment> cues) => [
  for (final cue in cues)
    CaptionSegment(text: cue.text, start: cue.start, end: cue.end),
];

void main() {
  group('groupCaptionSegments', () {
    test('returns an empty list for empty input', () {
      expect(groupCaptionSegments(const []), isEmpty);
    });

    test('keeps a single word as one cue', () {
      final cues = groupCaptionSegments([_word('hello', 0, 400)]);

      expect(_withoutWords(cues), equals([_word('hello', 0, 400)]));
    });

    test('merges words within all limits into one cue', () {
      final cues = groupCaptionSegments([
        _word('hello', 0, 400),
        _word('there', 450, 800),
        _word('world', 900, 1300),
      ]);

      expect(
        _withoutWords(cues),
        equals([_word('hello there world', 0, 1300)]),
      );
    });

    test('starts a new cue after a long silence gap', () {
      final cues = groupCaptionSegments([
        _word('hello', 0, 400),
        _word('world', 3000, 3400),
      ]);

      expect(
        _withoutWords(cues),
        equals([_word('hello', 0, 400), _word('world', 3000, 3400)]),
      );
    });

    test('starts a new cue when the character limit would be exceeded', () {
      final cues = groupCaptionSegments(
        [
          _word('aaaa', 0, 200),
          _word('bbbb', 250, 450),
          _word('cccc', 500, 700),
        ],
        maxCharactersPerCaption: 9,
      );

      expect(
        _withoutWords(cues),
        equals([_word('aaaa bbbb', 0, 450), _word('cccc', 500, 700)]),
      );
    });

    test('starts a new cue when the duration limit would be exceeded', () {
      final cues = groupCaptionSegments(
        [
          _word('one', 0, 400),
          _word('two', 900, 1300),
          _word('three', 1800, 2200),
        ],
        maxCaptionDuration: const Duration(milliseconds: 1500),
      );

      expect(
        _withoutWords(cues),
        equals([_word('one two', 0, 1300), _word('three', 1800, 2200)]),
      );
    });

    test('keeps a single word longer than the character limit as own cue', () {
      final cues = groupCaptionSegments(
        [_word('supercalifragilistic', 0, 900), _word('yes', 950, 1200)],
        maxCharactersPerCaption: 10,
      );

      expect(
        _withoutWords(cues),
        equals([
          _word('supercalifragilistic', 0, 900),
          _word('yes', 950, 1200),
        ]),
      );
    });

    test('sorts unsorted input by start time before grouping', () {
      final cues = groupCaptionSegments([
        _word('world', 450, 800),
        _word('hello', 0, 400),
      ]);

      expect(_withoutWords(cues), equals([_word('hello world', 0, 800)]));
    });

    test('preserves caller order for words sharing a start time', () {
      final cues = groupCaptionSegments([
        _word('New', 1000, 1100),
        _word('York', 1000, 1200),
      ]);

      expect(_withoutWords(cues), equals([_word('New York', 1000, 1200)]));
    });

    test('starts a new cue after sentence-final punctuation', () {
      final cues = groupCaptionSegments([
        _word('Hello,', 0, 300),
        _word('a', 350, 500),
        _word('test.', 550, 900),
        _word('Can', 950, 1100),
        _word('you?', 1150, 1400),
        _word('Yes', 1450, 1700),
      ]);

      expect(
        _withoutWords(cues),
        equals([
          _word('Hello, a test.', 0, 900),
          _word('Can you?', 950, 1400),
          _word('Yes', 1450, 1700),
        ]),
      );
    });

    test('treats punctuation wrapped in closing quotes as sentence end', () {
      final cues = groupCaptionSegments([
        _word('"Stop!"', 0, 400),
        _word('she', 450, 600),
        _word('said', 650, 900),
      ]);

      expect(
        _withoutWords(cues),
        equals([_word('"Stop!"', 0, 400), _word('she said', 450, 900)]),
      );
    });

    test('keeps sentences together when splitAtSentenceEnd is false', () {
      final cues = groupCaptionSegments(
        [
          _word('One.', 0, 300),
          _word('Two.', 350, 600),
        ],
        splitAtSentenceEnd: false,
      );

      expect(_withoutWords(cues), equals([_word('One. Two.', 0, 600)]));
    });

    test('does not split on mid-sentence commas', () {
      final cues = groupCaptionSegments([
        _word('Well,', 0, 300),
        _word('okay', 350, 600),
      ]);

      expect(_withoutWords(cues), equals([_word('Well, okay', 0, 600)]));
    });

    test('throws $ArgumentError for a non-positive character limit', () {
      expect(
        () => groupCaptionSegments(const [], maxCharactersPerCaption: 0),
        throwsArgumentError,
      );
    });

    test('throws $ArgumentError for a non-positive duration limit', () {
      expect(
        () => groupCaptionSegments(const [], maxCaptionDuration: Duration.zero),
        throwsArgumentError,
      );
    });

    test('throws $ArgumentError for a non-positive silence gap', () {
      expect(
        () => groupCaptionSegments(const [], maxSilenceGap: Duration.zero),
        throwsArgumentError,
      );
    });

    group('words', () {
      test('keeps each recognized word with its own timing', () {
        final cues = groupCaptionSegments([
          _word('hello', 0, 400),
          _word('there', 450, 800),
          _word('world', 3000, 3400),
        ]);

        expect(cues.map((cue) => cue.words), [
          [_word('hello', 0, 400), _word('there', 450, 800)],
          [_word('world', 3000, 3400)],
        ]);
      });

      test('spreads the words of a multi-word segment over its span', () {
        final cues = groupCaptionSegments([
          _word('hi there', 0, 700),
          _word('you', 800, 1100),
        ]);

        expect(cues.single.words, [
          _word('hi', 0, 200),
          _word('there', 200, 700),
          _word('you', 800, 1100),
        ]);
      });
    });
  });
}
