// ABOUTME: Tests for VoiceEffect: clamping to range, persistence, and identity.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VoiceEffect, () {
    test('clamps every change to its range', () {
      const effect = VoiceEffect(pitch: 30, robot: -5, echo: 250);

      expect(effect.pitch, VoiceEffect.maxPitch);
      expect(effect.robot, 0);
      expect(effect.echo, VoiceEffect.maxAmount);
    });

    test('is none only when nothing changes', () {
      expect(VoiceEffect.none.isNone, isTrue);
      expect(const VoiceEffect(pitch: -1).isNone, isFalse);
      expect(const VoiceEffect(echo: 5).isNone, isFalse);
    });

    group('toJson', () {
      test('keeps only the changes and survives fromJson', () {
        const effect = VoiceEffect(pitch: -5, echo: 80);

        expect(effect.toJson(), {'pitch': -5, 'echo': 80});
        expect(VoiceEffect.fromJson(effect.toJson()), effect);
      });

      test('reads clamped values back from out-of-range json', () {
        expect(
          VoiceEffect.fromJson(const {'pitch': -40, 'robot': 70.4}),
          const VoiceEffect(pitch: VoiceEffect.minPitch, robot: 70),
        );
      });
    });

    group('copyWith', () {
      test('replaces one change and keeps the others', () {
        const effect = VoiceEffect(pitch: 8, robot: 20);

        expect(effect.copyWith(robot: 0), const VoiceEffect(pitch: 8));
      });
    });
  });
}
