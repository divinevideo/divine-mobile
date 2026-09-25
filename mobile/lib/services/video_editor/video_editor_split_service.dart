// ABOUTME: Service for splitting a clip into two trim-based halves (no re-encode)
// ABOUTME: Both halves share the source file; only their trim windows differ

import 'dart:async';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for splitting video clips into two separate segments
class VideoEditorSplitService {
  static const minClipDuration = Duration(milliseconds: 30);

  /// Defensive cap on the background preview-thumbnail decode. The decode runs
  /// fire-and-forget (it never blocks the split), so this only bounds the
  /// orphaned work if a native decode stalls (#4801).
  static const _thumbnailWatchdogTimeout = Duration(seconds: 30);

  /// Validates if the split position is valid for the given clip.
  ///
  /// [splitPosition] is relative to the trimmed clip (0 to trimmedDuration).
  /// Both resulting clips must meet the minimum duration requirement.
  static bool isValidSplitPosition(
    DivineVideoClip clip,
    Duration splitPosition,
  ) {
    return splitPosition >= minClipDuration &&
        clip.trimmedDuration - splitPosition >= minClipDuration;
  }

  /// Splits a clip at the specified position — a pure trim-based cut.
  ///
  /// Both halves keep the **same** source video; only their trim windows
  /// differ, so there is **no re-encode** and the cut is instant. This is safe
  /// because:
  /// * the export already clips each clip to its `[trimStart, trimEnd]` window
  ///   (`ClipNormalizationRender.normalizeClipsToAspectRatio`), so two clips
  ///   on one file each export their own segment, and
  /// * `FileCleanupService` only deletes a file no clip/draft still references,
  ///   so a shared source file is never deleted out from under a sibling half.
  ///
  /// The end half's representative thumbnail is refreshed in the background
  /// (fire-and-forget) so the cut stays instant; [onThumbnailExtracted] fires
  /// once it lands.
  ///
  /// Throws [ArgumentError] if the split position is invalid.
  static Future<void> splitClip({
    required DivineVideoClip sourceClip,
    required Duration splitPosition,
    required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
    onClipsCreated,
    required void Function(DivineVideoClip clip, String thumbnailPath)?
    onThumbnailExtracted,
  }) async {
    if (!isValidSplitPosition(sourceClip, splitPosition)) {
      Log.error(
        '❌ Invalid split position: ${splitPosition.inSeconds}s '
        '(clip: ${sourceClip.trimmedDuration.inSeconds}s, '
        'min: ${minClipDuration.inMilliseconds}ms)',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      throw ArgumentError(
        'Split position $splitPosition is invalid. '
        'Both clips must be at least $minClipDuration.',
      );
    }

    // splitPosition is relative to the trimmed clip (0 to trimmedDuration).
    // Convert to an absolute position within the source file.
    final absoluteSplitPos = sourceClip.trimStart + splitPosition;

    Log.info(
      '✂️ Splitting clip ${sourceClip.id} at ${splitPosition.inSeconds}s '
      '(absolute: ${absoluteSplitPos.inSeconds}s) — trim-based, no re-encode',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    final timestampMs = DateTime.now().microsecondsSinceEpoch;

    // Start half: source start → split point. [duration] caps the visible end
    // at the split, and it drops the source's outgoing transition — only the
    // end half (which now owns the boundary into the next clip) keeps it.
    final startClip = sourceClip.copyWith(
      id: '${timestampMs}_start',
      duration: absoluteSplitPos,
      trimEnd: Duration.zero,
      clearTransition: true,
    );
    // End half: split point → source end. [minTrimStart] pins its left trim
    // handle at the split so it can't be dragged back into the start half's
    // frames (both halves share the same source file).
    final endClip = sourceClip.copyWith(
      id: '${timestampMs}_end',
      trimStart: absoluteSplitPos,
      minTrimStart: absoluteSplitPos,
    );

    onClipsCreated?.call(startClip, endClip);

    Log.info(
      '✅ Split complete (trim-based) — 2 clips from ${sourceClip.id}',
      name: 'VideoEditorSplitService',
      category: .video,
    );

    // Refresh the end half's representative thumbnail to its new first frame
    // (the split point) in the background, so the split itself is instant and
    // the editor's loading state clears immediately. Owns its error handling;
    // on failure the end half keeps the inherited thumbnail. Bounded so a
    // stalled native decode can't leak (#4801).
    unawaited(
      _extractThumbnailForClip(
        sourceClip,
        absoluteSplitPos,
        endClip,
        onThumbnailExtracted,
      ).timeout(_thumbnailWatchdogTimeout, onTimeout: () {}),
    );
  }

  /// Extract a thumbnail for the split clip at the specified timestamp.
  static Future<void> _extractThumbnailForClip(
    DivineVideoClip sourceClip,
    Duration timestamp,
    DivineVideoClip targetClip,
    void Function(DivineVideoClip clip, String thumbnailPath)?
    onThumbnailExtracted,
  ) async {
    try {
      Log.debug(
        '🖼️ Extracting thumbnail at ${timestamp.inSeconds}s for ${targetClip.id}',
        name: 'VideoEditorSplitService',
        category: .video,
      );
      final thumbnailResult = await VideoThumbnailService.extractThumbnail(
        videoPath: await sourceClip.requireVideo.safeFilePath(),
        targetTimestamp: timestamp,
      );
      if (thumbnailResult != null) {
        onThumbnailExtracted?.call(targetClip, thumbnailResult.path);
        Log.debug(
          '✅ Thumbnail extracted: ${thumbnailResult.path}',
          name: 'VideoEditorSplitService',
          category: .video,
        );
      }
    } catch (e) {
      Log.warning(
        '⚠️ Failed to extract thumbnail for ${targetClip.id}: $e',
        name: 'VideoEditorSplitService',
        category: .video,
      );
    }
  }
}
