import 'package:divine_video_player/divine_video_player.dart' as player;
import 'package:models/models.dart' show EqualizerSettings;
import 'package:pro_video_editor/pro_video_editor.dart' as render;

/// Hands a clip's or a sound's [EqualizerSettings] to the preview player and
/// to the export as the same band list, which both filter with the same
/// cookbook biquads their native tests pin, so the preview sounds like the
/// posted video.
///
/// The outer bands shelve, so a cut at 31 Hz takes out all of the rumble
/// below it and a boost at 16 kHz all of the air above it; the bands between
/// peak an octave wide around their frequency, as a graphic equalizer's do.
extension EqualizerSettingsMapping on EqualizerSettings {
  /// The preview player's equalizer, or `null` when this changes nothing.
  player.AudioEqualizer? toPlayerEqualizer() => isNone
      ? null
      : player.AudioEqualizer(
          bands: [
            for (var band = 0; band < _bandCount(gains); band++)
              player.AudioEqualizerBand(
                type: switch (_shapeOf(band)) {
                  _BandShape.lowShelf => player.AudioEqualizerBandType.lowShelf,
                  _BandShape.peak => player.AudioEqualizerBandType.peak,
                  _BandShape.highShelf =>
                    player.AudioEqualizerBandType.highShelf,
                },
                frequency: EqualizerSettings.frequencies[band].toDouble(),
                gain: gains[band].toDouble(),
                q: _octaveQ,
              ),
          ],
        );

  /// The export's equalizer, or `null` when this changes nothing.
  render.AudioEqualizer? toRenderEqualizer() => isNone
      ? null
      : render.AudioEqualizer(
          bands: [
            for (var band = 0; band < _bandCount(gains); band++)
              render.AudioEqualizerBand(
                type: switch (_shapeOf(band)) {
                  _BandShape.lowShelf => render.AudioEqualizerBandType.lowShelf,
                  _BandShape.peak => render.AudioEqualizerBandType.peak,
                  _BandShape.highShelf =>
                    render.AudioEqualizerBandType.highShelf,
                },
                frequency: EqualizerSettings.frequencies[band].toDouble(),
                gain: gains[band].toDouble(),
                q: _octaveQ,
              ),
          ],
        );
}

/// The Q of a peak an octave wide; shelves ignore it.
const double _octaveQ = 1.4142135623730951;

/// The bands [gains] describes, never more than there are frequencies for.
int _bandCount(List<int> gains) => gains.length < EqualizerSettings.bandCount
    ? gains.length
    : EqualizerSettings.bandCount;

enum _BandShape { lowShelf, peak, highShelf }

_BandShape _shapeOf(int band) => band == 0
    ? _BandShape.lowShelf
    : (band == EqualizerSettings.bandCount - 1
          ? _BandShape.highShelf
          : _BandShape.peak);
