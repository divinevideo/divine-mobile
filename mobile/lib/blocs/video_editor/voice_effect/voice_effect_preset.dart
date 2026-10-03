// ABOUTME: One-tap voice effects the voice-effect sheet offers above its
// ABOUTME: sliders; each is just a setting the sliders could reach too.

import 'package:models/models.dart' show VoiceEffect;

/// A one-tap [VoiceEffect].
///
/// The settings are the product's tuning: far enough to be the joke, not so
/// far that the words get lost.
enum VoiceEffectPreset {
  /// The voice as recorded.
  original(VoiceEffect.none),

  /// Higher and smaller, like a chipmunk.
  highPitch(VoiceEffect(pitch: 8)),

  /// Lower and bigger, like a movie-trailer narrator.
  lowPitch(VoiceEffect(pitch: -5)),

  /// A monotone robot.
  robot(VoiceEffect(robot: VoiceEffect.maxAmount)),

  /// Repeats bouncing back from a big room.
  echo(VoiceEffect(echo: 80));

  const VoiceEffectPreset(this.effect);

  /// The setting this preset picks.
  final VoiceEffect effect;

  /// The preset whose setting is [effect], or `null` for a setting made with
  /// the sliders that no preset matches.
  static VoiceEffectPreset? matching(VoiceEffect effect) {
    for (final preset in values) {
      if (preset.effect == effect) return preset;
    }
    return null;
  }
}
