// ABOUTME: Brings mixed-resolution clips onto one aspect ratio before the
// ABOUTME: export concatenates them, pre-rendering only the clips that differ.

import 'dart:io';

import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/clip_normalization_models.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path/path.dart' as path;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// The aspect-ratio normalization pass of an export.
///
/// Every clip is analysed for the crop that maps its native resolution onto
/// the target aspect ratio. When all clips agree, the concatenation applies a
/// single global transform; otherwise only the clips that need a different
/// crop are pre-rendered to intermediate files. [VideoEditorRenderService]
/// owns the surrounding export and its cleanup; this class owns the decision
/// of which clips to re-encode and how.
abstract final class ClipNormalizationRender {
  static const _logName = 'VideoEditorRenderService';

  /// Normalizes all clips to the target aspect ratio.
  ///
  /// Optimizes rendering by:
  /// - Using a single global transform if all clips have the same resolution
  /// - Only pre-rendering clips that differ from the majority
  ///
  /// Returns video segments ready for concatenation and an optional global
  /// transform when all clips share the same crop parameters.
  ///
  /// [taskId] is the export's own id — the one a user cancel targets — so this
  /// pass can stop between clips instead of rendering the whole set (#7833).
  /// [tempFilePaths] is owned by the caller so partial output remains visible
  /// to its cleanup handlers when this pass throws.
  static Future<NormalizationResult> normalizeClipsToAspectRatio({
    required List<DivineVideoClip> clips,
    required model.AspectRatio aspectRatio,
    required Directory cacheDir,
    required CompleteParameters? parameters,
    required String taskId,
    required List<String> tempFilePaths,
  }) async {
    // Analyze all clips first to determine the optimal rendering strategy
    final clipAnalysis = await _analyzeClips(clips, aspectRatio);

    // A transition overlaps the tail of its clip and the head of the next, so
    // clamp it to a duration both clips can sustain. Without this the native
    // render fails on a transition longer than a (possibly later-trimmed) clip,
    // even though the lightweight seam preview clamps independently.
    final clampedTransitions = clampTransitions(clips);

    // If all clips have the same crop params, use global transform (most efficient)
    if (clipAnalysis.allSameCropParams) {
      Log.debug(
        '⚡ All ${clips.length} clips have identical resolution - using global transform',
        name: _logName,
        category: .video,
      );
      return NormalizationResult(
        segments: clips
            .map(
              (c) => VideoSegment(
                video: c.requireVideo,
                startTime: c.trimStart == .zero ? null : c.trimStart,
                endTime: c.trimStart + c.trimmedDuration,
                volume: c.volume,
                playbackSpeed: c.playbackSpeed,
                transition: clampedTransitions[c.id],
              ),
            )
            .toList(),
        globalTransform:
            clipAnalysis.entries.first.cropParams.needsCropping(
              clipAnalysis.entries.first.resolution,
            )
            ? clipAnalysis.entries.first.cropParams
            : null,
      );
    }

    // Mixed resolutions: normalize clips that differ from the target
    Log.debug(
      '🔄 Mixed resolutions detected - normalizing individual clips',
      name: _logName,
      category: .video,
    );

    final segments = <VideoSegment>[];
    for (int i = 0; i < clips.length; i++) {
      RenderCancellationRegistry.throwIfRequested(taskId);
      final entry = clipAnalysis.entries[i];
      final needsCrop = entry.cropParams.needsCropping(entry.resolution);

      Log.debug(
        '🎯 Clip ${entry.clip.id}: ${entry.resolution.width.round()}x${entry.resolution.height.round()}, '
        'crop: ${entry.cropParams}, needsCrop: $needsCrop',
        name: _logName,
        category: .video,
      );

      if (!needsCrop) {
        segments.add(
          VideoSegment(
            video: entry.clip.requireVideo,
            startTime: entry.clip.trimStart == .zero
                ? null
                : entry.clip.trimStart,
            endTime: entry.clip.trimStart + entry.clip.trimmedDuration,
            volume: entry.clip.volume,
            playbackSpeed: entry.clip.playbackSpeed,
            transition: clampedTransitions[entry.clip.id],
          ),
        );
      } else {
        final normalizedPath = path.join(
          cacheDir.path,
          'normalized_${i}_${DateTime.now().microsecondsSinceEpoch}.mp4',
        );
        tempFilePaths.add(normalizedPath);
        await _renderNormalizedClip(
          clip: entry.clip,
          cropParams: entry.cropParams,
          outputPath: normalizedPath,
          parameters: parameters,
          ownerTaskId: taskId,
        );
        segments.add(
          VideoSegment(
            video: EditorVideo.file(File(normalizedPath)),
            transition: clampedTransitions[entry.clip.id],
          ),
        );
      }
    }

    return NormalizationResult(segments: segments);
  }

  /// Analyzes all clips to determine their crop parameters.
  static Future<ClipAnalysis> _analyzeClips(
    List<DivineVideoClip> clips,
    model.AspectRatio aspectRatio,
  ) async {
    final entries = <ClipAnalysisEntry>[];

    for (final clip in clips) {
      final metaData = await ProVideoEditor.instance.getMetadata(
        clip.requireVideo,
      );
      final resolution = metaData.resolution;
      final cropParams = CropParameters.forAspectRatio(
        resolution: resolution,
        aspectRatio: aspectRatio,
      );
      entries.add(
        ClipAnalysisEntry(
          clip: clip,
          resolution: resolution,
          cropParams: cropParams,
        ),
      );
    }

    return ClipAnalysis(entries: entries);
  }

  /// Renders a single clip with crop transform to normalize its aspect ratio.
  static Future<String> _renderNormalizedClip({
    required DivineVideoClip clip,
    required CropParameters cropParams,
    required String outputPath,
    required CompleteParameters? parameters,
    required String ownerTaskId,
  }) async {
    final task = VideoRenderData(
      id: '${clip.id}_normalized',
      videoSegments: [
        VideoSegment(
          video: clip.requireVideo,
          startTime: clip.trimStart == .zero ? null : clip.trimStart,
          endTime: clip.trimStart + clip.trimmedDuration,
          volume: clip.volume,
          playbackSpeed: clip.playbackSpeed,
        ),
      ],
      shouldOptimizeForNetworkUse: true,
      imageBytesWithCropping: true,
      transform: ExportTransform(
        x: cropParams.x,
        y: cropParams.y,
        width: cropParams.width,
        height: cropParams.height,
        flipX: parameters?.flipX ?? false,
        flipY: parameters?.flipY ?? false,
        rotateTurns: parameters?.rotateTurns ?? 0,
      ),
    );

    await VideoEditorRenderService.renderWithEncoderFallback(
      baseTask: task,
      encode: (attemptTask) =>
          VideoEditorRenderService.cancelAndRender(outputPath, attemptTask),
      ownerTaskId: ownerTaskId,
    );

    Log.debug(
      '✅ Clip ${clip.id} normalized to: $outputPath',
      name: _logName,
      category: .video,
    );

    return outputPath;
  }
}
