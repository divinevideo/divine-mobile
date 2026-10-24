import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

import 'helpers/generated_scene.dart';

void main() {
  const limits = LoopAlignmentLimits();
  for (final size in [(160, 96), (96, 160)]) {
    final (w, h) = size;
    group('$w x $h', () {
      test('confidence boundaries and geometry are enforced', () {
        expect(limits.acceptsMatch(evidence(LoopPose.identity), w, h), isTrue);
        final failures = [
          evidence(LoopPose.identity, boundaryModelError: .50001),
          evidence(LoopPose.identity, consistent: 19),
          evidence(LoopPose.identity, retained: 34),
          evidence(LoopPose.identity, cells: 3),
          evidence(LoopPose.identity, width: .3499),
          evidence(LoopPose.identity, height: .3499),
          evidence(LoopPose.identity, withheld: 4),
          evidence(LoopPose.identity, error: 1.0001),
          evidence(LoopPose.identity, left: 3),
          evidence(LoopPose.identity, boundaryRetained: 7),
          evidence(LoopPose.identity, left: 0, right: 4, top: 4, bottom: 0),
          evidence(LoopPose.components(x: w * .03001)),
          evidence(LoopPose.components(y: h * .03001)),
          evidence(LoopPose.components(angle: 2.001 * math.pi / 180)),
          evidence(LoopPose.components(logScale: math.log(1.03001))),
          evidence(LoopPose.components(logScale: math.log(.96999))),
        ];
        for (final match in failures) {
          expect(limits.acceptsMatch(match, w, h), isFalse);
        }
        expect(
          limits.acceptsMatch(
            evidence(LoopPose.identity, consistent: 21, retained: 35),
            w,
            h,
          ),
          isTrue,
        );
        expect(
          limits.acceptsMatch(
            evidence(LoopPose.identity, left: 0, right: 0, top: 4, bottom: 4),
            w,
            h,
          ),
          isTrue,
        );
      });
      test(
        'known translated scene closes with measured displayed improvement',
        () {
          final frames = <LoopFrame>[], poses = <LoopFrame, LoopPose>{};
          for (var i = 0; i <= 50; i++) {
            final pose = LoopPose.components(x: 2.4 * i / 50);
            final frame = scene(
              width: w,
              height: h,
              time: Duration(milliseconds: i * 40),
              pose: pose,
            );
            frames.add(frame);
            poses[frame] = pose;
          }
          final input = LoopRepairInput(
            clips: [clip('one', width: w, height: h)],
            revision: 'one',
          );
          final plan = const LoopAlignmentPlanner().plan(
            input: input,
            firstFrames: frames,
            lastFrames: frames,
            matcher: SceneMatcher(poses),
            limits: limits,
          );
          expect(plan, isNotNull);
          final a = poses[frames.first]!.then(
            plan!.clips.single.correctionAt(frames.first.time),
          );
          final b = poses[frames.last]!.then(
            plan.clips.single.correctionAt(frames.last.time),
          );
          expect(
            a.inverse().then(b).maximumCornerDisplacement(w, h),
            lessThan(.5),
          );
          expect(plan.zoom, lessThanOrEqualTo(1.08));
          expect(plan.predictedScores.difference, lessThanOrEqualTo(.03));
          expect(
            const LoopAlignmentPlanner().plan(
              input: input,
              firstFrames: frames,
              lastFrames: frames,
              matcher: SceneMatcher(
                poses,
                unreliableTime: const Duration(milliseconds: 400),
              ),
              limits: limits,
            ),
            isNull,
          );
        },
      );
      test('identity gives no correction; uncertain scenes cannot be already smooth', () {
        final frames = [
          for (var i = 0; i < 6; i++)
            scene(
              width: w,
              height: h,
              time: Duration(milliseconds: 40 * i),
            ),
        ];
        final poses = {for (final f in frames) f: LoopPose.identity};
        expect(
          const LoopAlignmentPlanner().plan(
            input: LoopRepairInput(
              clips: [clip('one', width: w, height: h)],
              revision: 'one',
            ),
            firstFrames: frames,
            lastFrames: frames,
            matcher: SceneMatcher(poses),
            limits: limits,
          ),
          isNull,
        );
        expect(
          const LoopSeamScorer().alreadySmooth(
            registration: evidence(LoopPose.identity, consistent: 0),
            start: frames,
            end: frames,
          ),
          isFalse,
        );
      });
      test('coverage checks interior rotation and output transforms', () {
        final p = LoopClipPlan(
          clipId: 'one',
          sourceStart: Duration.zero,
          sourceEnd: const Duration(seconds: 1),
          keyframes: [
            const LoopKeyframe(
              sourceTime: Duration.zero,
              correction: LoopPose.identity,
            ),
            LoopKeyframe(
              sourceTime: const Duration(milliseconds: 500),
              correction: LoopPose.components(angle: .15),
            ),
            const LoopKeyframe(
              sourceTime: Duration(seconds: 1),
              correction: LoopPose.identity,
            ),
          ],
        );
        final zoom = const LoopAlignmentPlanner().requiredZoom(p, w, h, [
          const Duration(milliseconds: 499),
        ]);
        expect(zoom, greaterThan(1.08));
        for (var ms = 0; ms <= 1000; ms += 7) {
          final inverse = p.correctionAt(Duration(milliseconds: ms)).inverse();
          for (final x in [-w / 2, w / 2]) {
            for (final y in [-h / 2, h / 2]) {
              final point = inverse.transform(x / zoom, y / zoom);
              expect(point.x.abs(), lessThanOrEqualTo(w / 2 + 1e-6));
              expect(point.y.abs(), lessThanOrEqualTo(h / 2 + 1e-6));
            }
          }
        }
      });
    });
  }
  test('weighted difference includes available short-sequence pairs', () {
    LoopFrame solid(int value, int ms) => scene(
      width: 4,
      height: 4,
      time: Duration(milliseconds: ms),
      blank: true,
      exposure: value - 100.0,
    );
    expect(
      const LoopSeamScorer()
          .score(
            [solid(10, 0), solid(20, 40), solid(30, 80)],
            [solid(0, 0), solid(0, 40), solid(0, 80)],
          )
          .difference,
      closeTo((10 + 20 * .5 + 30 * .25) / 1.75 / 255, 1e-12),
    );
    expect(
      const LoopSeamScorer()
          .score([solid(10, 0), solid(20, 40)], [solid(0, 0), solid(0, 40)])
          .difference,
      closeTo(20 / 1.5 / 255, 1e-12),
    );
  });
}
