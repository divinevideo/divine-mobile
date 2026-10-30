import 'dart:math' as math;
import 'dart:typed_data';

import 'package:loop_alignment_repository/loop_alignment_repository.dart';

LoopFrame scene({
  required int width,
  required int height,
  required Duration time,
  LoopPose pose = LoopPose.identity,
  double exposure = 0,
  bool blank = false,
}) {
  final inv = pose.inverse(), bytes = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = inv.transform(x - width / 2.0, y - height / 2.0);
      final value = blank
          ? 100.0
          : 125 +
                35 * math.sin(p.x * .31) +
                30 * math.sin(p.y * .37) +
                24 * math.sin(p.x * .17 + p.y * .23) +
                20 * math.cos(p.x * .09 - p.y * .47);
      bytes[y * width + x] = (value + exposure).round().clamp(0, 255);
    }
  }
  return LoopFrame(time: time, width: width, height: height, luma: bytes);
}

LoopFrameMatch evidence(
  LoopPose pose, {
  int consistent = 20,
  int retained = 33,
  int cells = 4,
  double width = .35,
  double height = .35,
  int withheld = 5,
  double error = 1,
  int left = 4,
  int right = 4,
  int top = 0,
  int bottom = 0,
  double boundaryModelError = 0,
  int boundaryRetained = 6,
}) => LoopFrameMatch(
  pose: pose,
  boundaryModelError: boundaryModelError,
  consistentCount: consistent,
  retainedCount: retained,
  occupiedCells: cells,
  widthSpan: width,
  heightSpan: height,
  withheldCount: withheld,
  withheldMedianError: error,
  left: LoopBoundarySupport(agreeing: left, retained: boundaryRetained),
  right: LoopBoundarySupport(agreeing: right, retained: boundaryRetained),
  top: LoopBoundarySupport(agreeing: top, retained: boundaryRetained),
  bottom: LoopBoundarySupport(agreeing: bottom, retained: boundaryRetained),
);

class SceneMatcher implements LoopFrameMatcher {
  SceneMatcher(this.poses, {this.unreliableTime, this.refusedTime});
  final Map<LoopFrame, LoopPose> poses;
  final Duration? unreliableTime;

  /// The match at this time exists but carries no boundary support.
  final Duration? refusedTime;
  @override
  LoopFrameMatch? match(LoopFrame reference, LoopFrame target) {
    if (target.time == unreliableTime) return null;
    final pose = poses[reference]!.inverse().then(poses[target]!);
    return target.time == refusedTime
        ? evidence(pose, left: 0, right: 0)
        : evidence(pose);
  }
}

LoopClipInput clip(
  String id, {
  int width = 160,
  int height = 96,
  Duration start = Duration.zero,
  Duration end = const Duration(milliseconds: 2040),
  double speed = 1,
}) => LoopClipInput(
  clipId: id,
  path: '/synthetic/$id.mp4',
  sourceStart: start,
  sourceEnd: end,
  speed: speed,
  width: width,
  height: height,
);
