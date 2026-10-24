// ABOUTME: Captures displayed clip windows and a complete composition revision
// ABOUTME: for loop repair, without exposing editor types to the repository.

import 'dart:convert';
import 'dart:math' as math;

import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_loop_alignment.dart';
import 'package:openvine/models/video_editor/composition_duration.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

/// The caller supplies serialized layers, sound, effects and markers from the
/// editor state. Their values (including live volume) belong in the revision;
/// selection and player position do not.
abstract final class LoopRepairInputMapper {
  static LoopRepairInput fromComposition(
    List<DivineVideoClip> clips, {
    required Object composition,
    bool hasSourceTrackedLayers = false,
    bool platformSupported = true,
  }) {
    final supported =
        platformSupported &&
        clips.isNotEmpty &&
        !hasSourceTrackedLayers &&
        compositionDuration(clips) <= VideoEditorConstants.maxDuration &&
        clips.every(
          (clip) =>
              clip.video?.file != null &&
              !clip.isPlaceholder &&
              !clip.isFreezeFrame &&
              clip.stopMotionFrames == null &&
              clip.speedRamp == null &&
              clip.transition == null &&
              clip.mask == null &&
              clip.chromaKey == null &&
              !clip.hasPendingCaptureChromaKey &&
              (clip.playbackSpeed ?? 1).isFinite &&
              (clip.playbackSpeed ?? 1) > 0 &&
              clip.trimmedDuration.inMicroseconds / (clip.playbackSpeed ?? 1) >=
                  TimelineConstants.minTrimDuration.inMicroseconds,
        );
    return LoopRepairInput(
      clips: [
        for (final clip in clips)
          if (clip.video?.file?.path case final path?)
            LoopClipInput(
              clipId: clip.id,
              path: path,
              sourceStart: clip.trimStart,
              sourceEnd: clip.duration - clip.trimEnd,
              speed: clip.playbackSpeed ?? 1,
              width: _dimensions(clip.videoAspectRatio).$1,
              height: _dimensions(clip.videoAspectRatio).$2,
              minimumDuration: TimelineConstants.minTrimDuration,
            ),
      ],
      revision: jsonEncode(
        _canonical({
          'clips': [for (final clip in clips) clip.toJson()],
          // Persisted clip paths are basenames; a replacement in another
          // directory must still invalidate an in-flight result.
          'paths': [for (final clip in clips) clip.video?.file?.path],
          'composition': composition,
          'sourceTracked': hasSourceTrackedLayers,
        }),
      ),
      capability: supported
          ? LoopRepairCapability.supported
          : LoopRepairCapability.unsupported,
      minimumCompositionDuration: VideoEditorConstants.loopPointMinLoop,
    );
  }

  /// Builds all replacements before publishing any of them. History owns the
  /// original clips; this mapping never mutates them or deletes their sources.
  static List<DivineVideoClip> applyResult(
    List<DivineVideoClip> clips,
    LoopRepairResult result, {
    required String operationId,
  }) {
    final plan = result.plan;
    final output = result.output;
    if (result.status != LoopRepairStatus.repaired ||
        plan == null ||
        output == null ||
        operationId.isEmpty ||
        clips.isEmpty ||
        plan.clips.length != clips.length ||
        output.paths.length != clips.length ||
        output.paths.values.toSet().length != clips.length ||
        !plan.zoom.isFinite ||
        plan.zoom < 1 ||
        plan.zoom > 1.08) {
      throw StateError('Incomplete loop repair');
    }
    final replacements = <DivineVideoClip>[];
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final replacement = plan.clips[i];
      final path = output.paths[clip.id];
      final source = clip.video?.file?.path;
      final removed = clip.duration - clip.trimEnd - replacement.sourceEnd;
      final speed = clip.playbackSpeed ?? 1;
      if (source == null ||
          path == null ||
          path.isEmpty ||
          path == source ||
          clips.any((c) => c.video?.file?.path == path) ||
          replacement.clipId != clip.id ||
          replacement.sourceStart != clip.trimStart ||
          replacement.sourceStart < clip.minTrimStart ||
          removed < Duration.zero ||
          !speed.isFinite ||
          speed <= 0 ||
          removed.inMicroseconds / speed >
              const LoopAlignmentLimits().maximumTrim.inMicroseconds ||
          (i != clips.length - 1 && removed != Duration.zero) ||
          (replacement.sourceEnd - replacement.sourceStart).inMicroseconds /
                  speed <
              TimelineConstants.minTrimDuration.inMicroseconds) {
        throw StateError('Loop replacement does not match its source window');
      }
      replacements.add(
        clip.copyWith(
          video: EditorVideo.file(path),
          duration: replacement.sourceEnd - replacement.sourceStart,
          trimStart: Duration.zero,
          trimEnd: Duration.zero,
          minTrimStart: Duration.zero,
          sourceStartOffset: clip.sourceStartOffset + replacement.sourceStart,
          loopAlignment: ClipLoopAlignment(
            sourcePath: source,
            windowStart: replacement.sourceStart,
            sourceDuration: clip.duration,
            sourceMinTrimStart: clip.minTrimStart,
            sourceStartOffset: clip.sourceStartOffset,
            sourceDerivedFrom: clip.derivedFrom,
            operationId: operationId,
          ),
          derivedFrom: clip.signingSources,
          clearStabilization: true,
          clearBoomerang: true,
          clearForwardVideoPath: true,
          clearReversedVideoPath: true,
        ),
      );
    }
    if (compositionDuration(replacements) <
        VideoEditorConstants.loopPointMinLoop) {
      throw StateError('Loop repair would make the composition too short');
    }
    return List.unmodifiable(replacements);
  }

  static (int, int) _dimensions(double ratio) => ratio >= 1
      ? (320, math.max(1, (320 / ratio).round()))
      : (math.max(1, (320 * ratio).round()), 320);

  static Object? _canonical(Object? value) {
    if (value is Map<String, dynamic>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}
