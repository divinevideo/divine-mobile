// ABOUTME: Renders a split-screen layout into one clip: each cell's footage
// ABOUTME: framed the way the user left it, a shorter cell held on its end

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Alignment;
import 'package:models/models.dart' as model show AspectRatio, ClipSourceCredit;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/extensions/equalizer_settings_mapping.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'SplitScreenLayoutRenderService';

/// One filled cell of a layout, ready to render: its clip, where the cell sits
/// in fractions of the frame, and how the user framed the clip in it.
typedef SplitScreenRenderCell = ({
  DivineVideoClip clip,
  ui.Rect rect,
  Alignment alignment,
  double zoom,
});

/// Renders a split-screen layout into a single clip.
///
/// Every cell is a layer of one composition, so the layout is a single encode
/// however many cells it has; only a sped-up cell is rendered at its speed
/// first. A cell shows exactly what the layout screen showed: where the user
/// zoomed or slid the footage, the clip is drawn larger than its cell and an
/// alpha matte cuts it back to the cell, since the renderer only crops the
/// centre of a frame on its own.
abstract final class SplitScreenLayoutRenderService {
  /// How far before a cell's end its last frame is read from — see
  /// `FreezeFrameRenderService`: the end itself lies past the last frame.
  static const _lastFrameLead = Duration(milliseconds: 17);

  /// How long before a cell's footage ends its held last frame appears. The
  /// two show the same picture, so the overlap hides a frame the encoder might
  /// otherwise leave in the border colour between them.
  static const _holdOverlap = Duration(milliseconds: 34);

  /// Longest side of a matte. A matte is a hard-edged rectangle, so a coarser
  /// one costs nothing visible, while one the size of a 4× zoomed clip would
  /// cost tens of megabytes to decode.
  static const double _maxMatteSide = 2048;

  /// Longest side the last frame of a held cell is read at.
  static const double _maxHoldFrameSide = 1920;

  static const _holdFrameJpegQuality = 95;

  /// The size [video]'s frames are shown at, rotation applied, or `null` when
  /// it cannot be read.
  static Future<ui.Size?> videoSize(EditorVideo video) async {
    try {
      final resolution = (await ProVideoEditor.instance.getMetadata(video))
          .resolution;
      if (resolution.width <= 0 || resolution.height <= 0) return null;
      return resolution;
    } catch (e) {
      Log.warning(
        '⚠️ Could not read a layout clip resolution: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Renders [cells] into one clip of [aspectRatio], as long as its longest
  /// cell, with [backgroundColor] in the gaps and wherever no cell is.
  ///
  /// Cells are stacked in list order, so a picture-in-picture window listed
  /// after the clip it sits on stays on top. A cell that ends before the
  /// layout does holds its last frame until the end.
  ///
  /// Returns `null` when the render produced no file. Throws whatever the
  /// renderer throws, a [RenderCanceledException] included, and an
  /// [Exception] when a cell's clip cannot be read; nothing is left on disk
  /// then. [taskId] keys the encoder's progress stream.
  static Future<DivineVideoClip?> render({
    required List<SplitScreenRenderCell> cells,
    required model.AspectRatio aspectRatio,
    required ui.Color backgroundColor,
    required String taskId,
  }) async {
    if (cells.isEmpty) return null;
    final canvas = VideoEditorConstants.quality.resolutionForAspectRatio(
      aspectRatio,
    );
    final duration = cells
        .map((cell) => cell.clip.playbackDuration)
        .reduce((a, b) => a > b ? a : b);
    final pixelRects = [
      for (final cell in cells) _pixelRect(cell.rect, canvas),
    ];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final outputPath = p.join(
      await getDocumentsPath(),
      'split_layout_$stamp.mp4',
    );
    final tempPaths = <String>[];

    try {
      final layers = <VideoLayer>[];
      final holds = <ImageLayer>[];
      for (final (index, cell) in cells.indexed) {
        // Under the layout's own id, so its progress and a cancel of the
        // layout reach a sped-up cell's render too.
        final source = await _footageOf(
          cell.clip,
          taskId: taskId,
          tempPaths: tempPaths,
        );
        final size = await videoSize(source.video);
        if (size == null) throw _UnreadableLayoutClip(cell.clip.id);
        final cellRect = pixelRects[index];
        layers.add(
          await _layer(
            cell: cell,
            source: source,
            cellRect: cellRect,
            sourceAspectRatio: size.aspectRatio,
          ),
        );

        final end = cell.clip.playbackDuration;
        if (end < duration - _holdOverlap) {
          final hold = await _lastFrameHold(
            cell: cell,
            source: source,
            sourceSize: size,
            cellRect: cellRect,
            coveredBy: pixelRects.skip(index + 1),
            start: end > _holdOverlap ? end - _holdOverlap : Duration.zero,
          );
          if (hold != null) holds.add(hold);
        }
      }

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: VideoRenderData(
          id: taskId,
          shouldOptimizeForNetworkUse: true,
          endTime: duration,
          composition: VideoComposition(
            canvasSize: canvas,
            backgroundColor: backgroundColor,
            layers: layers,
          ),
          imageLayers: holds,
          // Without an explicit scale, iOS and macOS resize a composition by
          // its first cell's source size; the cells and held frames are
          // placed in canvas pixels, so the output must stay at the canvas.
          transform: const ExportTransform(scaleX: 1, scaleY: 1),
          qualityConfig: VideoQualityConfig.custom(
            bitrate: VideoEditorConstants.quality.bitrate,
            resolution: canvas,
          ),
        ),
        encode: (task) =>
            VideoEditorRenderService.cancelAndRender(outputPath, task),
        fallbackAspectRatio: aspectRatio,
        ownerTaskId: taskId,
      );
    } catch (_) {
      await _deleteQuietly(outputPath);
      rethrow;
    } finally {
      for (final path in tempPaths) {
        await _deleteQuietly(path);
      }
    }

    if (!File(outputPath).existsSync()) {
      Log.error(
        'Split-screen layout render produced no file',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    return _clipFor(
      outputPath,
      id: 'split_layout_$stamp',
      cells: [for (final cell in cells) cell.clip],
      aspectRatio: aspectRatio,
      expectedDuration: duration,
    );
  }

  /// [rect], in fractions of a [canvas], in whole canvas pixels — so the
  /// border between two cells is the same width on every edge.
  static ui.Rect _pixelRect(ui.Rect rect, ui.Size canvas) => ui.Rect.fromLTRB(
    (rect.left * canvas.width).roundToDouble(),
    (rect.top * canvas.height).roundToDouble(),
    (rect.right * canvas.width).roundToDouble(),
    (rect.bottom * canvas.height).roundToDouble(),
  );

  /// The media [clip] contributes and the part of it that plays.
  ///
  /// A layer cannot change speed, so a sped-up clip is first rendered at its
  /// speed into a file of [tempPaths]; that file already starts at the trim.
  static Future<({EditorVideo video, Duration start, Duration end})> _footageOf(
    DivineVideoClip clip, {
    required String taskId,
    required List<String> tempPaths,
  }) async {
    final start = clip.trimStart;
    final end = clip.trimStart + clip.trimmedDuration;
    final speed = clip.playbackSpeed;
    if (speed == null || speed == 1.0) {
      return (video: clip.requireVideo, start: start, end: end);
    }

    final path = p.join(
      (await getTemporaryDirectory()).path,
      'split_layout_${clip.id}_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    tempPaths.add(path);
    await VideoEditorRenderService.cancelAndRender(
      path,
      VideoRenderData(
        id: taskId,
        videoSegments: [
          VideoSegment(
            video: clip.requireVideo,
            startTime: start == Duration.zero ? null : start,
            endTime: end,
            playbackSpeed: speed,
          ),
        ],
      ),
    );
    return (
      video: EditorVideo.file(File(path)),
      start: Duration.zero,
      end: clip.playbackDuration,
    );
  }

  static Future<VideoLayer> _layer({
    required SplitScreenRenderCell cell,
    required ({EditorVideo video, Duration start, Duration end}) source,
    required ui.Rect cellRect,
    required double sourceAspectRatio,
  }) async {
    final crop = splitScreenCropRect(
      sourceAspectRatio: sourceAspectRatio,
      cellAspectRatio: cellRect.width / cellRect.height,
      alignment: cell.alignment,
      zoom: cell.zoom,
    );
    // The renderer's own cover fit crops the centre of the frame, which is
    // what an untouched cell shows; anything else needs the matte.
    final centred =
        cell.zoom <= 1 + _epsilon &&
        (crop.center - const ui.Offset(0.5, 0.5)).distance < _epsilon;
    final footage = centred
        ? cellRect
        : splitScreenFootageRect(
            cellSize: cellRect.size,
            sourceAspectRatio: sourceAspectRatio,
            alignment: cell.alignment,
            zoom: cell.zoom,
          ).shift(cellRect.topLeft);

    final clip = cell.clip;
    // No chromaKey: a clip's key is burned into its file already, the way
    // the export never keys a timeline clip again.
    return VideoLayer(
      mask: centred ? null : await _matte(crop, footage.size),
      clips: [
        VideoSegment(
          video: source.video,
          startTime: source.start == Duration.zero ? null : source.start,
          endTime: source.end,
          volume: clip.volume,
          equalizer: clip.equalizer.toRenderEqualizer(),
          transform: SegmentTransform(
            offset: footage.topLeft,
            size: footage.size,
            fit: centred ? SegmentFit.cover : SegmentFit.fill,
          ),
        ),
      ],
    );
  }

  static const double _epsilon = 1e-6;

  /// An alpha matte over a clip's whole frame, opaque only over [crop] — the
  /// part of the frame its cell shows. It is drawn at the shape of [footage],
  /// the box the frame is stretched over, so the cut lands on whole pixels.
  static Future<EditorLayerImage> _matte(ui.Rect crop, ui.Size footage) async {
    final scale = math.min(1, _maxMatteSide / footage.longestSide);
    final width = math.max(2, (footage.width * scale).round());
    final height = math.max(2, (footage.height * scale).round());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTRB(
        (crop.left * width).roundToDouble(),
        (crop.top * height).roundToDouble(),
        (crop.right * width).roundToDouble(),
        (crop.bottom * height).roundToDouble(),
      ),
      // Only the matte's alpha counts, and a plain paint is opaque.
      ui.Paint(),
    );
    return EditorLayerImage.memory(
      await _encodePng(recorder.endRecording(), width, height),
    );
  }

  /// The last frame of [cell]'s footage, framed like the cell, shown in it
  /// from [start] to the end of the layout.
  ///
  /// Image layers are drawn over every video layer, so wherever a cell after
  /// this one — [coveredBy] — sits on top of it, the frame is cut out and that
  /// cell's video keeps showing through.
  ///
  /// Returns `null` when the frame cannot be read; the cell then shows the
  /// border colour once its footage ends, which beats failing the layout.
  static Future<ImageLayer?> _lastFrameHold({
    required SplitScreenRenderCell cell,
    required ({EditorVideo video, Duration start, Duration end}) source,
    required ui.Size sourceSize,
    required ui.Rect cellRect,
    required Iterable<ui.Rect> coveredBy,
    required Duration start,
  }) async {
    final lastFrame = source.end - _lastFrameLead;
    final position = lastFrame > source.start ? lastFrame : source.start;
    final scale = math.min(1, _maxHoldFrameSide / sourceSize.longestSide);
    final Uint8List? frame;
    try {
      final thumbnails = await ProVideoEditor.instance.getThumbnails(
        ThumbnailConfigs(
          video: source.video,
          outputSize: ui.Size(
            (sourceSize.width * scale).roundToDouble(),
            (sourceSize.height * scale).roundToDouble(),
          ),
          timestamps: [position],
          jpegQuality: _holdFrameJpegQuality,
        ),
      );
      frame = thumbnails.firstOrNull;
    } catch (e) {
      Log.warning(
        '⚠️ Could not read the last frame of layout clip ${cell.clip.id}: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    if (frame == null || frame.isEmpty) return null;

    final codec = await ui.instantiateImageCodec(frame);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    try {
      final width = cellRect.width.round();
      final height = cellRect.height.round();
      final crop = splitScreenCropRect(
        sourceAspectRatio: sourceSize.aspectRatio,
        cellAspectRatio: cellRect.width / cellRect.height,
        alignment: cell.alignment,
        zoom: cell.zoom,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawImageRect(
          image,
          ui.Rect.fromLTWH(
            crop.left * image.width,
            crop.top * image.height,
            crop.width * image.width,
            crop.height * image.height,
          ),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
      for (final above in coveredBy) {
        final overlap = above.intersect(cellRect);
        if (overlap.isEmpty) continue;
        canvas.drawRect(
          overlap.shift(-cellRect.topLeft),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }
      return ImageLayer(
        image: EditorLayerImage.memory(
          await _encodePng(recorder.endRecording(), width, height),
        ),
        startTime: start,
        offset: cellRect.topLeft,
        size: cellRect.size,
      );
    } finally {
      image.dispose();
    }
  }

  static Future<Uint8List> _encodePng(
    ui.Picture picture,
    int width,
    int height,
  ) async {
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('A split-screen layout image could not be encoded');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// The clip the rendered layout at [path] becomes.
  ///
  /// It is signed as a composite of [cells], the way a merge is, so it keeps
  /// their camera proof. Left unsigned, for example offline, it remembers the
  /// media it was made from, so an edit of it is signed against that.
  static Future<DivineVideoClip> _clipFor(
    String path, {
    required String id,
    required List<DivineVideoClip> cells,
    required model.AspectRatio aspectRatio,
    required Duration expectedDuration,
  }) async {
    final video = EditorVideo.file(File(path));
    Duration? probed;
    try {
      probed = (await ProVideoEditor.instance.getMetadata(video)).duration;
    } catch (e) {
      Log.warning(
        '⚠️ Could not probe the layout render; assuming '
        '${expectedDuration.inMilliseconds}ms: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
    final thumbnail = await VideoThumbnailService.extractThumbnail(
      videoPath: path,
    );
    final proof = await VideoEditorRenderService.proofRenderedVideo(
      File(path),
      clips: cells,
    );

    final credits = <model.ClipSourceCredit>[];
    final seen = <String>{};
    for (final clip in cells) {
      for (final credit in clip.sourceCredits) {
        if (seen.add(credit.identityKey)) credits.add(credit);
      }
    }

    return DivineVideoClip(
      id: id,
      video: video,
      duration: probed != null && probed > Duration.zero
          ? probed
          : expectedDuration,
      recordedAt: DateTime.now(),
      targetAspectRatio: aspectRatio,
      originalAspectRatio: aspectRatio.value,
      thumbnailPath: thumbnail?.path,
      thumbnailTimestamp: thumbnail?.timestamp,
      sourceCredits: credits,
      proofManifestJson: proof == null ? null : jsonEncode(proof),
      derivedFrom: proof?.c2paManifestId == null
          ? NativeProofModeService.editSources(clips: cells)
          : null,
    );
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (e) {
      Log.warning(
        '⚠️ Failed to delete layout render file $path: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}

/// A cell whose clip cannot be read, such as one moved or damaged since it
/// was picked. Not a [StateError]: that is an expected failure the user can
/// recover from, not a broken invariant worth a crash report.
class _UnreadableLayoutClip implements Exception {
  const _UnreadableLayoutClip(this.clipId);

  final String clipId;

  @override
  String toString() => 'UnreadableLayoutClip: $clipId';
}
