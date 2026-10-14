// ABOUTME: Measures how loud a sound is in each of its frequency bands over
// ABOUTME: time, and turns that into the levels an audio visualizer draws.

import 'dart:math' as math;
import 'dart:typed_data';

/// Rows of band energies a second: one per frame of a 60 fps display.
const int audioBandFrameRate = 60;

/// How many frequency bands [bandEnergies] measures. A visualizer with fewer
/// bands merges neighbouring ones, see [audioVisualizerLevels].
const int audioBandCount = 48;

/// The lowest frequency the bands start at, in hertz: below it a phone
/// speaker plays almost nothing.
const double _lowestFrequency = 40;

/// The highest frequency the bands reach, in hertz. The bands are the same
/// whatever a file's sample rate, so the energies of files of different rates
/// add up band by band; bands above what a file holds stay silent.
const double _highestFrequency = 16000;

/// How long the stretch of sound is that each row looks at: about 45 ms, long
/// enough to tell low notes apart and short enough to follow a drum.
const double _windowSeconds = 0.045;

/// How far below the loudest moment of the video, in decibels, a band counts
/// as silent in [audioVisualizerLevels], for the calmest and the liveliest
/// reaction: a narrower range lets the bars swing further between quiet and
/// loud.
const double _calmLevelRange = 54;
const double _livelyLevelRange = 30;

/// How much louder the bands get per octave in [audioVisualizerLevels], in
/// decibels: music carries far less energy in its highs than in its bass, and
/// without the lift the right half of a visualizer would hardly move.
const double _tiltPerOctave = 2;

/// How far a level may fall in a second in [audioVisualizerLevels], for the
/// calmest and the liveliest reaction. In the middle a bar drops from the top
/// to nothing in a third of a second instead of flickering with every dip of
/// the sound.
const double _calmFallPerSecond = 1.5;
const double _livelyFallPerSecond = 6;

/// How far a level may rise in a second in [audioVisualizerLevels] at the
/// calmest reaction, and halfway to the middle. From the middle on a bar
/// rises at once.
const double _calmRisePerSecond = 8;
const double _halfCalmRisePerSecond = 64;

/// The energy of each of [audioBandCount] frequency bands in [samples], mono
/// audio from -1 to 1 at [sampleRate] samples a second, [audioBandFrameRate]
/// rows a second: row `row` measures the sound around `row /
/// audioBandFrameRate` seconds. The energy of `band` in `row` is at `row *
/// audioBandCount + band`.
///
/// The bands are spaced evenly in pitch, each a fraction of an octave wide,
/// from [_lowestFrequency] up. An energy is the summed power of the band, not
/// a level, so the energies of several sounds playing at once add up.
Float32List bandEnergies(Float32List samples, {required int sampleRate}) {
  if (sampleRate <= 0 || samples.isEmpty) return Float32List(0);
  final size = _windowSize(sampleRate);
  final window = Float64List(size);
  for (var i = 0; i < size; i++) {
    window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
  }
  final bins = _bandBins(size, sampleRate);
  final rows = (samples.length * audioBandFrameRate / sampleRate).ceil().clamp(
    1,
    1 << 30,
  );
  final energies = Float32List(rows * audioBandCount);
  final real = Float64List(size);
  final imaginary = Float64List(size);
  final power = Float64List(size ~/ 2 + 1);

  for (var row = 0; row < rows; row++) {
    final center = (row * sampleRate / audioBandFrameRate).round();
    final start = center - size ~/ 2;
    for (var i = 0; i < size; i++) {
      final at = start + i;
      real[i] = at >= 0 && at < samples.length ? samples[at] * window[i] : 0;
      imaginary[i] = 0;
    }
    _fft(real, imaginary);
    for (var bin = 0; bin < power.length; bin++) {
      power[bin] = real[bin] * real[bin] + imaginary[bin] * imaginary[bin];
    }
    for (var band = 0; band < audioBandCount; band++) {
      var sum = 0.0;
      for (final (bin, share) in bins[band]) {
        sum += power[bin] * share;
      }
      energies[row * audioBandCount + band] = sum;
    }
  }
  return energies;
}

/// The levels an audio visualizer of [bandCount] bands draws for [energies],
/// band energies from [bandEnergies] (or several of them added up), row
/// after row: from 0 (silent) to 1 (the loudest moment), in the same rows.
///
/// Neighbouring bands are merged into [bandCount] bands. A level follows the
/// loudness in decibels, measured against the loudest band of the loudest
/// row, so a quiet video moves as much as a loud one.
///
/// [reaction] runs from 0 (calm) to 1 (lively): the livelier, the further a
/// bar swings between quiet and loud and the faster it falls; below the
/// middle it also rises gently. At 0.5 it covers 42 dB, falls three levels a
/// second and rises at once.
Float32List audioVisualizerLevels(
  Float32List energies, {
  required int bandCount,
  double reaction = 0.5,
}) {
  final lively = reaction.clamp(0.0, 1.0);
  final levelRange =
      _calmLevelRange + (_livelyLevelRange - _calmLevelRange) * lively;
  final fall =
      _calmFallPerSecond *
      math.pow(_livelyFallPerSecond / _calmFallPerSecond, lively) /
      audioBandFrameRate;
  final rise = lively >= 0.5
      ? double.infinity
      : _calmRisePerSecond *
            math.pow(_halfCalmRisePerSecond / _calmRisePerSecond, lively * 2) /
            audioBandFrameRate;
  final rows = energies.length ~/ audioBandCount;
  final levels = Float32List(rows * bandCount);
  if (rows == 0 || bandCount <= 0) return levels;

  final decibels = Float64List(rows * bandCount);
  var loudest = double.negativeInfinity;
  for (var row = 0; row < rows; row++) {
    for (var band = 0; band < bandCount; band++) {
      final from = band * audioBandCount ~/ bandCount;
      final to = math.max(from + 1, (band + 1) * audioBandCount ~/ bandCount);
      var sum = 0.0;
      for (var fine = from; fine < to; fine++) {
        sum += energies[row * audioBandCount + fine];
      }
      // The octave of the band's middle above the lowest band.
      final octave = (from + to) / 2 / audioBandCount * _octaves;
      final value = sum > 0
          ? 10 * math.log(sum) / math.ln10 + _tiltPerOctave * octave
          : double.negativeInfinity;
      decibels[row * bandCount + band] = value;
      if (value > loudest) loudest = value;
    }
  }
  if (loudest == double.negativeInfinity) return levels;

  for (var band = 0; band < bandCount; band++) {
    var previous = 0.0;
    for (var row = 0; row < rows; row++) {
      final value = decibels[row * bandCount + band];
      final level = ((value - loudest + levelRange) / levelRange).clamp(
        0.0,
        1.0,
      );
      previous = level.clamp(previous - fall, previous + rise);
      levels[row * bandCount + band] = previous;
    }
  }
  return levels;
}

/// How many octaves the bands span.
final double _octaves =
    math.log(_highestFrequency / _lowestFrequency) / math.ln2;

/// The window length for [sampleRate]: the power of two nearest to
/// [_windowSeconds], as the FFT needs.
int _windowSize(int sampleRate) {
  final ideal = sampleRate * _windowSeconds;
  var size = 64;
  while (size * 2 <= ideal * 1.5) {
    size *= 2;
  }
  return size;
}

/// For every band, the FFT bins it covers and how much of each: a bin
/// stands for the frequencies within half a bin of its own, and counts by the
/// share of that range inside the band. A band narrower than a bin, as the
/// lowest ones are, so takes a matching part of the bin around it instead of
/// all of it or none.
List<List<(int, double)>> _bandBins(int size, int sampleRate) {
  final binWidth = sampleRate / size;
  final ratio = math.pow(
    _highestFrequency / _lowestFrequency,
    1 / audioBandCount,
  );
  final lastBin = size ~/ 2;
  return [
    for (var band = 0; band < audioBandCount; band++)
      _binsBetween(
        _lowestFrequency * math.pow(ratio, band),
        _lowestFrequency * math.pow(ratio, band + 1),
        binWidth,
        lastBin,
      ),
  ];
}

/// The bins of [binWidth] hertz that cover [low] to [high] hertz, each with
/// the share of it inside that range; see [_bandBins].
List<(int, double)> _binsBetween(
  double low,
  double high,
  double binWidth,
  int lastBin,
) {
  final first = (low / binWidth + 0.5).floor().clamp(0, lastBin);
  final last = (high / binWidth + 0.5).floor().clamp(0, lastBin);
  return [
    for (var bin = first; bin <= last; bin++)
      if (math.min(high, (bin + 0.5) * binWidth) -
              math.max(low, (bin - 0.5) * binWidth) >
          0)
        (
          bin,
          (math.min(high, (bin + 0.5) * binWidth) -
                  math.max(low, (bin - 0.5) * binWidth)) /
              binWidth,
        ),
  ];
}

/// An in-place radix-2 FFT of the complex signal [real] + i [imaginary],
/// whose length is a power of two.
void _fft(Float64List real, Float64List imaginary) {
  final n = real.length;
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final r = real[i];
      real[i] = real[j];
      real[j] = r;
      final m = imaginary[i];
      imaginary[i] = imaginary[j];
      imaginary[j] = m;
    }
  }
  for (var length = 2; length <= n; length <<= 1) {
    final angle = -2 * math.pi / length;
    final stepReal = math.cos(angle);
    final stepImaginary = math.sin(angle);
    for (var start = 0; start < n; start += length) {
      var twiddleReal = 1.0;
      var twiddleImaginary = 0.0;
      for (var k = 0; k < length ~/ 2; k++) {
        final a = start + k;
        final b = a + length ~/ 2;
        final br = real[b] * twiddleReal - imaginary[b] * twiddleImaginary;
        final bi = real[b] * twiddleImaginary + imaginary[b] * twiddleReal;
        real[b] = real[a] - br;
        imaginary[b] = imaginary[a] - bi;
        real[a] += br;
        imaginary[a] += bi;
        final nextReal =
            twiddleReal * stepReal - twiddleImaginary * stepImaginary;
        twiddleImaginary =
            twiddleReal * stepImaginary + twiddleImaginary * stepReal;
        twiddleReal = nextReal;
      }
    }
  }
}
