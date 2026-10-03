// ABOUTME: Shifts a voice up or down in pitch without changing its length:
// ABOUTME: a WSOLA time-stretch followed by resampling back to the original.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/fft.dart';

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

  /// WSOLA frame length, in seconds. Long enough to span two periods of a low
  /// voice, short enough not to smear syllables.
  static const double _frameSeconds = 0.03;

  /// How far, in seconds, a frame may move from its nominal position to line
  /// up with the previous one.
  static const double _toleranceSeconds = 0.008;

  /// Coarse step of the alignment search before it is refined sample by
  /// sample around the best candidate.
  static const int _coarseStep = 4;

  @override
  Float32List apply(Float32List samples, int sampleRate) {
    final ratio = math.pow(2, semitones / 12).toDouble();
    if (ratio == 1 || samples.isEmpty) return Float32List.fromList(samples);
    final stretched = _stretch(samples, sampleRate, ratio);
    if (ratio > 1) {
      _lowPass(stretched, sampleRate / (2 * ratio) * 0.9, sampleRate);
    }
    return _resample(stretched, samples.length, ratio);
  }

  /// [samples] made [ratio] times longer at the same pitch.
  Float64List _stretch(Float32List samples, int sampleRate, double ratio) {
    final frame = math.max(4, (sampleRate * _frameSeconds).round() & ~1);
    final synthesisHop = frame ~/ 2;
    final analysisHop = synthesisHop / ratio;
    final tolerance = math.min(
      synthesisHop - 1,
      (sampleRate * _toleranceSeconds).round(),
    );
    final window = hannWindow(frame);
    // Every sample's correlation is not needed to find the alignment; a
    // decimated sum finds the same peak for a fraction of the work.
    final stride = math.max(1, sampleRate ~/ 16000);

    // Pad by a frame on each side so the edges are covered by whole frames.
    final pad = frame;
    final input = Float64List(samples.length + 2 * pad);
    for (var i = 0; i < samples.length; i++) {
      input[pad + i] = samples[i];
    }
    final outputLength = (input.length * ratio).ceil() + frame;
    final output = Float64List(outputLength);

    var previous = 0;
    for (var k = 0; ; k++) {
      final outStart = k * synthesisHop;
      if (outStart + frame > outputLength) break;
      final nominal = (k * analysisHop).round();
      final position = k == 0
          ? 0
          : _bestAlignment(
              input,
              target: previous + synthesisHop,
              nominal: nominal,
              tolerance: tolerance,
              length: frame - synthesisHop,
              stride: stride,
            );
      for (var i = 0; i < frame; i++) {
        output[outStart + i] += window[i] * _at(input, position + i);
      }
      previous = position;
    }

    // Crop the stretched padding back off.
    final start = (pad * ratio).round();
    final length = (samples.length * ratio).ceil();
    final cropped = Float64List(length);
    for (var i = 0; i < length; i++) {
      cropped[i] = _at(output, start + i);
    }
    return cropped;
  }

  /// Position within `nominal ± tolerance` whose next [length] samples best
  /// continue the waveform at [target].
  static int _bestAlignment(
    Float64List input, {
    required int target,
    required int nominal,
    required int tolerance,
    required int length,
    required int stride,
  }) {
    double correlation(int candidate) {
      var sum = 0.0;
      for (var i = 0; i < length; i += stride) {
        sum += _at(input, target + i) * _at(input, candidate + i);
      }
      return sum;
    }

    var best = nominal;
    var bestScore = double.negativeInfinity;
    for (var delta = -tolerance; delta <= tolerance; delta += _coarseStep) {
      final score = correlation(nominal + delta);
      if (score > bestScore) {
        bestScore = score;
        best = nominal + delta;
      }
    }
    final first = math.max(best - _coarseStep + 1, nominal - tolerance);
    final last = math.min(best + _coarseStep - 1, nominal + tolerance);
    for (var candidate = first; candidate <= last; candidate++) {
      final score = correlation(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return math.max(0, best);
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
