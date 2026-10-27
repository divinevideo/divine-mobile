// ABOUTME: Tests how a shape mask's keyframes stay in place through timeline
// ABOUTME: edits of the item they mask.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_mask_keyframes.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerMask, LayerMaskKeyframe, LayerMaskShape;

void main() {
  const ms = Duration(milliseconds: 1);

  LayerMaskKeyframe keyframe(int timeMs, {double x = 0.5}) =>
      LayerMaskKeyframe(time: ms * timeMs, center: Offset(x, 0.5));

  final mask = const LayerMask(shape: LayerMaskShape.ellipse).withKeyframes([
    keyframe(0, x: 0.2),
    keyframe(500, x: 0.4),
    keyframe(1000, x: 0.6),
    keyframe(1500, x: 0.8),
  ]);

  group('LayerMaskKeyframeTimeline', () {
    group('shiftedBy', () {
      test('moves every keyframe by the shift', () {
        expect(
          mask.shiftedBy(ms * -300).keyframes.map((k) => k.time),
          [ms * -300, ms * 200, ms * 700, ms * 1200],
        );
      });

      test('returns a mask without keyframes as it is', () {
        const still = LayerMask(shape: LayerMaskShape.heart);

        expect(still.shiftedBy(ms * 300), same(still));
      });
    });

    group('forPart', () {
      test('keeps the keyframes inside the part and the nearest outside, '
          'measured from its start', () {
        final part = mask.forPart(ms * 600, ms * 1200);

        expect(part.keyframes.map((k) => k.time), [
          ms * -100,
          ms * 400,
          ms * 900,
        ]);
      });

      test('changes the part exactly as the whole mask did', () {
        final part = mask.forPart(ms * 600, ms * 1200);

        for (final at in [600, 750, 1000, 1100, 1200]) {
          expect(
            part.at(ms * (at - 600)).center.dx,
            closeTo(mask.at(ms * at).center.dx, 1e-9),
            reason: 'at $at ms',
          );
        }
      });

      test('returns a mask without keyframes as it is', () {
        const still = LayerMask(shape: LayerMaskShape.heart);

        expect(still.forPart(ms * 100, ms * 200), same(still));
      });
    });
  });

  group('LayerMaskTimeline', () {
    final layer = Layer(startTime: ms * 1000, mask: mask);

    test('maskFrom keeps the mask motion where it is on the video', () {
      final rebased = layer.maskFrom(ms * 1300)!;
      final moved = Layer(startTime: ms * 1300, mask: rebased);

      for (final at in [1300, 1700, 2400]) {
        expect(
          moved.maskAt(ms * at)!.center.dx,
          closeTo(layer.maskAt(ms * at)!.center.dx, 1e-9),
          reason: 'at $at ms',
        );
      }
    });

    test('maskForPart measures the part from its own start', () {
      final part = layer.maskForPart(ms * 1600, ms * 2200)!;
      final split = Layer(startTime: ms * 1600, mask: part);

      for (final at in [1600, 1900, 2200]) {
        expect(
          split.maskAt(ms * at)!.center.dx,
          closeTo(layer.maskAt(ms * at)!.center.dx, 1e-9),
          reason: 'at $at ms',
        );
      }
    });

    test('is null without a mask', () {
      expect(Layer().maskFrom(ms * 10), isNull);
      expect(Layer().maskForPart(ms * 10, ms * 20), isNull);
    });
  });
}
