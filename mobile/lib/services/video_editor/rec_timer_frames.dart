// ABOUTME: Renders the frames a REC timer sticker exports as: one image per
// ABOUTME: frame of a 30 fps video, each showing the time that frame shows.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/utils/rec_timer_paint.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// How often an exported REC timer changes: every frame of a 30 fps video,
/// so its hundredths run on the way a stopwatch's do when it is filmed. Any
/// slower and the hundredths visibly stutter.
const recTimerFrameStep = Duration(microseconds: 33333);

/// The pixels all frames of one exported REC timer may hold together.
///
/// The renderer keeps every frame decoded for the whole export, at four
/// bytes a pixel, the way it keeps every step of a typewriter text. A timer
/// as wide as the video still changes 25 times a second within this; only
/// one scaled up past the frame changes less often, instead of holding
/// gigabytes.
const int recTimerPixelBudget = 48 * 1000 * 1000;

/// How many frames are painted at once: enough to keep the raster thread
/// busy, few enough that their images do not pile up in memory.
const _paintBatch = 24;

/// The frames every REC timer among [layers] exports as, keyed by layer id.
///
/// The layer capture holds one still of the timer at rest, but the timer
/// runs with the video, so it is painted again for every frame it shows, at
/// the size, mask, turn, flip and opacity the capture baked into that still.
/// The renderer shows the frames one after the other, the way it shows a
/// typewriter text, so the timer reads 00:00, 00:03, 00:06 and so on
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
    final stopwatch = clock.stopwatch()..start();
    frames[item.layer.id] = await _framesOf(item, data.style, editorDuration);
    Log.debug(
      'Painted ${frames[item.layer.id]!.length} REC timer frames of '
      '${item.logicalSize} logical px for layer ${item.layer.id} in '
      '${stopwatch.elapsedMilliseconds} ms',
      name: 'RecTimerFrames',
      category: LogCategory.video,
    );
  }
  return frames;
}

/// The time windows of a timer from [start] until [end], or until the
/// video ends when [end] is `null`: one per [step] of the video, each with
/// the time it shows, cut at the timer's own start and end.
List<({Duration shown, Duration? start, Duration? end})> recTimerWindows({
  required Duration? start,
  required Duration? end,
  required Duration editorDuration,
  Duration step = recTimerFrameStep,
}) {
  final from = start ?? Duration.zero;
  final to = end ?? editorDuration;
  final windows = <({Duration shown, Duration? start, Duration? end})>[];
  for (
    var shown = step * (from.inMicroseconds ~/ step.inMicroseconds);
    shown < to;
    shown += step
  ) {
    final windowEnd = shown + step;
    windows.add((
      shown: shown,
      start: shown < from ? start : shown,
      // The last window keeps the layer's own end, which may be "the end of
      // the video".
      end: windowEnd >= to ? end : windowEnd,
    ));
  }
  return windows;
}

/// The step between the frames of a timer painted [frame] pixels large that
/// runs for [span]: [recTimerFrameStep], or longer when that many frames
/// would hold more than [recTimerPixelBudget] pixels.
Duration recTimerFrameStepFor({required Size frame, required Duration span}) {
  final pixels = frame.width * frame.height;
  final budgeted = span.inMicroseconds * pixels / recTimerPixelBudget;
  return Duration(
    microseconds: math.max(recTimerFrameStep.inMicroseconds, budgeted.ceil()),
  );
}

Future<List<ExportedLayerFrame>> _framesOf(
  ExportedLayer item,
  InfoStickerStyle style,
  Duration editorDuration,
) async {
  final layer = item.layer;
  final pixelRatio = await _capturedPixelRatio(item);
  final box = _unturnedSize(item.logicalSize, layer.rotation) * pixelRatio;
  final span =
      (layer.endTime ?? editorDuration) - (layer.startTime ?? Duration.zero);
  final windows = recTimerWindows(
    start: layer.startTime,
    end: layer.endTime,
    editorDuration: editorDuration,
    step: recTimerFrameStepFor(frame: box, span: span),
  );
  final frames = <ExportedLayerFrame>[];
  for (var i = 0; i < windows.length; i += _paintBatch) {
    frames.addAll(
      await Future.wait([
        for (final window in windows.skip(i).take(_paintBatch))
          _paintFrame(layer, style, box, window.shown).then(
            (bytes) => ExportedLayerFrame(
              bytes: bytes,
              startTime: window.start,
              endTime: window.end,
            ),
          ),
      ]),
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
