import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/services/video_editor/pve_loop_frame_matcher.dart';

// Continuous synthetic scene: expectations are known camera translations,
// independent of the estimator or its resampler.
LoopFrame _frame(
  int width,
  int height, {
  double dx = 0,
  double dy = 0,
  double angle = 0,
  double scale = 1,
  bool blank = false,
  bool plainMargins = false,
  Duration time = Duration.zero,
  double foreground = 0,
}) {
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final cx = x - width / 2 - dx;
      final cy = y - height / 2 - dy;
      final sx =
          (math.cos(angle) * cx + math.sin(angle) * cy) / scale + width / 2;
      final sy =
          (-math.sin(angle) * cx + math.cos(angle) * cy) / scale + height / 2;
      var value = blank
          ? 100.0
          : 100 +
                26 * math.sin(sx * .43 + sy * .11) +
                23 * math.cos(sy * .37 - sx * .09) +
                21 * math.sin(sx * .17 + sy * .23) +
                17 * math.cos(sx * .61 - sy * .41);
      if (plainMargins && (sx < width * .1 || sy < height * .1)) {
        value = 100;
      }
      if (foreground != 0 &&
          x > width * .1 &&
          x < width * .9 &&
          y > height * .1 &&
          y < height * .9) {
        value =
            160 +
            40 *
                math.sin((x - foreground) * .7) *
                math.cos((y + foreground) * .6);
      }
      pixels[y * width + x] = value.round().clamp(0, 255);
    }
  }
  return LoopFrame(
    time: time,
    width: width,
    height: height,
    luma: pixels,
  );
}

LoopFrame _repeatedFrame(int width, int height, double shift) => LoopFrame(
  time: Duration.zero,
  width: width,
  height: height,
  luma: Uint8List.fromList([
    for (var y = 0; y < height; y++)
      for (var x = 0; x < width; x++)
        (128 +
                60 *
                    math.cos((x - shift) * math.pi / 8) *
                    math.cos(y * math.pi / 8))
            .round(),
  ]),
);

void main() {
  group('PVE loop frame matching', () {
    for (final size in [(320, 180), (180, 320)]) {
      for (final shift in [0.0, 1.0, 16.0, 17.0]) {
        test('repeated texture is ambiguous at shift $shift for $size', () {
          final match = PveLoopFrameMatcher().match(
            _repeatedFrame(size.$1, size.$2, 0),
            _repeatedFrame(size.$1, size.$2, shift),
          );
          expect(match, isNull);
        });
      }
    }
    for (final size in [(320, 180), (180, 320)]) {
      test('public PVE adapter recovers subpixel camera shift for $size', () {
        final match = PveLoopFrameMatcher().match(
          _frame(size.$1, size.$2),
          _frame(size.$1, size.$2, dx: 2, dy: -1),
        );
        expect(match, isNotNull);
        expect(match!.pose.tx, closeTo(2, .3));
        expect(match.pose.ty, closeTo(-1, .3));
        expect(
          const LoopAlignmentLimits().acceptsMatch(match, size.$1, size.$2),
          isTrue,
        );
      });
    }
    for (final (width, height) in [(180, 320), (320, 180)]) {
      test('repairs gentle drift with plain margins at $width x $height', () {
        // A wall at the top and left has no corners. Reliable background
        // texture starts just inside the trackable edge region. Eroding that
        // region by the tracker border used to discard every repair candidate.
        final frames = [
          for (var i = 0; i < 90; i++)
            _frame(
              width,
              height,
              dx: 2 * i / 89,
              time: Duration(microseconds: i * 33333),
              plainMargins: true,
            ),
        ];
        final plan = const LoopAlignmentPlanner().plan(
          input: LoopRepairInput(
            clips: [
              LoopClipInput(
                clipId: 'drifting-camera',
                path: '/synthetic.mp4',
                sourceStart: Duration.zero,
                sourceEnd: const Duration(microseconds: 90 * 33333),
                speed: 1,
                width: width,
                height: height,
              ),
            ],
            revision: 'synthetic-drift',
          ),
          firstFrames: frames,
          lastFrames: frames,
          matcher: PveLoopFrameMatcher(),
          limits: const LoopAlignmentLimits(),
        );
        expect(plan, isNotNull);
        expect(plan!.zoom, inInclusiveRange(1, 1.08));
        final opening = const LoopFrameResampler().warp(
          frames.first,
          plan.clips.single.correctionAt(frames.first.time),
          plan.zoom,
          longestEdge: 320,
        );
        final ending = const LoopFrameResampler().warp(
          frames.last,
          plan.clips.single.correctionAt(frames.last.time),
          plan.zoom,
          longestEdge: 320,
        );
        final seam = PveLoopFrameMatcher().match(opening, ending);
        expect(seam, isNotNull);
        expect(
          seam!.pose.maximumCornerDisplacement(width, height),
          lessThan(.5),
        );
      });
    }
    for (final (width, height) in [(180, 320), (320, 180)]) {
      test('small subject motion is not camera drift at $width x $height', () {
        final match = PveLoopFrameMatcher().match(
          _frame(width, height, plainMargins: true, foreground: 1),
          _frame(width, height, plainMargins: true, foreground: 1.5),
        );
        expect(
          match != null &&
              const LoopAlignmentLimits().acceptsMatch(match, width, height),
          isFalse,
        );
      });
    }
    test('large camera movement remains outside drift correction', () {
      final match = PveLoopFrameMatcher().match(
        _frame(180, 320, plainMargins: true),
        _frame(180, 320, dx: 12, plainMargins: true),
      );
      expect(
        match != null &&
            const LoopAlignmentLimits().acceptsMatch(match, 180, 320),
        isFalse,
      );
    });
    test('moving foreground beside plain margins is not camera drift', () {
      final match = PveLoopFrameMatcher().match(
        _frame(180, 320, plainMargins: true, foreground: 1),
        _frame(180, 320, plainMargins: true, foreground: 5),
      );
      expect(
        match != null &&
            const LoopAlignmentLimits().acceptsMatch(match, 180, 320),
        isFalse,
      );
    });
    test('rotation and scale recover known centered camera geometry', () {
      const angle = .01;
      const scale = 1.01;
      final match = PveLoopFrameMatcher().match(
        _frame(320, 180),
        _frame(320, 180, angle: angle, scale: scale),
      );
      expect(match, isNotNull);
      expect(match!.pose.angle, closeTo(angle, .001));
      expect(match.pose.scale, closeTo(scale, .001));
      expect(match.pose.tx.abs(), lessThan(.3));
      expect(match.pose.ty.abs(), lessThan(.3));
      expect(const LoopAlignmentLimits().acceptsMatch(match, 320, 180), isTrue);
    });
    test('blank frames never establish camera confidence', () {
      expect(
        PveLoopFrameMatcher().match(
          _frame(320, 180, blank: true),
          _frame(320, 180, blank: true),
        ),
        isNull,
      );
    });
    test('moving foreground cannot impersonate the stationary camera', () {
      final match = PveLoopFrameMatcher().match(
        _frame(320, 180, foreground: 1),
        _frame(320, 180, foreground: 5),
      );
      if (match != null &&
          const LoopAlignmentLimits().acceptsMatch(match, 320, 180)) {
        expect(match.pose.tx.abs(), lessThan(.5));
        expect(match.pose.ty.abs(), lessThan(.5));
      }
    });
  });
}
