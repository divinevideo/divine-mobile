import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/src/biquad.dart';

import '../helpers/signals.dart';

/// [hz] at full scale through [filter], as its level in decibels once the
/// filter has settled.
double _gainDb(Biquad filter, double hz, {int sampleRate = 16000}) {
  final input = sine(hz: hz, seconds: 1, sampleRate: sampleRate);
  final output = Float32List(input.length);
  for (var i = 0; i < input.length; i++) {
    output[i] = filter.next(input[i]);
  }
  final settled = input.length ~/ 2;
  return decibels(rms(output, settled), rms(input, settled));
}

void main() {
  group(Biquad, () {
    test('a low-pass keeps the lows and cuts the highs', () {
      expect(_gainDb(Biquad.lowPass(1000, 16000), 100), closeTo(0, 0.1));
      expect(_gainDb(Biquad.lowPass(1000, 16000), 1000), closeTo(-3, 0.2));
      expect(_gainDb(Biquad.lowPass(1000, 16000), 4000), lessThan(-20));
    });

    test('a high-pass keeps the highs and cuts the lows', () {
      expect(_gainDb(Biquad.highPass(1000, 16000), 4000), closeTo(0, 0.2));
      expect(_gainDb(Biquad.highPass(1000, 16000), 1000), closeTo(-3, 0.2));
      expect(_gainDb(Biquad.highPass(1000, 16000), 100), lessThan(-35));
    });

    test('a peaking filter raises its band and leaves the rest', () {
      final peak = Biquad.peaking(1000, 16000, gainDb: 6);

      expect(_gainDb(peak, 1000), closeTo(6, 0.2));
      expect(
        _gainDb(Biquad.peaking(1000, 16000, gainDb: 6), 60),
        closeTo(0, 0.2),
      );
    });

    test('keeps a corner above Nyquist working', () {
      // A cut tuned for 44.1 kHz audio, run on 16 kHz audio.
      expect(_gainDb(Biquad.lowPass(12000, 16000), 100), closeTo(0, 0.1));
    });
  });
}
