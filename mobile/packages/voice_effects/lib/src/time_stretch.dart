import 'dart:typed_data';

import 'package:voice_effects/src/pcm_audio.dart';
import 'package:voice_effects/src/wsola.dart';

/// Changes playback speed without changing pitch or sample rate.
///
/// Unlike an AudioEffect, this changes duration: the result has
/// `ceil(inputFrames / speed)` frames. All channels share a single waveform
/// alignment so stereo phase relationships survive the stretch.
class TimeStretch {
  /// Creates a stretch at [speed] times normal playback speed.
  const TimeStretch(this.speed);

  /// Playback multiplier: `2` halves duration; `0.5` doubles it.
  final double speed;

  /// Returns newly allocated PCM at [speed], leaving [audio] untouched.
  ///
  /// Throws [ArgumentError] for a non-finite or non-positive speed, sample
  /// rate or channel count, or an incomplete interleaved frame.
  PcmAudio apply(PcmAudio audio) {
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Must be finite and positive');
    }
    validatePcmAudio(audio);
    final samples = speed == 1 || audio.samples.isEmpty
        ? Float32List.fromList(audio.samples)
        : Float32List.fromList(
            stretchPcm(
              audio.samples,
              audio.sampleRate,
              1 / speed,
              channels: audio.channels,
            ),
          );
    return PcmAudio(
      samples: samples,
      sampleRate: audio.sampleRate,
      channels: audio.channels,
    );
  }
}
