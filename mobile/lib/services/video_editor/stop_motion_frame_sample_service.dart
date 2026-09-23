// ABOUTME: Samples a video clip into stop-motion stills at the session's hold
// ABOUTME: The reverse of StopMotionRenderService: footage in, frames out

import 'dart:io';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Turns a video clip into the stills a stop-motion composition edits.
///
/// A frame-first session has no player, so a video clip can only join it as
/// stills: one frame every hold across the clip's trimmed range, each held for
/// that hold, so the footage plays back at its own speed in the cadence the
/// rest of the composition already uses. That is the mirror image of
/// `StopMotionRenderService.materialize`, which takes a set the other way into
/// a video composition.
class StopMotionFrameSampleService {
  StopMotionFrameSampleService._();

  static const _logName = 'StopMotionFrameSampleService';

  /// Prefix of every still this service writes. Distinct from captured and
  /// transformed stills so a sampled frame is recognisable on disk.
  static const _fileNamePrefix = 'stop_motion_frame_sampled';

  /// Source-time positions sampled from [clip]: one every hold of
  /// [framesPerImage] output frames, from the trim-in point up to (never
  /// onto) the trim-out point, so a still is never asked for past the last
  /// decodable frame. A clip shorter than one hold still yields its first
  /// frame.
  ///
  /// Speed is deliberately ignored: a library clip carries none, and a still
  /// per hold of *source* time is what keeps the footage at its own pace.
  static List<Duration> sampleTimestamps(
    DivineVideoClip clip, {
    required int framesPerImage,
  }) {
    final hold = StopMotionFrameOps.framesPerImageToDuration(framesPerImage);
    final range = clip.trimmedDuration;
    final count = range < hold
        ? 1
        : range.inMicroseconds ~/ hold.inMicroseconds;
    return [
      for (var i = 0; i < count; i++)
        clip.trimStart + Duration(microseconds: hold.inMicroseconds * i),
    ];
  }

  /// Samples [clip] into stills held for [framesPerImage] output frames each,
  /// written to the documents directory (the only place a frame may live —
  /// `StopMotionClipFrame` persists its basename). [taskId] names the decode
  /// task; [onProgress] hears the share of positions resolved so far, since
  /// the frame stream carries its own progress and nothing reaches
  /// `ProVideoEditor.progressStreamById` for it.
  ///
  /// Every requested position is decoded in one native pass; a position the
  /// decoder cannot resolve is skipped rather than failing the clip, so the
  /// result can be shorter than [sampleTimestamps]. Returns the stills in
  /// source order, or `null` when not one frame came back. Anything written
  /// before a failure is deleted again, so a thrown error leaves nothing
  /// behind.
  ///
  /// Throws [StateError] if [clip] is a frames-only stop-motion clip — those
  /// already are stills, and a caller handing one here has the wrong clip.
  static Future<List<StopMotionClipFrame>?> sampleClip(
    DivineVideoClip clip, {
    required int framesPerImage,
    String? taskId,
    void Function(double progress)? onProgress,
  }) async {
    final video = clip.requireVideo;
    final hold = StopMotionFrameOps.framesPerImageToDuration(framesPerImage);
    final timestamps = sampleTimestamps(clip, framesPerImage: framesPerImage);
    final documentsPath = await getDocumentsPath();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final paths = List<String?>.filled(timestamps.length, null);

    Log.debug(
      '🎞️ Sampling clip ${clip.id} into ${timestamps.length} still(s) '
      '(hold: $framesPerImage frame(s))',
      name: _logName,
      category: LogCategory.video,
    );

    final stream = ProVideoEditor.instance.getThumbnailStream(
      ThumbnailConfigs(
        id: taskId,
        video: video,
        outputSize: VideoEditorConstants.quality.resolutionForAspectRatio(
          clip.targetAspectRatio,
        ),
        timestamps: timestamps,
      ),
    );

    try {
      await for (final frame in stream) {
        // A frame several positions resolve to is written once per position:
        // every still owns its file, which is what the cleanup that reclaims
        // a draft's frames assumes.
        for (final index in frame.indices) {
          final path = p.join(
            documentsPath,
            '${_fileNamePrefix}_${stamp}_$index.jpg',
          );
          await File(path).writeAsBytes(frame.bytes, flush: true);
          paths[index] = path;
        }
        onProgress?.call(frame.progress);
      }
    } catch (e) {
      await cleanupSampledFrames(paths.whereType<String>());
      rethrow;
    }

    final frames = [
      for (final path in paths)
        if (path != null) StopMotionClipFrame(path: path, duration: hold),
    ];
    if (frames.isEmpty) {
      Log.warning(
        '⚠️ Sampling clip ${clip.id} produced no still',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    if (frames.length < timestamps.length) {
      Log.warning(
        '⚠️ Sampling clip ${clip.id}: ${timestamps.length - frames.length} of '
        '${timestamps.length} position(s) did not decode',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return frames;
  }

  /// Deletes stills [sampleClip] wrote that never reached the timeline.
  ///
  /// Immediate rather than deferred: nothing in the editor history can point
  /// at a still that was never committed, so there is no undo to protect.
  static Future<void> cleanupSampledFrames(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } on FileSystemException catch (e) {
        Log.warning(
          '⚠️ Failed to delete sampled still $path: $e',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }
  }
}
