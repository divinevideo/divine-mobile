import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/video_editor/layer_capture_resolution.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

WidgetLayer _stickerLayer({double rotation = 0}) => WidgetLayer(
  widget: const SizedBox.shrink(),
  rotation: rotation,
  meta: const {'assetPath': 'assets/stickers/angry_cat.svg'},
  exportConfigs: const WidgetLayerExportConfigs(
    id: 'sticker',
    meta: {'assetPath': 'assets/stickers/angry_cat.svg'},
  ),
);

WidgetLayer _detachedLayer() {
  final meta = DetachedClipLayerData(
    clip: DivineVideoClip(
      id: 'clip-1',
      video: EditorVideo.file('/docs/clip-1.mp4'),
      duration: const Duration(seconds: 6),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
    ),
    layerId: 'layer-1',
  ).toMeta();
  return WidgetLayer(
    widget: const SizedBox.shrink(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'l-clip-1', meta: meta),
  );
}

void main() {
  group('capturePixelRatioForLayer', () {
    test('keeps the pixel ratio of a sticker that fits the frame', () {
      expect(
        capturePixelRatioForLayer(_stickerLayer(), const Size(130, 130), 5.9),
        5.9,
      );
    });

    test(
      'keeps the pixel ratio of a layer that fills the frame at any angle',
      () {
        // A layer that fits the frame never grows past the frame's diagonal at
        // any angle, and that has to stay below the capture extent: a larger
        // export quality needs a larger extent.
        const pixelRatio = 5.9;
        final frame = VideoEditorConstants.quality.resolution;
        final angles = [
          0.0,
          math.pi / 6,
          math.atan2(frame.width, frame.height),
          math.pi / 4,
          math.pi / 2,
        ];

        for (final angle in angles) {
          for (final side in [frame, frame.flipped]) {
            expect(
              capturePixelRatioForLayer(
                _stickerLayer(rotation: angle),
                Size(side.width / pixelRatio, side.height / pixelRatio),
                pixelRatio,
              ),
              equals(pixelRatio),
              reason: '${side.width}×${side.height} layer turned by $angle',
            );
          }
        }
      },
    );

    test('holds a sticker scaled far past the frame to the capture extent', () {
      // A sticker scaled up eightfold on a square video: at the editor's export
      // ratio its image would be 6136 px on each side.
      const size = Size(1040, 1040);
      final ratio = capturePixelRatioForLayer(_stickerLayer(), size, 5.9);

      expect(
        size.longestSide * ratio,
        closeTo(layerCaptureMaxExtent, 1e-9),
      );
    });

    test('holds an oversized text layer to the capture extent', () {
      const size = Size(1500, 300);
      final ratio = capturePixelRatioForLayer(
        TextLayer(text: 'caption'),
        size,
        4.9,
      );

      expect(
        size.longestSide * ratio,
        closeTo(layerCaptureMaxExtent, 1e-9),
      );
    });

    test('measures a turned layer by the box around it', () {
      // Turned by 45°, the captured image is the box around the turned
      // square: 2000 × √2 px on each side, not 2000.
      const size = Size(2000, 2000);
      final ratio = capturePixelRatioForLayer(
        _stickerLayer(rotation: math.pi / 4),
        size,
        4.9,
      );

      expect(
        size.width * math.sqrt2 * ratio,
        closeTo(layerCaptureMaxExtent, 1e-6),
      );
    });

    test('holds a scaled-up detached clip to the detached clip extent', () {
      // A clip scaled up past the frame: at the export ratio its image would be
      // 7350 px on its longest side.
      const size = Size(900, 1500);
      final ratio = capturePixelRatioForLayer(_detachedLayer(), size, 4.9);

      expect(
        size.longestSide * ratio,
        closeTo(detachedClipCaptureExtent, 1e-9),
      );
    });

    test('keeps the pixel ratio of a detached clip already small enough', () {
      expect(
        capturePixelRatioForLayer(_detachedLayer(), const Size(80, 140), 4.9),
        4.9,
      );
    });
  });
}
