// ABOUTME: Decides the pixel ratio each editor layer is rasterized at on Next,
// ABOUTME: so a layer scaled far past the frame cannot exhaust app memory

import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;

/// The longest side, in pixels, any layer image is captured at, rotation
/// included.
///
/// A layer that fits inside the 1080×1920 frame stays below this at any angle
/// (the frame's diagonal is 2203 px), so only a layer scaled up past the frame
/// is captured below export resolution, and only the part of it reaching into
/// the frame is ever seen. Uncapped, a layer's image grows with the square of
/// its scale: three stickers scaled up eightfold over a square video took the
/// capture on Next past 2.7 GB, and a memory kill took the app with it.
const double layerCaptureMaxExtent = 3072;

/// The longest side, in pixels, a detached clip's layer image is captured at,
/// measured before the capture turns the image by the layer's rotation, which
/// grows it by up to a factor of √2.
///
/// The export places a detached clip from its own video, so its captured image
/// only ever stands in for media that cannot be read (see
/// `partitionDetachedClipLayers`). Enough for a recognisable frame there.
const double detachedClipCaptureExtent = 720;

/// The longest side, in pixels, an audio visualizer's layer image is captured
/// at, before the capture turns it.
///
/// The export draws the visualizer itself and reads nothing but the captured
/// layer's size, so its image is kept small.
const double audioVisualizerCaptureExtent = 256;

/// The pixel ratio a layer is captured at, for
/// `ImageGenerationConfigs.layerCapturePixelRatio`.
///
/// Every layer keeps [pixelRatio] until its rotated image would exceed
/// [layerCaptureMaxExtent], and a detached clip is held to
/// [detachedClipCaptureExtent]: three clips scaled up over the frame took the
/// capture on Next past 1.7 GB (#10071), for images the export throws away.
/// An audio visualizer is held to [audioVisualizerCaptureExtent] for the same
/// reason.
///
/// [size] is the layer's laid-out size before rotation, as pro_image_editor
/// passes it; the capture turns the image by the layer's rotation afterwards,
/// which grows it to the box around the turned layer.
double capturePixelRatioForLayer(Layer layer, Size size, double pixelRatio) {
  final rotatedExtent = _rotatedLongestSide(size, layer.rotation);
  if (rotatedExtent <= 0) return pixelRatio;
  final ratio = math.min(pixelRatio, layerCaptureMaxExtent / rotatedExtent);
  if (AudioVisualizerLayerData.isAudioVisualizerLayer(layer)) {
    return math.min(ratio, audioVisualizerCaptureExtent / size.longestSide);
  }
  if (!DetachedClipLayerData.isDetachedClipLayer(layer)) return ratio;
  return math.min(ratio, detachedClipCaptureExtent / size.longestSide);
}

/// The longest side of the box around [size] turned by [rotation] radians.
double _rotatedLongestSide(Size size, double rotation) {
  final cos = math.cos(rotation).abs();
  final sin = math.sin(rotation).abs();
  return math.max(
    size.width * cos + size.height * sin,
    size.width * sin + size.height * cos,
  );
}
