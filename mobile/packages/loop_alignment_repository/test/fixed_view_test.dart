import 'dart:math' as math;

import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:test/test.dart';

import 'helpers/generated_scene.dart';

void main() {
  group('LoopAlignmentPlanner.plan', () {
    test('holds the background fixed throughout a translated clip', () {
      final fixture = _Fixture(
        times: [for (var ms = 0; ms <= 1600; ms += 40) ms],
        poseAt: (ms) => LoopPose.components(x: 2.4 * ms / 1600),
      );
      final plan = fixture.plan();
      expect(plan, isNotNull);
      final first = fixture.displayedAt(plan!, fixture.frames.first);
      for (final frame in fixture.frames) {
        final displayed = fixture.displayedAt(plan, frame);
        expect(displayed.tx, closeTo(first.tx, 1e-9), reason: '${frame.time}');
        expect(displayed.ty, closeTo(first.ty, 1e-9), reason: '${frame.time}');
      }
    });

    test(
      'chooses the least cropped trusted reference instead of the opening view',
      () {
        final fixture = _Fixture(
          times: [for (var ms = 0; ms <= 1600; ms += 40) ms],
          poseAt: (ms) => LoopPose.components(x: 2.4 * ms / 1600),
        );
        final plan = fixture.plan();
        expect(plan, isNotNull);
        // Trusted anchors translate by 0, .6, 1.2, 1.8 and 2.4 pixels.
        // The central reference needs at most 1.2 pixels per horizontal edge:
        // 80 / (80 - 1.2) = 1.015228426395939. Opening needs 80 / 77.6.
        expect(plan!.zoom, closeTo(1.015228426395939, 1e-12));
        expect(plan.zoom, lessThan(1.0309278350515465));
        for (final frame in fixture.frames) {
          expect(fixture.displayedAt(plan, frame).tx, closeTo(1.2, 1e-9));
        }
      },
    );

    for (final (laterAdvantage, expectedTarget, expectedZoom) in [
      (0.0, .96, 1.0183299389002036),
      (1e-11, 1.43999999999, 1.018329938900074),
    ]) {
      test(
        'selects the strict minimum crop with later advantage $laterAdvantage',
        () {
          final fixture = _Fixture(
            times: [for (var ms = 0; ms <= 2000; ms += 40) ms],
            poseAt: (ms) => LoopPose.components(
              x: 2.4 * ms / 2000 - (ms == 1200 ? laterAdvantage : 0),
            ),
          );
          final plan = fixture.plan();
          expect(plan, isNotNull);
          // Exact ties retain the earlier .96 target. With a later advantage,
          // 80 / (80 - 1.43999999999) is strictly smaller than 80 / (80 - 1.44).
          expect(plan!.zoom, closeTo(expectedZoom, 1e-15));
          for (final frame in fixture.frames) {
            expect(
              fixture.displayedAt(plan, frame).tx,
              closeTo(expectedTarget, 1e-9),
            );
          }
        },
      );
    }

    test(
      'accepts the lower crop when only the later reference meets the ceiling',
      () {
        final fixture = _Fixture(
          times: [for (var ms = 0; ms <= 2000; ms += 40) ms],
          poseAt: (ms) => LoopPose.components(
            x: 2.4 * ms / 2000 - (ms == 1200 ? 1e-11 : 0),
          ),
        );
        // Put the configured ceiling between the hand-derived costs above:
        // earlier reference 1.0183299389002036, later 1.018329938900074.
        const ceiling = 1.01832993890015;
        final plan = fixture.plan(
          limits: const LoopAlignmentLimits(maximumZoom: ceiling),
        );
        expect(plan, isNotNull);
        expect(plan!.zoom, closeTo(1.018329938900074, 1e-15));
        expect(plan.zoom, lessThanOrEqualTo(ceiling));
        expect(
          fixture.displayedAt(plan, fixture.frames.first).tx,
          closeTo(1.43999999999, 1e-9),
        );
      },
    );

    for (final (width, height) in [(160, 96), (96, 160)]) {
      test('$width x $height fixes mixed rotation and scale with covered corners', () {
        LoopPose poseAt(int ms) => LoopPose.components(
          x: 1.5 * ms / 1600,
          y: -.7 * ms / 1600,
          angle: .018 * ms / 1600,
          logScale: math.log(1.015) * ms / 1600,
        );
        final fixture = _Fixture(
          width: width,
          height: height,
          times: [for (var ms = 0; ms <= 1600; ms += 40) ms],
          poseAt: poseAt,
        );
        final plan = fixture.plan();
        expect(plan, isNotNull);
        final correction = plan!.clips.single;
        // Check real background points after camera motion AND correction,
        // including times between decoded samples and between trusted anchors.
        for (final point in [
          const math.Point(-30.0, -25.0),
          const math.Point(28.0, 22.0),
          const math.Point(0.0, 0.0),
        ]) {
          final first = correction
              .correctionAt(Duration.zero)
              .transform(point.x, point.y);
          for (var ms = 0; ms <= 1600; ms += 5) {
            final observed = poseAt(ms).transform(point.x, point.y);
            final displayed = correction
                .correctionAt(Duration(milliseconds: ms))
                .transform(observed.x, observed.y);
            expect(
              displayed.distanceTo(first) * plan.zoom,
              lessThan(.05),
              reason: 'background point $point at $ms ms',
            );
          }
        }
        // Independently project each output corner back into its source image.
        for (var ms = 0; ms <= 1600; ms++) {
          final inverse = correction
              .correctionAt(Duration(milliseconds: ms))
              .inverse();
          for (final x in [-width / 2, width / 2]) {
            for (final y in [-height / 2, height / 2]) {
              final source = inverse.transform(x / plan.zoom, y / plan.zoom);
              expect(source.x.abs(), lessThanOrEqualTo(width / 2 + 1e-9));
              expect(source.y.abs(), lessThanOrEqualTo(height / 2 + 1e-9));
            }
          }
        }
        expect(plan.zoom, lessThanOrEqualTo(1.08));
      });
    }

    for (final speed in [.5, 1.0, 2.0]) {
      test(
        'fixed framing follows irregular source timestamps at speed $speed',
        () {
          const visibleTimes = [
            0,
            55,
            150,
            200,
            330,
            390,
            400,
            530,
            600,
            720,
            780,
            800,
            930,
            1000,
            1130,
            1180,
            1200,
            1330,
            1400,
            1520,
            1580,
            1600,
          ];
          final fixture = _Fixture(
            times: [for (final ms in visibleTimes) 1000 + (ms * speed).round()],
            speed: speed,
            poseAt: (ms) =>
                LoopPose.components(x: 2.4 * (ms - 1000) / (1600 * speed)),
          );
          final plan = fixture.plan();
          expect(plan, isNotNull);
          final first = fixture.displayedAt(plan!, fixture.frames.first);
          for (final frame in fixture.frames) {
            expect(
              fixture.displayedAt(plan, frame).tx,
              closeTo(first.tx, 1e-9),
            );
          }
          expect(plan.clips.single.sourceStart, const Duration(seconds: 1));
          expect(
            plan.clips.single.sourceEnd,
            fixture.input.clips.single.sourceEnd,
          );
        },
      );
    }

    test(
      'rejects an unreliable interior anchor instead of selecting around it',
      () {
        final fixture = _Fixture(
          times: [for (var ms = 0; ms <= 1600; ms += 40) ms],
          poseAt: (ms) => LoopPose.components(x: 2.4 * ms / 1600),
        );
        expect(
          fixture.plan(unreliableTime: const Duration(milliseconds: 800)),
          isNull,
        );
      },
    );
  });
}

final class _Fixture {
  _Fixture({
    required List<int> times,
    required LoopPose Function(int) poseAt,
    int width = 160,
    int height = 96,
    double speed = 1,
  }) {
    for (final ms in times) {
      final pose = poseAt(ms);
      final frame = scene(
        width: width,
        height: height,
        time: Duration(milliseconds: ms),
        pose: pose,
      );
      frames.add(frame);
      poses[frame] = pose;
    }
    input = LoopRepairInput(
      clips: [
        clip(
          'fixed',
          width: width,
          height: height,
          start: frames.first.time,
          end:
              frames.last.time +
              Duration(microseconds: (40000 * speed).round()),
          speed: speed,
        ),
      ],
      revision: 'fixed-view',
    );
  }

  final frames = <LoopFrame>[];
  final poses = <LoopFrame, LoopPose>{};
  late final LoopRepairInput input;

  LoopAlignmentPlan? plan({
    Duration? unreliableTime,
    LoopAlignmentLimits limits = const LoopAlignmentLimits(),
  }) => const LoopAlignmentPlanner().plan(
    input: input,
    firstFrames: frames,
    lastFrames: frames,
    matcher: SceneMatcher(poses, unreliableTime: unreliableTime),
    limits: limits,
  );

  LoopPose displayedAt(LoopAlignmentPlan plan, LoopFrame frame) =>
      poses[frame]!.then(plan.clips.single.correctionAt(frame.time));
}
