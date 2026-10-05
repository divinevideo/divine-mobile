// ABOUTME: Tests how an area hidden behind a blur or pixelation reaches the
// ABOUTME: export: its censor layer's box, strength and place among the layers.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

void main() {
  PaintLayer censorLayer({
    PaintMode mode = PaintMode.blur,
    Offset offset = Offset.zero,
    double rotation = 0,
    double scale = 1,
    bool flipX = false,
    String? id,
  }) => PaintLayer(
    id: id,
    item: PaintedModel(
      mode: mode,
      offsets: const [Offset.zero, Offset(40, 20)],
      erasedOffsets: const [],
      color: const Color(0xFFFFFFFF),
      strokeWidth: 1,
      opacity: 1,
    ),
    rawSize: const Size(40, 20),
    opacity: 1,
    offset: offset,
    rotation: rotation,
    scale: scale,
    flipX: flipX,
  );

  // A 100 x 200 body mapped onto a 300 x 600 frame: three frame pixels per
  // body pixel, with the body's top-left on the frame's.
  final mapping = ExportLayerMapping(
    bodySize: const Size(100, 200),
    frameSize: const Size(300, 600),
    targetAspectRatio: 0.5,
  );

  group('censorStrengthOf', () {
    test('gives the default strength halfway', () {
      expect(
        censorStrengthOf(PaintMode.blur, 0.5),
        VideoEditorConstants.censorBlurSigma,
      );
      expect(
        censorStrengthOf(PaintMode.pixelate, 0.5),
        VideoEditorConstants.censorPixelBlockSize,
      );
    });

    test('spans the intensity range on either side of the default', () {
      const range = VideoEditorConstants.censorIntensityRange;
      expect(
        censorStrengthOf(PaintMode.blur, 0),
        closeTo(VideoEditorConstants.censorBlurSigma / range, 1e-9),
      );
      expect(
        censorStrengthOf(PaintMode.pixelate, 1),
        closeTo(VideoEditorConstants.censorPixelBlockSize * range, 1e-9),
      );
    });
  });

  group('censorImageLayer', () {
    pve.ImageLayer build(PaintLayer layer) => censorImageLayer(
      layer,
      bodySize: const Size(100, 200),
      mapping: mapping,
      startTime: const Duration(seconds: 1),
      endTime: const Duration(seconds: 2),
    );

    test("covers the layer's unrotated box in frame pixels", () {
      final image = build(censorLayer(offset: const Offset(10, -20), scale: 2));

      // The box is 80 x 40 body pixels around (60, 80), the body's center
      // moved by the offset.
      expect(image.size, const Size(240, 120));
      expect(image.offset, const Offset(60, 180));
    });

    test('passes the rotation on, mirrored for a flipped layer', () {
      expect(build(censorLayer(rotation: 0.5)).rotation, 0.5);
      expect(build(censorLayer(rotation: 0.5, flipX: true)).rotation, -0.5);
    });

    test('scales the strength like the box', () {
      expect(
        build(censorLayer()).censor,
        const pve.LayerCensor.blur(
          sigma: VideoEditorConstants.censorBlurSigma * 3,
        ),
      );
      expect(
        build(censorLayer(mode: PaintMode.pixelate)).censor,
        const pve.LayerCensor.pixelate(
          blockSize: VideoEditorConstants.censorPixelBlockSize * 3,
        ),
      );
    });

    test('exports an area with its own strength', () {
      final layer = censorLayer(mode: PaintMode.pixelate)
        ..item.censorStrength = 20;

      expect(
        build(layer).censor,
        const pve.LayerCensor.pixelate(blockSize: 20 * 3),
      );
    });

    test('keeps the time window it was given', () {
      final image = build(censorLayer());

      expect(image.startTime, const Duration(seconds: 1));
      expect(image.endTime, const Duration(seconds: 2));
    });
  });

  group('withCensorLayers', () {
    ExportedLayer captured(Layer layer) => ExportedLayer(
      layer: layer,
      bytes: Uint8List.fromList(const [1, 2, 3]),
      logicalSize: const Size(10, 10),
    );

    test('returns the capture as it is without censor layers', () {
      final text = Layer(id: 'text');
      final layers = [captured(text)];

      expect(withCensorLayers([text], layers), same(layers));
    });

    test('puts back a censor layer the capture dropped, in its place', () {
      final below = Layer(id: 'below');
      final censor = censorLayer(id: 'censor');
      final above = Layer(id: 'above');

      final result = withCensorLayers(
        [below, censor, above],
        [captured(below), captured(above)],
      );

      expect(result.map((item) => item.layer.id), [
        'below',
        'censor',
        'above',
      ]);
    });

    test('reports a censor layer at the size a capture would', () {
      final censor = censorLayer(rotation: math.pi / 2, id: 'censor');

      final result = withCensorLayers([censor], const []);

      expect(result.single.logicalSize.width, closeTo(20, 1e-9));
      expect(result.single.logicalSize.height, closeTo(40, 1e-9));
    });
  });
}
