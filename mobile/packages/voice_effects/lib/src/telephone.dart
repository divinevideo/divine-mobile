// ABOUTME: Phone-call voice: the thin, slightly gritty sound of a voice
// ABOUTME: squeezed into a telephone line or an old radio.

import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/speaker.dart';

/// Makes a voice sound as if it came through a phone or an old radio.
///
/// The voice is cut down to the band a telephone line carries, [lowCutHz] to
/// [highCutHz] — no chest, no air — and driven lightly by [drive] for the
/// grit of a cheap earpiece, at its original loudness.
class Telephone extends AudioEffect {
  /// Creates a phone voice.
  const Telephone({
    this.lowCutHz = 300,
    this.highCutHz = 3400,
    this.drive = 1.5,
  }) : assert(drive > 0, 'drive must be positive');

  /// Below this, the voice is rolled off.
  final double lowCutHz;

  /// Above this, the voice is rolled off.
  final double highCutHz;

  /// How hard the voice is driven into the clipper.
  final double drive;

  @override
  Float32List apply(Float32List samples, int sampleRate) => playThroughSpeaker(
    samples,
    sampleRate,
    lowCutHz: lowCutHz,
    highCutHz: highCutHz,
    drive: drive,
  );
}
