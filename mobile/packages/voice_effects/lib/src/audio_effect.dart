// ABOUTME: Common contract for an offline effect on mono or multi-channel PCM,
// ABOUTME: and the chain runner that applies several in order, unclipped.

import 'dart:typed_data';

/// An offline transformation of a signal.
///
/// Samples are floats in `-1.0..1.0`. Every effect returns new samples of the
/// same length as its input, so a processed take keeps the timeline window of
/// the original.
abstract class AudioEffect {
  /// Const base constructor for subclasses.
  const AudioEffect();

  /// Returns the mono [samples], recorded at [sampleRate] Hz, with the effect
  /// applied.
  Float32List apply(Float32List samples, int sampleRate);

  /// Returns [channels] — one list per channel, all of one length, at least
  /// one — with the effect applied.
  ///
  /// Applies [apply] to each channel on its own, which suits an effect that
  /// treats every channel alike. An effect whose channels must stay in step,
  /// or that spreads one signal across them, overrides it.
  List<Float32List> applyToChannels(
    List<Float32List> channels,
    int sampleRate,
  ) => [for (final channel in channels) apply(channel, sampleRate)];
}

/// Peak level the chain leaves headroom below, so the 16-bit encode never
/// clips.
const double _peakCeiling = 0.98;

/// Applies [effects] to the mono [samples] in list order.
///
/// Scales the result down when an effect pushed it past full scale — echo
/// stacks repeats on top of the voice and robotization concentrates each
/// period into one pulse — and never scales it up, so a quiet take stays
/// quiet.
Float32List applyAudioEffects(
  Float32List samples,
  int sampleRate,
  List<AudioEffect> effects,
) => applyAudioEffectsToChannels([samples], sampleRate, effects).single;

/// Applies [effects] to [channels] in list order, as [applyAudioEffects] does
/// to one.
///
/// The channels are scaled down together, so their balance stays.
///
/// Throws an [ArgumentError] when there are no channels.
List<Float32List> applyAudioEffectsToChannels(
  List<Float32List> channels,
  int sampleRate,
  List<AudioEffect> effects,
) {
  if (channels.isEmpty) {
    throw ArgumentError.value(channels, 'channels', 'must not be empty');
  }
  var output = channels;
  for (final effect in effects) {
    output = effect.applyToChannels(output, sampleRate);
  }
  var peak = 0.0;
  for (final channel in output) {
    for (final sample in channel) {
      final level = sample.abs();
      if (level > peak) peak = level;
    }
  }
  if (peak <= _peakCeiling) {
    return [
      for (var c = 0; c < output.length; c++)
        if (identical(output[c], channels[c]))
          Float32List.fromList(output[c])
        else
          output[c],
    ];
  }
  final scale = _peakCeiling / peak;
  return [for (final channel in output) _scaled(channel, scale)];
}

Float32List _scaled(Float32List samples, double scale) {
  final scaled = Float32List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    scaled[i] = samples[i] * scale;
  }
  return scaled;
}
