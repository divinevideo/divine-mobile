import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(Telephone, () {
    const sampleRate = 16000;

    /// How much [hz] sits below 1 kHz once a mix of both has come through a
    /// phone, in decibels. Measured on one mix, since the phone brings what
    /// it plays back to the input's level.
    double levelAgainstMidDb(double hz) {
      final tone = sine(hz: hz, seconds: 1, sampleRate: sampleRate);
      final mid = sine(hz: 1000, seconds: 1, sampleRate: sampleRate);
      final mix = Float32List(tone.length);
      for (var i = 0; i < mix.length; i++) {
        mix[i] = tone[i] + mid[i];
      }
      final output = const Telephone().apply(mix, sampleRate);
      const settled = sampleRate ~/ 2;
      return decibels(
        goertzel(output, hz, sampleRate, from: settled, length: 4000),
        goertzel(output, 1000, sampleRate, from: settled, length: 4000),
      );
    }

    test('keeps the length of the voice', () {
      final input = sine(hz: 1000, seconds: 0.3, sampleRate: sampleRate);

      expect(
        const Telephone().apply(input, sampleRate),
        hasLength(input.length),
      );
    });

    test('cuts the chest and the air out of the voice', () {
      expect(levelAgainstMidDb(100), lessThan(-30));
      expect(levelAgainstMidDb(7000), lessThan(-20));
    });

    test('keeps the voice as loud as it was', () {
      final input = sine(hz: 1000, seconds: 1, sampleRate: sampleRate);

      final output = const Telephone().apply(input, sampleRate);

      expect(decibels(rms(output), rms(input)), closeTo(0, 0.1));
    });
  });
}
