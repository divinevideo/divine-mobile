// ABOUTME: Level helpers the effects share: a signal's RMS, scaling an
// ABOUTME: effect's output back to its input's loudness, and soft clipping.

import 'dart:math' as math;
import 'dart:typed_data';

/// Root-mean-square level of [samples], `0` when there are none.
double rmsOf(Float32List samples) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final sample in samples) {
    sum += sample * sample;
  }
  return math.sqrt(sum / samples.length);
}

/// Scales [output] in place to the RMS level of [reference].
///
/// Leaves silent output alone: there is nothing to scale.
void matchLoudness(Float32List output, Float32List reference) {
  final current = rmsOf(output);
  if (current == 0) return;
  final gain = rmsOf(reference) / current;
  for (var i = 0; i < output.length; i++) {
    output[i] *= gain;
  }
}

/// [samples] driven into a soft clipper: the loudest sample is brought to
/// [drive] before it is rounded off, so the higher [drive], the more the
/// peaks flatten and the more harmonics the sound gains, at any recording
/// level.
///
/// Returns a silent copy for silent [samples].
Float32List saturate(Float32List samples, double drive) {
  var peak = 0.0;
  for (final sample in samples) {
    final level = sample.abs();
    if (level > peak) peak = level;
  }
  final output = Float32List(samples.length);
  if (peak == 0) return output;
  final gain = drive / peak;
  for (var i = 0; i < samples.length; i++) {
    final x = samples[i] * gain;
    output[i] = x / math.sqrt(1 + x * x);
  }
  return output;
}
