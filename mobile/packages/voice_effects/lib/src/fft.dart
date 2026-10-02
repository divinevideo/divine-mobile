// ABOUTME: In-place radix-2 complex FFT plus the periodic Hann window the
// ABOUTME: short-time effects analyse and resynthesise their frames with.

import 'dart:math' as math;
import 'dart:typed_data';

/// In-place radix-2 FFT of a fixed power-of-two [size].
///
/// Twiddle factors and the bit-reversal table are built once, so one instance
/// is reused for every frame of a signal.
class Fft {
  /// Creates an FFT for frames of [size] samples.
  ///
  /// Throws an [ArgumentError] when [size] is not a power of two of at least 2.
  Fft(this.size)
    : _cos = Float64List(size ~/ 2),
      _sin = Float64List(size ~/ 2),
      _reversed = Int32List(size) {
    if (size < 2 || size & (size - 1) != 0) {
      throw ArgumentError.value(size, 'size', 'must be a power of two >= 2');
    }
    for (var k = 0; k < size ~/ 2; k++) {
      final angle = 2 * math.pi * k / size;
      _cos[k] = math.cos(angle);
      _sin[k] = math.sin(angle);
    }
    final bits = size.bitLength - 1;
    for (var i = 0; i < size; i++) {
      var reversed = 0;
      for (var b = 0; b < bits; b++) {
        reversed |= ((i >> b) & 1) << (bits - 1 - b);
      }
      _reversed[i] = reversed;
    }
  }

  /// Number of samples per frame.
  final int size;

  final Float64List _cos;
  final Float64List _sin;
  final Int32List _reversed;

  /// Replaces [re] and [im] with their forward transform.
  void forward(Float64List re, Float64List im) => _transform(re, im, -1);

  /// Replaces [re] and [im] with their inverse transform, scaled by `1/size`
  /// so `inverse(forward(x)) == x`.
  void inverse(Float64List re, Float64List im) {
    _transform(re, im, 1);
    final scale = 1 / size;
    for (var i = 0; i < size; i++) {
      re[i] *= scale;
      im[i] *= scale;
    }
  }

  void _transform(Float64List re, Float64List im, int sign) {
    for (var i = 0; i < size; i++) {
      final j = _reversed[i];
      if (j > i) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var length = 2; length <= size; length <<= 1) {
      final half = length >> 1;
      final step = size ~/ length;
      for (var start = 0; start < size; start += length) {
        for (var k = 0; k < half; k++) {
          final wr = _cos[k * step];
          final wi = sign * _sin[k * step];
          final a = start + k;
          final b = a + half;
          final tr = wr * re[b] - wi * im[b];
          final ti = wr * im[b] + wi * re[b];
          re[b] = re[a] - tr;
          im[b] = im[a] - ti;
          re[a] += tr;
          im[a] += ti;
        }
      }
    }
  }
}

/// Periodic Hann window of [length] samples.
///
/// Periodic rather than symmetric, so frames hopped by a quarter or a half of
/// [length] overlap-add to a constant.
Float64List hannWindow(int length) {
  final window = Float64List(length);
  for (var i = 0; i < length; i++) {
    window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / length);
  }
  return window;
}

/// Largest power of two that is at most [value], and at least 2.
int powerOfTwoAtMost(num value) {
  var size = 2;
  while (size * 2 <= value) {
    size *= 2;
  }
  return size;
}
