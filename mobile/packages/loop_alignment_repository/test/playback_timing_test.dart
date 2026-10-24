import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

LoopFrame signal(int value, int ms) => LoopFrame(
  time: Duration(milliseconds: ms),
  width: 64,
  height: 1,
  luma: Uint8List.fromList(
    List.generate(64, (i) => 128 + (i.isEven ? value : -value)),
  ),
);
void main() {
  test(
    'same displayed timing has identical motion despite different source speed',
    () {
      const scorer = LoopSeamScorer();
      final end = [signal(-2, 0), signal(-1, 40)];
      final ordinary = scorer.score(
        [signal(0, 0), signal(1, 40)],
        end,
        seamInterval: const Duration(milliseconds: 40),
      );
      final doubleSpeed = scorer.score(
        [signal(0, 0), signal(1, 80)],
        end,
        startSpeed: 2,
        seamInterval: const Duration(milliseconds: 40),
      );
      expect(ordinary.motion, 0);
      expect(doubleSpeed.motion, ordinary.motion);
      final bad = scorer.score(
        [signal(0, 0), signal(1, 80)],
        end,
        startSpeed: 1,
        seamInterval: const Duration(milliseconds: 40),
      );
      expect(bad.motion, greaterThan(ordinary.motion));
      expect(
        const LoopAlignmentLimits().acceptsScores(
          const LoopSeamScores(difference: .04, motion: 0),
          LoopSeamScores(difference: .02, motion: bad.motion),
        ),
        isFalse,
      );
    },
  );
  test(
    'seam motion uses actual held duration rather than neighboring mean',
    () {
      final start = [signal(0, 0), signal(4, 40)],
          end = [signal(-5, 0), signal(-1, 40)];
      expect(
        const LoopSeamScorer()
            .score(start, end, seamInterval: const Duration(milliseconds: 10))
            .motion,
        0,
      );
      expect(
        const LoopSeamScorer()
            .score(start, end, seamInterval: const Duration(milliseconds: 40))
            .motion,
        greaterThan(0),
      );
      expect(
        () => const LoopSeamScorer().score(
          start,
          end,
          seamInterval: Duration.zero,
        ),
        throwsArgumentError,
      );
    },
  );
  test('ordinary motion uses the same resampled grid as displayed score', () {
    final highResolution = [
      for (var t = 0; t < 5; t++)
        LoopFrame(
          time: Duration(milliseconds: t * 40),
          width: 320,
          height: 192,
          luma: Uint8List.fromList(
            List.generate(
              320 * 192,
              (i) => (i * 37 + t * t * (i.isEven ? 2 : -2)) % 256,
            ),
          ),
        ),
    ];
    final grid = highResolution
        .map((f) => const LoopFrameResampler().warp(f, LoopPose.identity, 1))
        .toList();
    final original = const LoopSeamScorer().motionReference(
      highResolution,
      highResolution,
    );
    final resampled = const LoopSeamScorer().motionReference(grid, grid);
    expect(original.samples, resampled.samples);
    expect(original.p95, resampled.p95);
  });
}
