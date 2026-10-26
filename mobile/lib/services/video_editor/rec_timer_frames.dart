// ABOUTME: Renders the frames a REC timer sticker exports as: one image per
// ABOUTME: second of the video, each showing the time that second shows.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/utils/rec_timer_paint.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The frames every REC timer among [layers] exports as, keyed by layer id.
///
/// The layer capture holds one still of the timer at rest, but the timer
/// runs with the video, so it is painted again for every second it shows,
/// at the size, mask, turn, flip and opacity the capture baked into that
/// still. The renderer shows the frames one after the other, the way it
/// shows a typewriter text, so the timer reads 00:00, 00:01 and so on
/// wherever it sits on the timeline.
///
/// [editorDuration] is where a timer without an end stops counting.
Future<Map<String, List<ExportedLayerFrame>>> recTimerLayerFrames(
  List<ExportedLayer> layers, {
  required Duration editorDuration,
}) async {
  final frames = <String, List<ExportedLayerFrame>>{};
  for (final item in layers) {
    final data = InfoStickerData.of(item.layer);
    if (data == null || data.kind != InfoStickerKind.recTimer) continue;
    frames[item.layer.id] = await _framesOf(item, data.style, editorDuration);
  }
  return frames;
}

/// The time windows of a timer from [start] until [end], or until the
/// video ends when [end] is `null`: one per second of the video the timer
/// shows, cut at its own start and end.
List<({Duration second, Duration? start, Duration? end})> recTimerWindows({
  required Duration? start,
  required Duration? end,
  required Duration editorDuration,
}) {
  final from = start ?? Duration.zero;
  final to = end ?? editorDuration;
  const second = Duration(seconds: 1);
  final windows = <({Duration second, Duration? start, Duration? end})>[];
  for (
    var shown = Duration(seconds: from.inSeconds);
    shown < to;
    shown += second
  ) {
    final windowEnd = shown + second;
    windows.add((
      second: shown,
      start: shown < from ? start : shown,
      // The last window keeps the layer's own end, which may be "the end of
      // the video".
      end: windowEnd >= to ? end : windowEnd,
    ));
  }
  return windows;
}

Future<List<ExportedLayerFrame>> _framesOf(
  ExportedLayer item,
  InfoStickerStyle style,
  Duration editorDuration,
) async {
  final layer = item.layer;
  final pixelRatio = await _capturedPixelRatio(item);
  final box = _unturnedSize(item.logicalSize, layer.rotation) * pixelRatio;
  final frames = <ExportedLayerFrame>[];
  for (final window in recTimerWindows(
    start: layer.startTime,
    end: layer.endTime,
    editorDuration: editorDuration,
  )) {
    frames.add(
      ExportedLayerFrame(
        bytes: await _paintFrame(layer, style, box, window.second),
        startTime: window.start,
        endTime: window.end,
      ),
    );
  }
  return frames;
}

/// The timer's own box, before the layer turned it into [turned].
///
/// The capture reports the box around the turned layer; the timer always
/// has the same shape, which pins down the box it was turned from.
Size _unturnedSize(Size turned, double rotation) {
  final cos = math.cos(rotation).abs();
  final sin = math.sin(rotation).abs();
  final aspect = recTimerDesignSize.aspectRatio;
  final width = turned.width / (cos + sin / aspect);
  return Size(width, width / aspect);
}

/// The pixel ratio the layer was captured at, read from its still.
Future<double> _capturedPixelRatio(ExportedLayer item) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(item.bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final width = descriptor.width;
  descriptor.dispose();
  buffer.dispose();
  return item.logicalSize.width > 0 ? width / item.logicalSize.width : 1;
}

/// The timer at [elapsed], painted at [box] pixels and finished the way the
/// layer capture finishes a still: masked, then turned, flipped and faded.
Future<Uint8List> _paintFrame(
  Layer layer,
  InfoStickerStyle style,
  Size box,
  Duration elapsed,
) async {
  final width = box.width.ceil();
  final height = box.height.ceil();
  final recorder = ui.PictureRecorder();
  paintRecTimer(
    ui.Canvas(recorder),
    Size(width.toDouble(), height.toDouble()),
    style: style,
    elapsed: elapsed,
  );
  final picture = recorder.endRecording();
  var image = await picture.toImage(width, height);
  picture.dispose();

  if (layer.mask case final mask?) {
    final masked = await mask.applyTo(image);
    image.dispose();
    image = masked;
  }

  final turned = layer.rotation != 0 || layer.flipX || layer.flipY;
  final opacity = layer.hasKeyframes ? 1.0 : layer.opacity.clamp(0.0, 1.0);
  if (turned || opacity < 1) {
    final finished = await _turned(image, layer, opacity);
    image.dispose();
    image = finished;
  }

  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// [image] turned and flipped like [layer], into the box around the turned
/// image, and drawn at [opacity].
Future<ui.Image> _turned(ui.Image image, Layer layer, double opacity) async {
  final w = image.width.toDouble();
  final h = image.height.toDouble();
  final cos = math.cos(layer.rotation).abs();
  final sin = math.sin(layer.rotation).abs();
  final turnedWidth = w * cos + h * sin;
  final turnedHeight = w * sin + h * cos;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, turnedWidth, turnedHeight),
  )..translate(turnedWidth / 2, turnedHeight / 2);
  if (layer.flipX) canvas.scale(-1, 1);
  if (layer.flipY) canvas.scale(1, -1);
  canvas
    ..rotate(layer.rotation)
    ..translate(-w / 2, -h / 2)
    ..drawImage(
      image,
      ui.Offset.zero,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        // Only the alpha counts when an image is drawn.
        ..color = VineTheme.whiteText.withValues(alpha: opacity),
    );
  final picture = recorder.endRecording();
  final turned = await picture.toImage(
    turnedWidth.ceil(),
    turnedHeight.ceil(),
  );
  picture.dispose();
  return turned;
}
