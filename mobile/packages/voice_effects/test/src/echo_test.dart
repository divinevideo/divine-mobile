import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

import '../helpers/signals.dart';

void main() {
  group(Echo, () {
    const sampleRate = 8000;
    const echo = Echo(delay: Duration(milliseconds: 100), feedback: 0.5);
    // 100 ms at 8 kHz.
    const delaySamples = 800;

    late Float32List output;

    setUp(() {
      final click = Float32List(sampleRate)..[0] = 1;
      output = echo.apply(click, sampleRate);
    });

    test('keeps the length of the take', () {
      expect(output, hasLength(sampleRate));
    });

    test('leaves the voice itself untouched until the first repeat', () {
      expect(output[0], equals(1));
      expect(rms(output, 1, delaySamples), equals(0));
    });

    test('repeats the voice once per delay, each repeat quieter', () {
      final first = rms(output, delaySamples, 2 * delaySamples);
      final second = rms(output, 2 * delaySamples, 3 * delaySamples);
      final third = rms(output, 3 * delaySamples, 4 * delaySamples);

      expect(first, greaterThan(0));
      expect(second, lessThan(first));
      expect(third, lessThan(second));
    });
  });
}
