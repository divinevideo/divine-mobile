import 'dart:io';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for baking a crop / 90°-rotation / flip transform into a new local
/// clip file.
class VideoEditorTransformService {
  /// Renders the full clip with [transform] applied and returns the new file.
  ///
  /// [transform] is already expressed in the clip's pixel space (the crop
  /// rect, rotate turns and flips come straight from the editor), so it is
  /// baked into the output via [ExportTransform] and the rendered file needs
  /// no further transform on export. Trim bounds stay in clip state and are
  /// derived from the rendered file, so the full clip is rendered here rather
  /// than the trimmed segment.
  static Future<EditorVideo> transformClip({
    required DivineVideoClip sourceClip,
    required ExportTransform transform,
    required String renderId,
  }) async {
    final documentsPath = await getDocumentsPath();
    final inputPath = await sourceClip.requireVideo.safeFilePath();
    // Unique per render so transforming the same clip twice never targets the
    // previous output (which is the new input). The prior file stays on disk
    // for the session — undo history points back to it — and `ClipEditorBloc`
    // queues it for the editor session's deferred cleanup.
    final outputPath = p.join(
      documentsPath,
      '${sourceClip.id}_transformed_'
      '${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    // Defensive: refuse to render when the input path collides with the
    // output path. We delete the output file before rendering, so a collision
    // would destroy the source video in-place.
    if (p.equals(inputPath, outputPath)) {
      throw StateError(
        'Transform render aborted: input path equals output path ($inputPath)',
      );
    }

    final inputVideo = EditorVideo.file(inputPath);
    final outputFile = File(outputPath);

    Log.info(
      '🔳 Rendering transformed clip ${sourceClip.id} to $outputPath',
      name: 'VideoEditorTransformService',
      category: LogCategory.video,
    );

    try {
      if (outputFile.existsSync()) {
        await outputFile.delete();
        Log.debug(
          '🗑️ Deleted stale transform output: $outputPath',
          name: 'VideoEditorTransformService',
          category: LogCategory.video,
        );
      }

      await VideoEditorRenderService.renderNativeVideoToFile(
        outputPath,
        VideoRenderData(
          id: renderId,
          videoSegments: [VideoSegment(video: inputVideo)],
          shouldOptimizeForNetworkUse: true,
          transform: transform,
        ),
      );
    } catch (e) {
      if (outputFile.existsSync()) {
        try {
          await outputFile.delete();
        } catch (deleteError) {
          Log.warning(
            '⚠️ Failed to delete partial transform output $outputPath: '
            '$deleteError',
            name: 'VideoEditorTransformService',
            category: LogCategory.video,
          );
        }
      }
      rethrow;
    }

    Log.info(
      '✅ Transform render complete for ${sourceClip.id}',
      name: 'VideoEditorTransformService',
      category: LogCategory.video,
    );

    return EditorVideo.file(outputPath);
  }

  /// The pixel aspect ratio of [video], or `null` when it cannot be read.
  ///
  /// Measured off the finished file rather than derived from the crop rect the
  /// editor returned. The renderer decides the final ordering of crop, rotate
  /// and flip and rounds to even pixel dimensions, so the only dependable
  /// answer to "what shape did this come out" is the file itself.
  static Future<double?> aspectRatioOf(EditorVideo video) async {
    try {
      final resolution = (await ProVideoEditor.instance.getMetadata(
        video,
      )).resolution;
      if (resolution.width <= 0 || resolution.height <= 0) return null;
      return resolution.width / resolution.height;
    } catch (e) {
      Log.warning(
        '⚠️ Could not read the transformed clip resolution: $e',
        name: 'VideoEditorTransformService',
        category: LogCategory.video,
      );
      return null;
    }
  }
}
