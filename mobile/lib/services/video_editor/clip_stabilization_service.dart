// ABOUTME: Steadies a shaky clip: measures its camera shake and renders the
// ABOUTME: steadied footage to a new local file (#9847).

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/native_render_task_registry.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// The part of a clip's footage a stabilization render covers.
typedef StabilizationWindow = ({Duration start, Duration end});

/// What a stabilization render produced.
@immutable
class StabilizedClipRender {
  const StabilizedClipRender({
    required this.video,
    required this.rawSourcePath,
    required this.window,
  });

  /// The steadied footage, without any green screen.
  final EditorVideo video;

  /// The unstabilized footage it was rendered from.
  final String rawSourcePath;

  /// Where in [rawSourcePath] the render starts and ends.
  final StabilizationWindow window;
}

/// Renders [sourceClip] steadied. Injected into the clip editor bloc so tests
/// can swap the analysis and render out.
typedef StabilizeClipFn = Future<StabilizedClipRender> Function({
  required DivineVideoClip sourceClip,
  required String renderId,
  void Function(double progress)? onProgress,
});

/// Steadies shaky handheld footage after it was recorded (#9847).
///
/// Classical motion analysis, no ML model: corners are tracked from frame to
/// frame, the camera path is smoothed, and each frame is moved onto the
/// smooth path. The borders that exposes are hidden by zooming in, never
/// filled, so every pixel of the result is a pixel of the camera's. Where a
/// steadier shot would need more than [VideoEditorConstants.
/// stabilizationMaxZoom], some shake stays instead.
///
/// The result is baked into a new file like a green screen, so the preview
/// and the export show the same picture without any work at export time.
abstract class ClipStabilizationService {
  static const _logName = 'ClipStabilizationService';

  /// The share of the progress the analysis takes; the render takes the
  /// rest. Decoding for the analysis and encoding the result cost about the
  /// same.
  static const _analysisShare = 0.5;

  /// The render task id for stabilizing [clipId].
  ///
  /// Namespaced so it never shares an id with a reverse, transform or
  /// chroma-key render of the same clip.
  static String renderIdFor(String clipId) => '${clipId}_stabilize';

  /// The id of the frame stream that feeds the analysis of [clipId].
  static String analysisIdFor(String clipId) => '${clipId}_stabilize_analysis';

  /// The window a stabilization of [clip] renders: the visible part plus
  /// [VideoEditorConstants.stabilizationMargin] on both sides, within the
  /// clip's own footage.
  ///
  /// The margin keeps the trim handles movable after the bake; for a clip
  /// recorded in the app it covers the whole file. The window never reaches
  /// below [DivineVideoClip.minTrimStart] or past [DivineVideoClip.duration],
  /// where a split clip's file holds its sibling's frames.
  static StabilizationWindow windowFor(DivineVideoClip clip) {
    const margin = VideoEditorConstants.stabilizationMargin;
    final visibleStart = clip.trimStart;
    final visibleEnd = clip.duration - clip.trimEnd;
    final start = visibleStart - margin;
    final end = visibleEnd + margin;
    return (
      start: start < clip.minTrimStart ? clip.minTrimStart : start,
      end: end > clip.duration ? clip.duration : end,
    );
  }

  /// Measures [sourceClip]'s shake and renders its [windowFor] steadied.
  ///
  /// Works on raw footage: a clip with a green screen baked in is rendered
  /// from the footage under the key, which the caller applies again. The
  /// analysis and the render run under [renderId]'s cancellation and
  /// together under the preview render watchdog. [onProgress] reports 0..1.
  ///
  /// Throws when the analysis or the render fails or is cancelled.
  static Future<StabilizedClipRender> stabilizeClip({
    required DivineVideoClip sourceClip,
    required String renderId,
    void Function(double progress)? onProgress,
  }) async {
    // Registered before any await, so a cancel landing while the input is
    // still being resolved stops the job before the analysis starts.
    final renderToken = RenderCancellationRegistry.start(renderId);
    try {
      return await VideoRenderWatchdog.run(
        render: _stabilizeClip(
          sourceClip: sourceClip,
          renderId: renderId,
          onProgress: onProgress,
        ),
        taskId: renderId,
        cancelTask: (taskId) async {
          await VideoEditorRenderService.cancelTask(
            analysisIdFor(sourceClip.id),
          );
          await VideoEditorRenderService.cancelTask(taskId);
        },
        timeout: VideoEditorConstants.previewRenderWatchdogTimeout,
        reason: 'clip stabilization timed out',
      );
    } finally {
      RenderCancellationRegistry.finish(renderId, renderToken);
    }
  }

  static Future<StabilizedClipRender> _stabilizeClip({
    required DivineVideoClip sourceClip,
    required String renderId,
    void Function(double progress)? onProgress,
  }) async {
    final rawPath = await rawFootagePath(sourceClip);
    final window = windowFor(sourceClip);
    final input = EditorVideo.file(rawPath);
    final startTime = window.start > Duration.zero ? window.start : null;

    Log.info(
      '🫨 Stabilizing clip ${sourceClip.id} '
      '(${window.start.inMilliseconds}–${window.end.inMilliseconds} ms)',
      name: _logName,
      category: LogCategory.video,
    );

    final analysisId = analysisIdFor(sourceClip.id);
    final stabilization = await NativeRenderTaskRegistry.track(
      analysisId,
      () => VideoStabilizationAnalyzer.analyzeVideo(
        input,
        startTime: startTime,
        endTime: window.end,
        // The design limit, pinned so a change of the package's default
        // cannot move it.
        // ignore: avoid_redundant_argument_values
        maxZoom: VideoEditorConstants.stabilizationMaxZoom,
        id: analysisId,
        // The editor's player keeps decoding next to the analysis.
        maxParallelDecoders: 1,
        onProgress: (p) => onProgress?.call(p * _analysisShare),
      ),
    );
    RenderCancellationRegistry.throwIfRequested(renderId);

    Log.info(
      '🫨 Clip ${sourceClip.id}: zoom '
      '${stabilization.zoom.toStringAsFixed(3)}, '
      '${stabilization.unreliableFrames} unreliable and '
      '${stabilization.attenuatedFrames} capped frames',
      name: _logName,
      category: LogCategory.video,
    );

    // Unique per render so a later stabilization never targets the file a
    // draft or undo step still points at.
    final outputPath = p.join(
      await getDocumentsPath(),
      '${sourceClip.id}_stabilized_'
      '${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    if (p.equals(rawPath, outputPath)) {
      throw StateError(
        'Stabilization aborted: input path equals output path ($rawPath)',
      );
    }
    final outputFile = File(outputPath);

    final progress = onProgress == null
        ? null
        : ProVideoEditor.instance
              .progressStreamById(renderId)
              .listen(
                (model) => onProgress(
                  _analysisShare +
                      math.min(1, model.progress) * (1 - _analysisShare),
                ),
              );
    try {
      await VideoEditorRenderService.renderNativeVideoToFile(
        outputPath,
        VideoRenderData(
          id: renderId,
          videoSegments: [
            VideoSegment(
              video: input,
              startTime: startTime,
              endTime: window.end,
              stabilization: stabilization,
            ),
          ],
        ),
        reuseActiveCancellation: true,
      );
    } catch (_) {
      if (outputFile.existsSync()) {
        try {
          await outputFile.delete();
        } catch (deleteError) {
          Log.warning(
            '⚠️ Failed to delete partial stabilization output $outputPath: '
            '$deleteError',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }
      rethrow;
    } finally {
      await progress?.cancel();
    }

    return StabilizedClipRender(
      video: EditorVideo.file(outputPath),
      rawSourcePath: rawPath,
      window: window,
    );
  }

  /// The unstabilized, unkeyed footage of [clip]: the footage under its
  /// green screen when it has one baked in and still on disk, otherwise its
  /// video.
  static Future<String> rawFootagePath(DivineVideoClip clip) async {
    final keySource = clip.chromaKey == null ? null : clip.chromaKeySourcePath;
    if (keySource != null && File(keySource).existsSync()) return keySource;
    return clip.requireVideo.safeFilePath();
  }
}
