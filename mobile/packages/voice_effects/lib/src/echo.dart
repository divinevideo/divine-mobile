// ABOUTME: Feedback-delay echo whose repeats fade and darken, like a voice
// ABOUTME: bouncing back from the far wall of a big room.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';

/// Repeats the voice after [delay], each repeat [feedback] times quieter and
/// a little duller than the one before.
///
/// The repeats run in a delay line with a one-pole low-pass in its feedback
/// path, cutting above [dampingHz], so they read as distance rather than as a
/// metallic copy. The output keeps the input's length: repeats still ringing
/// when the take ends are cut with it.
class Echo extends AudioEffect {
  /// Creates an echo.
  const Echo({
    this.delay = const Duration(milliseconds: 260),
    this.feedback = 0.42,
    this.mix = 0.5,
    this.dampingHz = 3200,
  }) : assert(feedback >= 0 && feedback < 1, 'feedback must be in [0, 1)');

  /// Time between the voice and its first repeat.
  final Duration delay;

  /// Level of each repeat relative to the previous one.
  final double feedback;

  /// Level of the first repeat relative to the voice.
  final double mix;

  /// Corner frequency of the low-pass each repeat passes through.
  final double dampingHz;

  @override
  Float32List apply(Float32List samples, int sampleRate) {
    final output = Float32List(samples.length);
    final delaySamples = math.max(
      1,
      (delay.inMicroseconds * sampleRate / Duration.microsecondsPerSecond)
          .round(),
    );
    final line = Float64List(delaySamples);
    final coefficient = math.exp(-2 * math.pi * dampingHz / sampleRate);
    var lowPassed = 0.0;
    var cursor = 0;
    for (var i = 0; i < samples.length; i++) {
      lowPassed = (1 - coefficient) * line[cursor] + coefficient * lowPassed;
      line[cursor] = samples[i] + feedback * lowPassed;
      output[i] = samples[i] + mix * lowPassed;
      cursor = cursor + 1 == delaySamples ? 0 : cursor + 1;
    }
    return output;
  }
}
