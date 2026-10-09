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
