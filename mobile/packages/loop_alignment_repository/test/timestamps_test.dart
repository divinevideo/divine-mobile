import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

import 'helpers/generated_scene.dart';

class RecordingMatcher extends SceneMatcher {
  RecordingMatcher(super.poses);
  final targets = <Duration>[];
  @override
  LoopFrameMatch? match(LoopFrame reference, LoopFrame target) {
    targets.add(target.time);
    return super.match(reference, target);
  }
}

void main() {
  group('LoopAlignmentLimits and source timestamps', () {
    test('anchor spacing uses visible time for slowed uniform playback', () {
      final frames = <LoopFrame>[], poses = <LoopFrame, LoopPose>{};
      for (var i = 0; i <= 10; i++) {
        final p = LoopPose.components(x: 2 * i / 10);
        final f = scene(
          width: 160,
          height: 96,
          time: Duration(milliseconds: 100 * i),
          pose: p,
        );
        frames.add(f);
        poses[f] = p;
      }
      final matcher = RecordingMatcher(poses);
      const LoopAlignmentPlanner().plan(
        input: LoopRepairInput(
          clips: [
            clip('one', speed: .5, end: const Duration(milliseconds: 1100)),
          ],
          revision: 'slow',
        ),
        firstFrames: frames,
        lastFrames: frames,
        matcher: matcher,
        limits: const LoopAlignmentLimits(),
      );
      final targets = matcher.targets.toSet().toList()..sort();
      expect(targets.first, Duration.zero);
      expect(targets.last, const Duration(seconds: 1));
      for (var i = 1; i < targets.length; i++) {
        expect(
          (targets[i] - targets[i - 1]).inMilliseconds / .5,
          lessThanOrEqualTo(400),
        );
      }
    });
    test(
      'already-smooth requires four ordinary motion acceleration samples',
      () {
        final frames = [
          for (var i = 0; i < 6; i++)
            scene(width: 160, height: 96, time: Duration(milliseconds: i * 40)),
        ];
        expect(
          const LoopSeamScorer().alreadySmooth(
            registration: evidence(LoopPose.identity),
            start: frames,
            end: frames,
            seamInterval: const Duration(milliseconds: 40),
          ),
          isTrue,
        );
        expect(
          const LoopSeamScorer().alreadySmooth(
            registration: evidence(LoopPose.identity),
            start: frames.take(3).toList(),
            end: frames.take(3).toList(),
            seamInterval: const Duration(milliseconds: 40),
          ),
          isFalse,
        );
      },
    );
  });
}
