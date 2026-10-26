import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(Underwater, () {
    const sampleRate = 16000;

    test('keeps the length of the voice', () {
      final input = sine(hz: 200, seconds: 0.3, sampleRate: sampleRate);

      expect(
        const Underwater().apply(input, sampleRate),
        hasLength(input.length),
      );
    });

    test('muffles everything but the lows', () {
      final low = sine(hz: 150, seconds: 1, sampleRate: sampleRate);
      final crisp = sine(hz: 3000, seconds: 1, sampleRate: sampleRate);
      const settled = sampleRate ~/ 2;

      // Each is brought back to its own level, so measure the cut on a mix.
      final mix = Float32List(low.length);
      for (var i = 0; i < mix.length; i++) {
        mix[i] = low[i] + crisp[i];
      }
      final output = const Underwater().apply(mix, sampleRate);

      expect(
        goertzel(output, 3000, sampleRate, from: settled, length: 4096),
        lessThan(
          goertzel(output, 150, sampleRate, from: settled, length: 4096) / 100,
        ),
      );
    });

    test('bends the pitch down and back up as the warble swings', () {
      final tone = sine(hz: 300, seconds: 4, sampleRate: sampleRate);
      const warble = Underwater(
        warbleDepth: Duration(milliseconds: 100),
        warbleHz: 0.25,
      );

      final output = warble.apply(tone, sampleRate);

      // The delay grows fastest a second in and shrinks fastest at three.
      expect(
        dominantFrequency(output, sampleRate, from: sampleRate - 4096),
        lessThan(285),
      );
      expect(
        dominantFrequency(output, sampleRate, from: 3 * sampleRate - 4096),
        greaterThan(315),
      );
    });

    test('starts the voice on time', () {
      final click = Float32List(sampleRate)..[0] = 1;

      final output = const Underwater().apply(click, sampleRate);

      expect(output[0], isNot(equals(0)));
    });

    test('keeps the voice as loud as it was', () {
      final input = sine(hz: 150, seconds: 1, sampleRate: sampleRate);

      final output = const Underwater().apply(input, sampleRate);

      expect(decibels(rms(output), rms(input)), closeTo(0, 0.1));
    });
  });
}
