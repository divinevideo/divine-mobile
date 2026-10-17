// ABOUTME: Follows an object through a clip so a layer can be pinned to it:
// ABOUTME: classical motion tracking from pro_video_editor, no ML (#9848).

import 'dart:ui';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Tracks the object in [region] of [target]'s clip. Injected into the
/// layer tracking cubit so tests can swap the analysis out.
typedef TrackLayerObjectFn = Future<VideoObjectTrack> Function({
  required LayerTrackTarget target,
  required Rect region,
  required String taskId,
  void Function(double progress)? onProgress,
});

/// Stops the tracking started under a task id.
typedef CancelLayerTrackingFn = Future<void> Function(String taskId);

/// Follows an object through a clip so a layer can move with it (#9848).
///
/// Classical motion analysis, no ML model, as agreed for stabilization in
/// #9847: corners on the object are tracked from frame to frame and the
/// median of their motion moves the region. Nothing is generated or
/// changed in the footage; the result only places a layer.
abstract class LayerTrackingService {
  /// The task id for tracking on the layer [layerId].
  static String taskIdFor(String layerId) => '${layerId}_track';

  /// Follows [region] (fractions of the upright frame) through [target]'s
  /// clip, forward and backward from the frame at [LayerTrackTarget.anchor],
  /// within the stretch from [LayerTrackTarget.start] to
  /// [LayerTrackTarget.end].
  ///
  /// The frames are read at the package's 480 pixels on the long side, which
  /// keeps a small subject such as a ball a few dozen pixels wide, and the
  /// path is steadied over about one and a half frames: enough to take the
  /// jitter out of a following layer, not enough to let it trail a quick
  /// move. Runs under the preview render watchdog, which cancels it when it
  /// stops settling. [onProgress] reports 0..1.
  ///
  /// Throws a `RenderCanceledException` once [cancel] stopped it, a
  /// `VideoRenderFailedException` when the watchdog gave up on it, and a
  /// `PlatformException` when the clip cannot be decoded.
  static Future<VideoObjectTrack> trackObject({
    required LayerTrackTarget target,
    required Rect region,
    required String taskId,
    void Function(double progress)? onProgress,
  }) {
    return VideoRenderWatchdog.run(
      render: VideoObjectTracker.trackVideo(
        target.video,
        region: region,
        anchorTime: target.sourceTimeAt(target.anchor),
        startTime: target.sourceTimeAt(target.start),
        endTime: target.sourceTimeAt(target.end),
        maxFrameRate: VideoEditorConstants.trackingMaxFrameRate,
        // The preview keeps its own decoder while this runs.
        maxParallelDecoders: 1,
        id: taskId,
        onProgress: onProgress,
      ),
      taskId: taskId,
      cancelTask: cancel,
      timeout: VideoEditorConstants.previewRenderWatchdogTimeout,
      reason: 'layer tracking timed out',
    );
  }

  /// Stops the tracking started under [taskId]; it then fails with a
  /// `RenderCanceledException`. Does nothing when none runs.
  static Future<void> cancel(String taskId) =>
      VideoObjectTracker.cancel(taskId);
}
