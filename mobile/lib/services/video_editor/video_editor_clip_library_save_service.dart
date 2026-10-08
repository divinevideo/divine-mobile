// ABOUTME: Flattens one timeline clip into a standalone file for the clip library
// ABOUTME: Bakes trim/speed/volume plus the overlays over it into a fresh documents-dir clip

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show CompleteParameters;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart';

/// Service for saving a single timeline clip to the persistent clip library.
class VideoEditorClipLibrarySaveService {
  /// Renders [clip]'s trim window into a standalone file and returns it as a
  /// fresh [DivineVideoClip] ready to hand to the clip library.
  ///
  /// Unlike the editor's own trim-based split (which keeps both halves on the
  /// shared source file), a library clip must outlive the editing session that
  /// produced it and be insertable into an unrelated project. So this re-encodes
  /// rather than carrying a trim window: the output holds *only* the selected
  /// section, and the returned clip carries no residual trim/speed/volume — the
  /// [VideoEditorRenderService.renderVideo] pipeline bakes all three in. That is
  /// what lets the user reuse a moment from a long video without dragging the
  /// whole source along (#5322).
  ///
  /// `reversed` is deliberately dropped rather than copied: a reversed clip's
  /// `video` already points at reversed content, so the flattened file is
  /// reversed too and re-flagging it would double-apply on the next render.
  ///
  /// The render is uncapped (`maxOutputDuration: null`) because a library clip
  /// is an intermediate clip the user can still trim, not a final export — the
  /// same reasoning as `VideoEditorMergeService.mergeClips`.
  ///
  /// [overlays] are the layers/filters/tune/effects/blur that were over *this
  /// clip*, already windowed and rebased to start at zero by
  /// [EditorOverlaySnapshot.windowedTo]. They get baked into the output too, so
  /// the saved clip looks the way it looked on the timeline, except for
  /// flashing effects, which are left out. Pass `null` (or an empty snapshot)
  /// to render the bare video. Only *visual* overlays are baked
  /// — session audio (background music, voice-over) spans the whole project
  /// timeline and is deliberately not carried onto a single saved clip.
  ///
  /// [renderId] keys the native progress/cancel stream.
  ///
  /// Returns `null` when the render is cancelled or fails — both already
  /// surface as a `null` output path from [VideoEditorRenderService.renderVideo].
  /// The returned clip's file lives in the persistent documents dir; if the
  /// caller does not go on to store it in the library, it must call
  /// [cleanupFlattenedClip] to avoid leaving an orphan there.
  static Future<DivineVideoClip?> flattenClipForLibrary({
    required DivineVideoClip clip,
    required String renderId,
    EditorOverlaySnapshot? overlays,
  }) async {
    Log.info(
      '💾 Flattening clip ${clip.id} for the clip library '
      '(${overlays?.capturedLayers.length ?? 0} layer(s), '
      '${overlays?.filterStates.length ?? 0} filter(s))',
      name: 'VideoEditorClipLibrarySaveService',
      category: LogCategory.video,
    );

    // A library clip keeps no record of the effects baked into it, so a video
    // reusing it could neither require the Flashing Lights warning nor keep a
    // second flashing effect off it.
    final parameters = _renderParameters(overlays?.withoutFlashingEffects());

    // usePersistentStorage writes into the documents dir, which the library
    // requires: it persists only a basename and resolves it back against
    // getDocumentsPath(), so a temp-dir file would save and then dangle.
    final outputPath = await VideoEditorRenderService.renderVideo(
      // A transition describes a boundary with the *next* clip, which this
      // render doesn't have — leaving it on would blend the clip into nothing.
      clips: [clip.copyWith(clearTransition: true)],
      usePersistentStorage: true,
      taskId: renderId,
      maxOutputDuration: null,
      parameters: parameters,
    );

    if (outputPath == null) return null;

    // Signed as an edit of the clip, so it can be shared and edited further
    // with its camera proof intact (#9893).
    final proof = await VideoEditorRenderService.proofRenderedVideo(
      File(outputPath),
      clips: [clip],
      parameters: parameters,
    );

    final thumbnail = await _extractThumbnail(outputPath);

    return DivineVideoClip(
      id: 'clip_library_${DateTime.now().microsecondsSinceEpoch}',
      video: EditorVideo.file(outputPath),
      duration: clip.playbackDuration,
      recordedAt: clip.recordedAt,
      targetAspectRatio: clip.targetAspectRatio,
      originalAspectRatio: clip.originalAspectRatio,
      // Fall back to the source clip's frame when extraction fails; a library
      // card without any thumbnail is worse than a slightly-off one.
      thumbnailPath: thumbnail?.path ?? clip.thumbnailPath,
      thumbnailTimestamp: thumbnail?.timestamp,
      lensMetadata: clip.lensMetadata,
      // A flatten re-renders the same logical clip, so every imported-source
      // credit carries over unchanged — a merged clip keeps all of them, since
      // the library clip is reusable in later videos and a dropped credit here
      // would be permanent.
      sourceCredits: clip.sourceCredits,
      proofManifestJson: proof == null ? null : jsonEncode(proof),
    );
  }

  /// Deletes the files a [flattenClipForLibrary] result left in the documents
  /// dir when the clip never reached the library — the re-encoded video and,
  /// when it was freshly extracted, its thumbnail.
  ///
  /// The render writes into persistent storage, so nothing reclaims these files
  /// unless a library row ends up referencing them. Call this on every path
  /// where the save does not land (render discarded, library write rejected, or
  /// the save threw) so the documents dir isn't left with permanent orphans.
  ///
  /// [keepThumbnailPath] is the source clip's own thumbnail: when frame
  /// extraction fails, [flattenClipForLibrary] falls back to it, and it is still
  /// referenced by the live source clip, so it must never be deleted here.
  static Future<void> cleanupFlattenedClip(
    DivineVideoClip flattened, {
    String? keepThumbnailPath,
  }) async {
    await _deleteQuietly(flattened.video?.file?.path);

    final thumbnailPath = flattened.thumbnailPath;
    if (thumbnailPath != null && thumbnailPath != keepThumbnailPath) {
      await _deleteQuietly(thumbnailPath);
    }
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      Log.warning(
        '⚠️ Failed to delete orphaned library-clip file $path: $e',
        name: 'VideoEditorClipLibrarySaveService',
        category: LogCategory.video,
      );
    }
  }

  /// Wraps [overlays] in the [CompleteParameters] shape the render pipeline
  /// reads, or `null` when there is nothing to bake.
  ///
  /// Only the overlay fields are populated. Geometry (crop / rotate / flip) is
  /// deliberately left at its defaults: a clip's own spatial transform is
  /// already baked into its file by the transform action, and the aspect-ratio
  /// crop comes from the clip's `targetAspectRatio` inside `renderVideo`.
  static CompleteParameters? _renderParameters(
    EditorOverlaySnapshot? overlays,
  ) {
    if (overlays == null || overlays.isEmpty) return null;

    return CompleteParameters(
      blur: overlays.blur,
      capturedLayers: overlays.capturedLayers,
      filterStates: overlays.filterStates,
      tuneAdjustments: overlays.tuneAdjustments,
      bodySize: overlays.bodySize,
      // The render reads effects from the history meta, as in a full export.
      meta: {
        if (overlays.effects.isNotEmpty || overlays.customEffects.isNotEmpty)
          VideoEditorConstants.effectsStateHistoryKey: [
            for (final effect in overlays.effects) effect.toMap(),
            for (final effect in overlays.customEffects)
              {EditorVideoEffect.customKey: effect.toMap()},
          ],
      },
      // Geometry: the render pipeline *does* read these into its ExportTransform,
      // so they are deliberately left at identity — a clip's own spatial
      // transform is already baked into its file, and the aspect-ratio crop
      // comes from targetAspectRatio in renderVideo. Applying geometry here
      // would double-transform.
      rotateTurns: 0,
      flipX: false,
      flipY: false,
      // The render pipeline reads none of the below for an overlay bake; they
      // are required constructor args, so they carry inert defaults.
      matrixFilterList: const [],
      matrixTuneAdjustmentsList: const [],
      startTime: null,
      endTime: null,
      cropWidth: null,
      cropHeight: null,
      cropX: null,
      cropY: null,
      image: Uint8List(0),
      isTransformed: false,
      layers: const [],
      originalImageSize: null,
      temporaryDecodedImageSize: null,
      editorSize: null,
    );
  }

  /// Extracts a representative frame from the freshly rendered [videoPath].
  ///
  /// The source clip's own thumbnail can point at a frame the trim window
  /// excludes, and its timestamp is measured against the source timeline — both
  /// meaningless for the flattened file, which starts at zero.
  static Future<ThumbnailFileResult?> _extractThumbnail(
    String videoPath,
  ) async {
    try {
      return await VideoThumbnailService.extractThumbnail(videoPath: videoPath);
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to extract library-clip thumbnail: $e',
        name: 'VideoEditorClipLibrarySaveService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
