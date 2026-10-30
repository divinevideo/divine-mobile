// ABOUTME: Adapts PVE's public corner tracking and robust similarity fit to
// ABOUTME: measurable loop confidence, including independently detected edges.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:pro_video_editor/core/analysis/corner_detector.dart';
import 'package:pro_video_editor/core/analysis/lucas_kanade_tracker.dart';
import 'package:pro_video_editor/core/analysis/luma_pyramid.dart';
import 'package:pro_video_editor/core/analysis/similarity_estimator.dart';

/// All coordinates are upright analysis pixels. The returned pose maps the
/// reference to the target, about the image center rather than its top left.
class PveLoopFrameMatcher implements LoopFrameMatcher {
  @override
  LoopFrameMatch? match(LoopFrame reference, LoopFrame target) {
    final w = reference.width;
    final h = reference.height;
    if (w != target.width || h != target.height || math.min(w, h) < 64) {
      return null;
    }
    if (_hasAmbiguousTexture(reference)) return null;
    final from = LumaPyramid.fromLuma(reference.luma, w, h);
    final to = LumaPyramid.fromLuma(target.luma, w, h);
    final points = <double>[...detectCorners(from.levels.first)];
    // Local quality thresholds keep a bright subject from suppressing weaker
    // background features. These points are tracked independently of the fit.
    final strips = [
      (0.0, 0.0, w * .08, h.toDouble()),
      (w * .92, 0.0, w.toDouble(), h.toDouble()),
      (0.0, 0.0, w.toDouble(), h * .08),
      (0.0, h * .92, w.toDouble(), h.toDouble()),
    ];
    final boundaryPoints = <Float32List>[];
    for (final strip in strips) {
      boundaryPoints.add(
        detectCornersInRect(
          from.levels.first,
          left: strip.$1,
          top: strip.$2,
          right: strip.$3,
          bottom: strip.$4,
        ),
      );
    }
    final tracked = _track(from, to, Float32List.fromList(points));
    if (tracked.length < 20) return null;
    final fitting = <(double, double, double, double)>[];
    final withheld = <(double, double, double, double)>[];
    for (var i = 0; i < tracked.length; i++) {
      (i % 3 == 0 ? withheld : fitting).add(tracked[i]);
    }
    final src = Float32List.fromList([
      for (final p in fitting) ...[p.$1, p.$2],
    ]);
    final dst = Float32List.fromList([
      for (final p in fitting) ...[p.$3, p.$4],
    ]);
    final fit = fitSimilarityRansac(src, dst, fitting.length);
    if (fit == null) return null;
    final model = fit.transform;
    double error((double, double, double, double) p) => math.sqrt(
      math.pow(model.mapX(p.$1, p.$2) - p.$3, 2) +
          math.pow(model.mapY(p.$1, p.$2) - p.$4, 2),
    );
    final inliers = tracked.where((p) => error(p) <= 1).toList();
    if (inliers.isEmpty || withheld.length < 5) return null;
    final errors = withheld.map(error).toList()..sort();
    final median = errors.length.isOdd
        ? errors[errors.length ~/ 2]
        : (errors[errors.length ~/ 2 - 1] + errors[errors.length ~/ 2]) / 2;
    final support = <LoopBoundarySupport>[];
    final boundaryMatches = <(double, double, double, double)>[];
    for (final points in boundaryPoints) {
      final matches = _track(from, to, points);
      boundaryMatches.addAll(matches);
      support.add(
        LoopBoundarySupport(
          agreeing: matches.where((p) => error(p) <= 1).length,
          retained: matches.length,
        ),
      );
    }
    // A subpixel compromise between foreground and background can pass a
    // one-pixel inlier count everywhere. Measure disagreement with an
    // independent background fit instead of treating that count as proof.
    final boundaryTraining = [
      for (var i = 0; i < boundaryMatches.length; i++)
        if (i % 3 != 0) boundaryMatches[i],
    ];
    final boundaryFit = fitSimilarityRansac(
      Float32List.fromList([
        for (final p in boundaryTraining) ...[p.$1, p.$2],
      ]),
      Float32List.fromList([
        for (final p in boundaryTraining) ...[p.$3, p.$4],
      ]),
      boundaryTraining.length,
    );
    var boundaryModelError = double.infinity;
    if (boundaryFit != null) {
      boundaryModelError = 0;
      for (final x in [0.0, w.toDouble()]) {
        for (final y in [0.0, h.toDouble()]) {
          final dx = model.mapX(x, y) - boundaryFit.transform.mapX(x, y);
          final dy = model.mapY(x, y) - boundaryFit.transform.mapY(x, y);
          boundaryModelError = math.max(
            boundaryModelError,
            math.sqrt(dx * dx + dy * dy),
          );
        }
      }
    }
    final cells = <int>{};
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final point in inliers) {
      minX = math.min(minX, point.$1);
      maxX = math.max(maxX, point.$1);
      minY = math.min(minY, point.$2);
      maxY = math.max(maxY, point.$2);
      cells.add(
        (point.$1 * 3 / w).floor().clamp(0, 2) +
            3 * (point.$2 * 3 / h).floor().clamp(0, 2),
      );
    }
    return LoopFrameMatch(
      pose: LoopPose(
        a: model.a,
        b: model.b,
        tx: model.mapX(w / 2, h / 2) - w / 2,
        ty: model.mapY(w / 2, h / 2) - h / 2,
      ),
      consistentCount: inliers.length,
      retainedCount: tracked.length,
      occupiedCells: cells.length,
      widthSpan: (maxX - minX) / w,
      heightSpan: (maxY - minY) / h,
      boundaryModelError: boundaryModelError,
      withheldCount: withheld.length,
      withheldMedianError: median,
      left: support[0],
      right: support[1],
      top: support[2],
      bottom: support[3],
    );
  }

  /// A locally excellent track is not unique on a periodic scene. Look for a
  /// distinct translation that reproduces the reference itself, independently
  /// of LK's initial basin. This is a conservative rejection test, not an
  /// alternative estimator: it cannot make an uncertain fit acceptable.
  ///
  /// The search uses at most 64 pixels per axis on a two-pixel lattice and 143
  /// spatially distributed samples per alternative. Mean subtraction tolerates
  /// illumination offsets. Residual variance below 1% of texture variance is
  /// ambiguous; sparse samples deliberately cannot certify uniqueness.
  bool _hasAmbiguousTexture(LoopFrame frame) {
    final width = frame.width;
    final height = frame.height;
    final radius = math.min(64, math.min(width, height) ~/ 3);
    final maximum = radius - radius % 2;
    for (var dy = 0; dy <= maximum; dy += 2) {
      for (var dx = -maximum; dx <= maximum; dx += 2) {
        // Opposite offsets are the same autocorrelation alternative. Distances
        // under four pixels are the fit's own local neighborhood, not aliases.
        if ((dy == 0 && dx < 4) || dx * dx + dy * dy < 16) continue;
        final left = math.max(8, 8 - dx);
        final top = math.max(8, 8 - dy);
        final right = math.min(width - 8, width - 8 - dx);
        final bottom = math.min(height - 8, height - 8 - dy);
        var sumA = 0.0;
        var sumB = 0.0;
        var squaredA = 0.0;
        var squaredB = 0.0;
        var difference = 0.0;
        var squaredDifference = 0.0;
        for (var row = 0; row < 11; row++) {
          for (var column = 0; column < 13; column++) {
            // Jitter within grid cells avoids sampling a single repeated phase.
            final fx =
                (column + .25 + .5 * ((column * 7 + row * 11) % 13) / 12) / 13;
            final fy =
                (row + .25 + .5 * ((column * 11 + row * 7) % 11) / 10) / 11;
            final x = left + ((right - left) * fx).floor();
            final y = top + ((bottom - top) * fy).floor();
            final a = frame.luma[y * width + x].toDouble();
            final b = frame.luma[(y + dy) * width + x + dx].toDouble();
            sumA += a;
            sumB += b;
            squaredA += a * a;
            squaredB += b * b;
            difference += a - b;
            squaredDifference += (a - b) * (a - b);
          }
        }
        const count = 143;
        final variance =
            (squaredA / count -
                math.pow(sumA / count, 2) +
                squaredB / count -
                math.pow(sumB / count, 2)) /
            2;
        final residual =
            squaredDifference / count - math.pow(difference / count, 2);
        if (variance >= 16 && residual <= variance * .01) return true;
      }
    }
    return false;
  }

  List<(double, double, double, double)> _track(
    LumaPyramid from,
    LumaPyramid to,
    Float32List points,
  ) {
    if (points.isEmpty) return [];
    final tracker = LucasKanadeTracker();
    final forward = Float32List(points.length);
    final backward = Float32List(points.length);
    final ok = tracker.track(from, to, points, forward);
    final back = tracker.track(to, from, forward, backward);
    return [
      for (var i = 0; i < ok.length; i++)
        if (ok[i] != 0 &&
            back[i] != 0 &&
            math.pow(points[2 * i] - backward[2 * i], 2) +
                    math.pow(points[2 * i + 1] - backward[2 * i + 1], 2) <=
                1)
          (
            points[2 * i],
            points[2 * i + 1],
            forward[2 * i],
            forward[2 * i + 1],
          ),
    ];
  }
}
