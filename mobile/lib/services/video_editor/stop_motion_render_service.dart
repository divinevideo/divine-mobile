// ABOUTME: Assembles captured stop-motion frames into a single silent video
// ABOUTME: Thin wrapper over pro_video_editor's renderStopMotionToFile

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_editor/native_render_task_registry.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Encodes a sequence of captured stop-motion stills into one silent video.
class StopMotionRenderService {
  StopMotionRenderService._();

  /// Crash reporting for this static utility (#4743).
  ///
  /// No instances exist, so there is no constructor to inject through.
  /// `app_bootstrap` assigns the real reporter at startup; tests assign a
  /// recording fake. Defaults to a silent reporter only so an unwired test
  /// cannot NPE — production must assign, or reports are lost.
  static CrashReporter crashReporter = const SilentCrashReporter();

  static const _logName = 'StopMotionRenderService';
  static final RegExp _materializedOutputName = RegExp(
    r'^stop_motion_\d+\.mp4$',
  );

  /// Output frame rate of the assembled video.
  ///
  /// Matches the frame grid the rest of the app works on — the editor
  /// timeline's frame ruler labels ticks at 30fps — so "frames per image"
  /// counts the same frames everywhere: a hold of 2 shows 15 images per
  /// second, and N stills at the default hold play as N/30 s.
  static const double defaultFrameRate = 30;

  /// Test-only override for [assemble].
  ///
  /// When set, [assemble] delegates to this callback instead of running the
  /// real native render. Reset to `null` in `tearDown`.
  @visibleForTesting
  static Future<String?> Function({
    required List<StopMotionClipFrame> frames,
    required model.AspectRatio aspectRatio,
    double frameRate,
    String? taskId,
  })?
  assembleOverride;

  /// Test-only override for the encoded-duration probe in [materialize].
  ///
  /// When set, [materialize] uses this instead of reading the assembled mp4's
  /// real duration via the native metadata reader. Reset to `null` in
  /// `tearDown`.
  @visibleForTesting
  static Future<Duration?> Function(String outputPath)? probeDurationOverride;

  /// Assembles [frames] (captured stills with their hold times, in order)
  /// into a single silent mp4 using pro_video_editor's stop-motion encoder.
  ///
  /// Each still is held for its own [StopMotionClipFrame.duration], so
  /// per-frame edits from the editor survive into the output. [aspectRatio]
  /// sets the output resolution and a centered crop ([StopMotionFit.cover]).
  /// When [taskId] is set, the native encoder emits its progress under that
  /// id via [ProVideoEditor.progressStreamById].
  ///
  /// Returns the output file path, or null if rendering failed.
  ///
  /// Throws [RenderCanceledException] when the native assembly is cancelled
  /// (user cancel or lifecycle teardown via [NativeRenderTaskRegistry]).
  /// Callers that only need a null-on-failure contract should catch that and
  /// map it; the final-export path must keep cancel distinct from a failed
  /// assembly so telemetry does not tag it `stop_motion_assembly`.
  ///
  /// The native render path needs a device build to exercise.
  static Future<String?> assemble({
    required List<StopMotionClipFrame> frames,
    required model.AspectRatio aspectRatio,
    double frameRate = defaultFrameRate,
    String? taskId,
  }) async {
    final override = assembleOverride;
    if (override != null) {
      return override(
        frames: frames,
        aspectRatio: aspectRatio,
        frameRate: frameRate,
        taskId: taskId,
      );
    }

    if (frames.isEmpty) return null;

    return _renderToFile(
      frames: frames,
      aspectRatio: aspectRatio,
      frameRate: frameRate,
      taskId: taskId,
    );
  }

  /// Renders [clip]'s stop-motion frames into an mp4 and returns a plain
  /// video-backed copy of the clip. Returns [clip] unchanged when it is already
  /// a normal video clip. [taskId] is forwarded to [assemble] for progress
  /// reporting.
  ///
  /// The returned clip is a genuine video clip: its stills are cleared (they
  /// are now transient and may be cleaned up) and its [DivineVideoClip.duration]
  /// is set to the assembled mp4's real (probed) length. Short captures are
  /// looped up to the minimum output duration (see [framesForMinOutputDuration]),
  /// whose summed holds are only the fallback estimate if the probe fails.
  /// Using the encoded length matters twice: keeping the old single-pass
  /// duration would let the composite render trim the segment below the file
  /// length (dropping the loop, leaving the video shorter than muxed audio),
  /// and an *over*-estimate lets muxed audio outlive the video — which freezes
  /// the last frame on iOS.
  ///
  /// Returns `null` only when the render fails, so callers (publish, gallery
  /// save) can surface a failure instead of proceeding with a clip that has no
  /// playable video.
  ///
  /// Throws [RenderCanceledException] when assembly is cancelled — see
  /// [assemble].
  static Future<DivineVideoClip?> materialize(
    DivineVideoClip clip, {
    String? taskId,
  }) async {
    // A normal video clip (or a stop-motion clip already materialized once)
    // has its mp4; nothing to do. A frames-only clip (no video) is rendered on
    // demand below.
    if (clip.video != null) return clip;

    final frames = clip.stopMotionFrames;
    if (frames == null) return clip;

    final outputPath = await assemble(
      frames: frames,
      aspectRatio: clip.targetAspectRatio,
      taskId: taskId,
    );
    if (outputPath == null) return null;

    final estimatedDuration = framesForMinOutputDuration(
      frames,
    ).fold(Duration.zero, (sum, frame) => sum + frame.duration);
    final probedDuration = await _probeEncodedDuration(outputPath);
    final materializedDuration =
        probedDuration != null && probedDuration > Duration.zero
        ? probedDuration
        : estimatedDuration;
    return clip.copyWith(
      video: EditorVideo.file(outputPath),
      duration: materializedDuration,
      clearStopMotionFrames: true,
    );
  }

  /// Deletes the mp4 [materialize] created when [sourceClip] was frames-only.
  ///
  /// Normal video clips and already-materialized stop-motion clips pass through
  /// [materialize] unchanged, so their video files remain caller-owned. Gallery
  /// saves use this after copying the transient render to the camera roll.
  static Future<void> cleanupMaterializedOutput({
    required DivineVideoClip sourceClip,
    required DivineVideoClip? materializedClip,
  }) async {
    if (materializedClip == null ||
        sourceClip.video != null ||
        !sourceClip.isStopMotion) {
      return;
    }

    final outputPath = materializedClip.video?.file?.path;
    if (outputPath == null) return;

    await _deleteOutputPath(outputPath);
  }

  /// True for mp4 files created by this service's on-demand materializer.
  static bool isMaterializedOutputPath(String filePath) {
    return _materializedOutputName.hasMatch(path.basename(filePath));
  }

  /// Deletes a materialized stop-motion mp4 by path.
  static Future<void> cleanupMaterializedOutputPath(String outputPath) async {
    if (!isMaterializedOutputPath(outputPath)) return;
    await _deleteOutputPath(outputPath);
  }

  static Future<void> _deleteOutputPath(String outputPath) async {
    try {
      final file = File(outputPath);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      Log.debug(
        '⚠️ Failed to delete transient stop-motion render $outputPath: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// The real encoded duration of the assembled mp4 at [outputPath], or `null`
  /// when it can't be probed (caller falls back to the frame-hold estimate).
  static Future<Duration?> _probeEncodedDuration(String outputPath) async {
    final override = probeDurationOverride;
    if (override != null) return override(outputPath);
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(outputPath),
      );
      return metadata.duration;
    } catch (e) {
      Log.warning(
        '⚠️ Failed to probe assembled stop-motion duration; using estimate: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Repeats [frames] an integer number of times until the sequence's total
  /// duration (each frame held for its own hold time) reaches
  /// [VideoEditorConstants.stopMotionMinOutputDuration].
  ///
  /// Ultra-short clips (a single still ≈ 33ms) make looping players
  /// stutter/oscillate; repeating preserves the per-frame timing and keeps the
  /// loop seam clean (last frame → first frame). A sequence already at or above
  /// the minimum is returned unchanged.
  static List<StopMotionClipFrame> framesForMinOutputDuration(
    List<StopMotionClipFrame> frames,
  ) {
    if (frames.isEmpty) return frames;
    final singlePass = frames.fold(
      Duration.zero,
      (sum, frame) => sum + frame.duration,
    );
    const minDuration = VideoEditorConstants.stopMotionMinOutputDuration;
    final loops = singlePass >= minDuration || singlePass == Duration.zero
        ? 1
        : (minDuration.inMicroseconds / singlePass.inMicroseconds).ceil();
    return [for (var i = 0; i < loops; i++) ...frames];
  }

  static Future<String?> _renderToFile({
    required List<StopMotionClipFrame> frames,
    required model.AspectRatio aspectRatio,
    required double frameRate,
    String? taskId,
  }) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = path.join(
      outputDir.path,
      'stop_motion_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    final renderedFrames = framesForMinOutputDuration(frames);

    final data = StopMotionRenderData(
      id: taskId,
      frames: [
        for (final frame in renderedFrames)
          StopMotionFrame(
            image: EditorLayerImage.file(frame.path),
            duration: frame.duration,
          ),
      ],
      frameRate: frameRate,
      resolution: VideoEditorConstants.quality.resolutionForAspectRatio(
        aspectRatio,
      ),
      fit: StopMotionFit.cover,
    );

    try {
      Log.debug(
        '🎞️ Assembling ${frames.length} stop-motion frame(s) '
        '(rendered: ${renderedFrames.length}, fps: $frameRate)',
        name: _logName,
        category: LogCategory.video,
      );
      // Tracked so a lifecycle-detach cancelActiveNativeTasks() also cancels an
      // in-flight assembly. Keyed on data.id rather than taskId: most callers
      // pass no taskId, and StopMotionRenderData then generates its own — which
      // is the id the native side knows this task by.
      final result = await NativeRenderTaskRegistry.track(data.id, () {
        return ProVideoEditor.instance.renderStopMotionToFile(
          outputPath,
          data,
          nativeLogLevel: NativeLogLevel.warning,
        );
      });
      Log.info(
        '✅ Stop-motion video assembled to: $result',
        name: _logName,
        category: LogCategory.video,
      );
      return result;
    } on RenderCanceledException {
      Log.info(
        '🚫 Stop-motion assembly cancelled',
        name: _logName,
        category: LogCategory.video,
      );
      await _deletePartialOutput(outputPath);
      // Keep cancel distinct from a failed assembly: collapsing both to null
      // made the final-export path tag detach mid-assembly as
      // `stop_motion_assembly` / `failed` instead of `canceled` / `incomplete`.
      rethrow;
    } catch (e, stack) {
      Log.error(
        '❌ Stop-motion assembly failed: $e',
        name: _logName,
        category: LogCategory.video,
      );
      // Native/IO render failures are expected (return null so callers can
      // surface a friendly failure); only programming-invariant violations
      // (StateError/TypeError/RangeError — all `Error` subtypes) are worth
      // surfacing to Crashlytics.
      if (e is Error) {
        runDetached(
          crashReporter.recordError(
            e,
            stack,
            reason: 'StopMotionRenderService.assemble failed',
          ),
          'report a stop-motion assembly failure',
          logName: _logName,
          category: LogCategory.video,
        );
      }
      await _deletePartialOutput(outputPath);
      return null;
    }
  }

  /// Best-effort deletes a partial output file left behind by a failed or
  /// cancelled render.
  ///
  /// The native encoder writes to [outputPath] and only self-deletes when no
  /// output path is supplied; the app always passes one, so on failure the app
  /// owns cleanup. The success path is cleaned up by the caller (tracked in
  /// `intermediateStopMotionPaths`); without this, every failed/cancelled
  /// export would leak a full-size mp4 in the persistent documents dir.
  static Future<void> _deletePartialOutput(String outputPath) async {
    try {
      final file = File(outputPath);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      // Best-effort: a failed delete only leaves a temp file behind, never
      // aborts the caller.
      Log.debug(
        '⚠️ Failed to delete partial stop-motion render $outputPath: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}
