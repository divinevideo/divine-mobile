import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

/// A buzzy vowel-like tone: the first eight harmonics of [hz].
Float32List _voice(double hz, {required int sampleRate}) {
  final harmonics = [
    for (var h = 1; h <= 8; h++)
      sine(hz: hz * h, seconds: 1, sampleRate: sampleRate, amplitude: 0.1 / h),
  ];
  return Float32List.fromList([
    for (var i = 0; i < sampleRate; i++)
      harmonics.fold<double>(0, (sum, harmonic) => sum + harmonic[i]),
  ]);
}

void main() {
  group(Robotize, () {
    const sampleRate = 16000;
    const robot = Robotize(pitchHz: 100);

    test('speaks every input pitch on the same robot note', () {
      // One period of 100 Hz at 16 kHz.
      const robotPeriod = 160;
      for (final hz in [140.0, 230.0]) {
        final input = _voice(hz, sampleRate: sampleRate);

        final output = robot.apply(input, sampleRate);

        expect(
          periodicity(input, from: 4000, length: 4000, lag: robotPeriod),
          lessThan(0.5),
          reason: 'the $hz Hz input does not repeat at the robot period',
        );
        expect(
          periodicity(output, from: 4000, length: 4000, lag: robotPeriod),
          greaterThan(0.9),
          reason: 'the robot repeats at its period for a $hz Hz input',
        );
      }
    });

    test('keeps the length and the loudness of the take', () {
      final input = _voice(180, sampleRate: sampleRate);

      final output = robot.apply(input, sampleRate);

      expect(output, hasLength(input.length));
      expect(rms(output), closeTo(rms(input), 1e-6));
    });

    test('blends the robot in by its mix', () {
      final input = _voice(180, sampleRate: sampleRate);

      final dry = const Robotize(pitchHz: 100, mix: 0).apply(input, sampleRate);
      final half = const Robotize(
        pitchHz: 100,
        mix: 0.5,
      ).apply(input, sampleRate);
      final wet = robot.apply(input, sampleRate);

      expect(dry, equals(input));
      for (final i in [4000, 4321, 9000]) {
        expect(half[i], closeTo((input[i] + wet[i]) / 2, 1e-6));
      }
    });

    test('leaves silence silent', () {
      final output = robot.apply(Float32List(sampleRate), sampleRate);

      expect(rms(output), equals(0));
    });
  });
}
