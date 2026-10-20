// ABOUTME: Shared WSOLA time stretching with one frame alignment across all
// ABOUTME: channels, used by pitch shifting and playback-speed processing.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/fft.dart';

/// WSOLA frame length, in seconds. Long enough to span two periods of a low
/// voice, short enough not to smear syllables.
const double _frameSeconds = 0.03;

/// How far, in seconds, a frame may move from its nominal position to line
/// up with the previous one.
const double _toleranceSeconds = 0.008;

/// Coarse step of the alignment search before it is refined sample by
/// sample around the best candidate.
const int _coarseStep = 4;

/// [samples] made [ratio] times longer at the same pitch.
Float64List stretchPcm(
  Float32List samples,
  int sampleRate,
  double ratio, {
  int channels = 1,
}) {
  final frames = samples.length ~/ channels;
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
  final input = Float64List((frames + 2 * pad) * channels);
  for (var i = 0; i < samples.length; i++) {
    input[pad * channels + i] = samples[i];
  }
  final outputLength = ((frames + 2 * pad) * ratio).ceil() + frame;
  final output = Float64List(outputLength * channels);

  var previous = 0;
  for (var k = 0; ; k++) {
    final outStart = k * synthesisHop;
    if (outStart + frame > outputLength) break;
    final nominal = (k * analysisHop).round();
    final position = k == 0
        ? 0
        : _bestAlignment(
            input,
            channels: channels,
            target: previous + synthesisHop,
            nominal: nominal,
            tolerance: tolerance,
            length: frame - synthesisHop,
            stride: stride,
          );
    for (var i = 0; i < frame; i++) {
      for (var channel = 0; channel < channels; channel++) {
        output[(outStart + i) * channels + channel] +=
            window[i] * _at(input, (position + i) * channels + channel);
      }
    }
    previous = position;
  }

  // Crop the stretched padding back off.
  final start = (pad * ratio).round();
  final length = (frames * ratio).ceil();
  final cropped = Float64List(length * channels);
  for (var i = 0; i < cropped.length; i++) {
    cropped[i] = _at(output, start * channels + i);
  }
  return cropped;
}

/// Position within `nominal ± tolerance` whose next [length] samples best
/// continue the waveform at [target].
int _bestAlignment(
  Float64List input, {
  required int channels,
  required int target,
  required int nominal,
  required int tolerance,
  required int length,
  required int stride,
}) {
  double correlation(int candidate) {
    var sum = 0.0;
    for (var i = 0; i < length; i += stride) {
      for (var channel = 0; channel < channels; channel++) {
        sum +=
            _at(input, (target + i) * channels + channel) *
            _at(input, (candidate + i) * channels + channel);
      }
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

double _at(Float64List signal, int index) =>
    index >= 0 && index < signal.length ? signal[index] : 0;
