import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(PitchShift, () {
    const sampleRate = 16000;
    // One FFT bin of the dominantFrequency helper at this rate.
    const binHz = sampleRate / 8192;

    test('moves a tone up an octave at +12 semitones', () {
      final input = sine(hz: 220, seconds: 2, sampleRate: sampleRate);

      final output = const PitchShift(12).apply(input, sampleRate);

      expect(output, hasLength(input.length));
      expect(
        dominantFrequency(output, sampleRate, from: 8000),
        closeTo(440, 2 * binHz),
      );
    });

    test('moves a tone down an octave at -12 semitones', () {
      final input = sine(hz: 440, seconds: 2, sampleRate: sampleRate);

      final output = const PitchShift(-12).apply(input, sampleRate);

      expect(output, hasLength(input.length));
      expect(
        dominantFrequency(output, sampleRate, from: 8000),
        closeTo(220, 2 * binHz),
      );
    });

    test('keeps a word where it was said', () {
      // Half a second of tone in the middle of two seconds of silence.
      final input = Float32List(2 * sampleRate)
        ..setAll(
          sampleRate,
          sine(hz: 300, seconds: 0.5, sampleRate: sampleRate),
        );

      final output = const PitchShift(7).apply(input, sampleRate);

      // Within 50 ms of where the tone starts and stops.
      const ms = sampleRate ~/ 1000;
      expect(rms(output, 850 * ms, 950 * ms), lessThan(0.01));
      expect(rms(output, 1100 * ms, 1400 * ms), greaterThan(0.2));
      expect(rms(output, 1550 * ms, 1650 * ms), lessThan(0.01));
    });

    test('returns an unchanged copy at zero semitones', () {
      final input = sine(hz: 220, seconds: 0.1, sampleRate: sampleRate);

      final output = const PitchShift(0).apply(input, sampleRate);

      expect(output, equals(input));
      expect(identical(output, input), isFalse);
    });
  });
}
