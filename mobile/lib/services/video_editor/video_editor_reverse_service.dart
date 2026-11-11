import 'dart:io';

import 'package:clock/clock.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for rendering a reversed clip to a new local file.
class VideoEditorReverseService {
  /// Renders the clip's **visible window** `[trimStart, duration - trimEnd]`
  /// in reverse to a standalone file.
  ///
  /// The window is baked into the output — the reversed file is exactly the
  /// visible segment reversed, so the caller treats the result as a standalone
  /// clip (trims reset, floor cleared). This is required for a trim-based split
  /// half, whose source file is shared with its sibling: reversing the whole
  /// file and keeping metadata trims would expose the sibling's frames because
  /// the split half's `duration` no longer equals the real file length. For an
  /// untrimmed clip the window is the whole file, so the output is unchanged.
  ///
  /// Every render writes a new file. A trimmed clip keeps no forward copy
  /// after its reverse, so reversing it again renders from the file the first
  /// reverse wrote, and undo history still plays earlier renders.
  static Future<EditorVideo> reverseClip({
    required DivineVideoClip sourceClip,
    required String renderId,
  }) async {
    final documentsPath = await getDocumentsPath();
    final inputPath = await sourceClip.requireVideo.safeFilePath();
    final outputPath = p.join(
      documentsPath,
      '${sourceClip.id}_reversed_${clock.now().microsecondsSinceEpoch}.mp4',
    );

    // Defensive: refuse to render when the input path collides with the
    // output path. We delete the output file before rendering, so a collision
    // would destroy the source video in-place.
    if (p.equals(inputPath, outputPath)) {
      throw StateError(
        'Reverse render aborted: input path equals output path ($inputPath)',
      );
    }

    final outputFile = File(outputPath);

    Log.info(
      '🔄 Rendering reversed clip ${sourceClip.id} to $outputPath',
      name: 'VideoEditorReverseService',
      category: LogCategory.video,
    );

    try {
      if (outputFile.existsSync()) {
        await outputFile.delete();
        Log.debug(
          '🗑️ Deleted stale reverse output: $outputPath',
          name: 'VideoEditorReverseService',
          category: LogCategory.video,
        );
      }

      // Bake the visible window into the reversed output: select
      // [trimStart, duration - trimEnd] on the source, then reverse it. For an
      // untrimmed clip this is the whole file, so the output is unchanged.
      final windowStart = sourceClip.trimStart;
      final windowEnd = sourceClip.duration - sourceClip.trimEnd;
      await VideoEditorRenderService.renderNativeVideoToFile(
        outputPath,
        VideoRenderData(
          id: renderId,
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(inputPath),
              startTime: windowStart == Duration.zero ? null : windowStart,
              endTime: windowEnd,
              reverseVideo: true,
            ),
          ],
        ),
      );
    } catch (e) {
      if (outputFile.existsSync()) {
        try {
          await outputFile.delete();
        } catch (deleteError) {
          Log.warning(
            '⚠️ Failed to delete partial reverse output $outputPath: '
            '$deleteError',
            name: 'VideoEditorReverseService',
            category: LogCategory.video,
          );
        }
      }
      rethrow;
    }

    Log.info(
      '✅ Reverse render complete for ${sourceClip.id}',
      name: 'VideoEditorReverseService',
      category: LogCategory.video,
    );

    return EditorVideo.file(outputPath);
  }
}
