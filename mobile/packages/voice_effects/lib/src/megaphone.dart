// ABOUTME: Megaphone voice: narrow, honky and a little distorted, like an
// ABOUTME: announcement through a handheld loudspeaker.

import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/speaker.dart';

/// Makes a voice sound as if it came through a megaphone.
///
/// A megaphone's amplifier clips, so the voice is first driven hard by
/// [drive]. Its horn then passes only [lowCutHz] to [highCutHz], narrower than
/// a phone, and rings around [hornHz], raised by [hornDb] — the honk that
/// makes it carry. The result keeps the voice's loudness.
class Megaphone extends AudioEffect {
  /// Creates a megaphone voice.
  const Megaphone({
    this.lowCutHz = 500,
    this.highCutHz = 4000,
    this.hornHz = 1800,
    this.hornDb = 8,
    this.drive = 5,
  }) : assert(drive > 0, 'drive must be positive');

  /// Below this, the voice is rolled off.
  final double lowCutHz;

  /// Above this, the voice is rolled off.
  final double highCutHz;

  /// Centre of the horn's resonance.
  final double hornHz;

  /// How much the horn raises the band around [hornHz], in decibels.
  final double hornDb;

  /// How hard the voice is driven into the clipper.
  final double drive;

  @override
  Float32List apply(Float32List samples, int sampleRate) => playThroughSpeaker(
    samples,
    sampleRate,
    lowCutHz: lowCutHz,
    highCutHz: highCutHz,
    drive: drive,
    resonanceHz: hornHz,
    resonanceDb: hornDb,
  );
}
