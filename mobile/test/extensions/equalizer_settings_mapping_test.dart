import 'package:divine_video_player/divine_video_player.dart' as player;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/extensions/equalizer_settings_mapping.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as render;

void main() {
  group('EqualizerSettingsMapping', () {
    const settings = EqualizerSettings([-4, 6, 0, 3, -2, 0, 0, 0, 0, 0]);

    group('toPlayerEqualizer', () {
      test('is null for the recording', () {
        expect(EqualizerSettings.none.toPlayerEqualizer(), isNull);
      });

      test('shelves the outer bands and peaks the ones between', () {
        final bands = settings.toPlayerEqualizer()!.bands;

        expect(bands.map((band) => band.type), [
          player.AudioEqualizerBandType.lowShelf,
          for (var band = 1; band < EqualizerSettings.bandCount - 1; band++)
            player.AudioEqualizerBandType.peak,
          player.AudioEqualizerBandType.highShelf,
        ]);
        // An octave wide: the half-gain points of a peak at Q √2.
        expect(bands[1].q, closeTo(1.4142, 1e-4));
        expect(
          bands.map((band) => band.frequency),
          EqualizerSettings.frequencies,
        );
        expect(bands.map((band) => band.gain), settings.gains);
      });
    });

    group('toRenderEqualizer', () {
      test('is null for the recording', () {
        expect(EqualizerSettings.none.toRenderEqualizer(), isNull);
      });

      test('describes the same bands the preview plays', () {
        final preview = settings.toPlayerEqualizer()!.bands;
        final export = settings.toRenderEqualizer()!.bands;

        expect(export, hasLength(preview.length));
        for (var band = 0; band < export.length; band++) {
          expect(export[band].type.name, preview[band].type.name);
          expect(export[band].frequency, preview[band].frequency);
          expect(export[band].gain, preview[band].gain);
          expect(export[band].q, preview[band].q);
        }
        expect(
          export.first.type,
          render.AudioEqualizerBandType.lowShelf,
        );
      });
    });
  });
}
