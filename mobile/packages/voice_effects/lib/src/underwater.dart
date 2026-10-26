// ABOUTME: Underwater voice: everything but the lows is muffled away, and the
// ABOUTME: pitch drifts gently, as sound does through moving water.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/biquad.dart';
import 'package:voice_effects/src/levels.dart';

/// Makes a voice sound as if it was heard underwater.
///
/// A steep low-pass at [cutoffHz] muffles everything that makes words crisp,
/// and a delay swinging between zero and [warbleDepth], [warbleHz] times a
/// second, bends the pitch gently up and down. The result keeps the voice's
/// loudness.
class Underwater extends AudioEffect {
  /// Creates an underwater voice.
  const Underwater({
    this.cutoffHz = 500,
    this.warbleDepth = const Duration(microseconds: 1500),
    this.warbleHz = 1.1,
  });

  /// Above this, the voice is rolled off at 24 dB per octave.
  final double cutoffHz;

  /// The longest the warble delays the voice.
  final Duration warbleDepth;

  /// How many times a second the warble swings.
  final double warbleHz;

  @override
  Float32List apply(Float32List samples, int sampleRate) {
    final depth =
        warbleDepth.inMicroseconds *
        sampleRate /
        Duration.microsecondsPerSecond;
    final phaseStep = 2 * math.pi * warbleHz / sampleRate;
    final filters = [
      Biquad.lowPass(cutoffHz, sampleRate),
      Biquad.lowPass(cutoffHz, sampleRate),
    ];
    final output = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      // The delay starts at zero, so the take does not start late.
      final delay = depth * (1 - math.cos(phaseStep * i)) / 2;
      final position = i - delay;
      final index = position.floor();
      final t = position - index;
      var x = (1 - t) * _at(samples, index) + t * _at(samples, index + 1);
      for (final filter in filters) {
        x = filter.next(x);
      }
      output[i] = x;
    }
    matchLoudness(output, samples);
    return output;
  }

  static double _at(Float32List samples, int index) =>
      index >= 0 && index < samples.length ? samples[index] : 0;
}
