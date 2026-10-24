import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

import 'helpers/generated_scene.dart';

void main() {
  group('planLoopAlignment', () {
    test(
      'final-shot Hermite preserves internal cut and normal seam progression',
      () {
        final start = <LoopFrame>[],
            end = <LoopFrame>[],
            poses = <LoopFrame, LoopPose>{};
        for (var i = 0; i <= 50; i++) {
          final p = LoopPose.components(x: .04 * i);
          final f = scene(
            width: 160,
            height: 96,
            time: Duration(milliseconds: i * 40),
            pose: p,
          );
          start.add(f);
          poses[f] = p;
          final q = LoopPose.components(x: 1 + .02 * i);
          final g = scene(
            width: 160,
            height: 96,
            time: Duration(milliseconds: i * 40),
            pose: q,
          );
          end.add(g);
          poses[g] = q;
        }
        final plan = const LoopAlignmentPlanner().plan(
          input: LoopRepairInput(
            clips: [clip('first'), clip('last')],
            revision: 'revision',
          ),
          firstFrames: start,
          lastFrames: end,
          matcher: SceneMatcher(poses),
          limits: const LoopAlignmentLimits(),
        );
        expect(plan, isNotNull);
        final last = plan!.clips.last;
        expect(last.sourceStart, Duration.zero);
        expect(last.sourceEnd, const Duration(milliseconds: 2040));
        expect(
          last.keyframes.first.correction.maximumCornerDisplacement(160, 96),
          0,
        );
        expect(
          plan.clips.first.keyframes.every(
            (k) => k.correction.maximumCornerDisplacement(160, 96) == 0,
          ),
          isTrue,
        );
        final before = poses[end[end.length - 2]]!.then(
          last.correctionAt(end[end.length - 2].time),
        );
        final finalPose = poses[end.last]!.then(
          last.correctionAt(end.last.time),
        );
        final opening = poses[start.first]!;
        expect(finalPose.tx - before.tx, closeTo(.04, .01));
        expect(opening.tx - finalPose.tx, closeTo(.04, .01));
      },
    );
  });
}
