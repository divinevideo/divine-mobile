import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

import 'helpers/generated_scene.dart';

void main() {
  for (final speeds in [(1.0, 1.0), (2.0, .5)]) {
    final (firstSpeed, lastSpeed) = speeds;
    for (final tail in [10, 40, 100]) {
      test(
        'montage preserves velocity over actual ${tail}ms final presentation interval at $speeds',
        () {
          final start = <LoopFrame>[],
              end = <LoopFrame>[],
              poses = <LoopFrame, LoopPose>{};
          for (var i = 0; i <= 50; i++) {
            final p = LoopPose.components(x: .04 * i),
                q = LoopPose.components(x: 1 + .02 * i);
            final f = scene(
                  width: 160,
                  height: 96,
                  time: Duration(milliseconds: (40 * i * firstSpeed).round()),
                  pose: p,
                ),
                g = scene(
                  width: 160,
                  height: 96,
                  time: Duration(milliseconds: (40 * i * lastSpeed).round()),
                  pose: q,
                );
            start.add(f);
            end.add(g);
            poses[f] = p;
            poses[g] = q;
          }
          final plan = const LoopAlignmentPlanner().plan(
            input: LoopRepairInput(
              clips: [
                clip(
                  'a',
                  speed: firstSpeed,
                  end: Duration(milliseconds: (2040 * firstSpeed).round()),
                ),
                clip(
                  'b',
                  speed: lastSpeed,
                  end: Duration(
                    milliseconds: ((2000 + tail) * lastSpeed).round(),
                  ),
                ),
              ],
              revision: 'x',
            ),
            firstFrames: start,
            lastFrames: end,
            matcher: SceneMatcher(poses),
            limits: const LoopAlignmentLimits(),
          );
          expect(plan, isNotNull);
          final last = poses[end.last]!.then(
            plan!.clips.last.correctionAt(end.last.time),
          );
          expect(-last.tx / (tail / 1000), closeTo(1, 1e-9));
        },
      );
    }
  }
}
