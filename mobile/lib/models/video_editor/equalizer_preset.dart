// ABOUTME: One-tap equalizer settings the equalizer sheet offers above its
// ABOUTME: curve; each is just a setting the curve's points could reach too.

import 'package:models/models.dart' show EqualizerSettings;

/// A one-tap [EqualizerSettings], one gain per octave band from 31 Hz to
/// 16 kHz.
///
/// The settings are the product's tuning: a step from the recording that is
/// clearly heard on a phone speaker, which plays little below 250 Hz, yet
/// still sounds like the recording.
enum EqualizerPreset {
  /// The audio as recorded.
  original(EqualizerSettings.none),

  /// Less rumble and boom under a voice, more of the presence that makes
  /// words clear: for a muffled phone recording.
  voice(EqualizerSettings([-12, -10, -6, -3, -1, 0, 2, 4, 3, 0])),

  /// More low end, for music that sounds thin, reaching up to where a phone
  /// speaker plays it.
  bassy(EqualizerSettings([5, 6, 5, 4, 2, 0, 0, 0, 0, 0])),

  /// More high end, for a recording that sounds dull.
  bright(EqualizerSettings([0, 0, 0, 0, 0, 0, 1, 3, 5, 6]));

  const EqualizerPreset(this.settings);

  /// The setting this preset picks.
  final EqualizerSettings settings;

  /// The preset whose setting is [settings], or `null` for a setting made
  /// on the curve that no preset matches.
  static EqualizerPreset? matching(EqualizerSettings settings) {
    for (final preset in values) {
      if (preset.settings == settings) return preset;
    }
    return null;
  }
}
