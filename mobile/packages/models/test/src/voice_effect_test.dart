// ABOUTME: Tests for VoiceEffect: clamping to range, persistence, and identity.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VoiceEffect, () {
    test('clamps every change to its range', () {
      const effect = VoiceEffect(pitch: 30, robot: -5, echo: 250, reverb: 101);

      expect(effect.pitch, VoiceEffect.maxPitch);
      expect(effect.robot, 0);
      expect(effect.echo, VoiceEffect.maxAmount);
      expect(effect.reverb, VoiceEffect.maxAmount);
      expect(const VoiceEffect(echo: 1, reverb: -1).reverb, 0);
    });

    test('is none only when nothing changes', () {
      expect(VoiceEffect.none.isNone, isTrue);
      expect(const VoiceEffect(pitch: -1).isNone, isFalse);
      expect(const VoiceEffect(echo: 5).isNone, isFalse);
      expect(const VoiceEffect(reverb: 5).isNone, isFalse);
      expect(
        const VoiceEffect(filter: VoiceFilter.underwater).isNone,
        isFalse,
      );
    });

    group('toJson', () {
      test('keeps only the changes and survives fromJson', () {
        const effect = VoiceEffect(pitch: -5, echo: 80);

        expect(effect.toJson(), {'pitch': -5, 'echo': 80});
        expect(VoiceEffect.fromJson(effect.toJson()), effect);
      });

      test('keeps the reverb and the filter', () {
        const effect = VoiceEffect(
          reverb: 60,
          filter: VoiceFilter.megaphone,
        );

        expect(effect.toJson(), {'reverb': 60, 'filter': 'megaphone'});
        expect(VoiceEffect.fromJson(effect.toJson()), effect);
      });

      test('reads a filter it does not know as none', () {
        expect(
          VoiceEffect.fromJson(const {'echo': 10, 'filter': 'kazoo'}),
          const VoiceEffect(echo: 10),
        );
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

      test('replaces the reverb and the filter', () {
        const effect = VoiceEffect(pitch: -4, reverb: 60);

        expect(
          effect.copyWith(reverb: 0, filter: VoiceFilter.telephone),
          const VoiceEffect(pitch: -4, filter: VoiceFilter.telephone),
        );
      });
    });
  });
}
