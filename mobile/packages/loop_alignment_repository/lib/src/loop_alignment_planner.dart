import 'dart:math' as math;

import 'loop_alignment_models.dart';
import 'loop_seam_scorer.dart';

/// Pure planning over bounded decoded frames. Matchers provide measured evidence;
/// this package owns every acceptance threshold.
final class LoopAlignmentPlanner {
  const LoopAlignmentPlanner();
  LoopAlignmentPlan? plan({
    required LoopRepairInput input,
    required List<LoopFrame> firstFrames,
    required List<LoopFrame> lastFrames,
    required LoopFrameMatcher matcher,
    required LoopAlignmentLimits limits,
  }) {
    if (input.capability != LoopRepairCapability.supported ||
        input.clips.isEmpty ||
        firstFrames.length < 2 ||
        lastFrames.length < 2)
      return null;
    if (!_validFrames(firstFrames) || !_validFrames(lastFrames)) return null;
    final first = firstFrames.first, last = lastFrames.last;
    if (first.width != last.width || first.height != last.height) return null;
    final join = matcher.match(first, last);
    if (join == null || !limits.acceptsMatch(join, first.width, first.height))
      return null;
    if (join.pose.maximumCornerDisplacement(first.width, first.height) <= .5)
      return null;
    final plans = input.clips.length == 1
        ? _fixedView(input.clips.single, firstFrames, matcher, limits)
        : _finalShot(
            input.clips,
            lastFrames,
            firstFrames,
            matcher,
            limits,
            join.pose,
          );
    if (plans == null) return null;
    var zoom = 1.0;
    for (final p in plans) {
      final frames = p.clipId == input.clips.first.clipId
          ? firstFrames
          : lastFrames;
      zoom = math.max(
        zoom,
        requiredZoom(
          p,
          frames.first.width,
          frames.first.height,
          frames.map((f) => f.time),
        ),
      );
    }
    if (!zoom.isFinite || zoom > limits.maximumZoom) return null;
    final startPlan = plans.first, endPlan = plans.last;
    final start = _warped(firstFrames.take(3), startPlan, zoom);
    final end = _warped(
      lastFrames.skip(math.max(0, lastFrames.length - 3)),
      endPlan,
      zoom,
    );
    final originalStart = firstFrames
        .take(3)
        .map((f) => const LoopFrameResampler().warp(f, LoopPose.identity, zoom))
        .toList();
    final originalEnd = lastFrames
        .skip(math.max(0, lastFrames.length - 3))
        .map((f) => const LoopFrameResampler().warp(f, LoopPose.identity, zoom))
        .toList();
    final seamInterval = Duration(
      microseconds:
          ((input.clips.last.sourceEnd - lastFrames.last.time).inMicroseconds /
                  input.clips.last.speed)
              .round(),
    );
    if (seamInterval <= Duration.zero) return null;
    final corrected = const LoopSeamScorer().score(
      start,
      end,
      seamInterval: seamInterval,
      startSpeed: input.clips.first.speed,
      endSpeed: input.clips.last.speed,
    );
    final baseline = const LoopSeamScorer().score(
      originalStart,
      originalEnd,
      seamInterval: seamInterval,
      startSpeed: input.clips.first.speed,
      endSpeed: input.clips.last.speed,
    );
    if (!limits.acceptsScores(baseline, corrected)) return null;
    return LoopAlignmentPlan(
      clips: plans,
      zoom: zoom,
      confidence: join,
      predictedScores: corrected,
      baselineScores: baseline,
    );
  }

  bool _validFrames(List<LoopFrame> frames) {
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].width != frames.first.width ||
          frames[i].height != frames.first.height ||
          (i > 0 && frames[i].time <= frames[i - 1].time))
        return false;
    }
    return true;
  }

  List<LoopFrame> _warped(
    Iterable<LoopFrame> frames,
    LoopClipPlan p,
    double zoom,
  ) => frames
      .map(
        (f) => const LoopFrameResampler().warp(f, p.correctionAt(f.time), zoom),
      )
      .toList();
  List<LoopFrame>? _anchors(
    List<LoopFrame> frames,
    LoopAlignmentLimits limits,
    double speed,
  ) {
    final maximumGap = Duration(
      microseconds: (limits.maximumAnchorGap.inMicroseconds * speed).floor(),
    );
    final result = <LoopFrame>[frames.first];
    for (var i = 1; i < frames.length; i++) {
      if (frames[i].time - result.last.time > maximumGap) {
        if (i == 1 || identical(result.last, frames[i - 1])) return null;
        result.add(frames[i - 1]);
        if (frames[i].time - result.last.time > maximumGap) return null;
      }
    }
    if (!identical(result.last, frames.last)) result.add(frames.last);
    return result;
  }

  List<LoopClipPlan>? _fixedView(
    LoopClipInput clip,
    List<LoopFrame> frames,
    LoopFrameMatcher matcher,
    LoopAlignmentLimits limits,
  ) {
    final anchors = _anchors(frames, limits, clip.speed);
    if (anchors == null) return null;
    final path = <LoopKeyframe>[];
    for (final frame in anchors) {
      final match = matcher.match(frames.first, frame);
      if (match == null ||
          !limits.acceptsMatch(match, frame.width, frame.height))
        return null;
      path.add(LoopKeyframe(sourceTime: frame.time, correction: match.pose));
    }
    final camera = LoopClipPlan(
      clipId: clip.clipId,
      sourceStart: clip.sourceStart,
      sourceEnd: clip.sourceEnd,
      keyframes: path,
    );
    if (clip.sourceEnd <= clip.sourceStart) return null;
    LoopClipPlan? best;
    var bestZoom = double.infinity;
    // Every trusted anchor is a possible fixed view. Cancel the same measured
    // camera path into each one, then compare the constant crop they require.
    for (final reference in path) {
      final candidate = LoopClipPlan(
        clipId: clip.clipId,
        sourceStart: clip.sourceStart,
        sourceEnd: clip.sourceEnd,
        keyframes: [
          for (final frame in frames)
            LoopKeyframe(
              sourceTime: frame.time,
              correction: camera
                  .correctionAt(frame.time)
                  .inverse()
                  .then(reference.correction),
            ),
        ],
      );
      final zoom = requiredZoom(
        candidate,
        frames.first.width,
        frames.first.height,
        frames.map((frame) => frame.time),
      );
      // Keep the strict minimum crop; chronological iteration retains the
      // earliest trusted reference only when coverage costs are exactly equal.
      if (zoom.isFinite && zoom < bestZoom) {
        best = candidate;
        bestZoom = zoom;
      }
    }
    return best == null ? null : [best];
  }

  List<LoopClipPlan>? _finalShot(
    List<LoopClipInput> clips,
    List<LoopFrame> frames,
    List<LoopFrame> opening,
    LoopFrameMatcher matcher,
    LoopAlignmentLimits limits,
    LoopPose join,
  ) {
    final anchors = _anchors(frames, limits, clips.last.speed);
    if (anchors == null) return null;
    // Every anchor must support a reliable camera path, even though only the
    // final shot receives the Hermite correction.
    for (final frame in anchors) {
      final m = matcher.match(frames.first, frame);
      if (m == null || !limits.acceptsMatch(m, frame.width, frame.height))
        return null;
    }
    final incoming = matcher.match(frames[frames.length - 2], frames.last);
    final outgoing = matcher.match(opening[0], opening[1]);
    if (incoming == null ||
        outgoing == null ||
        !limits.acceptsMatch(
          incoming,
          frames.first.width,
          frames.first.height,
        ) ||
        !limits.acceptsMatch(outgoing, frames.first.width, frames.first.height))
      return null;
    final clip = clips.last;
    final duration = (clip.sourceEnd - clip.sourceStart).inMicroseconds
        .toDouble();
    if (duration <= 0 || frames.first.time != clip.sourceStart) return null;
    final dtIn =
        (frames.last.time - frames[frames.length - 2].time).inMicroseconds /
        clip.speed;
    final dtOut =
        (opening[1].time - opening[0].time).inMicroseconds / clips.first.speed;
    final seamInterval =
        (clip.sourceEnd - frames.last.time).inMicroseconds / clip.speed;
    if (seamInterval <= 0) return null;
    final previousOpening = _power(outgoing.pose, -seamInterval / dtOut);
    final endpoint = join.inverse().then(previousOpening);
    final incomingVelocity = _generator(incoming.pose, dtIn);
    final outgoingVelocity = _generator(outgoing.pose, dtOut);
    // For similarities C=(B,c), Q=(A,t), displayed framing is C Q.
    // With local camera generators Gin/Gout, C' = Gout C - C Gin.
    // In particular c' = omegaOut*c + vout - B*vin: subtracting the
    // relative matches' translation components misses this transport.
    final derivative = [
      outgoingVelocity.real * endpoint.tx -
          outgoingVelocity.imaginary * endpoint.ty +
          outgoingVelocity.x -
          (endpoint.a * incomingVelocity.x - endpoint.b * incomingVelocity.y),
      outgoingVelocity.imaginary * endpoint.tx +
          outgoingVelocity.real * endpoint.ty +
          outgoingVelocity.y -
          (endpoint.b * incomingVelocity.x + endpoint.a * incomingVelocity.y),
      outgoingVelocity.imaginary - incomingVelocity.imaginary,
      outgoingVelocity.real - incomingVelocity.real,
    ];
    final end = [
      endpoint.tx,
      endpoint.ty,
      endpoint.angle,
      math.log(endpoint.scale),
    ];
    // End position is at the last displayed frame; the next ordinary frame is
    // supplied by the opening shot, rather than duplicating an endpoint frame.
    final sampledDuration = (frames.last.time - clip.sourceStart).inMicroseconds
        .toDouble();
    if (sampledDuration <= 0) return null;
    final length = sampledDuration / clip.speed;
    final keys = <LoopKeyframe>[];
    for (final frame in frames) {
      final u =
          (frame.time - clip.sourceStart).inMicroseconds / sampledDuration;
      final h = -2 * u * u * u + 3 * u * u, hd = u * u * u - u * u;
      final values = List.generate(
        4,
        (i) => h * end[i] + hd * derivative[i] * length,
      );
      keys.add(
        LoopKeyframe(
          sourceTime: frame.time,
          correction: LoopPose.components(
            x: values[0],
            y: values[1],
            angle: values[2],
            logScale: values[3],
          ),
        ),
      );
    }
    return [
      for (final c in clips)
        if (c.clipId == clip.clipId)
          LoopClipPlan(
            clipId: c.clipId,
            sourceStart: c.sourceStart,
            sourceEnd: c.sourceEnd,
            keyframes: keys,
          )
        else
          LoopClipPlan(
            clipId: c.clipId,
            sourceStart: c.sourceStart,
            sourceEnd: c.sourceEnd,
            keyframes: [
              LoopKeyframe(
                sourceTime: c.sourceStart,
                correction: LoopPose.identity,
              ),
              LoopKeyframe(
                sourceTime: c.sourceEnd,
                correction: LoopPose.identity,
              ),
            ],
          ),
    ];
  }

  /// Logarithm of a similarity in the image coordinate system. A local
  /// generator acts on a point as omega*point + velocity (complex notation).
  ({double real, double imaginary, double x, double y}) _generator(
    LoopPose pose,
    double interval,
  ) {
    final real = math.log(pose.scale), imaginary = pose.angle;
    final zr = pose.a - 1, zi = pose.b, denominator = zr * zr + zi * zi;
    double ratioReal, ratioImaginary;
    if (denominator < 1e-16) {
      // log(z)/(z-1), expanded about identity to avoid cancellation.
      ratioReal = 1 - real / 2 + (real * real - imaginary * imaginary) / 12;
      ratioImaginary = -imaginary / 2 + real * imaginary / 6;
    } else {
      ratioReal = (real * zr + imaginary * zi) / denominator;
      ratioImaginary = (imaginary * zr - real * zi) / denominator;
    }
    return (
      real: real / interval,
      imaginary: imaginary / interval,
      x: (ratioReal * pose.tx - ratioImaginary * pose.ty) / interval,
      y: (ratioImaginary * pose.tx + ratioReal * pose.ty) / interval,
    );
  }

  /// Fractional composition, including the translation/linear-part coupling.
  LoopPose _power(LoopPose pose, double fraction) {
    final linear = LoopPose.components(
      angle: pose.angle * fraction,
      logScale: math.log(pose.scale) * fraction,
    );
    final zr = pose.a - 1, zi = pose.b, denominator = zr * zr + zi * zi;
    double real, imaginary;
    if (denominator < 1e-16) {
      final lr = math.log(pose.scale), li = pose.angle;
      real =
          fraction *
          (1 +
              (fraction - 1) * lr / 2 +
              (2 * fraction * fraction - 3 * fraction + 1) *
                  (lr * lr - li * li) /
                  12);
      imaginary =
          fraction *
          ((fraction - 1) * li / 2 +
              (2 * fraction * fraction - 3 * fraction + 1) * lr * li / 6);
    } else {
      real = ((linear.a - 1) * zr + linear.b * zi) / denominator;
      imaginary = (linear.b * zr - (linear.a - 1) * zi) / denominator;
    }
    return LoopPose(
      a: linear.a,
      b: linear.b,
      tx: real * pose.tx - imaginary * pose.ty,
      ty: imaginary * pose.tx + real * pose.ty,
    );
  }

  /// Includes every decoded output timestamp and intermediate path samples.
  /// The inverse-corner inequalities include translation, rotation, and scale.
  double requiredZoom(
    LoopClipPlan plan,
    int width,
    int height,
    Iterable<Duration> outputTimes,
  ) {
    final times = <int>{
      for (final t in outputTimes) t.inMicroseconds,
      for (final k in plan.keyframes) k.sourceTime.inMicroseconds,
    };
    for (var i = 1; i < plan.keyframes.length; i++) {
      final a = plan.keyframes[i - 1].sourceTime.inMicroseconds,
          b = plan.keyframes[i].sourceTime.inMicroseconds;
      for (var t = a + 1000; t < b; t += 1000) {
        times.add(t);
      }
    }
    var zoom = 1.0;
    for (final time in times) {
      final pose = plan.correctionAt(Duration(microseconds: time));
      if (!pose.isFinite) return double.infinity;
      final p = pose.inverse();
      final hw = width / 2, hh = height / 2;
      final availableX = hw - p.tx.abs(), availableY = hh - p.ty.abs();
      if (availableX <= 0 || availableY <= 0) return double.infinity;
      zoom = math.max(
        zoom,
        math.max(
          (p.a.abs() * hw + p.b.abs() * hh) / availableX,
          (p.b.abs() * hw + p.a.abs() * hh) / availableY,
        ),
      );
    }
    return zoom;
  }
}
