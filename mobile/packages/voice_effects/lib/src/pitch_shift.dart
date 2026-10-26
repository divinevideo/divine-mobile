// ABOUTME: Shifts a voice up or down in pitch without changing its length:
// ABOUTME: a WSOLA time-stretch followed by resampling back to the original.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/biquad.dart';
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
  Float32List apply(Float32List samples, int sampleRate) =>
      applyToChannels([samples], sampleRate).single;

  /// Shifts every channel through the same frames: where the frames line up
  /// best is searched on the channels' average, so a sound in the middle of a
  /// stereo mix stays there instead of smearing between channels that were
  /// stretched apart.
  @override
  List<Float32List> applyToChannels(
    List<Float32List> channels,
    int sampleRate,
  ) {
    final ratio = math.pow(2, semitones / 12).toDouble();
    if (ratio == 1 || channels.first.isEmpty) {
      return [for (final channel in channels) Float32List.fromList(channel)];
    }
    final frame = math.max(4, (sampleRate * _frameSeconds).round() & ~1);
    final guide = channels.length == 1 ? channels.single : _average(channels);
    final positions = _alignments(guide, sampleRate, ratio, frame);
    return [
      for (final channel in channels)
        _shift(channel, positions, sampleRate, ratio, frame),
    ];
  }

  /// Where each WSOLA frame of [samples] is read from to stretch them
  /// [ratio] times longer at the same pitch, as positions in the samples
  /// padded by a [frame] on each side, so the edges are covered by whole
  /// frames.
  static List<int> _alignments(
    Float32List samples,
    int sampleRate,
    double ratio,
    int frame,
  ) {
    final synthesisHop = frame ~/ 2;
    final analysisHop = synthesisHop / ratio;
    final tolerance = math.min(
      synthesisHop - 1,
      (sampleRate * _toleranceSeconds).round(),
    );
    // Every sample's correlation is not needed to find the alignment; a
    // decimated sum finds the same peak for a fraction of the work.
    final stride = math.max(1, sampleRate ~/ 16000);
    final input = _Padded(samples, frame);
    final outputLength = _stretchedLength(samples, ratio, frame);
    final positions = <int>[];
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
      positions.add(position);
      previous = position;
    }
    return positions;
  }

  /// [samples] stretched through the frames at [positions], then read back
  /// at [ratio] times the speed into their original length.
  static Float32List _shift(
    Float32List samples,
    List<int> positions,
    int sampleRate,
    double ratio,
    int frame,
  ) {
    final synthesisHop = frame ~/ 2;
    final window = hannWindow(frame);
    final input = _Padded(samples, frame);
    final stretched = Float32List(_stretchedLength(samples, ratio, frame));
    for (var k = 0; k < positions.length; k++) {
      final outStart = k * synthesisHop;
      final position = positions[k];
      for (var i = 0; i < frame; i++) {
        stretched[outStart + i] += window[i] * input[position + i];
      }
    }
    if (ratio > 1) {
      _lowPass(stretched, sampleRate / (2 * ratio) * 0.9, sampleRate);
    }
    // The stretched padding is skipped.
    return _resample(
      stretched,
      start: (frame * ratio).round(),
      length: samples.length,
      ratio: ratio,
    );
  }

  /// Length of the overlap-add buffer for [samples] padded by a [frame] on
  /// each side and stretched [ratio] times.
  static int _stretchedLength(Float32List samples, double ratio, int frame) =>
      ((samples.length + 2 * frame) * ratio).ceil() + frame;

  /// The sample-by-sample average of [channels].
  static Float32List _average(List<Float32List> channels) {
    final average = Float32List(channels.first.length);
    for (var i = 0; i < average.length; i++) {
      var sum = 0.0;
      for (final channel in channels) {
        sum += channel[i];
      }
      average[i] = sum / channels.length;
    }
    return average;
  }

  /// Position within `nominal ± tolerance` whose next [length] samples best
  /// continue the waveform at [target].
  static int _bestAlignment(
    _Padded input, {
    required int target,
    required int nominal,
    required int tolerance,
    required int length,
    required int stride,
  }) {
    double correlation(int candidate) {
      var sum = 0.0;
      for (var i = 0; i < length; i += stride) {
        sum += input[target + i] * input[candidate + i];
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

  /// [stretched] from [start] on, read back at [ratio] times the speed into
  /// [length] samples, with cubic interpolation between source samples.
  static Float32List _resample(
    Float32List stretched, {
    required int start,
    required int length,
    required double ratio,
  }) {
    final output = Float32List(length);
    for (var i = 0; i < length; i++) {
      final position = start + i * ratio;
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
  static void _lowPass(Float32List signal, double cutoffHz, int sampleRate) {
    final first = Biquad.lowPass(cutoffHz, sampleRate);
    final second = Biquad.lowPass(cutoffHz, sampleRate);
    for (var i = 0; i < signal.length; i++) {
      signal[i] = second.next(first.next(signal[i]));
    }
  }

  static double _at(Float32List signal, int index) =>
      index >= 0 && index < signal.length ? signal[index] : 0;
}

/// Samples read as if padded with [pad] zeros on each side, without copying
/// them.
class _Padded {
  const _Padded(this.samples, this.pad);

  final Float32List samples;
  final int pad;

  double operator [](int index) {
    final i = index - pad;
    return i >= 0 && i < samples.length ? samples[i] : 0;
  }
}
