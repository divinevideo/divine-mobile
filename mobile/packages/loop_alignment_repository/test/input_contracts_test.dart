import 'dart:typed_data';

import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:test/test.dart';

import 'helpers/generated_scene.dart';

LoopFrame frame(int milliseconds, {int width = 64, int height = 32}) =>
    LoopFrame(
      time: Duration(milliseconds: milliseconds),
      width: width,
      height: height,
      luma: Uint8List(width * height),
    );

void main() {
  group('Loop alignment input contracts', () {
    test('malformed raw luma cannot enter registration', () {
      expect(
        () => LoopFrame(
          time: Duration.zero,
          width: 2,
          height: 2,
          luma: Uint8List(3),
        ),
        throwsArgumentError,
      );
    });
    test('source window duration is expressed at displayed uniform speed', () {
      final input = clip(
        'speed',
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 5),
        speed: 2,
      );
      expect(input.visibleDuration, const Duration(milliseconds: 1500));
    });
    test('a finite correction holds after its last sampled timestamp', () {
      const endpoint = LoopPose(a: 1, b: 0, tx: 2, ty: -1);
      final plan = LoopClipPlan(
        clipId: 'a',
        sourceStart: Duration.zero,
        sourceEnd: const Duration(seconds: 2),
        keyframes: const [
          LoopKeyframe(
            sourceTime: Duration.zero,
            correction: LoopPose.identity,
          ),
          LoopKeyframe(sourceTime: Duration(seconds: 1), correction: endpoint),
        ],
      );
      expect(
        plan.correctionAt(const Duration(milliseconds: 1500)),
        same(endpoint),
      );
    });
    test('default already-smooth policy requires measured confidence', () {
      final smooth = LoopAnalysis(
        baselineScores: const LoopSeamScores(difference: 0, motion: 0),
        candidates: [],
        endpointRegistration: evidence(LoopPose.identity),
        endpointWidth: 320,
        endpointHeight: 180,
        ordinaryMotionSamples: 4,
      );
      expect(smooth.alreadySmooth, isTrue);
      expect(
        LoopAnalysis(
          baselineScores: smooth.baselineScores,
          candidates: [],
        ).alreadySmooth,
        isFalse,
      );
    });
    test('timeout diagnostics retain the distinct retryable failure type', () {
      const timeout = LoopAlignmentTimeout();
      expect(timeout, isA<LoopAlignmentException>());
      expect(timeout.toString(), 'LoopAlignmentTimeout: Loop repair timed out');
    });
    test(
      'resampling rejects invalid geometry rather than producing pixels',
      () {
        expect(
          () =>
              const LoopFrameResampler().warp(frame(0), LoopPose.identity, .9),
          throwsArgumentError,
        );
      },
    );
    test('join scoring rejects aspect changes and repeated timestamps', () {
      const scorer = LoopSeamScorer();
      expect(
        () => scorer.score(
          [frame(0), frame(40)],
          [frame(0, width: 32, height: 64), frame(40, width: 32, height: 64)],
          seamInterval: const Duration(milliseconds: 40),
        ),
        throwsArgumentError,
      );
      expect(
        () => scorer.score(
          [frame(0), frame(0)],
          [frame(0), frame(40)],
          seamInterval: const Duration(milliseconds: 40),
        ),
        throwsArgumentError,
      );
    });
    test(
      'ordinary motion needs neighbors and strictly increasing interior PTS',
      () {
        const scorer = LoopSeamScorer();
        expect(
          () => scorer.motionReference([frame(0)], [frame(0), frame(40)]),
          throwsArgumentError,
        );
        // Endpoint deltas alone are positive; the interior regression must also fail.
        expect(
          () => scorer.motionReference(
            [frame(0), frame(40), frame(20)],
            [frame(0), frame(40)],
          ),
          throwsArgumentError,
        );
      },
    );
    test('ordinary acceleration rejects incompatible luma grids', () {
      expect(
        () => const LoopSeamScorer().motionReference(
          [frame(0), frame(40, width: 64, height: 48), frame(80)],
          [frame(0), frame(40)],
        ),
        throwsArgumentError,
      );
    });
  });
}
