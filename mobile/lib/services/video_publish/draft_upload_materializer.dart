// ABOUTME: Turns a DivineVideoDraft into a single uploadable video file,
// ABOUTME: owning the video-editor work that upload orchestration should not.

import 'dart:io';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:upload_repository/upload_repository.dart';

/// A draft resolved down to one uploadable file plus its probed metadata.
///
/// [transientRenderPaths] are stop-motion renders materialized only so the
/// upload had an mp4 to send. The upload owner registers them for cleanup once
/// the upload is published or discarded.
typedef MaterializedDraftUpload = ({
  File videoFile,
  int? videoWidth,
  int? videoHeight,
  Duration? videoDuration,
  Set<String> transientRenderPaths,
});

/// Produces the single video file an upload sends for a [DivineVideoDraft].
///
/// This is video-editor output production, not upload orchestration: it
/// materializes stop-motion stills, merges multi-clip drafts through the
/// editor's render service, and probes the result's metadata. It was extracted
/// from `UploadManager.startUploadFromDraft` (#6935) so the upload pipeline
/// stops depending on the editor chain.
class DraftUploadMaterializer {
  const DraftUploadMaterializer();

  /// Resolves [draft] to one uploadable file.
  ///
  /// [pendingUploads] is used only to spare in-use merge renders when reaping
  /// stale ones from the temp directory.
  ///
  /// Throws [StateError] if a stop-motion clip cannot be assembled.
  Future<MaterializedDraftUpload> materialize({
    required DivineVideoDraft draft,
    required List<PendingUpload> pendingUploads,
    Duration? videoDuration,
  }) async {
    Log.info(
      '🚀 === MATERIALIZING DRAFT FOR UPLOAD ===',
      name: 'DraftUploadMaterializer',
      category: LogCategory.video,
    );
    Log.info(
      '📜 Draft ID: ${draft.id}, hasProofMode: ${draft.hasProofMode}',
      name: 'DraftUploadMaterializer',
      category: LogCategory.video,
    );

    if (draft.hasProofMode) {
      Log.info(
        '📜 Native ProofMode JSON length: '
        '${draft.proofManifestJson?.length ?? 0} characters',
        name: 'DraftUploadMaterializer',
        category: LogCategory.video,
      );
    }

    // A stop-motion clip's source of truth is its stills, not an mp4, so
    // requireVideo throws on one. Publish normally materializes it up front and
    // hands the upload the rendered clip; this fallback path only runs when
    // that render has gone missing, so it has to re-render rather than
    // dereference a video that was never there.
    //
    // Each fallback render is a transient mp4 in the app documents dir.
    // Track the pairs so they can be reaped once the upload has consumed them.
    final transientRenders =
        <({DivineVideoClip source, DivineVideoClip materialized})>[];
    Future<DivineVideoClip> materializedSource(DivineVideoClip clip) async {
      if (!clip.isStopMotion) return clip;
      final DivineVideoClip? materialized;
      try {
        materialized = await StopMotionRenderService.materialize(clip);
      } on RenderCanceledException {
        throw StateError(
          'Stop-motion assembly cancelled for clip ${clip.id} — '
          'nothing to upload',
        );
      }
      if (materialized == null) {
        throw StateError(
          'Stop-motion assembly failed for clip ${clip.id} — nothing to upload',
        );
      }
      transientRenders.add((source: clip, materialized: materialized));
      return materialized;
    }

    Future<String> prepareUploadFromSourceClips() async {
      if (draft.clips.length == 1) {
        final source = await materializedSource(draft.clips.first);
        return source.requireVideo.safeFilePath();
      }

      final tempDir = await getTemporaryDirectory();
      TempRenderJanitor.deleteStaleMergedUploadRenders(tempDir, pendingUploads);
      final mergedPath = path.join(
        tempDir.path,
        'merged_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );
      Log.info(
        '🎬 Merging ${draft.clips.length} clips into single video '
        '(unexpected: clips should be pre-merged at this point)...',
        name: 'DraftUploadMaterializer',
        category: .video,
      );
      final videoSegments = <VideoSegment>[
        for (final clip in draft.clips)
          VideoSegment(video: (await materializedSource(clip)).requireVideo),
      ];
      await VideoEditorRenderService.renderNativeVideoToFile(
        mergedPath,
        VideoRenderData(
          videoSegments: videoSegments,
          endTime: VideoEditorConstants.maxDuration,
          shouldOptimizeForNetworkUse: true,
        ),
      );
      Log.info(
        '✅ Video merge completed: $mergedPath',
        name: 'DraftUploadMaterializer',
        category: .video,
      );
      return mergedPath;
    }

    // Prefer the persisted final render when available. It preserves editor
    // overlays and gives retries/background uploads a stable file path.
    var resolvedDuration = videoDuration;
    String videoFilePath;
    final renderedClip = draft.finalRenderedClip;
    if (renderedClip != null) {
      final renderedPath = await renderedClip.requireVideo.safeFilePath();
      if (File(renderedPath).existsSync()) {
        videoFilePath = renderedPath;
        resolvedDuration ??= renderedClip.duration;
        Log.info(
          '🎬 Using final rendered clip for upload: $videoFilePath',
          name: 'DraftUploadMaterializer',
          category: .video,
        );
      } else {
        Log.warning(
          '⚠️ Final rendered clip missing at $renderedPath - '
          'falling back to source clips',
          name: 'DraftUploadMaterializer',
          category: .video,
        );
        videoFilePath = await prepareUploadFromSourceClips();
      }
    } else {
      videoFilePath = await prepareUploadFromSourceClips();
    }

    int? videoWidth;
    int? videoHeight;

    try {
      final meta = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(videoFilePath),
      );
      resolvedDuration ??= meta.duration;
      videoWidth = meta.resolution.width.round();
      videoHeight = meta.resolution.height.round();
    } catch (e) {
      Log.warning(
        '⚠️ Could not extract video metadata: $e',
        name: 'DraftUploadMaterializer',
        category: LogCategory.video,
      );
    }

    return (
      videoFile: File(videoFilePath),
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoDuration: resolvedDuration,
      transientRenderPaths: <String>{
        for (final render in transientRenders)
          if (render.source.video == null && render.source.isStopMotion)
            ?render.materialized.video?.file?.path,
      },
    );
  }
}
