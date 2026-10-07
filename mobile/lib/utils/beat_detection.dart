// ABOUTME: Finds the beats of a sound from its samples, where something in it
// ABOUTME: hits, so video effects can fire on them.

import 'dart:math' as math;
import 'dart:typed_data';

/// Loudness values a second: one every 5 ms.
const int _frameRate = 200;

/// Frames in the stretches before and after a moment whose loudness
/// [_rises] compares: 50 ms, longer than a crackle and shorter than the gap
/// between two fast drum hits.
const int _riseFrames = _frameRate * 50 ~/ 1000;

/// How far below the loudest moment of a sound, in decibels, its rises stop
/// counting: quieter stretches rise from this floor instead.
const double _quietestLevel = 40;

/// The smallest rise that fires, in decibels of the weighted bands. The
/// drums of a song mastered loud rise by 3 to 5, a spoken word by 13 or more.
const double _weakestHit = 3;

/// How strong a hit has to be, against the strongest one around it (see
/// [_neighbourhood]): a hit right after a much louder one fades into it to
/// the ear, while a run of even hits all count.
const double _relativeHit = 0.5;

/// How far around a hit [_relativeHit] compares it.
const Duration _neighbourhood = Duration(milliseconds: 750);

/// Frames within which a hit is the strongest rise: 40 ms.
const int _hitReach = _frameRate * 40 ~/ 1000;

/// The shortest gap between two hits; of two closer ones, the stronger
/// stays. A bang often strikes twice.
const Duration _shortestGap = Duration(milliseconds: 150);

/// The beats in [samples], mono audio from -1 to 1 at [sampleRate] samples a
/// second, as times from its start: where the music hits.
///
/// Empty when nothing in the sound hits, such as silence or a flat tone.
///
/// A hit is where the sound gets clearly louder in its bass, mids or highs,
/// and stays louder for a moment: a drum, a word or a bang rises far more
/// than a crackle over in a few milliseconds. Measuring the bands apart finds
/// a kick even in a song mastered so loud that its overall level hardly
/// moves. Of the hits, those much weaker than one right around them fade
/// into it to the ear and fire nothing.
List<Duration> detectBeats(Float32List samples, {required int sampleRate}) {
  if (sampleRate < _frameRate * 4) return const [];
  final rises = _rises(samples, sampleRate);
  if (rises == null) return const [];
  return [
    for (final hit in _hits(rises))
      Duration(
        microseconds: hit * Duration.microsecondsPerSecond ~/ _frameRate,
      ),
  ];
}

/// The frames of the hits in [rises]: the strongest rise within
/// [_hitReach], [_weakestHit] or more, at least [_relativeHit] of the
/// strongest within [_neighbourhood], and [_shortestGap] from any stronger
/// hit.
List<int> _hits(List<double> rises) {
  final around = _neighbourhood.inMilliseconds * _frameRate ~/ 1000;
  final candidates = <int>[];
  for (var i = 0; i < rises.length; i++) {
    if (rises[i] < _weakestHit || !_isPeak(rises, i, _hitReach)) continue;
    var strongest = 0.0;
    final to = math.min(rises.length - 1, i + around);
    for (var j = math.max(0, i - around); j <= to; j++) {
      strongest = math.max(strongest, rises[j]);
    }
    if (rises[i] >= _relativeHit * strongest) candidates.add(i);
  }

  final gap = _shortestGap.inMilliseconds * _frameRate ~/ 1000;
  final hits = <int>[];
  for (final candidate
      in candidates..sort((a, b) => rises[b].compareTo(rises[a]))) {
    if (hits.every((hit) => (hit - candidate).abs() >= gap)) {
      hits.add(candidate);
    }
  }
  return hits..sort();
}

/// Whether [values] peaks at [index] within [reach] frames; the first of
/// equal ones wins, so a flat top counts once.
bool _isPeak(List<double> values, int index, int reach) {
  final to = math.min(values.length - 1, index + reach);
  for (var j = math.max(0, index - reach); j <= to; j++) {
    if (values[j] > values[index] ||
        (values[j] == values[index] && j < index)) {
      return false;
    }
  }
  return true;
}

/// How much louder, in decibels, the sound gets at each of [_frameRate]
/// frames a second: the bands' rises from the [_riseFrames] before a frame
/// to the [_riseFrames] from it on, weighted; `null` for a silent sound.
List<double>? _rises(Float32List samples, int sampleRate) {
  final hop = sampleRate ~/ _frameRate;
  final frames = samples.length ~/ hop;
  if (frames == 0) return null;
  // The kick drum hits hardest, so the bass weighs most.
  final bands = [
    (filters: [_Biquad.lowPass(150, sampleRate)], weight: 1.0),
    (
      filters: [
        _Biquad.highPass(150, sampleRate),
        _Biquad.lowPass(2000, sampleRate),
      ],
      weight: 0.5,
    ),
    (filters: [_Biquad.highPass(2000, sampleRate)], weight: 0.3),
  ];

  // Each band's energy summed up to each frame, for the mean of any stretch.
  final energies = <List<double>>[];
  var loudest = 0.0;
  for (final band in bands) {
    final summed = List<double>.filled(frames + 1, 0);
    for (var frame = 0; frame < frames; frame++) {
      var sum = 0.0;
      for (var i = frame * hop; i < (frame + 1) * hop; i++) {
        var value = samples[i];
        for (final filter in band.filters) {
          value = filter.process(value);
        }
        sum += value * value;
      }
      summed[frame + 1] = summed[frame] + sum / hop;
    }
    energies.add(summed);
    for (var frame = 0; frame <= frames; frame++) {
      final from = math.max(0, frame - _riseFrames);
      final mean = (summed[frame] - summed[from]) / _riseFrames;
      if (mean > loudest) loudest = mean;
    }
  }
  // Quieter than about -50 dBFS throughout.
  if (loudest < 1e-5) return null;

  // Every band rises from the same floor, below the loudest moment of the
  // loudest band: a quiet band, or a quiet stretch, rises little however
  // suddenly it moves.
  final floor = loudest * math.pow(10, -_quietestLevel / 10);
  final rises = List<double>.filled(frames, 0);
  for (var b = 0; b < bands.length; b++) {
    final summed = energies[b];
    double level(int from, int to) {
      final start = math.max(0, from);
      final end = math.min(frames, to);
      final mean = (summed[end] - summed[start]) / (end - start);
      return 10 * math.log(floor + mean) / math.ln10;
    }

    for (var frame = 1; frame < frames; frame++) {
      final before = level(frame - _riseFrames, frame);
      final after = level(frame, frame + _riseFrames);
      rises[frame] += bands[b].weight * math.max(0, after - before);
    }
  }
  return rises;
}

class _Biquad {
  _Biquad._(this._b0, this._b1, this._b2, this._a1, this._a2);

  factory _Biquad.lowPass(double frequency, int sampleRate) {
    final (cos, alpha) = _shape(frequency, sampleRate);
    final a0 = 1 + alpha;
    return _Biquad._(
      (1 - cos) / 2 / a0,
      (1 - cos) / a0,
      (1 - cos) / 2 / a0,
      -2 * cos / a0,
      (1 - alpha) / a0,
    );
  }

  factory _Biquad.highPass(double frequency, int sampleRate) {
    final (cos, alpha) = _shape(frequency, sampleRate);
    final a0 = 1 + alpha;
    return _Biquad._(
      (1 + cos) / 2 / a0,
      -(1 + cos) / a0,
      (1 + cos) / 2 / a0,
      -2 * cos / a0,
      (1 - alpha) / a0,
    );
  }

  static (double, double) _shape(double frequency, int sampleRate) {
    final w0 = 2 * math.pi * frequency / sampleRate;
    return (math.cos(w0), math.sin(w0) / (2 * math.sqrt1_2));
  }

  final double _b0;
  final double _b1;
  final double _b2;
  final double _a1;
  final double _a2;
  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  double process(double x) {
    final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}
