// ABOUTME: Renders the frames a sticker that moves with the video exports as
// ABOUTME: (a REC timer, an animated sound credit): one image per video frame.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/utils/rec_timer_paint.dart';
import 'package:openvine/utils/sound_credit_paint.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// How often an exported moving sticker changes, per second: every frame of
/// a 30 fps video, so a REC timer's hundredths run on the way a stopwatch's
/// do when it is filmed, and a record turns smoothly. Any slower and the
/// hundredths visibly stutter.
const double stickerFramesPerSecond = 30;

/// The pixels all frames of one exported moving sticker may hold together.
///
/// The renderer keeps every frame decoded for the whole export, at four
/// bytes a pixel, the way it keeps every step of a typewriter text. A timer
/// as wide as the video still changes 25 times a second within this; only
/// one scaled up past the frame changes less often, instead of holding
/// gigabytes.
const int stickerFramePixelBudget = 48 * 1000 * 1000;

/// How many frames are painted at once: enough to keep the raster thread
/// busy, few enough that their images do not pile up in memory.
const _paintBatch = 24;

/// The frames every moving sticker among [layers] exports as, keyed by layer
/// id: every REC timer, and every sound credit whose record or reels turn,
/// whose player runs, or whose equalizer follows [audioEnergies], the band
/// energies of the exported video's sound.
///
/// The layer capture holds one still of the sticker at rest, but the sticker
/// moves with the video, so it is painted again for every frame it shows, at
/// the size, mask, turn, flip and opacity the capture baked into that still.
/// The renderer shows the frames one after the other, the way it shows a
/// typewriter text, so a timer reads 00:00, 00:03, 00:06 and so on wherever
/// it sits on the timeline.
///
/// A sticker without an end moves until [timelineMap]'s editor timeline
/// ends. An equalizer without [audioEnergies] has nothing to follow and
/// stays the still the capture took.
Future<Map<String, List<ExportedLayerFrame>>> stickerLayerFrames(
  List<ExportedLayer> layers,
  TransitionTimelineMap timelineMap, [
  Float32List? audioEnergies,
]) async {
  final editorDuration = timelineMap.editorDuration;
  final frames = <String, List<ExportedLayerFrame>>{};
  Float32List? soundLevels;
  for (final item in layers) {
    final _StickerPaint? paint;
    final info = InfoStickerData.of(item.layer);
    final social = SocialStickerData.of(item.layer);
    if (info != null && info.kind == InfoStickerKind.recTimer) {
      paint = _StickerPaint(
        aspectRatio: recTimerDesignSize.aspectRatio,
        paint: (canvas, size, shown) =>
            paintRecTimer(canvas, size, style: info.style, elapsed: shown),
      );
    } else if (social != null &&
        social.isAnimated &&
        (!social.listensToSound || audioEnergies != null)) {
      if (social.listensToSound) {
        soundLevels ??= soundCreditLevels(audioEnergies!);
      }
      final levels = social.listensToSound ? soundLevels : null;
      final length = timelineMap.outputDuration;
      paint = _StickerPaint(
        aspectRatio: soundCreditSize(social).aspectRatio,
        paint: (canvas, size, shown) {
          final time = timelineMap.editorToOutput(shown);
          paintSoundCredit(
            canvas,
            size,
            data: social,
            motion: SoundCreditMotion(
              time: time,
              progress: length > Duration.zero
                  ? time.inMicroseconds / length.inMicroseconds
                  : 0,
              levels: soundCreditLevelsAt(levels, time),
            ),
          );
        },
      );
    } else {
      paint = null;
    }
    if (paint == null) continue;
    final stopwatch = clock.stopwatch()..start();
    frames[item.layer.id] = await _framesOf(item, paint, editorDuration);
    Log.debug(
      'Painted ${frames[item.layer.id]!.length} frames of a moving sticker '
      'of ${item.logicalSize} logical px for layer ${item.layer.id} in '
      '${stopwatch.elapsedMilliseconds} ms',
      name: 'StickerFrames',
      category: LogCategory.video,
    );
  }
  return frames;
}

/// How a moving sticker is painted: [paint] draws it at an editor time into
/// a box of [aspectRatio], the sticker's own, before any turn.
class _StickerPaint {
  const _StickerPaint({required this.aspectRatio, required this.paint});

  final double aspectRatio;
  final void Function(ui.Canvas canvas, Size size, Duration shown) paint;
}

/// [layers] with every moving sticker among them swapped for a
/// [StickerFramesExportedLayer] that brings the frames it exports as; see
/// [stickerLayerFrames]. A sticker without an end moves until
/// [timelineMap]'s editor timeline ends.
Future<List<ExportedLayer>> withStickerFrames(
  List<ExportedLayer> layers,
  TransitionTimelineMap timelineMap, [
  Float32List? audioEnergies,
]) async {
  final frames = await stickerLayerFrames(layers, timelineMap, audioEnergies);
  return [
    for (final item in layers)
      if (frames[item.layer.id] case final timerFrames?)
        StickerFramesExportedLayer(item, timerFrames)
      else
        item,
  ];
}

/// A captured moving sticker that exports as [timerFrames], painted for every
/// frame it shows, instead of the one still the capture took.
class StickerFramesExportedLayer extends ExportedLayer {
  /// [captured] exporting as [timerFrames].
  StickerFramesExportedLayer(ExportedLayer captured, this.timerFrames)
    : super(
        layer: captured.layer,
        bytes: captured.bytes,
        logicalSize: captured.logicalSize,
        boxSize: captured.boxSize,
        highlightBytes: captured.highlightBytes,
        revealBytes: captured.revealBytes,
      );

  /// The frames the sticker exports as, one after the other.
  final List<ExportedLayerFrame> timerFrames;

  @override
  List<ExportedLayerFrame> get frames => timerFrames;
}

/// The time windows of a timer from [start] until [end], or until the
/// video ends when [end] is `null`: one for each of [framesPerSecond] frames
/// a second of the video, each with the time it shows, cut at the timer's
/// own start and end.
List<({Duration shown, Duration? start, Duration? end})> stickerFrameWindows({
  required Duration? start,
  required Duration? end,
  required Duration editorDuration,
  double framesPerSecond = stickerFramesPerSecond,
}) {
  final from = start ?? Duration.zero;
  final to = end ?? editorDuration;
  // Each frame's own time, rounded to the microsecond. Adding up a rounded
  // step instead falls behind: thirty steps of 33333 µs end short of a
  // second, and the timer read 00:99 on the frame at one second.
  Duration frameTime(int index) => Duration(
    microseconds: (index * Duration.microsecondsPerSecond / framesPerSecond)
        .round(),
  );
  var index =
      (from.inMicroseconds * framesPerSecond / Duration.microsecondsPerSecond)
          .floor();
  while (index > 0 && frameTime(index) > from) {
    index--;
  }
  final windows = <({Duration shown, Duration? start, Duration? end})>[];
  for (; frameTime(index) < to; index++) {
    final shown = frameTime(index);
    final windowEnd = frameTime(index + 1);
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

/// How many frames a second a timer painted [frame] pixels large that runs
/// for [span] changes: [stickerFramesPerSecond], or fewer when that many
/// frames would hold more than [stickerFramePixelBudget] pixels.
double stickerFramesPerSecondFor({
  required Size frame,
  required Duration span,
}) {
  final pixels = frame.width * frame.height;
  final seconds = span.inMicroseconds / Duration.microsecondsPerSecond;
  if (pixels <= 0 || seconds <= 0) return stickerFramesPerSecond;
  return math.min(
    stickerFramesPerSecond,
    stickerFramePixelBudget / pixels / seconds,
  );
}

Future<List<ExportedLayerFrame>> _framesOf(
  ExportedLayer item,
  _StickerPaint paint,
  Duration editorDuration,
) async {
  final layer = item.layer;
  final pixelRatio = await _capturedPixelRatio(item);
  final box =
      _unturnedSize(item.logicalSize, layer.rotation, paint.aspectRatio) *
      pixelRatio;
  final span =
      (layer.endTime ?? editorDuration) - (layer.startTime ?? Duration.zero);
  final windows = stickerFrameWindows(
    start: layer.startTime,
    end: layer.endTime,
    editorDuration: editorDuration,
    framesPerSecond: stickerFramesPerSecondFor(frame: box, span: span),
  );
  final frames = <ExportedLayerFrame>[];
  for (var i = 0; i < windows.length; i += _paintBatch) {
    frames.addAll(
      await Future.wait([
        for (final window in windows.skip(i).take(_paintBatch))
          _paintFrame(layer, paint, box, window.shown).then(
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

/// The sticker's own box, before the layer turned it into [turned].
///
/// The capture reports the box around the turned layer; the sticker's own
/// [aspect] ratio pins down the box it was turned from.
Size _unturnedSize(Size turned, double rotation, double aspect) {
  final cos = math.cos(rotation).abs();
  final sin = math.sin(rotation).abs();
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

/// The sticker at the editor time [shown], painted at [box] pixels and
/// finished the way the layer capture finishes a still: masked by a mask
/// that does not change, then turned, flipped and faded.
Future<Uint8List> _paintFrame(
  Layer layer,
  _StickerPaint paint,
  Size box,
  Duration shown,
) async {
  final width = box.width.ceil();
  final height = box.height.ceil();
  final recorder = ui.PictureRecorder();
  paint.paint(
    ui.Canvas(recorder),
    Size(width.toDouble(), height.toDouble()),
    shown,
  );
  final picture = recorder.endRecording();
  var image = await picture.toImage(width, height);
  picture.dispose();

  // A mask that changes over time is drawn by the renderer on every frame
  // (`ExportedLayer.divineShapeMaskForExport`); baked in, its first shape
  // would cut away what a later one shows.
  if (layer.mask case final mask? when !mask.hasKeyframes) {
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
