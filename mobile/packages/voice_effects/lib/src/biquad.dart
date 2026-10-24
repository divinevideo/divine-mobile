// ABOUTME: Second-order IIR filter sections from the RBJ audio EQ cookbook,
// ABOUTME: run one sample at a time: low-pass, high-pass and peaking.

import 'dart:math' as math;

/// The Q of a Butterworth section, whose pass band is as flat as it gets.
const double butterworthQ = math.sqrt1_2;

/// One second-order filter section that carries its state from sample to
/// sample, so a signal runs through it with [next] in order.
class Biquad {
  /// A low-pass that turns down everything above [cutoffHz].
  factory Biquad.lowPass(
    double cutoffHz,
    int sampleRate, {
    double q = butterworthQ,
  }) {
    final (:cosine, :alpha) = _angle(cutoffHz, sampleRate, q);
    return Biquad._(
      b0: (1 - cosine) / 2,
      b1: 1 - cosine,
      b2: (1 - cosine) / 2,
      a0: 1 + alpha,
      a1: -2 * cosine,
      a2: 1 - alpha,
    );
  }

  /// A high-pass that turns down everything below [cutoffHz].
  factory Biquad.highPass(
    double cutoffHz,
    int sampleRate, {
    double q = butterworthQ,
  }) {
    final (:cosine, :alpha) = _angle(cutoffHz, sampleRate, q);
    return Biquad._(
      b0: (1 + cosine) / 2,
      b1: -(1 + cosine),
      b2: (1 + cosine) / 2,
      a0: 1 + alpha,
      a1: -2 * cosine,
      a2: 1 - alpha,
    );
  }

  /// A bell that raises the band around [centerHz] by [gainDb], narrower the
  /// higher [q].
  factory Biquad.peaking(
    double centerHz,
    int sampleRate, {
    required double gainDb,
    double q = 1,
  }) {
    final (:cosine, :alpha) = _angle(centerHz, sampleRate, q);
    final amplitude = math.pow(10, gainDb / 40).toDouble();
    return Biquad._(
      b0: 1 + alpha * amplitude,
      b1: -2 * cosine,
      b2: 1 - alpha * amplitude,
      a0: 1 + alpha / amplitude,
      a1: -2 * cosine,
      a2: 1 - alpha / amplitude,
    );
  }

  Biquad._({
    required double b0,
    required double b1,
    required double b2,
    required double a0,
    required double a1,
    required double a2,
  }) : _b0 = b0 / a0,
       _b1 = b1 / a0,
       _b2 = b2 / a0,
       _a1 = a1 / a0,
       _a2 = a2 / a0;

  final double _b0;
  final double _b1;
  final double _b2;
  final double _a1;
  final double _a2;

  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  /// Filters the next sample of the signal, [x].
  double next(double x) {
    final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }

  /// The corner or centre [hz], kept below Nyquist so a filter tuned for a
  /// higher sample rate still works, as an angle's cosine and the bandwidth
  /// term the cookbook calls alpha.
  static ({double cosine, double alpha}) _angle(
    double hz,
    int sampleRate,
    double q,
  ) {
    final omega = 2 * math.pi * math.min(hz, sampleRate * 0.45) / sampleRate;
    return (cosine: math.cos(omega), alpha: math.sin(omega) / (2 * q));
  }
}
