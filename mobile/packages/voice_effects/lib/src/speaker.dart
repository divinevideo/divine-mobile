// ABOUTME: A voice played through a small, overdriven speaker: clipped, then
// ABOUTME: limited to the band the speaker can reproduce, at the input's level.

import 'dart:typed_data';

import 'package:voice_effects/src/biquad.dart';
import 'package:voice_effects/src/levels.dart';

/// [samples] as a speaker with the pass band [lowCutHz] to [highCutHz] plays
/// them: overdriven by [drive] — the amplifier clips before the cone — then
/// both band edges rolled off at 24 dB per octave, with the cone's resonance
/// raised by [resonanceDb] around [resonanceHz]. The result is brought back to
/// the input's loudness, so a thin voice is not also a quiet one.
Float32List playThroughSpeaker(
  Float32List samples,
  int sampleRate, {
  required double lowCutHz,
  required double highCutHz,
  required double drive,
  double resonanceHz = 1000,
  double resonanceDb = 0,
}) {
  final output = saturate(samples, drive);
  final filters = [
    Biquad.highPass(lowCutHz, sampleRate),
    Biquad.highPass(lowCutHz, sampleRate),
    Biquad.lowPass(highCutHz, sampleRate),
    Biquad.lowPass(highCutHz, sampleRate),
    if (resonanceDb != 0)
      Biquad.peaking(resonanceHz, sampleRate, gainDb: resonanceDb, q: 1.4),
  ];
  for (var i = 0; i < output.length; i++) {
    var x = output[i];
    for (final filter in filters) {
      x = filter.next(x);
    }
    output[i] = x;
  }
  matchLoudness(output, samples);
  return output;
}
