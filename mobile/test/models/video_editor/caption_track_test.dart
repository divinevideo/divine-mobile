// ABOUTME: Tests for the caption track/cue models.
// ABOUTME: Covers JSON round-trips, adapters, and unknown-mode fallback.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

void main() {
  const cue = CaptionCue(
    id: 'cue-1',
    text: 'Hello world.',
    start: Duration(milliseconds: 250),
    end: Duration(milliseconds: 1750),
  );

  group(CaptionCue, () {
    test('round-trips through toJson/fromJson', () {
      expect(CaptionCue.fromJson(cue.toJson()), equals(cue));
    });

    test('fromJson throws $FormatException for malformed maps', () {
      expect(
        () => CaptionCue.fromJson(const {'id': 'x', 'text': 'y'}),
        throwsFormatException,
      );
    });

    test('adapts a recognizer segment', () {
      const segment = CaptionSegment(
        text: 'Hi there.',
        start: Duration(milliseconds: 100),
        end: Duration(milliseconds: 900),
      );

      final adapted = CaptionCue.fromSegment(segment, id: 'cue-9');

      expect(adapted.id, equals('cue-9'));
      expect(adapted.text, equals('Hi there.'));
      expect(adapted.start, equals(const Duration(milliseconds: 100)));
      expect(adapted.end, equals(const Duration(milliseconds: 900)));
    });

    test('adapts to a SubtitleCue in milliseconds', () {
      final subtitle = cue.toSubtitleCue();

      expect(subtitle.start, equals(250));
      expect(subtitle.end, equals(1750));
      expect(subtitle.text, equals('Hello world.'));
    });

    test('exposes its duration and supports copyWith', () {
      expect(cue.duration, equals(const Duration(milliseconds: 1500)));
      final moved = cue.copyWith(start: Duration.zero);
      expect(moved.id, equals(cue.id));
      expect(moved.start, equals(Duration.zero));
      expect(moved.text, equals(cue.text));
    });

    group('words', () {
      CaptionSegment word(String text, int startMs, int endMs) =>
          CaptionSegment(
            text: text,
            start: Duration(milliseconds: startMs),
            end: Duration(milliseconds: endMs),
          );

      final spoken = cue.copyWith(
        words: [word('Hello', 300, 700), word('world.', 900, 1500)],
      );

      test('round-trip through toJson/fromJson', () {
        expect(CaptionCue.fromJson(spoken.toJson()), equals(spoken));
      });

      test('are left out of the JSON when there are none', () {
        expect(cue.toJson().containsKey('words'), isFalse);
      });

      test('are dropped, not the cue, when stored malformed', () {
        final json = spoken.toJson()
          ..['words'] = [
            {'text': 'Hello', 'startMs': 300},
          ];

        expect(CaptionCue.fromJson(json), equals(cue));
        expect(
          CaptionCue.fromJson(spoken.toJson()..['words'] = ['nope']),
          equals(cue),
        );
      });

      test('come along from a grouped recognizer segment', () {
        final adapted = CaptionCue.fromSegment(
          CaptionSegment(
            text: 'Hello world.',
            start: const Duration(milliseconds: 250),
            end: const Duration(milliseconds: 1750),
            words: spoken.words,
          ),
          id: 'cue-1',
        );

        expect(adapted, equals(spoken));
      });

      test('wordTimings are the words while they match the text', () {
        expect(spoken.wordTimings, equals(spoken.words));
      });

      test('wordTimings spread the text without matching words', () {
        expect(cue.wordTimings, [
          word('Hello', 250, 932),
          word('world.', 932, 1750),
        ]);
        expect(
          spoken.copyWith(text: 'Hello there world.').wordTimings,
          hasLength(3),
        );
      });

      test('withText keeps the timings when the word count stays', () {
        final corrected = spoken.withText('Yellow world!');

        expect(corrected.text, equals('Yellow world!'));
        expect(corrected.words, [
          word('Yellow', 300, 700),
          word('world!', 900, 1500),
        ]);
      });

      test('withText spreads the text while the word count differs', () {
        final rewritten = spoken.withText('Hello there, world.');

        expect(rewritten.text, equals('Hello there, world.'));
        expect(rewritten.wordTimings, hasLength(3));
        expect(
          rewritten.wordTimings.map((w) => w.text),
          ['Hello', 'there,', 'world.'],
        );
      });

      test('withText restores the timings when the word count returns', () {
        // Deleting a word keystroke by keystroke and typing it back passes
        // through a different count on the way.
        final retyped = spoken
            .withText('Hello ')
            .withText('Hello w')
            .withText('Hello world.');

        expect(retyped.wordTimings, equals(spoken.words));
      });

      test('withTiming moves the words along with a moved cue', () {
        final moved = spoken.withTiming(
          start: const Duration(milliseconds: 1250),
          end: const Duration(milliseconds: 2750),
        );

        expect(moved.start, equals(const Duration(milliseconds: 1250)));
        expect(moved.end, equals(const Duration(milliseconds: 2750)));
        expect(moved.words, [
          word('Hello', 1300, 1700),
          word('world.', 1900, 2500),
        ]);
      });

      test('withTiming leaves the words in place when trimming', () {
        final trimmed = spoken.withTiming(
          end: const Duration(milliseconds: 1000),
        );

        expect(trimmed.end, equals(const Duration(milliseconds: 1000)));
        expect(trimmed.words, equals(spoken.words));
      });
    });
  });

  group(CaptionTrack, () {
    const track = CaptionTrack(
      presetId: 'classic',
      languageTag: 'de-CH',
      cues: [cue],
    );

    test('round-trips through toJson/fromJson', () {
      final decoded = CaptionTrack.fromJson(track.toJson());

      expect(decoded, equals(track));
      expect(decoded.burnIn, isFalse);
      expect(decoded.cues.single, equals(cue));
    });

    test('round-trips a burn-in track with cues', () {
      const burnIn = CaptionTrack(
        burnIn: true,
        presetId: 'pop',
        languageTag: 'en-US',
        cues: [cue],
      );

      final decoded = CaptionTrack.fromJson(burnIn.toJson());

      expect(decoded.burnIn, isTrue);
      expect(decoded.cues.single, equals(cue));
    });

    test('round-trips a custom style', () {
      const custom = CaptionCustomStyle(
        fontIndex: 4,
        color: Color(0xFF112233),
        background: Color(0x80445566),
        colorMode: LayerBackgroundMode.onlyColor,
        animation: CaptionAnimationStyle.pop,
      );
      final withCustom = track.copyWith(burnIn: true, customStyle: custom);

      final decoded = CaptionTrack.fromJson(withCustom.toJson());

      expect(decoded.customStyle, equals(custom));
      expect(decoded, equals(withCustom));
    });

    test('omits customStyle from JSON when absent and clears it on copy', () {
      expect(track.toJson().containsKey('customStyle'), isFalse);

      const custom = CaptionCustomStyle(
        fontIndex: 0,
        color: Color(0xFFFFFFFF),
        background: Color(0x80000000),
        colorMode: LayerBackgroundMode.backgroundAndColor,
        animation: CaptionAnimationStyle.fade,
      );
      final withCustom = track.copyWith(customStyle: custom);
      expect(withCustom.copyWith(clearCustomStyle: true).customStyle, isNull);
    });

    test('reads burnIn from a legacy serialized mode field', () {
      final json = track.toJson()
        ..remove('burnIn')
        ..['mode'] = 'burnIn';

      expect(CaptionTrack.fromJson(json).burnIn, isTrue);
    });

    test('defaults burnIn to false for an unknown legacy mode', () {
      final json = track.toJson()
        ..remove('burnIn')
        ..['mode'] = 'holograph';

      expect(CaptionTrack.fromJson(json).burnIn, isFalse);
    });

    test('fromJson throws $FormatException for malformed maps', () {
      expect(
        () => CaptionTrack.fromJson(const {'presetId': 1}),
        throwsFormatException,
      );
    });

    test('copyWith replaces only the given fields', () {
      final updated = track.copyWith(presetId: 'mono');

      expect(updated.presetId, equals('mono'));
      expect(updated.burnIn, equals(track.burnIn));
      expect(updated.cues, equals(track.cues));
    });
  });
}
