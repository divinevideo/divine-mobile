import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

class _Add extends AudioEffect {
  const _Add(this.amount);

  final double amount;

  @override
  Float32List apply(Float32List samples, int sampleRate) =>
      Float32List.fromList([for (final s in samples) s + amount]);
}

class _Scale extends AudioEffect {
  const _Scale(this.factor);

  final double factor;

  @override
  Float32List apply(Float32List samples, int sampleRate) =>
      Float32List.fromList([for (final s in samples) s * factor]);
}

void main() {
  group('applyAudioEffects', () {
    test('applies the effects in list order', () {
      final input = Float32List.fromList([0.1]);

      final addThenScale = applyAudioEffects(input, 48000, const [
        _Add(0.1),
        _Scale(2),
      ]);
      final scaleThenAdd = applyAudioEffects(input, 48000, const [
        _Scale(2),
        _Add(0.1),
      ]);

      expect(addThenScale.single, closeTo(0.4, 1e-6));
      expect(scaleThenAdd.single, closeTo(0.3, 1e-6));
    });

    test('pulls a result past full scale back under the ceiling', () {
      final input = Float32List.fromList([0.5, -0.25]);

      final output = applyAudioEffects(input, 48000, const [_Scale(4)]);

      expect(output[0], closeTo(0.98, 1e-6));
      expect(output[1], closeTo(-0.49, 1e-6));
    });

    test('leaves a quiet result at its level', () {
      final input = Float32List.fromList([0.1, -0.2]);

      final output = applyAudioEffects(input, 48000, const [_Scale(2)]);

      expect(output[0], closeTo(0.2, 1e-6));
      expect(output[1], closeTo(-0.4, 1e-6));
    });

    test('returns a copy when there is nothing to apply', () {
      final input = Float32List.fromList([0.1, 0.2]);

      final output = applyAudioEffects(input, 48000, const []);

      expect(output, equals(input));
      expect(identical(output, input), isFalse);
    });
  });
}
