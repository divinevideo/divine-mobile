import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

void main() {
  test('similarity inverse and composition round-trip centered points', () {
    final pose = LoopPose(
      a: 1.02 * math.cos(.02),
      b: 1.02 * math.sin(.02),
      tx: 3,
      ty: -2,
    );
    final p = pose.then(pose.inverse()).transform(100, -70);
    expect(p.x, closeTo(100, 1e-9));
    expect(p.y, closeTo(-70, 1e-9));
  });
  test('scores identical frames and enforces exact acceptance boundaries', () {
    LoopFrame frame(int value, int time) => LoopFrame(
      time: Duration(milliseconds: time),
      width: 4,
      height: 4,
      luma: Uint8List(16)..fillRange(0, 16, value),
    );
    final frames = [frame(40, 0), frame(40, 40)];
    expect(const LoopSeamScorer().score(frames, frames).difference, 0);
    const limits = LoopAlignmentLimits();
    expect(
      limits.acceptsScores(
        const LoopSeamScores(difference: .04, motion: .1),
        const LoopSeamScores(difference: .03, motion: .1),
      ),
      isTrue,
    );
    expect(
      limits.acceptsScores(
        const LoopSeamScores(difference: .04, motion: .1),
        const LoopSeamScores(difference: .03001, motion: .1),
      ),
      isFalse,
    );
    expect(
      limits.acceptsScores(
        const LoopSeamScores(difference: .04, motion: .1),
        const LoopSeamScores(difference: .0304, motion: .1),
      ),
      isFalse,
    );
    expect(
      limits.acceptsScores(
        const LoopSeamScores(difference: .04, motion: .1),
        const LoopSeamScores(difference: .02, motion: .11),
      ),
      isFalse,
    );
    expect(
      () => const LoopSeamScorer().score([frame(0, 0)], frames),
      throwsArgumentError,
    );
  });
}
