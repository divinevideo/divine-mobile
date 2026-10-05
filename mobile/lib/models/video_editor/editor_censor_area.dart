// ABOUTME: Areas the creator hides behind a blur or pixelation: how the editor
// ABOUTME: previews them and how the export turns them into censor layers.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// Whether [layer] hides an area of the video (blur, pixelate) instead of
/// drawing on it.
///
/// Such a layer is a [PaintLayer] whose stroke is a censor area: a rectangle
/// that the editor previews with a backdrop filter over everything beneath it.
bool isCensorLayer(Layer layer) => layer is PaintLayer && layer.isCensor;

/// Whether a censor [layer] pixelates rather than blurs.
bool isPixelateCensorLayer(PaintLayer layer) =>
    layer.item.mode == PaintMode.pixelate;

/// The preview of censor areas in the editor, as strong as the export.
///
/// Both the blur and the pixelation are measured in the area's own
/// coordinates, the canvas pixels [censorImageLayer] scales to the video, so
/// the preview shows what the export draws whatever the canvas's size on
/// screen. Pixelate blocks start at the area's corner on both sides.
CensorConfigs videoEditorCensorConfigs() => const CensorConfigs(
  // Passed although it equals the package default, so the preview cannot
  // drift from the export, which reads the same constant.
  // ignore: avoid_redundant_argument_values
  blurSigmaX: VideoEditorConstants.censorBlurSigma,
  // Passed for the same reason as blurSigmaX.
  // ignore: avoid_redundant_argument_values
  blurSigmaY: VideoEditorConstants.censorBlurSigma,
  pixelBlockSize: VideoEditorConstants.censorPixelBlockSize,
  pixelateInLayerSpace: true,
);

/// The strength of a censor area in [mode] at [intensity] (0 to 1): its blur
/// sigma or pixel block size, measured like [videoEditorCensorConfigs].
///
/// [VideoEditorConstants.censorDefaultIntensity] gives the default strength,
/// and each end of the range is [VideoEditorConstants.censorIntensityRange]
/// times weaker or stronger, in even steps along the way.
double censorStrengthOf(PaintMode mode, double intensity) {
  final base = mode == PaintMode.pixelate
      ? VideoEditorConstants.censorPixelBlockSize
      : VideoEditorConstants.censorBlurSigma;
  final steps =
      (intensity.clamp(0.0, 1.0) -
          VideoEditorConstants.censorDefaultIntensity) /
      VideoEditorConstants.censorDefaultIntensity;
  return base * math.pow(VideoEditorConstants.censorIntensityRange, steps);
}

/// The mask of every censor area on the export: an opaque square that
/// `ImageLayer.size` stretches over the area's box.
///
/// It is large enough that stretching it over an area as wide as the frame
/// softens the edge by about a pixel, where the renderer filters it against
/// the transparent outside.
final Uint8List censorAreaMaskPng = img.encodePng(
  img.Image(width: 512, height: 512, numChannels: 4)
    ..clear(img.ColorRgba8(255, 255, 255, 255)),
);

/// The censor layer [layer] exports as, laid out by [mapping] over the frame
/// the image layers are composited on.
///
/// The strength is the area's own, or the default one of an area drawn
/// before areas had a strength.
///
/// The box is the layer's unrotated size with its rotation passed on, rather
/// than the rotated bounding box captured layers are exported in: the capture
/// of a backdrop filter holds nothing to draw. A flipped layer shows its
/// rotation mirrored, which the rotation's sign carries over.
///
/// [startTime] and [endTime] are already on the output timeline.
pve.ImageLayer censorImageLayer(
  PaintLayer layer, {
  required Size bodySize,
  required ExportLayerMapping mapping,
  required Duration? startTime,
  required Duration? endTime,
}) {
  final size = layer.size;
  final mirrored = layer.flipX != layer.flipY;
  final scale = mapping.scale;
  return pve.ImageLayer(
    image: pve.EditorLayerImage.memory(censorAreaMaskPng),
    startTime: startTime,
    endTime: endTime,
    offset: exportedLayerTopLeft(
      anchor: layer.offset,
      bodySize: bodySize,
      logicalSize: size,
      mapping: mapping,
    ),
    size: size * scale,
    rotation: mirrored ? -layer.rotation : layer.rotation,
    censor: isPixelateCensorLayer(layer)
        ? pve.LayerCensor.pixelate(
            blockSize:
                (layer.item.censorStrength ??
                    VideoEditorConstants.censorPixelBlockSize) *
                scale,
          )
        : pve.LayerCensor.blur(
            sigma:
                (layer.item.censorStrength ??
                    VideoEditorConstants.censorBlurSigma) *
                scale,
          ),
  );
}

/// [captured] with an entry for every censor layer of [layers], in the order
/// of [layers].
///
/// A censor layer's capture is a backdrop filter with nothing behind it, which
/// can come out empty or be dropped altogether; its export is built from the
/// layer alone (see [censorImageLayer]). Making sure it is in the list keeps
/// an area the creator hid from reaching the export unhidden. Captured layers
/// that are not in [layers] keep their place at the end.
List<ExportedLayer> withCensorLayers(
  List<Layer> layers,
  List<ExportedLayer> captured,
) {
  if (!layers.any(isCensorLayer)) return captured;
  final byLayer = {for (final item in captured) item.layer.id: item};
  final ordered = <ExportedLayer>[];
  for (final layer in layers) {
    final item = byLayer.remove(layer.id);
    if (layer is PaintLayer && layer.isCensor) {
      ordered.add(
        ExportedLayer(
          layer: item?.layer ?? layer,
          bytes: censorAreaMaskPng,
          logicalSize: _rotatedBox(layer.size, layer.rotation),
        ),
      );
    } else if (item != null) {
      ordered.add(item);
    }
  }
  return [...ordered, ...byLayer.values];
}

/// The bounding box of [size] turned by [rotation], as `Layer.captureAllLayers`
/// reports a rotated layer's size.
Size _rotatedBox(Size size, double rotation) {
  if (rotation == 0) return size;
  final cos = math.cos(rotation).abs();
  final sin = math.sin(rotation).abs();
  return Size(
    size.width * cos + size.height * sin,
    size.width * sin + size.height * cos,
  );
}
