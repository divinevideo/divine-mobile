import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(NoiseReduction, () {
    const sampleRate = 16000;
    const reduction = NoiseReduction();

    test('turns down the hiss and keeps the voice above it', () {
      // Three seconds of hiss with a tone over the middle second.
      final hiss = whiteNoise(
        seconds: 3,
        sampleRate: sampleRate,
        amplitude: 0.02,
      );
      final tone = sine(hz: 440, seconds: 1, sampleRate: sampleRate);
      final input = Float32List.fromList(hiss);
      for (var i = 0; i < tone.length; i++) {
        input[sampleRate + i] += tone[i];
      }

      final output = reduction.apply(input, sampleRate);

      expect(output, hasLength(input.length));
      // The first second is hiss alone.
      expect(
        decibels(rms(output, 0, sampleRate), rms(input, 0, sampleRate)),
        lessThan(-15),
      );
      // The tone comes through at its level.
      expect(
        decibels(
          rms(output, sampleRate + 1600, 2 * sampleRate - 1600),
          rms(tone),
        ),
        closeTo(0, 1),
      );
    });

    test('cuts rumble below the voice, even when it comes and goes', () {
      // A 30 Hz rumble that bumps in for every other half second, like the
      // phone being handled: too unsteady for the quiet-moments estimate.
      const rate = 48000;
      final rumble = sine(hz: 30, seconds: 2, sampleRate: rate);
      final input = Float32List.fromList([
        for (var i = 0; i < rumble.length; i++)
          rumble[i] * ((i ~/ (rate ~/ 2)).isOdd ? 0.5 : 0.01),
      ]);

      final output = reduction.apply(input, rate);

      expect(decibels(rms(output), rms(input)), lessThan(-12));
    });

    test('learns the floor from the whole take when it is under a frame', () {
      final input = whiteNoise(
        seconds: 0.01,
        sampleRate: sampleRate,
        amplitude: 0.05,
      );

      final output = reduction.apply(input, sampleRate);

      expect(output, hasLength(input.length));
      expect(rms(output), lessThan(rms(input)));
    });

    test('returns digital silence unchanged', () {
      final input = Float32List(sampleRate);

      final output = reduction.apply(input, sampleRate);

      expect(output, equals(input));
      expect(identical(output, input), isFalse);
    });
  });
}
