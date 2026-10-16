// ABOUTME: The export's second pass: composites every detached clip over the
// ABOUTME: finished timeline track, and decides whether it is needed at all

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;
import 'dart:ui' show Size;

import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/detached_clip_composite.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as path;
import 'package:pro_image_editor/pro_image_editor.dart' show ExportedLayer;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'DetachedClipRenderPass';

/// The export's second pass over a composition that contains detached clips.
///
/// The timeline track has to be rendered by the single-segment path — overlap
/// transitions, per-clip speed and reverse all live there, and a
/// [VideoComposition] layer accepts none of them — so a detached clip cannot
/// join it. It is composited over the finished track instead, as another layer
/// of a composition whose bottom layer is that track.
///
/// [prepare] answers whether the pass is needed and where the base render
/// should write; [composite] runs it. A composition with nothing detached
/// leaves both a no-op, so the ordinary export still pays for exactly one
/// encode.
class DetachedClipRenderPass {
  const DetachedClipRenderPass._({
    required this.basePath,
    required this.finalOutputPath,
    required this.partitioned,
    required this.cacheDir,
  });

  /// Where the base track render must write.
  ///
  /// The final output path when nothing is detached, so the base render *is*
  /// the export; a temp file otherwise, which [composite] reads back.
  final String basePath;

  final String finalOutputPath;
  final PartitionedLayers partitioned;
  final Directory cacheDir;

  /// Whether a second pass will run.
  bool get isActive => partitioned.detached.isNotEmpty;

  /// The layers the base render bakes in — those sitting under the lowest
  /// detached clip. An unreadable detached layer also supplies the complete
  /// stack so its raster fallback is not filtered out. Ordinary exports keep
  /// returning `null` and stay on the existing render path.
  List<ExportedLayer>? get baseImageLayers {
    if (isActive) return partitioned.below;
    final hasRescuedRaster = partitioned.below.any(
      (item) => DetachedClipLayerData.isDetachedClipLayer(item.layer),
    );
    return hasRescuedRaster ? partitioned.below : null;
  }

  /// Works out whether [capturedLayers] contains detached clips, and where the
  /// base track render should write as a result.
  static Future<DetachedClipRenderPass> prepare({
    required List<ExportedLayer> capturedLayers,
    required Directory cacheDir,
    required String finalOutputPath,
  }) async {
    final documentsPath = await getDocumentsPath();
    final partitioned = partitionDetachedClipLayers(
      capturedLayers,
      documentsPath,
    );
    return DetachedClipRenderPass._(
      basePath: partitioned.detached.isEmpty
          ? finalOutputPath
          : path.join(
              cacheDir.path,
              'divine_base_${DateTime.now().microsecondsSinceEpoch}.mp4',
            ),
      finalOutputPath: finalOutputPath,
      partitioned: partitioned,
      cacheDir: cacheDir,
    );
  }

  /// Composites every detached clip over the base track, returning the path of
  /// the finished export.
  ///
  /// Each detached clip becomes a layer placed with the same geometry its
  /// raster would have had. Layers that sat above the lowest detached clip on
  /// the canvas are baked on top as image layers, so a caption written over a
  /// detached clip stays over it.
  ///
  /// Audio visualizers above the clips are drawn from [audioEnergies]; see
  /// [VideoEditorRenderService.buildImageLayers].
  ///
  /// Returns [basePath] unchanged when there is nothing to composite.
  ///
  /// Throws a [VideoRenderFailedException] with
  /// [VideoRenderFailureReason.tooManyDetachedClips] when the encode still
  /// fails transiently after every retry, which is how Android reports a
  /// decoder it could not start (#10141). Any other [RenderEncoderException]
  /// is rethrown as is.
  Future<String> composite({
    required List<DivineVideoClip> clips,
    required Size? bodySize,
    required model.AspectRatio aspectRatio,
    required String taskId,
    required List<String> tempFilePaths,
    required Duration? maxOutputDuration,
    Float32List? audioEnergies,
  }) async {
    if (!isActive) return basePath;

    if (bodySize == null || bodySize.isEmpty) {
      // Layer offsets are meaningless without the body they were laid out
      // against. Ship the base track rather than stacking clips at a guessed
      // position — the same tolerance `buildImageLayers` applies.
      Log.warning(
        '⚠️ Skipping ${partitioned.detached.length} detached clip(s): the '
        'editor body size is unknown, so their positions cannot be resolved',
        name: _logName,
        category: LogCategory.video,
      );
      await File(basePath).rename(finalOutputPath);
      return finalOutputPath;
    }

    final base = EditorVideo.file(File(basePath));
    final metadata = await ProVideoEditor.instance.getMetadata(base);
    final videoSize = metadata.resolution;
    final timelineMap = TransitionTimelineMap.fromClips(clips);

    final layers = <VideoLayer>[
      VideoLayer(clips: [VideoSegment(video: base)]),
    ];

    for (final item in partitioned.detached) {
      _throwIfCancelled(taskId);
      final (video, flattened) = await _resolveVideo(
        item.clip,
        tempFilePaths: tempFilePaths,
        ownerTaskId: taskId,
      );
      layers.add(
        buildDetachedClipVideoLayer(
          item: item,
          resolvedVideo: video,
          bodySize: bodySize,
          videoSize: videoSize,
          targetAspectRatio: aspectRatio.value,
          timelineMap: timelineMap,
          speedFlattened: flattened,
          mask: await _maskMatte(
            item,
            detachedClipExportSize(
              item: item,
              bodySize: bodySize,
              videoSize: videoSize,
              targetAspectRatio: aspectRatio.value,
            ),
          ),
        ),
      );
    }

    final task = VideoRenderData(
      id: taskId,
      shouldOptimizeForNetworkUse: true,
      endTime: maxOutputDuration,
      composition: VideoComposition(canvasSize: videoSize, layers: layers),
      imageLayers: VideoEditorRenderService.buildImageLayers(
        capturedLayers: partitioned.above,
        bodySize: bodySize,
        videoSize: videoSize,
        targetAspectRatio: aspectRatio.value,
        timelineMap: timelineMap,
        // Valid detached clips were already removed by the partition. Anything
        // with only the kind marker left here is the deliberately rescued
        // raster fallback for unreadable media and must stay visible.
        excludeDetachedClips: false,
        audioEnergies: audioEnergies,
      ),
      imageBytesWithCropping: true,
      qualityConfig: VideoQualityConfig.custom(
        bitrate: VideoEditorConstants.quality.bitrate,
        resolution: VideoEditorConstants.quality.resolutionForAspectRatio(
          aspectRatio,
        ),
      ),
    );

    try {
      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: task,
        encode: (attemptTask) =>
            VideoEditorRenderService.renderNativeVideoToFile(
              finalOutputPath,
              attemptTask,
              reuseActiveCancellation: true,
            ),
        fallbackAspectRatio: aspectRatio,
        ownerTaskId: taskId,
      );
    } on RenderEncoderException catch (error, stackTrace) {
      // Codecs still out of reach after every retry. The base track was just
      // encoded with the same encoder, so what this pass cannot get is a
      // decoder for each detached clip: `pro_video_editor` reports a starved
      // decoder as a transient encoder failure too, and on a Galaxy S26 that
      // is how 12 detached clips failed (#10141). A retry hits the same limit.
      if (!error.isTransient) rethrow;
      Log.warning(
        '⚠️ Could not get a decoder for each of '
        '${partitioned.detached.length} detached clip(s): $error',
        name: _logName,
        category: LogCategory.video,
      );
      // Thrown with the native failure's own stack, so the crash report the
      // export sends for it matches the one it sent before this had a reason
      // of its own.
      Error.throwWithStackTrace(
        VideoRenderFailedException(
          VideoRenderFailureReason.tooManyDetachedClips,
          cause: error,
        ),
        stackTrace,
      );
    }

    return finalOutputPath;
  }

  /// The media a detached [clip] contributes to the composition.
  ///
  /// Returns the clip's own file unchanged when it plays at normal speed. A
  /// clip carrying a speed is re-rendered with the speed baked in, because
  /// [VideoLayer] asserts against `playbackSpeed` — the second element of the
  /// record says which of the two came back, since a flattened file starts at
  /// zero instead of at the clip's trim point.
  Future<(EditorVideo, bool)> _resolveVideo(
    DivineVideoClip clip, {
    required List<String> tempFilePaths,
    required String ownerTaskId,
  }) async {
    final speed = clip.playbackSpeed;
    if (speed == null || speed == 1.0) return (clip.requireVideo, false);

    final flattenedPath = path.join(
      cacheDir.path,
      'detached_${clip.id}_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    tempFilePaths.add(flattenedPath);

    await VideoEditorRenderService.renderNativeVideoToFile(
      flattenedPath,
      VideoRenderData(
        id: '${ownerTaskId}_detached_${clip.id}',
        videoSegments: [
          VideoSegment(
            video: clip.requireVideo,
            startTime: clip.trimStart == Duration.zero ? null : clip.trimStart,
            endTime: clip.trimStart + clip.trimmedDuration,
            playbackSpeed: speed,
          ),
        ],
      ),
      reuseActiveCancellation: true,
    );
    return (EditorVideo.file(File(flattenedPath)), true);
  }

  /// The shape mask of [item] as an alpha matte of [size], or `null` when the
  /// layer has none.
  ///
  /// Rendered by the same painter the canvas masks the layer with, at the size
  /// the clip is placed at, so the soft edge is as wide in the file as on the
  /// canvas.
  static Future<EditorLayerImage?> _maskMatte(
    DetachedClipExportLayer item,
    Size size,
  ) async {
    final mask = item.layer.mask;
    if (mask == null || size.isEmpty) return null;
    final image = await mask.toImage(size);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError(
          'The mask of detached clip ${item.clip.id} could not '
          'be encoded',
        );
      }
      return EditorLayerImage.memory(data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  static void _throwIfCancelled(String taskId) {
    if (RenderCancellationRegistry.consumeCancellation(taskId)) {
      throw const RenderCanceledException();
    }
  }
}
