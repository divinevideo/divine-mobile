import 'dart:math' as math;
import 'dart:typed_data';

/// Upright analysis pixels at an actual decoded source timestamp.
final class LoopFrame {
  LoopFrame({
    required this.time,
    required this.width,
    required this.height,
    required Uint8List luma,
  }) : luma = Uint8List.fromList(luma).asUnmodifiableView() {
    if (width <= 0 || height <= 0 || luma.length != width * height) {
      throw ArgumentError('Invalid luma dimensions');
    }
  }
  final Duration time;
  final int width, height;
  final Uint8List luma;
}

/// Maps reference-centered coordinates into target-centered coordinates.
final class LoopPose {
  const LoopPose({
    required this.a,
    required this.b,
    required this.tx,
    required this.ty,
  });
  static const identity = LoopPose(a: 1, b: 0, tx: 0, ty: 0);
  final double a, b, tx, ty;
  double get scale => math.sqrt(a * a + b * b);
  double get angle => math.atan2(b, a);
  bool get isFinite =>
      a.isFinite && b.isFinite && tx.isFinite && ty.isFinite && scale > 0;
  math.Point<double> transform(double x, double y) =>
      math.Point(a * x - b * y + tx, b * x + a * y + ty);
  LoopPose inverse() {
    final d = a * a + b * b;
    if (!isFinite) throw StateError('Singular pose');
    return LoopPose(
      a: a / d,
      b: -b / d,
      tx: -(a * tx + b * ty) / d,
      ty: (b * tx - a * ty) / d,
    );
  }

  LoopPose then(LoopPose next) => LoopPose(
    a: next.a * a - next.b * b,
    b: next.b * a + next.a * b,
    tx: next.a * tx - next.b * ty + next.tx,
    ty: next.b * tx + next.a * ty + next.ty,
  );
  static LoopPose components({
    double x = 0,
    double y = 0,
    double angle = 0,
    double logScale = 0,
  }) => LoopPose(
    a: math.exp(logScale) * math.cos(angle),
    b: math.exp(logScale) * math.sin(angle),
    tx: x,
    ty: y,
  );
  static LoopPose interpolate(LoopPose p, LoopPose q, double t) {
    final delta = math.atan2(
      math.sin(q.angle - p.angle),
      math.cos(q.angle - p.angle),
    );
    return components(
      x: p.tx + (q.tx - p.tx) * t,
      y: p.ty + (q.ty - p.ty) * t,
      angle: p.angle + delta * t,
      logScale: math.log(p.scale) + (math.log(q.scale) - math.log(p.scale)) * t,
    );
  }

  double maximumCornerDisplacement(int width, int height) {
    var result = 0.0;
    for (final x in [-width / 2, width / 2]) {
      for (final y in [-height / 2, height / 2]) {
        final p = transform(x, y);
        result = math.max(
          result,
          math.sqrt(math.pow(p.x - x, 2) + math.pow(p.y - y, 2)),
        );
      }
    }
    return result;
  }
}

final class LoopBoundarySupport {
  const LoopBoundarySupport({required this.agreeing, required this.retained});
  final int agreeing, retained;
}

final class LoopFrameMatch {
  const LoopFrameMatch({
    required this.pose,
    required this.consistentCount,
    required this.retainedCount,
    required this.occupiedCells,
    required this.widthSpan,
    required this.heightSpan,
    required this.withheldCount,
    required this.withheldMedianError,
    this.boundaryModelError = double.infinity,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });
  final LoopPose pose;
  final int consistentCount, retainedCount, occupiedCells, withheldCount;

  /// Fractions of image width and height, respectively.
  final double widthSpan, heightSpan, withheldMedianError;

  /// Maximum corner disagreement with the independent boundary-only fit.
  final double boundaryModelError;

  /// Boundary agreement is measured independently within one analysis pixel.
  final LoopBoundarySupport left, right, top, bottom;
}

abstract interface class LoopFrameMatcher {
  LoopFrameMatch? match(LoopFrame reference, LoopFrame target);
}

final class LoopAlignmentLimits {
  const LoopAlignmentLimits({
    this.minimumMatches = 20,
    this.minimumAgreement = .6,
    this.minimumCells = 4,
    this.minimumSpan = .35,
    this.minimumBoundaryMatches = 4,
    this.minimumWithheld = 5,
    this.maximumWithheldError = 1,
    this.maximumBoundaryModelError = .5,
    this.maximumDisplacement = .03,
    this.maximumRotationDegrees = 2,
    this.minimumScale = .97,
    this.maximumScale = 1.03,
    this.maximumZoom = 1.08,
    this.minimumImprovement = .25,
    this.maximumDifference = .03,
    this.maximumTrim = const Duration(milliseconds: 200),
    this.maximumAnchorGap = const Duration(milliseconds: 400),
  });
  final int minimumMatches,
      minimumCells,
      minimumBoundaryMatches,
      minimumWithheld;
  final double minimumAgreement,
      minimumSpan,
      maximumWithheldError,
      maximumBoundaryModelError,
      maximumDisplacement,
      maximumRotationDegrees,
      minimumScale,
      maximumScale,
      maximumZoom,
      minimumImprovement,
      maximumDifference;
  final Duration maximumTrim, maximumAnchorGap;
  bool acceptsMatch(LoopFrameMatch m, int width, int height) {
    bool boundary(LoopBoundarySupport s) =>
        s.agreeing >= minimumBoundaryMatches &&
        s.retained >= s.agreeing &&
        s.retained > 0 &&
        s.agreeing / s.retained >= minimumAgreement;
    final p = m.pose;
    return p.isFinite &&
        m.consistentCount >= minimumMatches &&
        m.retainedCount >= m.consistentCount &&
        m.retainedCount > 0 &&
        m.consistentCount / m.retainedCount >= minimumAgreement &&
        m.occupiedCells >= minimumCells &&
        m.occupiedCells <= 9 &&
        m.widthSpan.isFinite &&
        m.heightSpan.isFinite &&
        m.widthSpan >= minimumSpan &&
        m.heightSpan >= minimumSpan &&
        m.widthSpan <= 1 &&
        m.heightSpan <= 1 &&
        m.withheldCount >= minimumWithheld &&
        m.withheldMedianError.isFinite &&
        m.withheldMedianError >= 0 &&
        m.withheldMedianError <= maximumWithheldError &&
        m.boundaryModelError.isFinite &&
        m.boundaryModelError >= 0 &&
        m.boundaryModelError <= maximumBoundaryModelError &&
        ((boundary(m.left) && boundary(m.right)) ||
            (boundary(m.top) && boundary(m.bottom))) &&
        p.tx.abs() <= width * maximumDisplacement &&
        p.ty.abs() <= height * maximumDisplacement &&
        p.angle.abs() <= maximumRotationDegrees * math.pi / 180 &&
        p.scale >= minimumScale &&
        p.scale <= maximumScale;
  }

  bool acceptsScores(LoopSeamScores baseline, LoopSeamScores corrected) =>
      baseline.isFinite &&
      corrected.isFinite &&
      baseline.difference > 0 &&
      corrected.difference <= maximumDifference &&
      corrected.difference <=
          baseline.difference * (1 - minimumImprovement) + 1e-12 &&
      corrected.motion <= baseline.motion + 1e-12;
}

final class LoopClipInput {
  const LoopClipInput({
    required this.clipId,
    required this.path,
    required this.sourceStart,
    required this.sourceEnd,
    required this.speed,
    required this.width,
    required this.height,
    this.minimumDuration = const Duration(milliseconds: 100),
  });
  final String clipId, path;
  final Duration sourceStart, sourceEnd, minimumDuration;
  final double speed;
  final int width, height;
  Duration get visibleDuration => Duration(
    microseconds: ((sourceEnd - sourceStart).inMicroseconds / speed).round(),
  );
}

enum LoopRepairCapability { supported, unsupported }

final class LoopRepairInput {
  LoopRepairInput({
    required List<LoopClipInput> clips,
    required this.revision,
    this.capability = LoopRepairCapability.supported,
    this.minimumCompositionDuration = const Duration(milliseconds: 500),
  }) : clips = List.unmodifiable(clips);
  final List<LoopClipInput> clips;
  final String revision;
  final LoopRepairCapability capability;
  final Duration minimumCompositionDuration;
}

final class LoopKeyframe {
  const LoopKeyframe({required this.sourceTime, required this.correction});
  final Duration sourceTime;
  final LoopPose correction;
}

final class LoopClipPlan {
  LoopClipPlan({
    required this.clipId,
    required this.sourceStart,
    required this.sourceEnd,
    required List<LoopKeyframe> keyframes,
  }) : keyframes = List.unmodifiable(keyframes);
  final String clipId;
  final Duration sourceStart, sourceEnd;
  final List<LoopKeyframe> keyframes;
  LoopPose correctionAt(Duration time) {
    if (keyframes.isEmpty) return LoopPose.identity;
    if (time <= keyframes.first.sourceTime) return keyframes.first.correction;
    for (var i = 1; i < keyframes.length; i++) {
      final right = keyframes[i];
      final left = keyframes[i - 1];
      if (time <= right.sourceTime)
        return LoopPose.interpolate(
          left.correction,
          right.correction,
          (time - left.sourceTime).inMicroseconds /
              (right.sourceTime - left.sourceTime).inMicroseconds,
        );
    }
    return keyframes.last.correction;
  }
}

final class LoopSeamScores {
  const LoopSeamScores({required this.difference, required this.motion});
  final double difference, motion;
  bool get isFinite =>
      difference.isFinite && motion.isFinite && difference >= 0 && motion >= 0;
}

final class LoopAlignmentPlan {
  LoopAlignmentPlan({
    required List<LoopClipPlan> clips,
    required this.zoom,
    required this.confidence,
    required this.predictedScores,
    required this.baselineScores,
    this.trimmedSourceEnd,
  }) : clips = List.unmodifiable(clips);
  final List<LoopClipPlan> clips;
  final double zoom;
  final LoopFrameMatch confidence;
  final LoopSeamScores predictedScores;

  /// Uncorrected footage scored with this candidate's common coverage crop.
  final LoopSeamScores baselineScores;
  final Duration? trimmedSourceEnd;
}

final class LoopAnalysis {
  LoopAnalysis({
    required this.baselineScores,
    required List<LoopAlignmentPlan> candidates,
    this.endpointRegistration,
    this.endpointWidth = 0,
    this.endpointHeight = 0,
    this.ordinaryMotionP95 = 0,
    this.ordinaryMotionSamples = 0,
    List<Duration> eligibleTrimEnds = const [],
  }) : eligibleTrimEnds = List.unmodifiable(eligibleTrimEnds),
       candidates = List.unmodifiable(candidates);
  final LoopSeamScores baselineScores;
  final List<LoopAlignmentPlan> candidates;
  final List<Duration> eligibleTrimEnds;

  final LoopFrameMatch? endpointRegistration;
  final int endpointWidth, endpointHeight, ordinaryMotionSamples;
  final double ordinaryMotionP95;
  bool isAlreadySmooth(LoopAlignmentLimits limits) {
    final match = endpointRegistration;
    return match != null &&
        endpointWidth > 0 &&
        endpointHeight > 0 &&
        limits.acceptsMatch(match, endpointWidth, endpointHeight) &&
        match.pose.maximumCornerDisplacement(endpointWidth, endpointHeight) <=
            .5 &&
        baselineScores.isFinite &&
        baselineScores.difference <= limits.maximumDifference &&
        ordinaryMotionSamples >= 4 &&
        ordinaryMotionP95.isFinite &&
        ordinaryMotionP95 >= 0 &&
        baselineScores.motion <= ordinaryMotionP95 + 1e-12;
  }

  bool get alreadySmooth => isAlreadySmooth(const LoopAlignmentLimits());
}

final class LoopMediaMetadata {
  LoopMediaMetadata({
    required this.videoDuration,
    required this.audioDuration,
    required List<Duration> frameTimes,
    required this.width,
    required this.height,
  }) : frameTimes = List.unmodifiable(frameTimes);
  final Duration videoDuration;
  final Duration? audioDuration;
  final List<Duration> frameTimes;
  final int width, height;
}

final class LoopRenderedOutput {
  LoopRenderedOutput({
    required Map<String, String> paths,
    required Map<String, LoopMediaMetadata> metadata,
  }) : paths = Map.unmodifiable(paths),
       metadata = Map.unmodifiable(metadata);
  final Map<String, String> paths;
  final Map<String, LoopMediaMetadata> metadata;
}

final class LoopInspection {
  LoopInspection({
    required this.scores,
    required List<Duration> frameTimes,
    required this.audioDuration,
    required this.videoDuration,
    required this.covered,
    Map<String, LoopMediaMetadata> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata),
       frameTimes = List.unmodifiable(frameTimes);
  final LoopSeamScores scores;
  final List<Duration> frameTimes;
  final Duration videoDuration;
  final Duration? audioDuration;
  final bool covered;
  final Map<String, LoopMediaMetadata> metadata;
}

enum LoopRepairStatus { repaired, alreadySmooth, noMatch, unsupported }

final class LoopRepairResult {
  const LoopRepairResult({required this.status, this.output, this.plan});
  final LoopRepairStatus status;
  final LoopRenderedOutput? output;
  final LoopAlignmentPlan? plan;
}

sealed class LoopAlignmentException implements Exception {
  const LoopAlignmentException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

final class LoopAlignmentCancelled extends LoopAlignmentException {
  const LoopAlignmentCancelled() : super('Loop repair cancelled');
}

final class LoopAlignmentFailure extends LoopAlignmentException {
  const LoopAlignmentFailure(super.message);
}

final class LoopAlignmentTimeout extends LoopAlignmentException {
  const LoopAlignmentTimeout() : super('Loop repair timed out');
}
