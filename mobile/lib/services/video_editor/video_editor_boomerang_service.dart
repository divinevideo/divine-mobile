// ABOUTME: Renders a clip that plays its footage forward and then backward
// ABOUTME: (a boomerang) into a new file, so preview and export agree.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// A rendered boomerang: its file, how long it plays at normal speed, and how
/// much of that is the forward part.
typedef BoomerangRender = ({
  EditorVideo video,
  Duration duration,
  Duration forwardDuration,
});

/// Service for rendering a boomerang of a clip to a new local file.
class VideoEditorBoomerangService {
  /// Frame rate assumed when the source does not report one.
  static const fallbackFrameRate = 30.0;

  /// The render id of the boomerang of the clip [clipId], namespaced so it
  /// cannot collide with a reverse or transform of the same clip.
  static String renderIdFor(String clipId) => '${clipId}_boomerang';

  /// Renders the clip's **visible window** `[trimStart, duration - trimEnd]`
  /// forward and then backward into a standalone file.
  ///
  /// The backward part leaves out the window's last frame, which the forward
  /// part just showed, and its first frame, which the forward part shows
  /// again when the clip loops or a boomerang repeats. Without that the bounce
  /// holds each turn for two frames.
  ///
  /// A frame rarely lasts a whole number of microseconds (33333.3 at 30 fps),
  /// and the renderers cut a reversed segment differently, so each platform
  /// rounds the cuts its own way; both are measured frame-exact on device.
  /// Android keeps the frames whose timestamps, whole microseconds rounded
  /// down, fall in `[startTime, endTime)`, so its cuts round onto the frames
  /// next to the turns. iOS and macOS reverse in one-frame slices from the
  /// end back and show the frame each slice starts on: their cuts sit just
  /// past a frame boundary, the start one microsecond further so no sliver of
  /// the frame before it is left over to become a frame of its own.
  ///
  /// Speed, volume and the equalizer are not baked in: the boomerang clip
  /// keeps playing at the clip's own settings.
  static Future<BoomerangRender> renderBoomerang({
    required DivineVideoClip sourceClip,
    required String renderId,
  }) async {
    final documentsPath = await getDocumentsPath();
    final inputPath = await sourceClip.requireVideo.safeFilePath();
    final outputPath = p.join(
      documentsPath,
      '${sourceClip.id}_boomerang_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    final source = EditorVideo.file(inputPath);
    final frameUs = await _frameMicroseconds(source);
    final windowStart = sourceClip.trimStart;
    final windowEnd = sourceClip.duration - sourceClip.trimEnd;
    final window = windowEnd - windowStart;
    // A window too short to lose two frames bounces whole.
    final dropTurns = window.inMicroseconds > frameUs * 3;
    final byTimestamp = defaultTargetPlatform == TargetPlatform.android;
    final startCut = byTimestamp ? frameUs.floor() : frameUs.ceil() + 1;
    final endCut = byTimestamp ? frameUs.ceil() : frameUs.floor();
    final backwardStart = dropTurns
        ? windowStart + Duration(microseconds: startCut)
        : windowStart;
    final backwardEnd = dropTurns
        ? windowEnd - Duration(microseconds: endCut)
        : windowEnd;

    Log.info(
      '🪃 Rendering boomerang of clip ${sourceClip.id} to $outputPath',
      name: 'VideoEditorBoomerangService',
      category: LogCategory.video,
    );

    final outputFile = File(outputPath);
    try {
      await VideoEditorRenderService.renderNativeVideoToFile(
        outputPath,
        VideoRenderData(
          id: renderId,
          videoSegments: [
            // The motion is baked in: each frame keeps it both ways.
            VideoSegment(
              video: source,
              startTime: windowStart == Duration.zero ? null : windowStart,
              endTime: windowEnd,
              keyframes: sourceClip.keyframes,
            ),
            VideoSegment(
              video: source,
              startTime: backwardStart == Duration.zero ? null : backwardStart,
              endTime: backwardEnd,
              reverseVideo: true,
              keyframes: sourceClip.keyframes,
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
            '⚠️ Failed to delete partial boomerang output $outputPath: '
            '$deleteError',
            name: 'VideoEditorBoomerangService',
            category: LogCategory.video,
          );
        }
      }
      rethrow;
    }

    Log.info(
      '✅ Boomerang render complete for ${sourceClip.id}',
      name: 'VideoEditorBoomerangService',
      category: LogCategory.video,
    );

    return (
      video: EditorVideo.file(outputPath),
      duration: window + (backwardEnd - backwardStart),
      forwardDuration: window,
    );
  }

  /// How many microseconds one frame of [video] lasts, from the frame rate it
  /// reports. Rarely a whole number: 33333.3 at 30 fps.
  static Future<double> _frameMicroseconds(EditorVideo video) async {
    double? frameRate;
    try {
      frameRate = (await ProVideoEditor.instance.getMetadata(video)).frameRate;
    } catch (e) {
      // Only the two turning frames depend on it, so a missing rate is not
      // worth failing the render over.
      Log.warning(
        '⚠️ Could not read the frame rate for a boomerang: $e',
        name: 'VideoEditorBoomerangService',
        category: LogCategory.video,
      );
    }
    final rate = frameRate != null && frameRate.isFinite && frameRate > 0
        ? frameRate
        : fallbackFrameRate;
    return Duration.microsecondsPerSecond / rate;
  }
}
