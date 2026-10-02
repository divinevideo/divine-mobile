import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/src/fft.dart';

void main() {
  group(Fft, () {
    test('inverse undoes forward', () {
      const size = 64;
      final random = math.Random(3);
      final original = Float64List.fromList([
        for (var i = 0; i < size; i++) random.nextDouble() * 2 - 1,
      ]);
      final re = Float64List.fromList(original);
      final im = Float64List(size);
      Fft(size)
        ..forward(re, im)
        ..inverse(re, im);

      for (var i = 0; i < size; i++) {
        expect(re[i], closeTo(original[i], 1e-12));
        expect(im[i], closeTo(0, 1e-12));
      }
    });

    test('puts a cosine on its own bin and the mirrored one', () {
      const size = 32;
      const bin = 3;
      final re = Float64List.fromList([
        for (var i = 0; i < size; i++) math.cos(2 * math.pi * bin * i / size),
      ]);
      final im = Float64List(size);
      Fft(size).forward(re, im);

      for (var k = 0; k < size; k++) {
        final magnitude = math.sqrt(re[k] * re[k] + im[k] * im[k]);
        final expected = k == bin || k == size - bin ? size / 2 : 0.0;
        expect(magnitude, closeTo(expected, 1e-9), reason: 'bin $k');
      }
    });

    test('rejects a size that is not a power of two', () {
      expect(() => Fft(12), throwsArgumentError);
    });
  });

  group('hannWindow', () {
    test('overlap-adds to a constant at a quarter-frame hop', () {
      const size = 16;
      final window = hannWindow(size);

      for (var i = 0; i < size ~/ 4; i++) {
        var sum = 0.0;
        for (var frame = 0; frame < 4; frame++) {
          final w = window[i + frame * size ~/ 4];
          sum += w * w;
        }
        expect(sum, closeTo(1.5, 1e-12));
      }
    });
  });

  group('powerOfTwoAtMost', () {
    test('rounds down to a power of two', () {
      expect(powerOfTwoAtMost(1200), equals(1024));
      expect(powerOfTwoAtMost(2048), equals(2048));
    });

    test('never returns less than 2', () {
      expect(powerOfTwoAtMost(1), equals(2));
    });
  });
}
