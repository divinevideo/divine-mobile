import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/track_frame_mapping.dart';

void main() {
  const canvas = Size(225, 400);

  Matcher offsetCloseTo(Offset expected) => isA<Offset>()
      .having((o) => o.dx, 'dx', closeTo(expected.dx, 1e-9))
      .having((o) => o.dy, 'dy', closeTo(expected.dy, 1e-9));

  group(TrackFrameMapping, () {
    test('lays a frame shaped like the canvas over all of it', () {
      final mapping = TrackFrameMapping(
        canvasSize: canvas,
        videoAspectRatio: 9 / 16,
        targetAspectRatio: 9 / 16,
      );
      expect(mapping.layerOffsetOf(const Offset(0.5, 0.5)), Offset.zero);
      expect(
        mapping.layerOffsetOf(Offset.zero),
        offsetCloseTo(const Offset(-112.5, -200)),
      );
      expect(mapping.visibleFrame, const Rect.fromLTRB(0, 0, 1, 1));
      expect(mapping.layerPixelsPerFrameWidth, closeTo(225, 1e-9));
      expect(mapping.layerPixelsPerFrameHeight, closeTo(400, 1e-9));
    });

    test('shows only the kept square of a vertical clip cut square', () {
      final mapping = TrackFrameMapping(
        canvasSize: canvas,
        videoAspectRatio: 9 / 16,
        targetAspectRatio: 1,
      );
      final visible = mapping.visibleFrame;
      expect(visible.left, closeTo(0, 1e-9));
      expect(visible.right, closeTo(1, 1e-9));
      expect(visible.top, closeTo(7 / 32, 1e-9));
      expect(visible.bottom, closeTo(25 / 32, 1e-9));
      // The kept square's top edge is the canvas's kept square's top edge.
      expect(
        mapping.layerOffsetOf(Offset(0.5, visible.top)),
        offsetCloseTo(const Offset(0, -112.5)),
      );
    });

    test('places a layer over the frame point the export puts it on', () {
      // A square file on a vertical canvas, both cut square: the frame is
      // not shaped like the canvas, which is what the export mapping covers.
      const frame = Size(1080, 1080);
      final mapping = TrackFrameMapping(
        canvasSize: canvas,
        videoAspectRatio: 1,
        targetAspectRatio: 1,
      );
      final export = ExportLayerMapping(
        bodySize: canvas,
        frameSize: frame,
        targetAspectRatio: 1,
      );
      for (final layer in const [
        Offset(30, -40),
        Offset(-100, 90),
        Offset.zero,
      ]) {
        final framePoint =
            export.origin + (canvas.center(Offset.zero) + layer) * export.scale;
        final fraction = mapping.fractionOf(layer);
        expect(fraction.dx * frame.width, closeTo(framePoint.dx, 1e-6));
        expect(fraction.dy * frame.height, closeTo(framePoint.dy, 1e-6));
        expect(mapping.layerOffsetOf(fraction), offsetCloseTo(layer));
      }
    });

    test('turns regions into canvas rects and back', () {
      final mapping = TrackFrameMapping(
        canvasSize: canvas,
        videoAspectRatio: 9 / 16,
        targetAspectRatio: 1,
      );
      const region = Rect.fromLTRB(0.3, 0.4, 0.6, 0.55);
      final rect = mapping.layerRectOf(region);
      expect(rect.width, closeTo(0.3 * 225, 1e-9));
      final back = mapping.regionOf(rect);
      expect(back.left, closeTo(region.left, 1e-12));
      expect(back.top, closeTo(region.top, 1e-12));
      expect(back.right, closeTo(region.right, 1e-12));
      expect(back.bottom, closeTo(region.bottom, 1e-12));
    });
  });
}
