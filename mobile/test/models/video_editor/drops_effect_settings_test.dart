import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';

void main() {
  group(DropsEffectSettings, () {
    group('fromParams', () {
      test('falls back to the default look for missing settings', () {
        expect(
          DropsEffectSettings.fromParams(const {'intensity': 0.4}),
          const DropsEffectSettings(),
        );
      });

      test('reads back what toParams wrote', () {
        const settings = DropsEffectSettings(
          count: 5,
          size: 0.2,
          speed: 0,
          frost: 1,
          fringes: 0.75,
          seed: 4211,
        );

        expect(
          DropsEffectSettings.fromParams(settings.toParams()),
          settings,
        );
      });

      test('clamps settings out of range and rounds whole numbers', () {
        expect(
          DropsEffectSettings.fromParams(const {
            'count': 9,
            'size': 2,
            'speed': -1,
            'seed': 3.6,
          }),
          const DropsEffectSettings(count: 5, size: 1, speed: 0, seed: 4),
        );
      });
    });

    group('copyWith', () {
      test('clamps into range', () {
        expect(
          const DropsEffectSettings().copyWith(count: 0, frost: 1.5),
          const DropsEffectSettings(count: 1, frost: 1),
        );
      });
    });
  });

  group('dropsLayout', () {
    // The same numbers are pinned for the native renderers in
    // `DropsVideoEffectTests` (ios/RunnerTests/RunnerTests.swift).
    void expectDrops(
      List<DropPlacement> drops,
      List<(double, double, double)> expected,
    ) {
      expect(drops, hasLength(DropsEffectSettings.maxCount));
      for (final (i, drop) in drops.indexed) {
        final (x, y, radius) = i < expected.length
            ? expected[i]
            : (-100.0, -100.0, 0.0);
        expect(drop.x, closeTo(x, 1e-5), reason: 'x of drop $i');
        expect(drop.y, closeTo(y, 1e-5), reason: 'y of drop $i');
        expect(drop.radius, closeTo(radius, 1e-9), reason: 'radius of $i');
      }
    }

    test('places the default drops along their paths', () {
      expectDrops(dropsLayout(const DropsEffectSettings(), seconds: 7), [
        (0.370810, 0.336231, 0.17),
        (0.240065, 0.584015, 0.13),
        (0.629452, 0.605205, 0.15),
      ]);
    });

    test('holds the drops still at speed 0, shows as many as the count says '
        'and scales them with the size', () {
      expectDrops(
        dropsLayout(
          const DropsEffectSettings(count: 5, size: 1, speed: 0, seed: 2),
          seconds: 5,
        ),
        [
          (0.260919, 0.330758, 0.255),
          (0.301859, 0.663046, 0.195),
          (0.680109, 0.581244, 0.225),
          (0.352791, 0.674857, 0.165),
          (0.379547, 0.649744, 0.21),
        ],
      );
    });

    test('runs the drops along their paths twice as fast at full speed', () {
      expectDrops(
        dropsLayout(
          const DropsEffectSettings(count: 1, size: 0, speed: 1),
          seconds: 3,
        ),
        [(0.490785, 0.367983, 0.085)],
      );
    });

    test('a seed rearranges the drops and keeps their sizes', () {
      const settings = DropsEffectSettings();
      final plain = dropsLayout(settings, seconds: 2);
      final shuffled = dropsLayout(settings.copyWith(seed: 3), seconds: 2);

      for (var i = 0; i < settings.count; i++) {
        expect(shuffled[i].x, isNot(closeTo(plain[i].x, 1e-3)));
        expect(shuffled[i].radius, plain[i].radius);
      }
    });
  });
}
