import 'dart:typed_data';

/// PCM audio with interleaved channels and float samples in `-1.0..1.0`.
class PcmAudio {
  /// Creates PCM audio; stereo samples are ordered `L, R, L, R, ...`.
  const PcmAudio({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });

  /// Interleaved samples, containing a whole number of frames.
  final Float32List samples;

  /// Sample frames per second, greater than zero.
  final int sampleRate;

  /// Number of samples per frame, greater than zero.
  final int channels;
}

/// Checks the PCM layout before encoding or processing it.
void validatePcmAudio(PcmAudio audio) {
  if (audio.sampleRate <= 0) {
    throw ArgumentError.value(
      audio.sampleRate,
      'sampleRate',
      'Must be positive',
    );
  }
  if (audio.channels <= 0) {
    throw ArgumentError.value(audio.channels, 'channels', 'Must be positive');
  }
  if (audio.samples.length % audio.channels != 0) {
    throw ArgumentError('Samples must contain complete interleaved frames');
  }
}
