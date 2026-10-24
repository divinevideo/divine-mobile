import 'dart:math' as math;
import 'dart:typed_data';

import 'loop_alignment_models.dart';

/// Pixel-center bilinear sampling shared by planning and rendered inspection.
final class LoopFrameResampler {
  const LoopFrameResampler();
  LoopFrame warp(
    LoopFrame frame,
    LoopPose correction,
    double zoom, {
    int longestEdge = 64,
  }) {
    if (!correction.isFinite || !zoom.isFinite || zoom < 1 || longestEdge <= 0)
      throw ArgumentError('Invalid output geometry');
    final ratio = longestEdge / math.max(frame.width, frame.height);
    final width = math.max(1, (frame.width * ratio).round());
    final height = math.max(1, (frame.height * ratio).round());
    final inverse = correction.inverse();
    final pixels = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final source = inverse.transform(
          ((x + .5) * frame.width / width - frame.width / 2) / zoom,
          ((y + .5) * frame.height / height - frame.height / 2) / zoom,
        );
        pixels[y * width + x] = sample(
          frame,
          source.x + frame.width / 2 - .5,
          source.y + frame.height / 2 - .5,
        ).round().clamp(0, 255);
      }
    }
    return LoopFrame(
      time: frame.time,
      width: width,
      height: height,
      luma: pixels,
    );
  }

  double sample(LoopFrame frame, double x, double y) {
    // Coverage is checked separately; clamp only the half-pixel sample footprint.
    x = x.clamp(0, frame.width - 1.0);
    y = y.clamp(0, frame.height - 1.0);
    final x0 = x.floor(), y0 = y.floor();
    final x1 = math.min(x0 + 1, frame.width - 1),
        y1 = math.min(y0 + 1, frame.height - 1);
    final fx = x - x0, fy = y - y0;
    return frame.luma[y0 * frame.width + x0] * (1 - fx) * (1 - fy) +
        frame.luma[y0 * frame.width + x1] * fx * (1 - fy) +
        frame.luma[y1 * frame.width + x0] * (1 - fx) * fy +
        frame.luma[y1 * frame.width + x1] * fx * fy;
  }
}

final class LoopSeamScorer {
  const LoopSeamScorer();

  /// Inputs are chronological on each side, end.last immediately before start.first.
  LoopSeamScores score(List<LoopFrame> start, List<LoopFrame> end) {
    if (start.length < 2 || end.length < 2)
      throw ArgumentError('Two frames per side are required');
    final s = start
        .map((f) => const LoopFrameResampler().warp(f, LoopPose.identity, 1))
        .toList();
    final e = end
        .map((f) => const LoopFrameResampler().warp(f, LoopPose.identity, 1))
        .toList();
    if (s.any((f) => f.width != s.first.width || f.height != s.first.height) ||
        e.any((f) => f.width != s.first.width || f.height != s.first.height))
      throw ArgumentError('Frame aspect ratios differ');
    var error = 0.0, weight = 0.0;
    for (var i = 0; i < math.min(3, math.min(s.length, e.length)); i++) {
      final w = math.pow(.5, i).toDouble();
      error += _difference(s[i], e[e.length - 1 - i]) * w;
      weight += w;
    }
    // Compare exposure-normalized temporal derivatives. Normalize to one ordinary
    // frame interval so variable-rate frames do not create a false acceleration.
    final dtStart = _seconds(start[1].time - start[0].time);
    final dtEnd = _seconds(end.last.time - end[end.length - 2].time);
    if (dtStart <= 0 || dtEnd <= 0)
      throw ArgumentError('Frame timestamps must increase');
    final dt = (dtStart + dtEnd) / 2;
    final incoming = _velocity(e[e.length - 2], e.last, dtEnd, dt);
    final outgoing = _velocity(s[0], s[1], dtStart, dt);
    final across = _velocity(e.last, s.first, dt, dt);
    var motion = 0.0;
    for (var i = 0; i < across.length; i++) {
      motion +=
          ((across[i] - incoming[i]).abs() + (outgoing[i] - across[i]).abs()) /
          2;
    }
    return LoopSeamScores(
      difference: error / weight,
      motion: motion / across.length,
    );
  }

  /// Requires at least four ordinary adjacent acceleration samples.
  bool alreadySmooth({
    required LoopFrameMatch registration,
    required List<LoopFrame> start,
    required List<LoopFrame> end,
    LoopAlignmentLimits limits = const LoopAlignmentLimits(),
  }) {
    if (start.length < 2 ||
        end.length < 2 ||
        !limits.acceptsMatch(
          registration,
          start.first.width,
          start.first.height,
        ) ||
        registration.pose.maximumCornerDisplacement(
              start.first.width,
              start.first.height,
            ) >
            .5)
      return false;
    final scores = score(start, end);
    if (scores.difference > limits.maximumDifference) return false;
    final ordinary = <double>[];
    for (final frames in [start, end]) {
      for (var i = 2; i < frames.length; i++) {
        final a = frames[i - 2], b = frames[i - 1], c = frames[i];
        final dt1 = _seconds(b.time - a.time), dt2 = _seconds(c.time - b.time);
        if (dt1 <= 0 || dt2 <= 0) return false;
        final velocity1 = _velocity(a, b, dt1, (dt1 + dt2) / 2),
            velocity2 = _velocity(b, c, dt2, (dt1 + dt2) / 2);
        var value = 0.0;
        for (var j = 0; j < velocity1.length; j++) {
          value += (velocity2[j] - velocity1[j]).abs();
        }
        ordinary.add(value / velocity1.length);
      }
    }
    if (ordinary.length < 4) return false;
    ordinary.sort();
    return scores.motion <=
        ordinary[(.95 * (ordinary.length - 1)).ceil()] + 1e-12;
  }

  double _difference(LoopFrame a, LoopFrame b) {
    var sum = 0;
    for (var i = 0; i < a.luma.length; i++) {
      sum += (a.luma[i] - b.luma[i]).abs();
    }
    return sum / a.luma.length / 255;
  }

  List<double> _velocity(
    LoopFrame a,
    LoopFrame b,
    double seconds,
    double interval,
  ) {
    if (a.luma.length != b.luma.length)
      throw ArgumentError('Frame dimensions differ');
    final meanA = a.luma.fold<int>(0, (s, v) => s + v) / a.luma.length;
    final meanB = b.luma.fold<int>(0, (s, v) => s + v) / b.luma.length;
    return List.generate(
      a.luma.length,
      (i) =>
          ((b.luma[i] - meanB) - (a.luma[i] - meanA)) /
          255 /
          seconds *
          interval,
    );
  }

  double _seconds(Duration time) =>
      time.inMicroseconds / Duration.microsecondsPerSecond;
}
