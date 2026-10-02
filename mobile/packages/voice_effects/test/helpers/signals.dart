import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/fft.dart';

/// [seconds] of a sine at [hz] and [amplitude], sampled at [sampleRate].
Float32List sine({
  required double hz,
  required double seconds,
  required int sampleRate,
  double amplitude = 0.5,
}) {
  final length = (seconds * sampleRate).round();
  return Float32List.fromList([
    for (var i = 0; i < length; i++)
      amplitude * math.sin(2 * math.pi * hz * i / sampleRate),
  ]);
}

/// [seconds] of uniform white noise at [amplitude], seeded so runs repeat.
Float32List whiteNoise({
  required double seconds,
  required int sampleRate,
  required double amplitude,
  int seed = 7,
}) {
  final random = math.Random(seed);
  final length = (seconds * sampleRate).round();
  return Float32List.fromList([
    for (var i = 0; i < length; i++) amplitude * (random.nextDouble() * 2 - 1),
  ]);
}

/// Root-mean-square level of `samples[from, to)`.
double rms(Float32List samples, [int from = 0, int? to]) {
  final end = to ?? samples.length;
  var sum = 0.0;
  for (var i = from; i < end; i++) {
    sum += samples[i] * samples[i];
  }
  return math.sqrt(sum / (end - from));
}

/// Level ratio of [a] over [b] in decibels.
double decibels(double a, double b) => 20 * math.log(a / b) / math.ln10;

/// Frequency, in hertz, of the strongest spectral peak in the 8192 samples
/// starting at [from].
double dominantFrequency(Float32List samples, int sampleRate, {int from = 0}) {
  const size = 8192;
  final fft = Fft(size);
  final window = hannWindow(size);
  final re = Float64List(size);
  final im = Float64List(size);
  for (var i = 0; i < size; i++) {
    re[i] = samples[from + i] * window[i];
  }
  fft.forward(re, im);
  var peak = 1;
  var peakPower = 0.0;
  for (var k = 1; k < size ~/ 2; k++) {
    final power = re[k] * re[k] + im[k] * im[k];
    if (power > peakPower) {
      peakPower = power;
      peak = k;
    }
  }
  return peak * sampleRate / size;
}

/// Normalised autocorrelation of `samples[from, from + length)` with itself
/// [lag] samples later: `1` for a signal that repeats every [lag] samples.
double periodicity(
  Float32List samples, {
  required int from,
  required int length,
  required int lag,
}) {
  var cross = 0.0;
  var energyA = 0.0;
  var energyB = 0.0;
  for (var i = from; i < from + length; i++) {
    final a = samples[i];
    final b = samples[i + lag];
    cross += a * b;
    energyA += a * a;
    energyB += b * b;
  }
  return cross / math.sqrt(energyA * energyB);
}
