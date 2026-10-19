import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/editor_mask.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  group('maskForDetachedClip', () {
    test('keeps an off-centre turned mask in the cropped part of a tall '
        'source', () {
      const mask = LayerMask(
        shape: LayerMaskShape.rectangle,
        center: Offset(0.6, 0.4),
        rotation: 0.2,
        cornerRadius: 0.3,
        invert: true,
        feather: 0.2,
      );

      final detached = maskForDetachedClip(
        mask,
        boxSize: const Size(1, 2),
        targetAspectRatio: 1,
      )!;

      expect(detached.center, const Offset(0.6, 0.45));
      expect(detached.size, const Size(0.5, 0.25));
      expect(detached.feather, mask.feather);
      expect(detached.rotation, mask.rotation);
      expect(detached.cornerRadius, mask.cornerRadius);
      expect(detached.invert, mask.invert);
      expect(
        maskForDetachedClip(
          null,
          boxSize: const Size(1, 2),
          targetAspectRatio: 1,
        ),
        isNull,
      );
    });
  });

  group('canMaskLayer', () {
    test('lets text, stickers and drawings take a mask', () {
      expect(canMaskLayer(TextLayer(text: 'Hi')), isTrue);
      expect(canMaskLayer(WidgetLayer(widget: const SizedBox())), isTrue);
    });

    test('leaves out a hidden area and an audio visualizer, which the export '
        'draws from their own description', () {
      final censor = PaintLayer(
        item: PaintedModel(
          mode: PaintMode.blur,
          offsets: const [Offset.zero, Offset(40, 20)],
          erasedOffsets: const [],
          color: const Color(0xFFFFFFFF),
          strokeWidth: 1,
          opacity: 1,
        ),
        rawSize: const Size(40, 20),
        opacity: 1,
      );
      final visualizer = WidgetLayer(
        widget: const SizedBox(),
        meta: const AudioVisualizerLayerData().toMeta(),
      );

      expect(canMaskLayer(censor), isFalse);
      expect(canMaskLayer(visualizer), isFalse);
      expect(canMaskLayer(null), isFalse);
    });
  });

  group('editorMaskForShape', () {
    const box = Size(200, 400);

    test('starts a circle round on screen, two thirds of the shorter side '
        'across', () {
      final mask = editorMaskForShape(LayerMaskShape.ellipse, boxSize: box);

      expect(mask.size.width * box.width, closeTo(400 / 3, 0.001));
      expect(mask.size.height * box.height, closeTo(400 / 3, 0.001));
      expect(mask.center, const Offset(0.5, 0.5));
      expect(mask.feather, 0);
    });

    test('starts a linear mask with a soft edge', () {
      final mask = editorMaskForShape(LayerMaskShape.linear, boxSize: box);

      expect(mask.feather, editorMaskLinearFeather);
    });

    test('keeps the place, turn, edge, inversion and size of the shape it '
        'switches from', () {
      const previous = LayerMask(
        shape: LayerMaskShape.ellipse,
        center: Offset(0.45, 0.6),
        size: Size(0.3, 0.4),
        rotation: 1,
        feather: 0.1,
        invert: true,
      );

      final heart = editorMaskForShape(
        LayerMaskShape.heart,
        boxSize: box,
        previous: previous,
      );

      expect(
        heart,
        previous.copyWith(
          shape: LayerMaskShape.heart,
          cornerRadius: editorMaskRectangleCorners,
        ),
      );
    });

    test('gives a shape switched from a linear mask a size of its own', () {
      final rectangle = editorMaskForShape(
        LayerMaskShape.rectangle,
        boxSize: box,
        previous: const LayerMask(shape: LayerMaskShape.linear),
      );

      expect(rectangle.size, const Size(0.8, 0.8));
      expect(rectangle.cornerRadius, editorMaskRectangleCorners);
    });
  });

  group('editorMaskForShape keeps the shape on the box', () {
    test('shrinks a turned shape that would reach off the box', () {
      // A circle as wide as the box fits turned; the square it becomes, at
      // an eighth of a turn, would reach past both sides.
      const circle = LayerMask(
        shape: LayerMaskShape.ellipse,
        size: Size(1, 0.5),
        rotation: math.pi / 4,
      );

      final square = editorMaskForShape(
        LayerMaskShape.rectangle,
        boxSize: const Size(200, 400),
        previous: circle,
      );

      expect(square.size.width, closeTo(1 / math.sqrt2, 0.0001));
      expect(square.rotation, circle.rotation);
    });
  });

  group('scaleEditorMask', () {
    test('scales both sides, keeping the proportions', () {
      const mask = LayerMask(
        shape: LayerMaskShape.ellipse,
        size: Size(0.2, 0.4),
      );

      expect(scaleEditorMask(mask, 2).size, const Size(0.4, 0.8));
    });

    test('stops at the limits without stretching the shape', () {
      const mask = LayerMask(
        shape: LayerMaskShape.ellipse,
        size: Size(0.1, 0.2),
      );

      final shrunk = scaleEditorMask(mask, 0.01).size;
      final grown = scaleEditorMask(mask, 1000).size;

      expect(shrunk.width, closeTo(editorMaskMinSize, 1e-9));
      expect(shrunk.height, closeTo(editorMaskMinSize * 2, 1e-9));
      expect(grown.height, closeTo(editorMaskMaxSize, 1e-9));
      expect(grown.width, closeTo(editorMaskMaxSize / 2, 1e-9));
    });
  });

  group('fitEditorMask', () {
    const boxSize = Size(200, 400);

    test('moves a shape that fits back onto the box', () {
      // 100 x 100 px on the box: a quarter of its width, an eighth of its
      // height either side of the centre.
      const circle = LayerMask(
        shape: LayerMaskShape.ellipse,
        center: Offset(1.2, -0.3),
        size: Size(0.5, 0.25),
      );

      final fitted = fitEditorMask(circle, boxSize);

      expect(fitted.center.dx, closeTo(0.75, 0.0001));
      expect(fitted.center.dy, closeTo(0.125, 0.0001));
      expect(fitted.size, circle.size);
    });

    test('measures a turned shape by how far it reaches now', () {
      // 40 x 200 px, turned a quarter: 100 px either side across the box.
      const bar = LayerMask(
        shape: LayerMaskShape.rectangle,
        center: Offset(0, 0.5),
        size: Size(0.2, 0.5),
        rotation: math.pi / 2,
      );

      expect(fitEditorMask(bar, boxSize).center.dx, closeTo(0.5, 0.0001));
    });

    test('shrinks a shape too large for the box, keeping its proportions', () {
      // 280 x 200 px on a 200 px wide box.
      const wide = LayerMask(
        shape: LayerMaskShape.rectangle,
        size: Size(1.4, 0.5),
      );

      final fitted = fitEditorMask(wide, boxSize);

      expect(fitted.size.width, closeTo(1, 0.0001));
      expect(fitted.size.height, closeTo(0.5 / 1.4, 0.0001));
      expect(fitted.center, wide.center);
    });

    test('keeps only the centre of a linear mask on the box', () {
      const linear = LayerMask(
        shape: LayerMaskShape.linear,
        center: Offset(-0.5, 1.5),
      );

      expect(fitEditorMask(linear, boxSize).center, const Offset(0, 1));
    });
  });

  group('resizeEditorMask', () {
    const boxSize = Size(200, 400);

    test('stops a side where the shape touches the edge of the box', () {
      // 0.2 from the right edge, so it can be 0.4 of the box wide around its
      // centre.
      const circle = LayerMask(
        shape: LayerMaskShape.ellipse,
        center: Offset(0.8, 0.5),
        size: Size(0.2, 0.1),
      );

      final resized = resizeEditorMask(
        circle,
        const Size(0.9, 0.1),
        boxSize: boxSize,
      );

      expect(resized.size.width, closeTo(0.4, 0.0001));
      expect(resized.size.height, 0.1);
      expect(resized.center, circle.center);
    });

    test('resizes freely while the shape stays on the box', () {
      const circle = LayerMask(
        shape: LayerMaskShape.ellipse,
        size: Size(0.2, 0.1),
      );

      expect(
        resizeEditorMask(
          circle,
          const Size(0.6, 0.1),
          boxSize: boxSize,
        ).size,
        const Size(0.6, 0.1),
      );
    });
  });

  group('transferEditorMask', () {
    const circle = LayerMask(
      shape: LayerMaskShape.ellipse,
      center: Offset(0.3, 0.5),
      size: Size(0.4, 0.4),
    );

    test('keeps a circle round on a box of another shape', () {
      final moved = transferEditorMask(
        circle,
        from: const Size(100, 100),
        to: const Size(100, 300),
      );

      // 40 px across on the square stays 40 px across on the tall box.
      expect(moved.size.width * 100, closeTo(40, 1e-9));
      expect(moved.size.height * 300, closeTo(40, 1e-9));
      expect(moved.center, circle.center);
    });

    test('carries the mask over as it is while a box is unknown', () {
      expect(
        transferEditorMask(circle, from: null, to: const Size(100, 300)),
        circle,
      );
    });
  });
}
