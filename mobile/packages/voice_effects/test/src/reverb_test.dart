import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(Reverb, () {
    const sampleRate = 16000;
    // Freeverb's shortest comb, 1116 samples at 44.1 kHz, at this rate.
    const firstReflection = 404;

    /// Half a second of noise, then a second and a half of silence.
    final burst = Float32List(2 * sampleRate)
      ..setAll(
        0,
        whiteNoise(seconds: 0.5, sampleRate: sampleRate, amplitude: 0.3),
      );
    const burstEnd = sampleRate ~/ 2;

    test('keeps the length of the sound', () {
      expect(const Reverb().apply(burst, sampleRate), hasLength(burst.length));
    });

    test('leaves the sound untouched until the first reflection', () {
      final output = const Reverb(mix: 1).apply(burst, sampleRate);

      for (var i = 0; i < firstReflection; i++) {
        expect(output[i], equals(burst[i]));
      }
      expect(
        output[firstReflection + 100],
        isNot(equals(burst[firstReflection + 100])),
      );
    });

    test('rings on after the sound stops, fading away', () {
      final output = const Reverb(mix: 1).apply(burst, sampleRate);

      final early = rms(output, burstEnd, burstEnd + 1600);
      final late = rms(output, burstEnd + 8000, burstEnd + 9600);

      expect(early, greaterThan(0.01));
      expect(late, lessThan(early / 4));
    });

    test('rings longer in a bigger room', () {
      final small = const Reverb(roomSize: 0, mix: 1).apply(burst, sampleRate);
      final large = const Reverb(roomSize: 1, mix: 1).apply(burst, sampleRate);

      const from = burstEnd + 8000;
      expect(
        rms(large, from, from + 1600),
        greaterThan(4 * rms(small, from, from + 1600)),
      );
    });

    test('adds more of the tail the higher the mix', () {
      final light = const Reverb(mix: 0.2).apply(burst, sampleRate);
      final heavy = const Reverb(mix: 0.8).apply(burst, sampleRate);

      expect(
        rms(heavy, burstEnd, burstEnd + 1600),
        closeTo(4 * rms(light, burstEnd, burstEnd + 1600), 1e-3),
      );
    });

    test('feeds the tail no bass', () {
      // Faded in and out, so its edges do not click into the tail.
      final bass = sine(hz: 40, seconds: 0.5, sampleRate: sampleRate);
      for (var i = 0; i < bass.length; i++) {
        bass[i] *= math.sin(math.pi * i / bass.length);
      }
      final input = Float32List(sampleRate)..setAll(0, bass);

      final cut = const Reverb(mix: 1).apply(input, sampleRate);
      final uncut = const Reverb(mix: 1, lowCutHz: 10).apply(input, sampleRate);

      expect(
        rms(cut, burstEnd, sampleRate),
        lessThan(rms(uncut, burstEnd, sampleRate) / 5),
      );
    });

    group('applyToChannels', () {
      test('gives one channel the same tail as apply', () {
        final mono = const Reverb().apply(burst, sampleRate);

        expect(
          const Reverb().applyToChannels([burst], sampleRate).single,
          equals(mono),
        );
      });

      test('spreads one sound into a wide tail', () {
        final stereo = const Reverb(mix: 1).applyToChannels([
          burst,
          burst,
        ], sampleRate);

        var cross = 0.0;
        var left = 0.0;
        var right = 0.0;
        for (var i = burstEnd; i < burst.length; i++) {
          cross += stereo[0][i] * stereo[1][i];
          left += stereo[0][i] * stereo[0][i];
          right += stereo[1][i] * stereo[1][i];
        }

        expect(cross / math.sqrt(left * right), lessThan(0.2));
      });

      test('keeps each channel its own dry sound', () {
        final quieter = Float32List.fromList([for (final s in burst) s / 2]);

        final stereo = const Reverb().applyToChannels([
          burst,
          quieter,
        ], sampleRate);

        for (var i = 0; i < firstReflection; i++) {
          expect(stereo[0][i], equals(burst[i]));
          expect(stereo[1][i], equals(quieter[i]));
        }
      });

      test('alternates the two tails across more channels', () {
        final surround = const Reverb(mix: 1).applyToChannels([
          burst,
          burst,
          burst,
        ], sampleRate);

        expect(surround[2], equals(surround[0]));
        expect(surround[1], isNot(equals(surround[0])));
      });
    });
  });
}
