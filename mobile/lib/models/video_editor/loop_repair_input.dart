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
    final exportClips = _exportClips(clips);
    final supported =
        platformSupported &&
        exportClips.isNotEmpty &&
        !hasSourceTrackedLayers &&
        exportClips.every(
          (clip) =>
              clip.video?.file != null &&
              !clip.isPlaceholder &&
              !clip.isFreezeFrame &&
              clip.stopMotionFrames == null &&
              clip.speedRamp == null &&
              clip.transition == null &&
              clip.mask == null &&
              // Analysis decodes the base file, not the clip's live motion.
              // Repair the loop before placing clip keyframes.
              clip.keyframes.isEmpty &&
              clip.chromaKey == null &&
              !clip.hasPendingCaptureChromaKey &&
              (clip.playbackSpeed ?? 1).isFinite &&
              (clip.playbackSpeed ?? 1) > 0 &&
              clip.trimmedDuration.inMicroseconds / (clip.playbackSpeed ?? 1) >=
                  TimelineConstants.minTrimDuration.inMicroseconds,
        );
    return LoopRepairInput(
      clips: [
        for (final clip in exportClips)
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
    final exportClips = _exportClips(clips);
    final plan = result.plan;
    final output = result.output;
    if (result.status != LoopRepairStatus.repaired ||
        plan == null ||
        output == null ||
        operationId.isEmpty ||
        clips.isEmpty ||
        plan.clips.length != exportClips.length ||
        output.paths.length != exportClips.length ||
        output.paths.values.toSet().length != exportClips.length ||
        !plan.zoom.isFinite ||
        plan.zoom < 1 ||
        plan.zoom > 1.08) {
      throw StateError('Incomplete loop repair');
    }
    final retainedSourcePaths = {
      for (final clip in clips.skip(exportClips.length))
        ...clip.ownedFilePaths.whereType<String>(),
      // Provenance can stop owning a source once a later merge is signed,
      // and splits clear the per-render restoration records. Keep the media
      // those history entries restore independently of either mechanism.
      for (final clip in exportClips)
        ...<String?>[
          clip.video?.file?.path,
          clip.loopAlignment?.sourcePath,
          clip.stabilization?.rawSourcePath,
          clip.boomerang?.sourcePath,
          ...?clip.derivedFrom?.map((source) => source.path),
          ...?clip.loopAlignment?.sourceDerivedFrom?.map(
            (source) => source.path,
          ),
          ...?clip.stabilization?.sourceDerivedFrom?.map(
            (source) => source.path,
          ),
          ...?clip.boomerang?.sourceDerivedFrom?.map((source) => source.path),
        ].whereType<String>(),
      for (final clip in clips) ...clip.retainedSourcePaths,
    }.toList()..sort();
    final replacements = <DivineVideoClip>[];
    for (var i = 0; i < exportClips.length; i++) {
      final clip = clips[i];
      final window = exportClips[i];
      final replacement = plan.clips[i];
      final path = output.paths[clip.id];
      final source = clip.video?.file?.path;
      final removed = window.duration - window.trimEnd - replacement.sourceEnd;
      final speed = clip.playbackSpeed ?? 1;
      if (source == null ||
          clip.keyframes.isNotEmpty ||
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
          (i != exportClips.length - 1 && removed != Duration.zero) ||
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
          retainedSourcePaths: retainedSourcePaths,
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

  /// Limits analysis and successful replacements to the exported prefix.
  static List<DivineVideoClip> _exportClips(List<DivineVideoClip> clips) {
    var remaining = VideoEditorConstants.maxDuration;
    final exported = <DivineVideoClip>[];
    for (final clip in clips) {
      if (remaining <= Duration.zero) break;
      final speed = clip.playbackSpeed ?? 1;
      if (!speed.isFinite || speed <= 0 || clip.speedRamp != null) return clips;
      if (clip.playbackDuration <= remaining) {
        exported.add(clip);
        remaining -= clip.playbackDuration;
      } else {
        // Round down so slow playback cannot exceed the export bound.
        final sourceSpan = Duration(
          microseconds: (remaining.inMicroseconds * speed).floor(),
        );
        exported.add(
          clip.copyWith(
            trimEnd: clip.duration - clip.trimStart - sourceSpan,
          ),
        );
        break;
      }
    }
    return exported;
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
