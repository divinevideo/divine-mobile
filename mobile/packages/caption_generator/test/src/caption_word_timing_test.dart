// ABOUTME: Tests for splitting timed caption text into timed words.
// ABOUTME: Covers length-weighted spreading and the per-segment word lookup.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';

CaptionSegment _word(String text, int startMs, int endMs) => CaptionSegment(
  text: text,
  start: Duration(milliseconds: startMs),
  end: Duration(milliseconds: endMs),
);

void main() {
  group('splitCaptionWords', () {
    test('splits on any whitespace and keeps punctuation on its word', () {
      expect(splitCaptionWords(' Well,  okay\nthen! '), [
        'Well,',
        'okay',
        'then!',
      ]);
    });

    test('returns no words for blank text', () {
      expect(splitCaptionWords(' \t '), isEmpty);
    });
  });

  group('spreadCaptionWords', () {
    test('gives each word a share of the time by its length', () {
      final words = spreadCaptionWords(
        'a bcd ef',
        start: const Duration(seconds: 1),
        end: const Duration(milliseconds: 1600),
      );

      expect(words, [
        _word('a', 1000, 1100),
        _word('bcd', 1100, 1400),
        _word('ef', 1400, 1600),
      ]);
    });

    test('ignores surrounding and repeated whitespace', () {
      final words = spreadCaptionWords(
        '  hi \n there ',
        start: Duration.zero,
        end: const Duration(milliseconds: 700),
      );

      expect(words, [_word('hi', 0, 200), _word('there', 200, 700)]);
    });

    test('rounds to whole milliseconds and ends exactly at the end', () {
      final words = spreadCaptionWords(
        'a b c',
        start: Duration.zero,
        end: const Duration(milliseconds: 100),
      );

      expect(words, [
        _word('a', 0, 33),
        _word('b', 33, 67),
        _word('c', 67, 100),
      ]);
    });

    test('returns no words for blank text', () {
      expect(
        spreadCaptionWords(
          '   ',
          start: Duration.zero,
          end: const Duration(seconds: 1),
        ),
        isEmpty,
      );
    });
  });

  group('captionWordsOf', () {
    test('returns the words a segment already carries', () {
      final segment = CaptionSegment(
        text: 'hi there',
        start: Duration.zero,
        end: const Duration(seconds: 1),
        words: [_word('hi', 0, 300), _word('there', 500, 1000)],
      );

      expect(captionWordsOf(segment), segment.words);
    });

    test('returns a one-word segment as its only word', () {
      expect(captionWordsOf(_word(' hello ', 100, 500)), [
        _word('hello', 100, 500),
      ]);
    });

    test('spreads a multi-word segment over its span', () {
      expect(captionWordsOf(_word('hi there', 0, 700)), [
        _word('hi', 0, 200),
        _word('there', 200, 700),
      ]);
    });
  });
}
