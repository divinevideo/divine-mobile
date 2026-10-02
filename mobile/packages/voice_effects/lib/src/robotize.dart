// ABOUTME: Robot voice: every short-time frame keeps its spectrum but loses its
// ABOUTME: phase, and the frames are laid one pitch period apart.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/fft.dart';

/// Turns a voice into a monotone robot at [pitchHz].
///
/// Phase-vocoder robotization: each analysis frame is replaced by the
/// zero-phase signal with the same magnitude spectrum — a single pulse that
/// still carries the frame's vowel colour — and the pulses are overlap-added
/// exactly one period of [pitchHz] apart. The words stay intelligible while
/// the melody of the speech is flattened into one buzzing note. The robot is
/// matched to the input's loudness and blended in by [mix].
class Robotize extends AudioEffect {
  /// Creates a robot voice at [pitchHz], blended in by [mix].
  const Robotize({this.pitchHz = 105, this.mix = 1})
    : assert(pitchHz > 0, 'pitchHz > 0'),
      assert(mix >= 0 && mix <= 1, 'mix must be in [0, 1]');

  /// The single note the robot speaks on.
  final double pitchHz;

  /// How much of the robot replaces the voice: `0` is the voice alone, `1`
  /// the robot alone, and anything between plays both.
  final double mix;

  /// Analysis frame length, in seconds, before rounding to a power of two.
  static const double _frameSeconds = 0.025;

  @override
  Float32List apply(Float32List samples, int sampleRate) {
    final size = powerOfTwoAtMost(sampleRate * _frameSeconds);
    final hop = math.max(1, (sampleRate / pitchHz).round());
    final window = hannWindow(size);
    final fft = Fft(size);
    final re = Float64List(size);
    final im = Float64List(size);

    // Padding on both sides lets the first and last samples sit under whole
    // frames, so the take does not fade in or out at its edges.
    final padded = Float64List(samples.length + 2 * size);
    for (var i = 0; i < samples.length; i++) {
      padded[size + i] = samples[i];
    }
    final out = Float64List(padded.length);
    final half = size ~/ 2;

    for (var start = 0; start + size <= padded.length; start += hop) {
      for (var i = 0; i < size; i++) {
        re[i] = padded[start + i] * window[i];
        im[i] = 0;
      }
      fft.forward(re, im);
      for (var k = 0; k < size; k++) {
        re[k] = math.sqrt(re[k] * re[k] + im[k] * im[k]);
        im[k] = 0;
      }
      fft.inverse(re, im);
      // The zero-phase pulse sits at index 0 and wraps around; rotating by
      // half a frame centres it under the window.
      for (var i = 0; i < size; i++) {
        out[start + i] += re[(i + half) % size] * window[i];
      }
    }

    final robot = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      robot[i] = out[size + i];
    }
    _matchLoudness(robot, samples);
    for (var i = 0; i < samples.length; i++) {
      robot[i] = (1 - mix) * samples[i] + mix * robot[i];
    }
    return robot;
  }

  /// Scales [output] in place to the RMS level of [reference].
  static void _matchLoudness(Float32List output, Float32List reference) {
    final target = _rms(reference);
    final current = _rms(output);
    if (current == 0) return;
    final gain = target / current;
    for (var i = 0; i < output.length; i++) {
      output[i] *= gain;
    }
  }

  static double _rms(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }
}
