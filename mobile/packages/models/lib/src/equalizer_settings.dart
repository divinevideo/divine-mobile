// ABOUTME: How a clip's or a sound's audio is raised or lowered in ten
// ABOUTME: octave bands, in whole decibels, for the editor's equalizer.

import 'package:meta/meta.dart';

/// How a clip's or a sound's audio is raised or lowered in each of ten
/// octave bands, centred on [frequencies].
///
/// Each gain is a whole number of decibels from [minGain] to [maxGain], so
/// presets and dragged settings are the same thing and a setting persists
/// exactly. [none] plays the audio as recorded. Local editor state only: it is
/// never published in an event's tags.
@immutable
class EqualizerSettings {
  /// Creates settings from one gain per band, lowest band first.
  ///
  /// The gains must be in range and there must be [bandCount] of them; use
  /// [EqualizerSettings.fromGains] for values that may not be.
  const EqualizerSettings(this.gains);

  /// Creates settings from [gains], clamping each to its range, filling
  /// missing bands with zero and ignoring any beyond [bandCount].
  factory EqualizerSettings.fromGains(List<int> gains) => EqualizerSettings(
    List.unmodifiable([
      for (var band = 0; band < bandCount; band++)
        if (band < gains.length) _clamp(gains[band]) else 0,
    ]),
  );

  /// Reads a value [toJson] wrote. Anything unreadable is the recording.
  factory EqualizerSettings.fromJson(Map<String, dynamic> json) {
    final gains = json['gains'];
    if (gains is! List) return none;
    return EqualizerSettings.fromGains([
      for (final gain in gains)
        if (gain is num) gain.round() else 0,
    ]);
  }

  /// The audio as recorded.
  static const none = EqualizerSettings([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

  /// The middle of each band, lowest first, in hertz: the octaves of a
  /// graphic equalizer, from the sub-bass felt more than heard to the air
  /// above a voice. A phone speaker plays little below the 250 Hz band.
  static const frequencies = [
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  /// How many bands there are.
  static const bandCount = 10;

  /// The deepest cut, in decibels.
  static const minGain = -18;

  /// The strongest boost, in decibels.
  static const maxGain = 18;

  /// Decibels each band is raised (positive) or lowered (negative), lowest
  /// band first.
  final List<int> gains;

  /// Whether this leaves the audio as recorded.
  bool get isNone => gains.every((gain) => gain == 0);

  /// Creates a copy with the gain of [band] set to [gain], clamped to its
  /// range.
  EqualizerSettings withGain(int band, int gain) => EqualizerSettings.fromGains(
    [
      for (var i = 0; i < bandCount; i++)
        if (i == band) gain else gains[i],
    ],
  );

  /// The gains of every band.
  Map<String, dynamic> toJson() => {'gains': List<int>.of(gains)};

  static int _clamp(int gain) =>
      gain < minGain ? minGain : (gain > maxGain ? maxGain : gain);

  @override
  bool operator ==(Object other) {
    if (other is! EqualizerSettings || other.gains.length != gains.length) {
      return false;
    }
    for (var i = 0; i < gains.length; i++) {
      if (other.gains[i] != gains[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(gains);

  @override
  String toString() => 'EqualizerSettings(gains: $gains)';
}
