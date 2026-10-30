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
  bool foregroundTouchesEdges = false,
  double plainHorizontalMargin = 0,
  bool stationaryStrip = false,
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
      var value = blank ? 100.0 : _texture(sx, sy);
      if (plainMargins && (sx < width * .1 || sy < height * .1)) {
        value = 100;
      }
      if (plainHorizontalMargin > 0 &&
          (sy < height * plainHorizontalMargin ||
              sy > height * (1 - plainHorizontalMargin))) {
        value = 100;
      }
      if (stationaryStrip && x > 16 && x < 22) {
        value = 160 + 40 * math.sin((x - 1) * .7) * math.cos((y + 1) * .6);
      }
      if (foreground != 0 &&
          x > width * .1 &&
          (foregroundTouchesEdges || x < width * .9) &&
          y > height * .1 &&
          (foregroundTouchesEdges || y < height * .9)) {
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

// A rigid foreground moves coherently; the narrow-band picture stays fixed.
LoopFrame _coherentForegroundFrame(
  int width,
  int height,
  double shift,
  Duration time,
) {
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var value = 100.0;
      final sx = x - shift;
      final sy = y.toDouble();
      if (sx > width * .1 && sy > height * .1) {
        value =
            160 +
            26 * math.sin(sx * .43 + sy * .11) +
            23 * math.cos(sy * .37 - sx * .09) +
            21 * math.sin(sx * .17 + sy * .23) +
            17 * math.cos(sx * .61 - sy * .41);
      }
      if (x > width * .02 &&
          x < width * .07 &&
          y > height * .3 &&
          y < height * .5) {
        value =
            100 +
            25 * math.sin(x * .43 + y * .11) +
            21 * math.cos(y * .37 - x * .09);
      }
      pixels[y * width + x] = value.round().clamp(0, 255);
    }
  }
  return LoopFrame(time: time, width: width, height: height, luma: pixels);
}

LoopFrame _flipped(
  LoopFrame frame, {
  required bool horizontal,
  required bool vertical,
}) => LoopFrame(
  time: frame.time,
  width: frame.width,
  height: frame.height,
  luma: Uint8List.fromList([
    for (var y = 0; y < frame.height; y++)
      for (var x = 0; x < frame.width; x++)
        frame.luma[(vertical ? frame.height - y - 1 : y) * frame.width +
            (horizontal ? frame.width - x - 1 : x)],
  ]),
);

double _texture(double x, double y) =>
    100 +
    26 * math.sin(x * .43 + y * .11) +
    23 * math.cos(y * .37 - x * .09) +
    21 * math.sin(x * .17 + y * .23) +
    17 * math.cos(x * .61 - y * .41);

double _subjectTexture(double x, double y) =>
    150 +
    30 * math.sin(x * .29 + y * .13) +
    25 * math.cos(y * .41 - x * .07) +
    18 * math.sin(x * .11 + y * .31) +
    14 * math.cos(x * .53 - y * .23);

// Camera drift over plain 10% margins, with textured patches placed in the
// left and right support bands. A stationary patch ignores the drift.
LoopFrame _patchedMarginFrame(
  int width,
  int height,
  double drift, {
  required double leftSpan,
  required double rightSpan,
  double stationaryLeftSpan = 0,
}) {
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final sx = x - drift;
      final fx = sx / width;
      final fy = y / height;
      var value = 100.0;
      if (fx > .1 && fx < .9 && fy > .1 && fy < .9) {
        value = _texture(sx, y.toDouble());
      }
      if (fx > .01 && fx < .075 && (fy - .5).abs() < leftSpan / 2) {
        value = _subjectTexture(sx, y.toDouble());
      }
      if (fx > .925 && fx < .99 && (fy - .5).abs() < rightSpan / 2) {
        value = _subjectTexture(sx, y.toDouble());
      }
      if (x / width > .01 &&
          x / width < .075 &&
          fy > .12 &&
          fy < .12 + stationaryLeftSpan) {
        value = _subjectTexture(x.toDouble(), y.toDouble());
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
    for (final (width, height) in [(180, 320), (320, 180)]) {
      test(
        'plain-margin drift requires narrow opposite-edge evidence at $width x $height',
        () {
          // Decline these ambiguous shots instead of widening into foreground.
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
          expect(plan, isNull);
        },
      );
    }
    for (final (width, height) in [(180, 320), (320, 180)]) {
      test('small subject motion is not camera drift at $width x $height', () {
        final match = PveLoopFrameMatcher().match(
          _frame(width, height, plainMargins: true, foreground: 1),
          _frame(width, height, plainMargins: true, foreground: 1.5),
        );
        expect(match, isNotNull);
        expect(
          const LoopAlignmentLimits().acceptsMatch(match!, width, height),
          isFalse,
        );
        expect(match.left.retained, isZero);
        expect(match.top.retained, isZero);
      });
    }
    for (final (width, height) in [(180, 320), (320, 180)]) {
      // The texture repeats on a (4.49, 5.24) lattice, so larger motions alias.
      for (final motion in [.5, 1.0, 2.0]) {
        test('edge-touching subject motion $motion is not camera drift at '
            '$width x $height', () {
          final match = PveLoopFrameMatcher().match(
            _frame(
              width,
              height,
              plainMargins: true,
              foreground: 1,
              foregroundTouchesEdges: true,
            ),
            _frame(
              width,
              height,
              plainMargins: true,
              foreground: 1 + motion,
              foregroundTouchesEdges: true,
            ),
          );
          expect(match, isNotNull);
          expect(
            const LoopAlignmentLimits().acceptsMatch(match!, width, height),
            isFalse,
          );
          expect(match.left.retained, isZero);
          expect(match.top.retained, isZero);
        });
      }
    }
    for (final (width, height) in [(180, 320), (320, 180)]) {
      for (final (horizontal, vertical) in [
        (true, false),
        (false, true),
        (true, true),
      ]) {
        test(
          'edge-touching subject rejection survives flip $horizontal/$vertical '
          'at $width x $height',
          () {
            final match = PveLoopFrameMatcher().match(
              _flipped(
                _frame(
                  width,
                  height,
                  plainMargins: true,
                  foreground: 1,
                  foregroundTouchesEdges: true,
                ),
                horizontal: horizontal,
                vertical: vertical,
              ),
              _flipped(
                _frame(
                  width,
                  height,
                  plainMargins: true,
                  foreground: 2,
                  foregroundTouchesEdges: true,
                ),
                horizontal: horizontal,
                vertical: vertical,
              ),
            );
            expect(match, isNotNull);
            expect(
              const LoopAlignmentLimits().acceptsMatch(match!, width, height),
              isFalse,
            );
            final plainSide = horizontal ? match.right : match.left;
            final plainEnd = vertical ? match.bottom : match.top;
            expect(plainSide.retained, isZero);
            expect(plainEnd.retained, isZero);
          },
        );
      }
    }
    test('a stationary arm in the wider ring preserves narrow background support', () {
      final match = PveLoopFrameMatcher().match(
        _frame(180, 320, plainHorizontalMargin: .13, stationaryStrip: true),
        _frame(
          180,
          320,
          dx: 2,
          plainHorizontalMargin: .13,
          stationaryStrip: true,
        ),
      );
      expect(match, isNotNull);
      expect(match!.pose.tx, closeTo(2, .3));
      expect(
        const LoopAlignmentLimits().acceptsMatch(match, 180, 320),
        isTrue,
        reason:
            'L${match.left.agreeing}/${match.left.retained} R${match.right.agreeing}/${match.right.retained} '
            'T${match.top.agreeing}/${match.top.retained} B${match.bottom.agreeing}/${match.bottom.retained} '
            'boundary=${match.boundaryModelError} withheld=${match.withheldMedianError} '
            'global=${match.consistentCount}/${match.retainedCount}',
      );
    });
    test('plans real camera drift behind an arm in the wider ring', () {
      final frames = [
        for (var i = 0; i < 90; i++)
          _frame(
            180,
            320,
            dx: 2 * i / 89,
            time: Duration(microseconds: i * 33333),
            plainHorizontalMargin: .13,
            stationaryStrip: true,
          ),
      ];
      final plan = const LoopAlignmentPlanner().plan(
        input: LoopRepairInput(
          clips: [
            const LoopClipInput(
              clipId: 'camera-with-occluding-arm',
              path: '/synthetic.mp4',
              sourceStart: Duration.zero,
              sourceEnd: Duration(microseconds: 90 * 33333),
              speed: 1,
              width: 180,
              height: 320,
            ),
          ],
          revision: 'synthetic-drift-with-arm',
        ),
        firstFrames: frames,
        lastFrames: frames,
        matcher: PveLoopFrameMatcher(),
        limits: const LoopAlignmentLimits(),
      );
      expect(plan, isNotNull);
      expect(plan!.zoom, inInclusiveRange(1, 1.08));
    });
    for (final (width, height) in [(180, 320), (320, 180)]) {
      for (final (horizontal, vertical) in [
        (false, false),
        (true, false),
        (false, true),
        (true, true),
      ]) {
        test('coherent subject cannot override stationary boundary '
            '$width x $height flip $horizontal/$vertical', () {
          final reference = _coherentForegroundFrame(
            width,
            height,
            1,
            Duration.zero,
          );
          final target = _coherentForegroundFrame(
            width,
            height,
            3,
            const Duration(seconds: 3),
          );
          final match = PveLoopFrameMatcher().match(
            _flipped(reference, horizontal: horizontal, vertical: vertical),
            _flipped(target, horizontal: horizontal, vertical: vertical),
          );
          expect(match, isNotNull);
          expect(
            const LoopAlignmentLimits().acceptsMatch(match!, width, height),
            isFalse,
          );
          final stationarySide = horizontal ? match.right : match.left;
          final plainEnd = vertical ? match.bottom : match.top;
          expect(stationarySide.retained, greaterThan(0));
          expect(stationarySide.agreeing, isZero);
          expect(plainEnd.retained, isZero);
        });
      }
    }
    test('coherent moving subject cannot reframe a stationary picture', () {
      final frames = [
        for (var i = 0; i < 90; i++)
          _coherentForegroundFrame(
            180,
            320,
            1 + 2 * i / 89,
            Duration(microseconds: i * 33333),
          ),
      ];
      final plan = const LoopAlignmentPlanner().plan(
        input: LoopRepairInput(
          clips: [
            const LoopClipInput(
              clipId: 'stationary-camera-moving-subject',
              path: '/synthetic.mp4',
              sourceStart: Duration.zero,
              sourceEnd: Duration(microseconds: 90 * 33333),
              speed: 1,
              width: 180,
              height: 320,
            ),
          ],
          revision: 'synthetic-stationary-camera',
        ),
        firstFrames: frames,
        lastFrames: frames,
        matcher: PveLoopFrameMatcher(),
        limits: const LoopAlignmentLimits(),
      );
      expect(plan, isNull);
    });
    test('large camera movement remains outside drift correction', () {
      // Six pixels is 3.3% of the width: only the 3% displacement limit
      // keeps this otherwise trackable movement out of drift correction.
      final match = PveLoopFrameMatcher().match(
        _frame(180, 320),
        _frame(180, 320, dx: 6),
      );
      expect(match, isNotNull);
      expect(
        const LoopAlignmentLimits(
          maximumDisplacement: 1,
        ).acceptsMatch(match!, 180, 320),
        isTrue,
      );
      expect(
        const LoopAlignmentLimits().acceptsMatch(match, 180, 320),
        isFalse,
      );
    });
    test('moving foreground beside plain margins is not camera drift', () {
      final match = PveLoopFrameMatcher().match(
        _frame(180, 320, plainMargins: true, foreground: 1),
        _frame(180, 320, plainMargins: true, foreground: 5),
      );
      expect(match, isNotNull);
      expect(
        const LoopAlignmentLimits().acceptsMatch(match!, 180, 320),
        isFalse,
      );
      expect(match.left.retained, isZero);
      expect(match.top.retained, isZero);
      expect(match.boundaryModelError, greaterThan(.5));
    });
    for (final (width, height) in [(180, 320), (320, 180)]) {
      for (final (dx, angle, scale) in [(2.0, 0.0, 1.0), (0.0, .01, 1.01)]) {
        test(
          'plans supported camera motion $dx/$angle/$scale at $width x $height',
          () {
            final frames = [
              for (var i = 0; i < 90; i++)
                _frame(
                  width,
                  height,
                  dx: dx * i / 89,
                  angle: angle * i / 89,
                  scale: math.pow(scale, i / 89).toDouble(),
                  time: Duration(microseconds: i * 33333),
                ),
            ];
            final plan = const LoopAlignmentPlanner().plan(
              input: LoopRepairInput(
                clips: [
                  LoopClipInput(
                    clipId: 'supported-camera',
                    path: '/synthetic.mp4',
                    sourceStart: Duration.zero,
                    sourceEnd: const Duration(microseconds: 90 * 33333),
                    speed: 1,
                    width: width,
                    height: height,
                  ),
                ],
                revision: 'synthetic-supported-motion',
              ),
              firstFrames: frames,
              lastFrames: frames,
              matcher: PveLoopFrameMatcher(),
              limits: const LoopAlignmentLimits(),
            );
            expect(plan, isNotNull);
            expect(plan!.zoom, inInclusiveRange(1, 1.08));
            final correction = plan.clips.single;
            final start = correction.correctionAt(frames.first.time);
            final end = correction.correctionAt(frames.last.time);
            expect(end.tx - start.tx, closeTo(-dx, .3));
            expect(end.angle - start.angle, closeTo(-angle, .001));
            expect(end.scale / start.scale, closeTo(1 / scale, .001));
          },
        );
      }
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
    for (final (width, height, leftSpan) in [
      (180, 320, .01),
      (320, 180, .02),
    ]) {
      test('a band with fewer than 4 matches rejects at $width x $height', () {
        final match = PveLoopFrameMatcher().match(
          _patchedMarginFrame(
            width,
            height,
            0,
            leftSpan: leftSpan,
            rightSpan: .7,
          ),
          _patchedMarginFrame(
            width,
            height,
            2,
            leftSpan: leftSpan,
            rightSpan: .7,
          ),
        );
        expect(match, isNotNull);
        expect(
          const LoopAlignmentLimits().acceptsMatch(match!, width, height),
          isFalse,
        );
        expect(match.left.agreeing, lessThan(4));
        expect(match.right.agreeing, greaterThanOrEqualTo(4));
        expect(match.boundaryModelError, lessThan(.5));
      });
    }
    for (final (width, height, stationarySpan) in [
      (180, 320, .3),
      (320, 180, .15),
    ]) {
      test('a band under 60% agreement rejects at $width x $height', () {
        final match = PveLoopFrameMatcher().match(
          _patchedMarginFrame(
            width,
            height,
            0,
            leftSpan: .2,
            rightSpan: .7,
            stationaryLeftSpan: stationarySpan,
          ),
          _patchedMarginFrame(
            width,
            height,
            2,
            leftSpan: .2,
            rightSpan: .7,
            stationaryLeftSpan: stationarySpan,
          ),
        );
        expect(match, isNotNull);
        expect(
          const LoopAlignmentLimits().acceptsMatch(match!, width, height),
          isFalse,
        );
        expect(match.left.agreeing, greaterThanOrEqualTo(4));
        expect(match.left.agreeing / match.left.retained, lessThan(.6));
        expect(match.right.agreeing, greaterThanOrEqualTo(4));
        expect(match.boundaryModelError, lessThan(.5));
      });
    }
    for (final (width, height, span) in [(180, 320, .08), (320, 180, .05)]) {
      test('no computable background fit rejects at $width x $height', () {
        final match = PveLoopFrameMatcher().match(
          _patchedMarginFrame(
            width,
            height,
            0,
            leftSpan: span,
            rightSpan: span,
          ),
          _patchedMarginFrame(
            width,
            height,
            2,
            leftSpan: span,
            rightSpan: span,
          ),
        );
        expect(match, isNotNull);
        expect(
          const LoopAlignmentLimits().acceptsMatch(match!, width, height),
          isFalse,
        );
        expect(match.boundaryModelError, double.infinity);
        expect(match.left.agreeing, greaterThanOrEqualTo(4));
        expect(match.right.agreeing, greaterThanOrEqualTo(4));
      });
    }
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
      expect(match, isNotNull);
      expect(
        const LoopAlignmentLimits().acceptsMatch(match!, 320, 180),
        isFalse,
      );
      expect(match.boundaryModelError, greaterThan(.5));
    });
  });
}
