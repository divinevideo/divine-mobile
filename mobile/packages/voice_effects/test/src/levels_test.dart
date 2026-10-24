import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/src/levels.dart';

import '../helpers/signals.dart';

void main() {
  group('rmsOf', () {
    test('is the RMS level of the samples', () {
      expect(rmsOf(Float32List.fromList([0.5, -0.5])), closeTo(0.5, 1e-9));
    });

    test('is zero without samples', () {
      expect(rmsOf(Float32List(0)), equals(0));
    });
  });

  group('matchLoudness', () {
    test('scales the output to the level of the reference', () {
      final output = Float32List.fromList([0.1, -0.1]);

      matchLoudness(output, Float32List.fromList([0.4, -0.4]));

      expect(output, equals([closeTo(0.4, 1e-6), closeTo(-0.4, 1e-6)]));
    });

    test('leaves silent output alone', () {
      final output = Float32List(2);

      matchLoudness(output, Float32List.fromList([0.4, -0.4]));

      expect(output, equals([0, 0]));
    });
  });

  group('saturate', () {
    test('flattens the peaks more the higher the drive', () {
      final tone = sine(hz: 100, seconds: 0.1, sampleRate: 8000);

      double crest(Float32List samples) {
        var peak = 0.0;
        for (final sample in samples) {
          if (sample.abs() > peak) peak = sample.abs();
        }
        return peak / rms(samples);
      }

      final light = saturate(tone, 1);
      final hard = saturate(tone, 10);

      expect(crest(light), lessThan(crest(tone)));
      expect(crest(hard), lessThan(crest(light)));
    });

    test('drives a quiet take as hard as a loud one', () {
      final loud = sine(hz: 100, seconds: 0.1, sampleRate: 8000);
      final quiet = sine(
        hz: 100,
        seconds: 0.1,
        sampleRate: 8000,
        amplitude: 0.05,
      );

      final fromLoud = saturate(loud, 4);
      final fromQuiet = saturate(quiet, 4);

      for (var i = 0; i < loud.length; i++) {
        expect(fromQuiet[i], closeTo(fromLoud[i], 1e-5));
      }
    });

    test('keeps silence silent', () {
      expect(saturate(Float32List(3), 4), equals([0, 0, 0]));
    });
  });
}
