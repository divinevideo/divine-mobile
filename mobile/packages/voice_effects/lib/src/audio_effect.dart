// ABOUTME: Common contract for an offline effect on mono PCM, and the chain
// ABOUTME: runner that applies several in order and keeps the result unclipped.

import 'dart:typed_data';

/// An offline transformation of a mono signal.
///
/// Samples are floats in `-1.0..1.0`. Every effect returns a new list of the
/// same length as its input, so a processed take keeps the timeline window of
/// the original.
// A class rather than a function type: each effect is a const value carrying
// its own settings, which the app composes into a chain.
// ignore: one_member_abstracts
abstract class AudioEffect {
  /// Const base constructor for subclasses.
  const AudioEffect();

  /// Returns [samples], recorded at [sampleRate] Hz, with the effect applied.
  Float32List apply(Float32List samples, int sampleRate);
}

/// Peak level the chain leaves headroom below, so the 16-bit encode never
/// clips.
const double _peakCeiling = 0.98;

/// Applies [effects] to [samples] in list order.
///
/// Scales the result down when an effect pushed it past full scale — echo
/// stacks repeats on top of the voice and robotization concentrates each
/// period into one pulse — and never scales it up, so a quiet take stays
/// quiet.
Float32List applyAudioEffects(
  Float32List samples,
  int sampleRate,
  List<AudioEffect> effects,
) {
  var output = samples;
  for (final effect in effects) {
    output = effect.apply(output, sampleRate);
  }
  var peak = 0.0;
  for (final sample in output) {
    final level = sample.abs();
    if (level > peak) peak = level;
  }
  if (peak <= _peakCeiling) {
    return identical(output, samples) ? Float32List.fromList(output) : output;
  }
  final scale = _peakCeiling / peak;
  final scaled = Float32List(output.length);
  for (var i = 0; i < output.length; i++) {
    scaled[i] = output[i] * scale;
  }
  return scaled;
}
