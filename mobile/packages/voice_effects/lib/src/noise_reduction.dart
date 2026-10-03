// ABOUTME: Noise reduction for a recorded voice: learns the steady hiss of a
// ABOUTME: take from its quietest moments and filters it out band by band.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_effects/src/audio_effect.dart';
import 'package:voice_effects/src/fft.dart';

/// Removes steady background noise — hiss, a fan, room tone — from a take.
///
/// The noise is learned from the take itself, so no separate noise sample is
/// needed: for every frequency band, the level the take sits at in its
/// quietest tenth of moments sets that band's noise estimate. Each short-time
/// frame then passes through a Wiener filter whose signal-to-noise estimate is
/// smoothed from frame to frame (the decision-directed rule of Ephraim and
/// Malah). A band well above the noise — a vowel's harmonics — passes
/// untouched, a band at the noise is turned down by up to [reductionDb], and
/// the smoothing keeps the leftover noise a soft bed instead of the chirping
/// "musical noise" a plain gate leaves behind.
class NoiseReduction extends AudioEffect {
  /// Creates a noise reduction.
  const NoiseReduction({this.reductionDb = 20});

  /// The most a band is turned down, in decibels.
  final double reductionDb;

  /// Analysis frame length, in seconds, before rounding to a power of two.
  static const double _frameSeconds = 0.025;

  /// Share of a take's frames assumed to hold nothing but noise.
  static const double _noisePercentile = 0.1;

  /// How much higher the noise is assumed to be than estimated, so the
  /// fluctuations of the noise around its mean are filtered too.
  static const double _overSubtraction = 1.5;

  /// Weight of the previous frame in each band's signal-to-noise estimate.
  static const double _smoothing = 0.98;

  /// Bands below this frequency are always turned all the way down. No voice
  /// sits there, but rumble, wind and handling noise do — and they drift too
  /// slowly over a take for the quiet-moments estimate to catch.
  static const double _lowCutHz = 70;

  /// Range and resolution of the level histogram the noise estimate is read
  /// from. Bounded memory, however long the take.
  static const double _histogramMinDb = -160;
  static const double _histogramMaxDb = 20;
  static const double _histogramStepDb = 0.5;

  /// Frame power below which a frame is digital silence, not noise.
  static const double _silencePower = 1e-12;

  @override
  Float32List apply(Float32List samples, int sampleRate) {
    final run = _Run(
      samples,
      size: powerOfTwoAtMost(sampleRate * _frameSeconds),
    );
    final noisePower = run.noisePower();
    if (noisePower == null) return Float32List.fromList(samples);
    return run.filter(
      noisePower: noisePower,
      floorGain: math.pow(10, -reductionDb / 20).toDouble(),
      lowCutBins: (_lowCutHz * run.size / sampleRate).ceil(),
    );
  }
}

/// Buffers for one pass of [NoiseReduction] over one take.
class _Run {
  _Run(this.samples, {required this.size})
    : hop = size ~/ 4,
      bins = size ~/ 2 + 1,
      window = hannWindow(size),
      fft = Fft(size),
      re = Float64List(size),
      im = Float64List(size),
      padded = Float64List(samples.length + 2 * size) {
    for (var i = 0; i < samples.length; i++) {
      padded[size + i] = samples[i];
    }
  }

  final Float32List samples;
  final int size;
  final int hop;
  final int bins;
  final Float64List window;
  final Fft fft;
  final Float64List re;
  final Float64List im;

  /// The take with a frame of silence on each side, so its first and last
  /// samples sit under whole frames.
  final Float64List padded;

  int get frameCount => (padded.length - size) ~/ hop + 1;

  /// Loads the windowed frame starting at [start] and transforms it.
  void _analyse(int start) {
    for (var i = 0; i < size; i++) {
      re[i] = padded[start + i] * window[i];
      im[i] = 0;
    }
    fft.forward(re, im);
  }

  double _power(int bin) => re[bin] * re[bin] + im[bin] * im[bin];

  /// Each band's mean noise power, or `null` when the take is digital silence
  /// throughout.
  ///
  /// Prefers frames that lie wholly inside the take, so the silent padding
  /// cannot drag the estimate down; a take shorter than one frame falls back
  /// to every frame.
  Float64List? noisePower() {
    const minDb = NoiseReduction._histogramMinDb;
    const stepDb = NoiseReduction._histogramStepDb;
    final buckets = ((NoiseReduction._histogramMaxDb - minDb) / stepDb).ceil();
    final counts = Int32List(bins * buckets);
    var counted = 0;

    void count(int frame) {
      _analyse(frame * hop);
      var energy = 0.0;
      for (var k = 0; k < bins; k++) {
        energy += _power(k);
      }
      if (energy < NoiseReduction._silencePower) return;
      for (var k = 0; k < bins; k++) {
        final db = 10 * math.log(_power(k) + 1e-30) / math.ln10;
        final bucket = ((db - minDb) / stepDb).floor().clamp(0, buckets - 1);
        counts[k * buckets + bucket]++;
      }
      counted++;
    }

    for (var frame = 0; frame < frameCount; frame++) {
      final start = frame * hop;
      if (start >= size && start + size <= size + samples.length) {
        count(frame);
      }
    }
    if (counted == 0) {
      for (var frame = 0; frame < frameCount; frame++) {
        count(frame);
      }
    }
    if (counted == 0) return null;

    // Noise power in a band is exponentially distributed, so its p-th
    // percentile sits at -ln(1 - p) times its mean.
    const percentile = NoiseReduction._noisePercentile;
    final toMean = NoiseReduction._overSubtraction / -math.log(1 - percentile);
    final rank = math.max(1, (counted * percentile).ceil());
    final noise = Float64List(bins);
    for (var k = 0; k < bins; k++) {
      var cumulative = 0;
      var bucket = 0;
      while (true) {
        cumulative += counts[k * buckets + bucket];
        if (cumulative >= rank) break;
        bucket++;
      }
      final db = minDb + (bucket + 0.5) * stepDb;
      noise[k] = math.pow(10, db / 10) * toMean;
    }
    return noise;
  }

  /// Resynthesises the take with every band of every frame Wiener-filtered
  /// against [noisePower], never turning a band down below [floorGain], and
  /// the lowest [lowCutBins] bands always all the way down.
  Float32List filter({
    required Float64List noisePower,
    required double floorGain,
    required int lowCutBins,
  }) {
    const smoothing = NoiseReduction._smoothing;
    // The filtered power of each band in the previous frame, which carries
    // the signal-to-noise estimate from one frame to the next.
    final previousClean = Float64List(bins);
    final out = Float64List(padded.length);

    for (var frame = 0; frame < frameCount; frame++) {
      _analyse(frame * hop);
      for (var k = 0; k < bins; k++) {
        final power = _power(k);
        final posterior = power / noisePower[k];
        final prior =
            smoothing * previousClean[k] / noisePower[k] +
            (1 - smoothing) * math.max(posterior - 1, 0);
        final gain = k < lowCutBins
            ? floorGain
            : math.max(prior / (1 + prior), floorGain);
        previousClean[k] = gain * gain * power;
        re[k] *= gain;
        im[k] *= gain;
        if (k > 0 && k < size - k) {
          re[size - k] *= gain;
          im[size - k] *= gain;
        }
      }
      fft.inverse(re, im);
      final start = frame * hop;
      for (var i = 0; i < size; i++) {
        out[start + i] += re[i] * window[i];
      }
    }

    // Hann analysis and synthesis at a quarter-frame hop overlap-add to a
    // constant: the window's energy per hop.
    var windowEnergy = 0.0;
    for (final value in window) {
      windowEnergy += value * value;
    }
    final normalisation = windowEnergy / hop;
    final output = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      output[i] = out[size + i] / normalisation;
    }
    return output;
  }
}
