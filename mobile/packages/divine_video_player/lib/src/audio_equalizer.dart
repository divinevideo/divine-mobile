import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The shape of an [AudioEqualizerBand]'s filter.
enum AudioEqualizerBandType {
  /// Raises or lowers everything below the band's frequency.
  lowShelf,

  /// Raises or lowers the frequencies around the band's, narrower the higher
  /// its q.
  peak,

  /// Raises or lowers everything above the band's frequency.
  highShelf,
}

/// One filter of an [AudioEqualizer].
@immutable
class AudioEqualizerBand {
  /// Creates a band that raises or lowers [frequency] by [gain] decibels.
  const AudioEqualizerBand({
    required this.type,
    required this.frequency,
    this.gain = 0,
    this.q = defaultQ,
  });

  /// 1/√2, a peak about two octaves wide. Shelves ignore q: their slope is 1,
  /// as in `pro_video_editor`'s export.
  static const double defaultQ = 0.7071067811865476;

  /// The shape of the filter.
  final AudioEqualizerBandType type;

  /// The corner of a shelf or the centre of a peak, in hertz; above zero.
  final double frequency;

  /// How far the band is raised (positive) or lowered (negative), in
  /// decibels.
  final double gain;

  /// How narrow a peak is; above zero.
  final double q;

  /// How far this band raises (positive) or lowers (negative) [frequency],
  /// in decibels, filtering at [sampleRate] as the players and
  /// `pro_video_editor`'s export do.
  ///
  /// A peak gives its whole [gain] at its own frequency; a shelf gives half
  /// of it at its corner and the whole of it well past.
  double responseDb(double frequency, {double sampleRate = 48000}) {
    if (gain == 0) return 0;
    final a = math.pow(10, gain / 40).toDouble();
    // Close to half the sample rate the filter squeezes flat, so the native
    // filters lower a corner there to 45 % of it.
    final corner = this.frequency.clamp(1, sampleRate * 0.45).toDouble();
    final w0 = 2 * math.pi * corner / sampleRate;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final double b0;
    final double b1;
    final double b2;
    final double a0;
    final double a1;
    final double a2;
    switch (type) {
      case AudioEqualizerBandType.peak:
        final alpha = sinW0 / (2 * q);
        b0 = 1 + alpha * a;
        b1 = -2 * cosW0;
        b2 = 1 - alpha * a;
        a0 = 1 + alpha / a;
        a1 = -2 * cosW0;
        a2 = 1 - alpha / a;
      // The cookbook's shelves at a slope of 1.
      case AudioEqualizerBandType.lowShelf:
        final twoSqrtAAlpha = math.sqrt(a) * sinW0 * math.sqrt2;
        b0 = a * ((a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosW0);
        b2 = a * ((a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha);
        a0 = (a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha;
        a1 = -2 * ((a - 1) + (a + 1) * cosW0);
        a2 = (a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha;
      case AudioEqualizerBandType.highShelf:
        final twoSqrtAAlpha = math.sqrt(a) * sinW0 * math.sqrt2;
        b0 = a * ((a + 1) + (a - 1) * cosW0 + twoSqrtAAlpha);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosW0);
        b2 = a * ((a + 1) + (a - 1) * cosW0 - twoSqrtAAlpha);
        a0 = (a + 1) - (a - 1) * cosW0 + twoSqrtAAlpha;
        a1 = 2 * ((a - 1) - (a + 1) * cosW0);
        a2 = (a + 1) - (a - 1) * cosW0 - twoSqrtAAlpha;
    }
    final w = 2 * math.pi * frequency / sampleRate;
    final cos1 = math.cos(w);
    final sin1 = math.sin(w);
    final cos2 = math.cos(2 * w);
    final sin2 = math.sin(2 * w);
    final numerator =
        math.pow(b0 + b1 * cos1 + b2 * cos2, 2) +
        math.pow(b1 * sin1 + b2 * sin2, 2);
    final denominator =
        math.pow(a0 + a1 * cos1 + a2 * cos2, 2) +
        math.pow(a1 * sin1 + a2 * sin2, 2);
    return 10 * math.log(numerator / denominator) / math.ln10;
  }

  /// Serializes this band for platform channel transport.
  Map<String, dynamic> toMap() => {
    'type': type.name,
    'frequencyHz': frequency,
    'gainDb': gain,
    'q': q,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AudioEqualizerBand &&
            other.type == type &&
            other.frequency == frequency &&
            other.gain == gain &&
            other.q == q;
  }

  @override
  int get hashCode => Object.hash(type, frequency, gain, q);

  @override
  String toString() =>
      'AudioEqualizerBand(${type.name}, $frequency Hz, $gain dB, q $q)';
}

/// Shapes the sound of a clip or an overlay audio track with a list of
/// filter [bands].
///
/// The bands are the filters `pro_video_editor` exports with, so the preview
/// sounds like the video it renders. A boost is limited at -1 dBFS rather
/// than clipped.
@immutable
class AudioEqualizer {
  /// Creates an equalizer from [bands].
  const AudioEqualizer({this.bands = const []});

  /// The filters, applied one after the other in this order.
  final List<AudioEqualizerBand> bands;

  /// Whether this equalizer leaves the audio unchanged.
  bool get isFlat => bands.every((band) => band.gain == 0);

  /// Whether any band raises its frequencies, which can cross full scale.
  bool get boosts => bands.any((band) => band.gain > 0);

  /// How far this equalizer raises (positive) or lowers (negative)
  /// [frequency], in decibels: what its [bands] add up to, one after the
  /// other, filtering at [sampleRate]. Neighbouring peaks overlap, so this
  /// is more than any one band's gain where they agree.
  double responseDb(double frequency, {double sampleRate = 48000}) =>
      bands.fold(
        0,
        (total, band) =>
            total + band.responseDb(frequency, sampleRate: sampleRate),
      );

  /// Serializes this equalizer for platform channel transport.
  Map<String, dynamic> toMap() => {
    'bands': [for (final band in bands) band.toMap()],
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AudioEqualizer && listEquals(other.bands, bands);
  }

  @override
  int get hashCode => Object.hashAll(bands);

  @override
  String toString() => 'AudioEqualizer($bands)';
}
