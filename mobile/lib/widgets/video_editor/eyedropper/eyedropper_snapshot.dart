// ABOUTME: A still capture of what a repaint boundary shows, and the color
// ABOUTME: under any point of it, for the editor's eyedropper.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart' show colorFromArgb32;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Captures what [boundary] shows right now, at [pixelRatio] image pixels per
/// logical pixel.
///
/// The result is `null` when the boundary went away while the capture waited,
/// or when its pixels could not be read.
typedef EyedropperCapture = Future<EyedropperSnapshot?> Function(
  RenderRepaintBoundary boundary, {
  required double pixelRatio,
});

/// What a [RenderRepaintBoundary] showed at one moment, held still so a color
/// can be picked from it while the live content keeps moving.
///
/// Owns [image]: call [dispose] once the snapshot is no longer shown.
class EyedropperSnapshot {
  /// Wraps a captured [image] and its [pixels], which must be [image]'s
  /// pixels as straight (not premultiplied) RGBA, row by row.
  EyedropperSnapshot({
    required this.image,
    required ByteData pixels,
    required this.size,
  }) : _pixels = pixels;

  /// How many image pixels around the touched one are averaged, in each
  /// direction.
  ///
  /// A video frame is noisy pixel to pixel, so a single pixel of a green
  /// screen can be noticeably off its neighbours. A 3×3 block at the device's
  /// pixel ratio is still far smaller than a fingertip.
  static const int sampleRadius = 1;

  /// The captured frame.
  final ui.Image image;

  /// The logical size of the area [image] shows.
  final Size size;

  final ByteData _pixels;

  /// The image pixel under [position], given in logical pixels of [size] and
  /// clamped into the image.
  ({int x, int y}) pixelAt(Offset position) => (
    x: (position.dx * image.width / size.width).floor().clamp(
      0,
      image.width - 1,
    ),
    y: (position.dy * image.height / size.height).floor().clamp(
      0,
      image.height - 1,
    ),
  );

  /// The opaque color under [position], in logical pixels of [size], averaged
  /// over [sampleRadius].
  ///
  /// `null` where nothing was painted: a fully transparent block has no color
  /// to pick.
  Color? colorAt(Offset position) {
    final (:x, :y) = pixelAt(position);
    var red = 0;
    var green = 0;
    var blue = 0;
    var weight = 0;
    for (var row = y - sampleRadius; row <= y + sampleRadius; row++) {
      if (row < 0 || row >= image.height) continue;
      for (
        var column = x - sampleRadius;
        column <= x + sampleRadius;
        column++
      ) {
        if (column < 0 || column >= image.width) continue;
        final offset = (row * image.width + column) * 4;
        // Straight alpha: a half-transparent pixel counts half, so a block
        // at the edge of what was painted keeps the painted color.
        final alpha = _pixels.getUint8(offset + 3);
        red += _pixels.getUint8(offset) * alpha;
        green += _pixels.getUint8(offset + 1) * alpha;
        blue += _pixels.getUint8(offset + 2) * alpha;
        weight += alpha;
      }
    }
    if (weight == 0) return null;
    int channel(int sum) => (sum / weight).round().clamp(0, 255);
    return colorFromArgb32(
      0xFF000000 | channel(red) << 16 | channel(green) << 8 | channel(blue),
    );
  }

  /// Releases [image].
  void dispose() => image.dispose();
}

/// How many frames [captureEyedropperSnapshot] waits for [boundary] to finish
/// painting before it gives up.
const _maxFrameWaits = 5;

/// Captures what [boundary] shows right now. See [EyedropperCapture].
///
/// A boundary whose content changes every frame — the editor canvas while a
/// layer animates — can be dirty again by the time this runs, and capturing
/// one before it painted asserts in debug builds. So this waits for frames
/// until it is clean, and returns `null` if it never is.
Future<EyedropperSnapshot?> captureEyedropperSnapshot(
  RenderRepaintBoundary boundary, {
  required double pixelRatio,
}) async {
  for (var waits = 0; _needsPaint(boundary); waits++) {
    if (waits == _maxFrameWaits || !boundary.attached) return null;
    await SchedulerBinding.instance.endOfFrame;
  }
  if (!boundary.attached || !boundary.hasSize || boundary.size.isEmpty) {
    return null;
  }
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? pixels;
  try {
    pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
  } catch (_) {
    image.dispose();
    rethrow;
  }
  if (pixels == null) {
    image.dispose();
    return null;
  }
  return EyedropperSnapshot(image: image, pixels: pixels, size: boundary.size);
}

/// Whether [boundary] has changes it has not painted yet.
///
/// Only knowable in debug builds, which are also the only ones where capturing
/// a dirty boundary fails: release captures the last painted frame.
bool _needsPaint(RenderRepaintBoundary boundary) {
  var needsPaint = false;
  assert(() {
    needsPaint = boundary.debugNeedsPaint;
    return true;
  }(), 'only reads the debug flag');
  return needsPaint;
}
