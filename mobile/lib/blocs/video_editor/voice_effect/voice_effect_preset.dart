// ABOUTME: One-tap voice effects the voice-effect sheet offers above its
// ABOUTME: sliders; each is a setting, and slowed + reverb also a speed.

import 'package:models/models.dart' show VoiceEffect, VoiceFilter;

/// A one-tap [VoiceEffect], and for a preset that also slows the sound, its
/// [playbackSpeed].
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
  echo(VoiceEffect(echo: 80)),

  /// The voice in a big, live room.
  reverb(VoiceEffect(reverb: 50)),

  /// The other end of a phone call.
  telephone(VoiceEffect(filter: VoiceFilter.telephone)),

  /// An announcer through a loudspeaker.
  megaphone(VoiceEffect(filter: VoiceFilter.megaphone)),

  /// A voice heard underwater.
  underwater(VoiceEffect(filter: VoiceFilter.underwater)),

  /// The dreamy edit of a song: played slower and lower, like a tape run
  /// slow, in a big hall.
  ///
  /// The sound's speed keeps its pitch, so the pitch is lowered on its own,
  /// by the 4 semitones a tape at 0.8× drops.
  slowedReverb(VoiceEffect(pitch: -4, reverb: 60), playbackSpeed: 0.8);

  const VoiceEffectPreset(this.effect, {this.playbackSpeed});

  /// The setting this preset picks.
  final VoiceEffect effect;

  /// The speed this preset plays the sound at, or `null` for a preset that
  /// leaves the speed alone.
  final double? playbackSpeed;

  /// The preset whose setting is [effect] and, if it has one, whose speed is
  /// [playbackSpeed], or `null` for a setting made with the sliders that no
  /// preset matches.
  static VoiceEffectPreset? matching(
    VoiceEffect effect, {
    required double playbackSpeed,
  }) {
    for (final preset in values) {
      if (preset.effect == effect &&
          (preset.playbackSpeed == null ||
              preset.playbackSpeed == playbackSpeed)) {
        return preset;
      }
    }
    return null;
  }
}
