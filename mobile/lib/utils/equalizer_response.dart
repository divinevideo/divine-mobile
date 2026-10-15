// ABOUTME: How much an equalizer raises or lowers each frequency band an audio
// ABOUTME: visualizer measures, filtered the way the export filters the sound.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/extensions/equalizer_settings_mapping.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioEqualizerBand, AudioEqualizerBandType;

/// The sample rate the filters are worked out at, that of most phone
/// recordings. A file at another rate is filtered a little differently near
/// the top band, where the bilinear transform bends the filters most.
const double _sampleRate = 48000;

/// The highest frequency a filter gets, as a fraction of the sample rate, as
/// in the export.
const double _maxCornerRatio = 0.45;

/// How much [settings] multiply the power of each of the [audioBandCount]
/// bands [bandEnergies] measures, at the band's middle, or `null` when they
/// leave the sound as recorded.
///
/// The filters are the ones [EqualizerSettingsMapping.toRenderEqualizer]
/// hands the export, run one after the other as the cookbook biquads the
/// export and the preview player share, so a boost or a cut moves a band as
/// much as it moves the sound. The export's limiter, which holds a boost
/// under full scale, is left out: it only turns down the loudest peaks.
Float64List? equalizerBandPowerGains(EqualizerSettings settings) {
  final equalizer = settings.toRenderEqualizer();
  if (equalizer == null) return null;
  final sections = [
    for (final band in equalizer.bands)
      if (band.gain != 0) _Biquad.of(band),
  ];
  return Float64List.fromList([
    for (var band = 0; band < audioBandCount; band++)
      sections.fold(
        1,
        (gain, section) => gain * section.powerGainAt(audioBandFrequency(band)),
      ),
  ]);
}

/// One cookbook section, normalised so `a0` is 1.
class _Biquad {
  const _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  /// The section that filters [band] in the export: a shelf of slope 1 or a
  /// peak as narrow as the band's q.
  factory _Biquad.of(AudioEqualizerBand band) {
    final a = math.pow(10, band.gain / 40).toDouble();
    final corner = band.frequency.clamp(1.0, _sampleRate * _maxCornerRatio);
    final w0 = 2 * math.pi * corner / _sampleRate;
    final cosW0 = math.cos(w0);
    switch (band.type) {
      case AudioEqualizerBandType.peak:
        final alpha = math.sin(w0) / (2 * band.q);
        final a0 = 1 + alpha / a;
        return _Biquad(
          (1 + alpha * a) / a0,
          -2 * cosW0 / a0,
          (1 - alpha * a) / a0,
          -2 * cosW0 / a0,
          (1 - alpha / a) / a0,
        );
      case AudioEqualizerBandType.lowShelf:
        final twoSqrtAAlpha = _twoSqrtAAlpha(a, w0);
        final a0 = (a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha;
        return _Biquad(
          a * ((a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha) / a0,
          2 * a * ((a - 1) - (a + 1) * cosW0) / a0,
          a * ((a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha) / a0,
          -2 * ((a - 1) + (a + 1) * cosW0) / a0,
          ((a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha) / a0,
        );
      case AudioEqualizerBandType.highShelf:
        final twoSqrtAAlpha = _twoSqrtAAlpha(a, w0);
        final a0 = (a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha;
        return _Biquad(
          a * ((a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha) / a0,
          -2 * a * ((a - 1) + (a + 1) * cosW0) / a0,
          a * ((a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha) / a0,
          2 * ((a - 1) - (a + 1) * cosW0) / a0,
          ((a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha) / a0,
        );
    }
  }

  /// A shelf's `2·√A·alpha`, with alpha at slope 1.
  static double _twoSqrtAAlpha(double a, double w0) =>
      2 * math.sqrt(a) * math.sin(w0) / 2 * math.sqrt2;

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;

  /// How much the section multiplies the power of a tone at [frequency] hertz.
  double powerGainAt(double frequency) {
    final w = 2 * math.pi * frequency / _sampleRate;
    double power(double c0, double c1, double c2) {
      final real = c0 + c1 * math.cos(w) + c2 * math.cos(2 * w);
      final imaginary = c1 * math.sin(w) + c2 * math.sin(2 * w);
      return real * real + imaginary * imaginary;
    }

    return power(b0, b1, b2) / power(1, a1, a2);
  }
}
