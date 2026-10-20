// ABOUTME: Finds where the last clip can end so the video loops without a
// ABOUTME: visible jump: plain frame comparison from pro_video_editor (#10249).

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/loop_point_search.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Looks for the loop point [search] describes. Injected into the loop
/// suggestion cubit so tests can swap the analysis out.
typedef FindClipLoopPointFn = Future<VideoLoopPoint> Function({
  required LoopPointSearch search,
  required String taskId,
  void Function(double progress)? onProgress,
});

/// Stops the loop point search started under a task id.
typedef CancelClipLoopPointFn = Future<void> Function(String taskId);

/// Suggests where to trim the last clip so the video loops seamlessly
/// (#10249).
///
/// Plain frame comparison, no ML model, as agreed in #8543: small grayscale
/// frames near the end are compared with the first frames, together with
/// their neighbours so the motion has to run the same way too. Nothing in
/// the footage changes; the result is only a trim.
abstract class ClipLoopPointService {
  /// The task id for a loop point search on the clip [clipId].
  static String taskIdFor(String clipId) => '${clipId}_loop_point';

  /// Finds the end of the last clip within [LoopPointSearch.endFrom] and
  /// [LoopPointSearch.endTo] whose frame looks most like the video's first
  /// one. Runs under the preview render watchdog. [onProgress] reports 0..1.
  ///
  /// Throws a `RenderCanceledException` once [cancel] stopped it, a
  /// `VideoRenderFailedException` when the watchdog gave up on it, and a
  /// `PlatformException` when a clip cannot be decoded.
  static Future<VideoLoopPoint> findLoopPoint({
    required LoopPointSearch search,
    required String taskId,
    void Function(double progress)? onProgress,
  }) {
    return VideoRenderWatchdog.run(
      render: VideoLoopPointFinder.findLoopPoint(
        search.endVideo,
        startVideo: search.startVideo,
        start: search.start,
        end: search.end,
        endFrom: search.endFrom,
        endTo: search.endTo,
        // The preview keeps its own decoder while this runs.
        maxParallelDecoders: 1,
        id: taskId,
        onProgress: onProgress,
      ),
      taskId: taskId,
      cancelTask: cancel,
      timeout: VideoEditorConstants.previewRenderWatchdogTimeout,
      reason: 'loop point search timed out',
    );
  }

  /// Stops the search started under [taskId]; it then fails with a
  /// `RenderCanceledException`. Does nothing when none runs.
  static Future<void> cancel(String taskId) =>
      VideoLoopPointFinder.cancel(taskId);
}
