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
        ? _periodic(input.clips.single, firstFrames, matcher, limits)
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
    final corrected = const LoopSeamScorer().score(start, end);
    final baseline = const LoopSeamScorer().score(originalStart, originalEnd);
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

  List<LoopClipPlan>? _periodic(
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
    final period = (clip.sourceEnd - clip.sourceStart).inMicroseconds
        .toDouble();
    if (period <= 0) return null;
    final sigma = math.min(500000 * clip.speed, period / 8);
    final samples = frames;
    final smoothed = <LoopKeyframe>[];
    // Integrate a periodic Gaussian over timestamp-weighted decoded samples.
    for (final frame in samples) {
      var total = 0.0, x = 0.0, y = 0.0, angle = 0.0, logScale = 0.0;
      for (var j = 0; j < samples.length; j++) {
        final other = samples[j];
        var d =
            (frame.time - other.time).inMicroseconds.toDouble().abs() % period;
        d = math.min(d, period - d);
        final next = j + 1 < samples.length
            ? samples[j + 1].time.inMicroseconds
            : clip.sourceEnd.inMicroseconds;
        final previous = j > 0
            ? samples[j - 1].time.inMicroseconds
            : clip.sourceStart.inMicroseconds;
        final weight =
            math.exp(-d * d / (2 * sigma * sigma)) *
            math.max(1, next - previous) /
            2;
        final pose = camera.correctionAt(other.time);
        total += weight;
        x += weight * pose.tx;
        y += weight * pose.ty;
        angle += weight * pose.angle;
        logScale += weight * math.log(pose.scale);
      }
      final target = LoopPose.components(
        x: x / total,
        y: y / total,
        angle: angle / total,
        logScale: logScale / total,
      );
      smoothed.add(
        LoopKeyframe(
          sourceTime: frame.time,
          correction: camera.correctionAt(frame.time).inverse().then(target),
        ),
      );
    }
    return [
      LoopClipPlan(
        clipId: clip.clipId,
        sourceStart: clip.sourceStart,
        sourceEnd: clip.sourceEnd,
        keyframes: smoothed,
      ),
    ];
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
    final seamInterval = (dtIn + dtOut) / 2;
    final previousOpening = LoopPose.components(
      x: -outgoing.pose.tx * seamInterval / dtOut,
      y: -outgoing.pose.ty * seamInterval / dtOut,
      angle: -outgoing.pose.angle * seamInterval / dtOut,
      logScale: -math.log(outgoing.pose.scale) * seamInterval / dtOut,
    );
    final endpoint = join.inverse().then(previousOpening);
    final vin = [
      incoming.pose.tx / dtIn,
      incoming.pose.ty / dtIn,
      incoming.pose.angle / dtIn,
      math.log(incoming.pose.scale) / dtIn,
    ];
    final vout = [
      outgoing.pose.tx / dtOut,
      outgoing.pose.ty / dtOut,
      outgoing.pose.angle / dtOut,
      math.log(outgoing.pose.scale) / dtOut,
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
        (i) => h * end[i] + hd * (vout[i] - vin[i]) * length,
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
