// ABOUTME: Shifts a voice up or down in pitch without changing its length:
// ABOUTME: a WSOLA time-stretch followed by resampling back to the original.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/wsola.dart';

/// Moves a voice [semitones] up or down while keeping its timing.
///
/// The take is first stretched in time by the pitch ratio with WSOLA, which
/// overlap-adds short frames from wherever the waveform lines up best with the
/// previous one, so the stretch keeps the pitch. Reading that stretched signal
/// back at the ratio's speed then restores the original length and moves every
/// frequency, formants included: up sounds like a chipmunk, down like a giant.
class PitchShift extends AudioEffect {
  /// Creates a pitch shift by [semitones]; positive is higher.
  const PitchShift(this.semitones);

  /// How far the voice moves, in equal-tempered semitones.
  final double semitones;

  @override
  Float32List apply(Float32List samples, int sampleRate) {
    final ratio = math.pow(2, semitones / 12).toDouble();
    if (ratio == 1 || samples.isEmpty) return Float32List.fromList(samples);
    final stretched = stretchPcm(samples, sampleRate, ratio);
    if (ratio > 1) {
      _lowPass(stretched, sampleRate / (2 * ratio) * 0.9, sampleRate);
    }
    return _resample(stretched, samples.length, ratio);
  }

  /// [stretched] read back at [ratio] times the speed into [length] samples,
  /// with cubic interpolation between source samples.
  static Float32List _resample(
    Float64List stretched,
    int length,
    double ratio,
  ) {
    final output = Float32List(length);
    for (var i = 0; i < length; i++) {
      final position = i * ratio;
      final index = position.floor();
      final t = position - index;
      final p0 = _at(stretched, index - 1);
      final p1 = _at(stretched, index);
      final p2 = _at(stretched, index + 1);
      final p3 = _at(stretched, index + 2);
      // Catmull-Rom spline through the four neighbours.
      output[i] =
          p1 +
          0.5 *
              t *
              (p2 -
                  p0 +
                  t *
                      (2 * p0 -
                          5 * p1 +
                          4 * p2 -
                          p3 +
                          t * (3 * (p1 - p2) + p3 - p0)));
    }
    return output;
  }

  /// Filters [signal] in place with two cascaded Butterworth low-pass biquads
  /// at [cutoffHz], so content the speed-up would fold back below Nyquist is
  /// removed first.
  static void _lowPass(Float64List signal, double cutoffHz, int sampleRate) {
    final omega = 2 * math.pi * cutoffHz / sampleRate;
    final alpha = math.sin(omega) / math.sqrt2;
    final cosine = math.cos(omega);
    final a0 = 1 + alpha;
    final b0 = (1 - cosine) / 2 / a0;
    final b1 = (1 - cosine) / a0;
    final a1 = -2 * cosine / a0;
    final a2 = (1 - alpha) / a0;
    for (var pass = 0; pass < 2; pass++) {
      var x1 = 0.0;
      var x2 = 0.0;
      var y1 = 0.0;
      var y2 = 0.0;
      for (var i = 0; i < signal.length; i++) {
        final x0 = signal[i];
        final y0 = b0 * x0 + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2;
        x2 = x1;
        x1 = x0;
        y2 = y1;
        y1 = y0;
        signal[i] = y0;
      }
    }
  }

  static double _at(Float64List signal, int index) =>
      index >= 0 && index < signal.length ? signal[index] : 0;
}
