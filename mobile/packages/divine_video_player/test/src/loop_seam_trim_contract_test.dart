import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loop seam trim contract', () {
    test('Apple clamps the clip to the shorter of the two tracks', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('trimToCommonTrackEnd'),
        reason:
            'Apple must honour the flag; without it a looping clip replays '
            'the tail where one track has already ended.',
      );
      expect(
        source,
        contains('boundedCommonTrackEnd('),
        reason:
            'The clip must end where both tracks still have content only when '
            'the mismatch is small enough to be a seam, not a malformed asset.',
      );
      expect(
        source,
        contains('CMTimeMinimum(endTime, commonEnd)'),
        reason:
            'Clamping may only ever shorten a clip — an explicit trim that '
            'ends earlier still wins.',
      );
      expect(
        source,
        contains('catch {'),
        reason:
            'A failure to read optional track ranges must leave the clip '
            'untrimmed rather than failing composition playback.',
      );
      expect(
        source,
        contains('maxCommonTrackEndTrimMs = 500.0'),
        reason:
            'The clamp must be bounded so stub audio tracks do not collapse a '
            'normal-length video into a tiny loop.',
      );
      expect(
        source,
        contains('maxCommonTrackEndTrimRatio = 0.10'),
        reason:
            'The clamp must also be relative to playable duration so short '
            'clips cannot lose an excessive fraction of content.',
      );
    });

    test('Android bounds the clamp and only ever shortens a clip', () {
      final source = _androidSourceFile(
        'CommonTrackEndMediaSource.kt',
      ).readAsStringSync();

      expect(
        source,
        contains('fun commonTrackEndUs('),
        reason:
            'Android must resolve the point where both tracks still have '
            'content before it clips the source.',
      );
      expect(
        source,
        contains('MAX_COMMON_TRACK_END_TRIM_US = 500_000L'),
        reason:
            'The clamp must be bounded so stub audio tracks do not collapse a '
            'normal-length video into a tiny loop.',
      );
      expect(
        source,
        contains('MAX_COMMON_TRACK_END_TRIM_RATIO = 0.10'),
        reason:
            'The clamp must also be relative to playable duration so short '
            'clips cannot lose an excessive fraction of content.',
      );
    });

    test('Android clips at the track end before the first frame', () {
      final instance = _androidSourceFile().readAsStringSync();
      final mediaSource = _androidSourceFile(
        'CommonTrackEndMediaSource.kt',
      ).readAsStringSync();

      expect(
        instance,
        contains('TrackEndCapturingExtractorsFactory('),
        reason:
            "The track ends come from the player's own extractor as it parses "
            'the container — no second read, and nothing in front of the load.',
      );
      expect(
        instance,
        contains('buildCommonTrackEndItem(uri, endMs)'),
        reason:
            'A clip that asks for the clamp must reach the player as an item '
            'the clipping source recognises.',
      );
      expect(
        mediaSource,
        contains('updateClipping(periodStartUs, periodEndUs)'),
        reason:
            'The end has to reach the period already being prepared: it is '
            'the one that parses the container, and it plays the first lap.',
      );
      expect(
        instance,
        isNot(contains('replaceMediaItem')),
        reason:
            'Installing a late clamp by swapping the item re-prepared the '
            'source on a playing video and froze the first loop restart for '
            '~300 ms. Nothing may swap the item to clip it.',
      );
      expect(
        instance,
        isNot(contains('MediaExtractor()')),
        reason:
            'A second read of the container either delayed the load or landed '
            'after the video had started; the extractor already has the '
            'answer before the first frame.',
      );
    });
  });
}

File _appleSourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
}

File _androidSourceFile([String name = 'DivineVideoPlayerInstance.kt']) {
  final packageRelative = File(
    'android/src/main/kotlin/com/divinevideo/divine_video_player/$name',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'android/src/main/kotlin/com/divinevideo/divine_video_player/$name',
  );
}
