// ABOUTME: Tests for EqualizerSettings: clamping to range, persistence, and
// ABOUTME: identity.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(EqualizerSettings, () {
    group('fromGains', () {
      test('clamps every gain to its range', () {
        final settings = EqualizerSettings.fromGains(const [30, -40, 5]);

        expect(settings.gains.take(3), [
          EqualizerSettings.maxGain,
          EqualizerSettings.minGain,
          5,
        ]);
      });

      test('fills missing bands with zero and drops extra ones', () {
        expect(EqualizerSettings.fromGains(const [3]).gains, [
          3,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ]);
        expect(
          EqualizerSettings.fromGains(List.filled(12, 1)).gains,
          List.filled(EqualizerSettings.bandCount, 1),
        );
      });
    });

    test('has one rising frequency per band', () {
      const frequencies = EqualizerSettings.frequencies;

      expect(frequencies, hasLength(EqualizerSettings.bandCount));
      for (var band = 1; band < frequencies.length; band++) {
        expect(frequencies[band], greaterThan(frequencies[band - 1]));
      }
      expect(
        EqualizerSettings.none.gains,
        hasLength(EqualizerSettings.bandCount),
      );
    });

    test('is none only when nothing changes', () {
      expect(EqualizerSettings.none.isNone, isTrue);
      expect(EqualizerSettings.none.withGain(7, -1).isNone, isFalse);
    });

    test('withGain changes one band and clamps it', () {
      final settings = EqualizerSettings.fromGains(const [3]);

      expect(
        settings.withGain(9, -2),
        EqualizerSettings.fromGains(const [3, 0, 0, 0, 0, 0, 0, 0, 0, -2]),
      );
      expect(
        EqualizerSettings.none.withGain(1, 99).gains[1],
        EqualizerSettings.maxGain,
      );
    });

    group('json', () {
      test('survives a toJson/fromJson roundtrip', () {
        final settings = EqualizerSettings.fromGains(
          const [-4, 2, 0, 6, 1, 0, 0, -3, 0, 5],
        );

        expect(settings.toJson(), {
          'gains': [-4, 2, 0, 6, 1, 0, 0, -3, 0, 5],
        });
        expect(EqualizerSettings.fromJson(settings.toJson()), settings);
      });

      test('reads anything unreadable as the recording', () {
        expect(EqualizerSettings.fromJson(const {}), EqualizerSettings.none);
        expect(
          EqualizerSettings.fromJson(const {'bass': 6, 'treble': 3}),
          EqualizerSettings.none,
        );
        expect(
          EqualizerSettings.fromJson(const {
            'gains': ['loud', 2.6],
          }),
          EqualizerSettings.none.withGain(1, 3),
        );
        expect(
          EqualizerSettings.fromJson(const {
            'gains': [double.infinity, double.nan, 4],
          }),
          EqualizerSettings.none.withGain(2, 4),
        );
      });
    });

    test('equal settings are equal and print their gains', () {
      final a = EqualizerSettings.fromGains(const [2]);
      final b = EqualizerSettings.none.withGain(0, 2);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(EqualizerSettings.none.withGain(1, 2)));
      expect(
        a.toString(),
        'EqualizerSettings(gains: [2, 0, 0, 0, 0, 0, 0, 0, 0, 0])',
      );
    });
  });
}
