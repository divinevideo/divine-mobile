import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(Megaphone, () {
    const sampleRate = 16000;

    test('keeps the length of the voice', () {
      final input = sine(hz: 1000, seconds: 0.3, sampleRate: sampleRate);

      expect(
        const Megaphone().apply(input, sampleRate),
        hasLength(input.length),
      );
    });

    test('is narrower than a phone', () {
      final mix = Float32List(sampleRate);
      final low = sine(hz: 350, seconds: 1, sampleRate: sampleRate);
      final horn = sine(hz: 1800, seconds: 1, sampleRate: sampleRate);
      for (var i = 0; i < mix.length; i++) {
        mix[i] = 0.1 * (low[i] + horn[i]);
      }
      const settled = sampleRate ~/ 2;

      double lowAgainstHornDb(AudioEffect effect) {
        final output = effect.apply(mix, sampleRate);
        return decibels(
          goertzel(output, 350, sampleRate, from: settled, length: 4000),
          goertzel(output, 1800, sampleRate, from: settled, length: 4000),
        );
      }

      expect(lowAgainstHornDb(const Telephone()), greaterThan(-6));
      expect(lowAgainstHornDb(const Megaphone(drive: 0.01)), lessThan(-15));
    });

    test('distorts the voice', () {
      final tone = sine(hz: 600, seconds: 1, sampleRate: sampleRate);
      const settled = sampleRate ~/ 2;

      double thirdHarmonic(Float32List output) =>
          goertzel(output, 1800, sampleRate, from: settled, length: 4000) /
          goertzel(output, 600, sampleRate, from: settled, length: 4000);

      final clean = const Megaphone(drive: 0.01).apply(tone, sampleRate);
      final driven = const Megaphone().apply(tone, sampleRate);

      expect(thirdHarmonic(clean), lessThan(0.001));
      expect(thirdHarmonic(driven), greaterThan(0.1));
    });

    test('keeps the voice as loud as it was', () {
      final input = sine(hz: 1800, seconds: 1, sampleRate: sampleRate);

      final output = const Megaphone().apply(input, sampleRate);

      expect(decibels(rms(output), rms(input)), closeTo(0, 0.1));
    });
  });
}
