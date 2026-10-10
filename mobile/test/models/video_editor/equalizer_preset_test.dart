import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/models/video_editor/equalizer_preset.dart';

void main() {
  group(EqualizerPreset, () {
    group('matching', () {
      test('finds the preset a setting came from', () {
        for (final preset in EqualizerPreset.values) {
          expect(EqualizerPreset.matching(preset.settings), preset);
        }
      });

      test('finds none for a setting only the curve reaches', () {
        expect(
          EqualizerPreset.matching(
            const EqualizerSettings([0, 1, 0, 0, 0, 0, 0, 0, 0, 0]),
          ),
          isNull,
        );
      });
    });

    test('keeps every preset inside the range the curve offers', () {
      for (final preset in EqualizerPreset.values) {
        expect(
          EqualizerSettings.fromGains(preset.settings.gains),
          preset.settings,
          reason: '$preset',
        );
        expect(
          preset.settings.gains,
          hasLength(EqualizerSettings.bandCount),
          reason: '$preset',
        );
      }
    });
  });
}
