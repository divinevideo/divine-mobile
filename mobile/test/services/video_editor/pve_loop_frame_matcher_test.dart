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
    time: Duration.zero,
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
