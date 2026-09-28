// ABOUTME: Estimates the camera move between a video's last and first frame,
// ABOUTME: so the loop restart can be eased into place instead of jumping.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A grayscale frame, normalised to zero mean and unit variance.
///
/// Normalising both frames first makes the comparison blind to a global
/// exposure change between the end and the start of a recording, which
/// otherwise reads as a mismatch everywhere and hides the geometry.
class GrayFrame {
  /// Wraps [luma] (row-major, [width] × [height]) as-is.
  GrayFrame(this.width, this.height, this.luma)
    : assert(luma.length == width * height, 'luma must be width * height');

  /// Builds a normalised frame from 8-bit RGBA bytes.
  factory GrayFrame.fromRgba(int width, int height, Uint8List rgba) {
    final count = width * height;
    final luma = Float32List(count);
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      final o = i * 4;
      final y = 0.299 * rgba[o] + 0.587 * rgba[o + 1] + 0.114 * rgba[o + 2];
      luma[i] = y;
      sum += y;
    }
    final mean = sum / count;
    var variance = 0.0;
    for (var i = 0; i < count; i++) {
      final d = luma[i] - mean;
      variance += d * d;
    }
    // A flat frame (a black fade, a lens cap) has no geometry to match; keep it
    // at zero rather than dividing by ~0 and amplifying compression noise.
    final std = math.sqrt(variance / count);
    final inv = std < 1 ? 0.0 : 1 / std;
    for (var i = 0; i < count; i++) {
      luma[i] = (luma[i] - mean) * inv;
    }
    return GrayFrame(width, height, luma);
  }

  final int width;
  final int height;
  final Float32List luma;

  /// This frame at half resolution, by 2×2 box averaging.
  GrayFrame downsampled() {
    final w = width ~/ 2;
    final h = height ~/ 2;
    final out = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      final r0 = 2 * y * width;
      final r1 = r0 + width;
      for (var x = 0; x < w; x++) {
        final c = 2 * x;
        out[y * w + x] =
            (luma[r0 + c] +
                luma[r0 + c + 1] +
                luma[r1 + c] +
                luma[r1 + c + 1]) *
            0.25;
      }
    }
    return GrayFrame(w, h, out);
  }

  double _sample(double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final fx = x - x0;
    final fy = y - y0;
    final i = y0 * width + x0;
    final a = luma[i];
    final b = luma[i + 1];
    final c = luma[i + width];
    final d = luma[i + width + 1];
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }
}

/// How the last frame has to be displayed to look like the first one.
///
/// The model is a uniform [scale] about the frame centre followed by a shift of
/// ([dx], [dy]), both shifts expressed as a fraction of the frame's width and
/// height so the value is independent of the resolution it was measured at.
/// Showing the last frame through this transform lines it up with the first.
@immutable
class LoopSeamAlignment {
  const LoopSeamAlignment({
    required this.scale,
    required this.dx,
    required this.dy,
    required this.residual,
    required this.identityResidual,
  });

  /// Uniform scale about the frame centre.
  final double scale;

  /// Horizontal shift, as a fraction of the frame width.
  final double dx;

  /// Vertical shift, as a fraction of the frame height.
  final double dy;

  /// Mean absolute difference between the frames once aligned.
  final double residual;

  /// Mean absolute difference between the frames without any alignment.
  final double identityResidual;

  /// Share of the seam mismatch the alignment removes, 0..1.
  double get improvement =>
      identityResidual <= 0 ? 0 : 1 - residual / identityResidual;

  @override
  String toString() =>
      'LoopSeamAlignment(scale: ${scale.toStringAsFixed(4)}, '
      'dx: ${dx.toStringAsFixed(4)}, dy: ${dy.toStringAsFixed(4)}, '
      'residual: ${residual.toStringAsFixed(3)}, '
      'identityResidual: ${identityResidual.toStringAsFixed(3)})';
}

/// Why an estimate is not safe to apply.
enum LoopSeamRejection {
  /// The two ends already match; there is no jump to fix.
  alreadySeamless,

  /// Aligning barely helps, so the jump is not camera motion.
  noImprovement,

  /// Even aligned the frames differ a lot — a cut, a new subject.
  unrelatedFrames,

  /// The correction is larger than a small zoom can hide.
  tooLarge,

  /// The best match sits on the edge of the search window, so the real move
  /// is probably outside it.
  searchBoundary,
}

/// Limits deciding whether an alignment is applied.
@immutable
class LoopSeamLimits {
  const LoopSeamLimits({
    this.maxShift = 0.08,
    this.maxScaleDelta = 0.05,
    this.minImprovement = 0.15,
    this.maxResidual = 0.65,
    this.seamlessResidual = 0.12,
  });

  /// Largest shift applied, as a fraction of the frame dimension.
  final double maxShift;

  /// Largest departure of the scale from 1.
  final double maxScaleDelta;

  /// Least share of the mismatch the alignment has to remove.
  final double minImprovement;

  /// Largest aligned residual still treated as the same shot.
  ///
  /// Two unrelated normalised frames differ by ~1.1 on average.
  final double maxResidual;

  /// Identity residual below which the ends already match.
  final double seamlessResidual;
}

/// Outcome of [estimateLoopSeamAlignment].
@immutable
class LoopSeamEstimate {
  const LoopSeamEstimate(this.alignment, {this.rejection});

  final LoopSeamAlignment alignment;

  /// Why [alignment] should not be applied, or `null` when it should.
  final LoopSeamRejection? rejection;

  bool get isUsable => rejection == null;
}

/// Search window of the coarsest level, as a fraction of the frame dimension.
const double _coarseShiftWindow = 0.12;
const double _coarseScaleWindow = 0.06;
const double _coarseScaleStep = 0.01;

/// Least share of the output that must map inside the source to score a pose.
const double _minOverlap = 0.6;

/// Finds how [last] has to be displayed to line up with [first].
///
/// Coarse-to-fine exhaustive search over scale and shift on an image pyramid.
/// The frames are small (the long side ~200 px), so the whole search is a few
/// million pixel reads — cheap enough to run on an isolate at export time, and
/// deterministic, which a feature-matching approach is not.
LoopSeamEstimate estimateLoopSeamAlignment({
  required GrayFrame last,
  required GrayFrame first,
  LoopSeamLimits limits = const LoopSeamLimits(),
}) {
  assert(
    last.width == first.width && last.height == first.height,
    'frames must share a size',
  );
  final lastPyramid = [last];
  final firstPyramid = [first];
  while (lastPyramid.last.width >= 48 && lastPyramid.last.height >= 48) {
    lastPyramid.add(lastPyramid.last.downsampled());
    firstPyramid.add(firstPyramid.last.downsampled());
  }

  // Coarsest level: exhaustive over the whole window.
  var level = lastPyramid.length - 1;
  var src = lastPyramid[level];
  var dst = firstPyramid[level];
  final rx = math.max(1, (src.width * _coarseShiftWindow).round());
  final ry = math.max(1, (src.height * _coarseShiftWindow).round());
  var best = const _Pose(1, 0, 0, double.infinity);
  for (
    var s = 1 - _coarseScaleWindow;
    s <= 1 + _coarseScaleWindow + 1e-9;
    s += _coarseScaleStep
  ) {
    for (var ty = -ry; ty <= ry; ty++) {
      for (var tx = -rx; tx <= rx; tx++) {
        final cost = _cost(src, dst, s, tx.toDouble(), ty.toDouble());
        if (cost < best.cost) {
          best = _Pose(s, tx.toDouble(), ty.toDouble(), cost);
        }
      }
    }
  }
  final hitBoundary =
      best.tx.abs() >= rx ||
      best.ty.abs() >= ry ||
      (best.scale - 1).abs() >= _coarseScaleWindow - 1e-9;

  // Finer levels: refine around the doubled estimate.
  var scaleStep = _coarseScaleStep / 2;
  while (level > 0) {
    level--;
    src = lastPyramid[level];
    dst = firstPyramid[level];
    final seed = _Pose(best.scale, best.tx * 2, best.ty * 2, double.infinity);
    best = seed;
    for (var ds = -2; ds <= 2; ds++) {
      final s = seed.scale + ds * scaleStep;
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          final tx = seed.tx + dx * 0.5;
          final ty = seed.ty + dy * 0.5;
          final cost = _cost(src, dst, s, tx, ty);
          if (cost < best.cost) best = _Pose(s, tx, ty, cost);
        }
      }
    }
    scaleStep /= 2;
  }

  final identity = _cost(last, first, 1, 0, 0);
  final alignment = LoopSeamAlignment(
    scale: best.scale,
    dx: best.tx / last.width,
    dy: best.ty / last.height,
    residual: best.cost,
    identityResidual: identity,
  );
  return LoopSeamEstimate(
    alignment,
    rejection: _rejectionFor(alignment, limits, hitBoundary: hitBoundary),
  );
}

LoopSeamRejection? _rejectionFor(
  LoopSeamAlignment a,
  LoopSeamLimits limits, {
  required bool hitBoundary,
}) {
  if (a.identityResidual <= limits.seamlessResidual) {
    return LoopSeamRejection.alreadySeamless;
  }
  if (hitBoundary) return LoopSeamRejection.searchBoundary;
  if (a.residual > limits.maxResidual) return LoopSeamRejection.unrelatedFrames;
  if (a.improvement < limits.minImprovement) {
    return LoopSeamRejection.noImprovement;
  }
  if (a.dx.abs() > limits.maxShift ||
      a.dy.abs() > limits.maxShift ||
      (a.scale - 1).abs() > limits.maxScaleDelta) {
    return LoopSeamRejection.tooLarge;
  }
  return null;
}

class _Pose {
  const _Pose(this.scale, this.tx, this.ty, this.cost);
  final double scale;
  final double tx;
  final double ty;
  final double cost;
}

/// Mean absolute difference between [dst] and [src] displayed at
/// scale [s] about the centre, shifted by ([tx], [ty]) pixels.
///
/// Output pixel p shows source point `c + (p - c - t) / s`. Pixels that map
/// outside the source are skipped; a pose leaving too little overlap scores
/// infinity so a large shift cannot win by comparing a sliver.
double _cost(GrayFrame src, GrayFrame dst, double s, double tx, double ty) {
  final w = src.width;
  final h = src.height;
  final cx = (w - 1) / 2;
  final cy = (h - 1) / 2;
  final inv = 1 / s;
  var sum = 0.0;
  var n = 0;
  for (var y = 0; y < h; y++) {
    final sy = cy + (y - cy - ty) * inv;
    if (sy < 0 || sy >= h - 1) continue;
    final row = y * w;
    for (var x = 0; x < w; x++) {
      final sx = cx + (x - cx - tx) * inv;
      if (sx < 0 || sx >= w - 1) continue;
      sum += (dst.luma[row + x] - src._sample(sx, sy)).abs();
      n++;
    }
  }
  if (n < w * h * _minOverlap) return double.infinity;
  return sum / n;
}
