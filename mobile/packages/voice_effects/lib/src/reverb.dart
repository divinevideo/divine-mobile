// ABOUTME: Room and hall reverb: a Freeverb network of damped combs and
// ABOUTME: all-passes, with a decorrelated tail per side for stereo sound.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/biquad.dart';

/// Places the sound in a room or a hall.
///
/// A Freeverb network (Jezar at Dreampoint's tuning of the Schroeder-Moorer
/// reverberator): eight parallel comb filters, each with a low-pass in its
/// feedback, build a dense tail whose highs die first, as they do on soft
/// walls, and four all-passes in series diffuse it. [roomSize] sets how long
/// the tail rings and [damping] how fast it darkens. The tail is fed only what
/// lies above [lowCutHz], so bass does not boom into mud, and is added on top
/// of the dry sound at [mix].
///
/// With more than one channel, the channels are mixed into one feed for two
/// networks, and every other channel takes its tail from the second, whose
/// delays are a little longer. The two sides decorrelate and the tail sounds
/// wide, as a real hall does, while the dry sound keeps its own stereo image.
/// The output keeps the input's length: a tail still ringing when the sound
/// ends is cut with it.
class Reverb extends AudioEffect {
  /// Creates a reverb.
  const Reverb({
    this.roomSize = 0.75,
    this.damping = 0.5,
    this.mix = 0.4,
    this.lowCutHz = 150,
  }) : assert(roomSize >= 0 && roomSize <= 1, 'roomSize must be in [0, 1]'),
       assert(damping >= 0 && damping <= 1, 'damping must be in [0, 1]'),
       assert(mix >= 0, 'mix must not be negative');

  /// How long the tail rings: `0` a small room, `1` a large hall.
  final double roomSize;

  /// How fast the highs of the tail die out: `0` bright stone, `1` a
  /// curtained room.
  final double damping;

  /// Level of the tail relative to the dry sound.
  final double mix;

  /// Corner frequency of the high-pass the tail is fed through.
  final double lowCutHz;

  /// Freeverb's comb delays, in samples at its reference rate.
  static const List<int> _combTuning = [
    1116,
    1188,
    1277,
    1356,
    1422,
    1491,
    1557,
    1617,
  ];

  /// Freeverb's all-pass delays, in samples at its reference rate.
  static const List<int> _allPassTuning = [556, 441, 341, 225];

  /// The rate the tunings were made for.
  static const int _referenceRate = 44100;

  /// How much longer, in samples at the reference rate, every delay of the
  /// second side's network is.
  static const int _stereoSpread = 23;

  /// Input gain into the combs, which sum eight copies at high feedback.
  static const double _inputGain = 0.03;

  /// Output gain of the tail, so [mix] `1` sits near the dry level.
  static const double _wetGain = 1.5;

  @override
  Float32List apply(Float32List samples, int sampleRate) =>
      applyToChannels([samples], sampleRate).single;

  @override
  List<Float32List> applyToChannels(
    List<Float32List> channels,
    int sampleRate,
  ) {
    final feed = _feed(channels, sampleRate);
    final outputs = [
      for (final channel in channels) Float32List.fromList(channel),
    ];
    final sides = channels.length > 1 ? 2 : 1;
    for (var side = 0; side < sides; side++) {
      _addTail(
        feed,
        [for (var c = side; c < outputs.length; c += sides) outputs[c]],
        sampleRate,
        spread: side * _stereoSpread,
      );
    }
    return outputs;
  }

  /// The mono signal the networks are fed: the channels' average, with the
  /// lows taken out.
  Float32List _feed(List<Float32List> channels, int sampleRate) {
    final feed = Float32List(channels.first.length);
    final highPass = Biquad.highPass(lowCutHz, sampleRate);
    for (var i = 0; i < feed.length; i++) {
      var sum = 0.0;
      for (final channel in channels) {
        sum += channel[i];
      }
      feed[i] = highPass.next(sum / channels.length) * _inputGain;
    }
    return feed;
  }

  /// Adds the tail of one side's network for [feed], its delays [spread]
  /// samples longer at the reference rate, to every channel of [targets].
  void _addTail(
    Float32List feed,
    List<Float32List> targets,
    int sampleRate, {
    required int spread,
  }) {
    final scale = sampleRate / _referenceRate;
    int delay(int tuning) => math.max(1, ((tuning + spread) * scale).round());
    final feedback = 0.7 + 0.28 * roomSize;
    final damp = 0.4 * damping;
    final combs = [
      for (final tuning in _combTuning)
        _Comb(delay(tuning), feedback: feedback, damp: damp),
    ];
    final allPasses = [
      for (final tuning in _allPassTuning) _AllPass(delay(tuning)),
    ];
    final gain = mix * _wetGain;
    for (var i = 0; i < feed.length; i++) {
      final input = feed[i];
      var out = 0.0;
      for (final comb in combs) {
        out += comb.next(input);
      }
      for (final allPass in allPasses) {
        out = allPass.next(out);
      }
      for (final target in targets) {
        target[i] += gain * out;
      }
    }
  }
}

/// A feedback comb with a one-pole low-pass in its loop.
class _Comb {
  _Comb(int length, {required this.feedback, required this.damp})
    : _buffer = Float64List(length);

  final double feedback;
  final double damp;
  final Float64List _buffer;
  var _cursor = 0;
  var _store = 0.0;

  double next(double input) {
    final output = _buffer[_cursor];
    _store = output * (1 - damp) + _store * damp;
    _buffer[_cursor] = input + _store * feedback;
    if (++_cursor == _buffer.length) _cursor = 0;
    return output;
  }
}

/// Freeverb's all-pass, which spreads a pulse in time without colouring it.
class _AllPass {
  _AllPass(int length) : _buffer = Float64List(length);

  static const double _feedback = 0.5;

  final Float64List _buffer;
  var _cursor = 0;

  double next(double input) {
    final delayed = _buffer[_cursor];
    _buffer[_cursor] = input + delayed * _feedback;
    if (++_cursor == _buffer.length) _cursor = 0;
    return delayed - input;
  }
}
