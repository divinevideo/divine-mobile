// ABOUTME: Tests for audioFadeGain, the fade envelope the timeline draws.
// ABOUTME: It must match the envelope the export bakes in and the preview plays.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/audio_fade.dart';

void main() {
  group('audioFadeGain', () {
    double gain(
      int positionMs, {
      int lengthMs = 4000,
      int fadeInMs = 0,
      int fadeOutMs = 0,
    }) => audioFadeGain(
      position: Duration(milliseconds: positionMs),
      length: Duration(milliseconds: lengthMs),
      fadeIn: Duration(milliseconds: fadeInMs),
      fadeOut: Duration(milliseconds: fadeOutMs),
    );

    test('is full volume without a fade', () {
      expect(gain(0), equals(1));
      expect(gain(4000), equals(1));
    });

    test('rises linearly from silence over the fade in', () {
      expect(gain(0, fadeInMs: 1000), equals(0));
      expect(gain(250, fadeInMs: 1000), closeTo(0.25, 1e-9));
      expect(gain(1000, fadeInMs: 1000), equals(1));
      expect(gain(3000, fadeInMs: 1000), equals(1));
    });

    test('falls linearly to silence at the end of the audio', () {
      expect(gain(2000, fadeOutMs: 2000), equals(1));
      expect(gain(3000, fadeOutMs: 2000), closeTo(0.5, 1e-9));
      expect(gain(4000, fadeOutMs: 2000), equals(0));
    });

    test('keeps the quieter ramp where the fades overlap', () {
      // Two 1 s fades on a 1 s sound cross half-way at half volume.
      expect(
        gain(500, lengthMs: 1000, fadeInMs: 1000, fadeOutMs: 1000),
        closeTo(0.5, 1e-9),
      );
      expect(
        gain(750, lengthMs: 1000, fadeInMs: 1000, fadeOutMs: 1000),
        closeTo(0.25, 1e-9),
      );
    });

    test('is silent rather than negative outside the audio', () {
      expect(gain(-100, fadeInMs: 1000), equals(0));
      expect(gain(4500, fadeOutMs: 1000), equals(0));
    });
  });
}
