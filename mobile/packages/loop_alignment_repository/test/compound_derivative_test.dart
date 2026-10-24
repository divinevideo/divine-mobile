import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

import 'helpers/generated_scene.dart';

void main() {
  group('planLoopAlignment', () {
    test('compound Hermite derivative composes translation rotation and scale', () {
      final first = <LoopFrame>[],
          last = <LoopFrame>[],
          poses = <LoopFrame, LoopPose>{};
      for (var i = 0; i <= 200; i++) {
        final u = i / 200;
        final p = LoopPose.components(
          x: .8 * u,
          y: .3 * u,
          angle: .01 * u,
          logScale: .01 * u,
        );
        final q = LoopPose.components(
          x: 1 + .4 * u,
          y: .4 * u,
          angle: .02 + .005 * u,
          logScale: .01 + .005 * u,
        );
        final f = scene(
              width: 160,
              height: 96,
              time: Duration(milliseconds: 10 * i),
              pose: p,
            ),
            g = scene(
              width: 160,
              height: 96,
              time: Duration(milliseconds: 10 * i),
              pose: q,
            );
        first.add(f);
        last.add(g);
        poses[f] = p;
        poses[g] = q;
      }
      final plan = const LoopAlignmentPlanner().plan(
        input: LoopRepairInput(
          clips: [
            clip('a', end: const Duration(milliseconds: 2010)),
            clip('b', end: const Duration(milliseconds: 2010)),
          ],
          revision: 'compound',
        ),
        firstFrames: first,
        lastFrames: last,
        matcher: SceneMatcher(poses),
        limits: const LoopAlignmentLimits(),
      );
      expect(plan, isNotNull);
      final keys = plan!.clips.last.keyframes;
      // Hermite component polynomials are cubic; four-point backward derivative
      // recovers their exact limiting endpoint slope, eliminating finite-step bias.
      double derivative(double Function(LoopPose) get) {
        final n = keys.length;
        return (11 * get(keys[n - 1].correction) -
                18 * get(keys[n - 2].correction) +
                9 * get(keys[n - 3].correction) -
                2 * get(keys[n - 4].correction)) /
            (6 * .01);
      }

      final c = keys.last.correction,
          q = poses[last.last]!,
          display = q.then(c);
      final rotationRate = derivative((p) => p.angle),
          scaleRate = derivative((p) => math.log(p.scale));
      final da = scaleRate * c.a - rotationRate * c.b,
          db = rotationRate * c.a + scaleRate * c.b;
      for (final point in [(0.0, 0.0), (80.0, 48.0)]) {
        final (x, y) = point;
        final source = q.transform(x, y);
        // The synthetic final camera has linear tx/ty, angle and log-scale paths.
        final sourceDx =
            .0025 * (q.a * x - q.b * y) - .0025 * (q.b * x + q.a * y) + .2;
        final sourceDy =
            .0025 * (q.b * x + q.a * y) + .0025 * (q.a * x - q.b * y) + .2;
        final dx =
            da * source.x -
            db * source.y +
            c.a * sourceDx -
            c.b * sourceDy +
            derivative((p) => p.tx);
        final dy =
            db * source.x +
            da * source.y +
            c.b * sourceDx +
            c.a * sourceDy +
            derivative((p) => p.ty);
        final shown = display.transform(x, y);
        final expectedX = .005 * shown.x - .005 * shown.y + .4;
        final expectedY = .005 * shown.x + .005 * shown.y + .15;
        expect(dx, closeTo(expectedX, .0001));
        expect(dy, closeTo(expectedY, .0001));
      }
    });
  });
}
