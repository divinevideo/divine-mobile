import 'dart:convert';
import 'dart:io';

import 'package:models/models.dart' as model show ClipSourceCredit;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransitionType, EditorVideo;
import 'package:unified_logger/unified_logger.dart';

/// Service for flattening several timeline clips into a single new clip.
class VideoEditorMergeService {
  /// Concatenates [clips] (already in timeline order) into one rendered file
  /// and returns it as a fresh [DivineVideoClip].
  ///
  /// Each clip's trim/speed/volume/equalizer/reverse is baked into the output
  /// by the underlying [VideoEditorRenderService.renderVideo] pipeline, so the
  /// merged clip carries no residual trim, speed or equalizer. The merged duration is the full
  /// sum of the inputs' [DivineVideoClip.playbackDuration] — the render is
  /// uncapped (`maxOutputDuration: null`) because the merged clip is an
  /// intermediate editor clip the user can still trim, not the final export
  /// (which applies the duration cap on its own).
  ///
  /// Flash transitions become dissolves of the same duration. The merged
  /// pixels carry no editable flash timing, so later spacing and beat
  /// limiting cannot account for a flash baked into this intermediate.
  ///
  /// Returns `null` when fewer than two clips are supplied, or when the render
  /// is cancelled / fails (both already surface as a `null` output path from
  /// [VideoEditorRenderService.renderVideo]).
  static Future<DivineVideoClip?> mergeClips({
    required List<DivineVideoClip> clips,
    required String renderId,
  }) async {
    if (clips.length < 2) return null;

    Log.info(
      '🧬 Merging ${clips.length} clip(s) into one',
      name: 'VideoEditorMergeService',
      category: LogCategory.video,
    );

    // Match library-save's rule for flashing effects: never bake a flash
    // whose timing the next edit cannot see. This also prevents subset-only
    // clamping from restoring a flash suppressed by the surrounding timeline.
    final renderClips =
        clips.any((clip) => clip.transition?.type.flashes ?? false)
        ? [
            for (final clip in clips)
              if (clip.transition case final transition?
                  when transition.type.flashes)
                clip.copyWith(
                  transition: transition.copyWith(
                    type: ClipTransitionType.dissolve,
                  ),
                )
              else
                clip,
          ]
        : clips;
    final outputPath = await VideoEditorRenderService.renderVideo(
      clips: renderClips,
      usePersistentStorage: true,
      taskId: renderId,
      maxOutputDuration: null,
    );

    if (outputPath == null) return null;

    // Signed as a composite of the clips, so the merged clip keeps their
    // camera proof (#9893).
    final proof = await VideoEditorRenderService.proofRenderedVideo(
      File(outputPath),
      clips: clips,
    );
    // Left unsigned, for example offline, it stays an editor intermediate:
    // an edit of it is signed against the media it was merged from.
    final mergedFrom = proof?.c2paManifestId == null
        ? NativeProofModeService.editSources(clips: clips)
        : null;

    final mergedDuration = clips.fold(
      Duration.zero,
      (sum, clip) => sum + clip.playbackDuration,
    );

    final first = clips.first;
    final sourceCredits = _sourceCreditsFromClips(clips);
    return DivineVideoClip(
      id: 'merged_${DateTime.now().microsecondsSinceEpoch}',
      video: EditorVideo.file(outputPath),
      duration: mergedDuration,
      recordedAt: first.recordedAt,
      targetAspectRatio: first.targetAspectRatio,
      originalAspectRatio: first.originalAspectRatio,
      thumbnailPath: first.thumbnailPath,
      lensMetadata: first.lensMetadata,
      sourceCredits: sourceCredits,
      proofManifestJson: proof == null ? null : jsonEncode(proof),
      derivedFrom: mergedFrom,
      retainedSourcePaths: {
        for (final clip in clips) ...clip.retainedSourcePaths,
      }.toList(),
    );
  }

  static List<model.ClipSourceCredit> _sourceCreditsFromClips(
    List<DivineVideoClip> clips,
  ) {
    final credits = <model.ClipSourceCredit>[];
    final seen = <String>{};

    for (final clip in clips) {
      for (final credit in clip.sourceCredits) {
        if (seen.add(credit.identityKey)) credits.add(credit);
      }
    }

    return credits;
  }
}
