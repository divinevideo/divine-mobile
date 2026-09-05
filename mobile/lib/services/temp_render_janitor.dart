// ABOUTME: Shared matching and stale cleanup for regenerable temp render files.
// ABOUTME: Keeps upload, watermark, and storage cleanup using the same filename rules.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:upload_repository/upload_repository.dart';

/// Filename pattern for a regenerable temp render.
class TempRenderPattern {
  /// Creates a pattern matched by filename [prefix] and [extension].
  const TempRenderPattern({
    required this.prefix,
    required this.extension,
    this.excludedPrefixes = const [],
  });

  /// Required filename prefix.
  final String prefix;

  /// Required filename extension, including the leading dot.
  final String extension;

  /// Prefixes that should not match even when [prefix] does.
  final List<String> excludedPrefixes;

  /// Whether [name] matches this temp-render pattern.
  bool matches(String name) =>
      name.startsWith(prefix) &&
      name.endsWith(extension) &&
      !excludedPrefixes.any(name.startsWith);
}

/// Shared temp-render filename patterns.
abstract final class TempRenderPatterns {
  /// Watermarked gallery-save render.
  static const watermarkedVideo = TempRenderPattern(
    prefix: 'watermarked_',
    extension: '.mp4',
  );

  /// Multi-clip upload merge render.
  static const mergedVideo = TempRenderPattern(
    prefix: 'merged_',
    extension: '.mp4',
    excludedPrefixes: ['merged_audio_'],
  );

  /// Multi-clip caption/audio merge render.
  static const mergedAudio = TempRenderPattern(
    prefix: 'merged_audio_',
    extension: '.wav',
  );

  /// Duration-limit trim output; renamed over its source on success, so one
  /// left behind belongs to a trim that never finished.
  static const trimmedVideo = TempRenderPattern(
    prefix: 'trimmed_',
    extension: '.mp4',
  );

  /// Aspect-ratio crop for a gallery save.
  static const croppedVideo = TempRenderPattern(
    prefix: 'cropped_',
    extension: '.mp4',
  );

  /// Per-clip normalization pass of an export.
  static const normalizedVideo = TempRenderPattern(
    prefix: 'normalized_',
    extension: '.mp4',
  );

  /// Retimed preview body of a speed-changed clip.
  static const speedVideo = TempRenderPattern(
    prefix: 'speed_',
    extension: '.mp4',
  );

  /// One-shot audio extraction for caption generation. The copy a draft keeps
  /// lives under the documents directory and is not a temp render.
  static const extractedAudio = TempRenderPattern(
    prefix: 'extracted_audio_',
    extension: '.wav',
  );

  /// Timeline strip thumbnail.
  static const stripThumbnail = TempRenderPattern(
    prefix: 'strip_',
    extension: '.jpg',
  );

  /// All temp-render files that are safe to count and clear.
  ///
  /// The set the settings "Storage" screen counts and clears. It is wider
  /// than what any single stale sweep passes explicitly (#7641): the editor
  /// writes every one of these to the temporary directory, a repair wipe
  /// already removes them, and a routine clear that skipped them reported a
  /// fraction of what it could reclaim.
  static const List<TempRenderPattern> all = [
    watermarkedVideo,
    mergedVideo,
    mergedAudio,
    trimmedVideo,
    croppedVideo,
    normalizedVideo,
    speedVideo,
    extractedAudio,
    stripThumbnail,
  ];
}

/// Temporary-directory subtrees that hold only regenerable render output.
abstract final class TempRenderDirectories {
  /// Speed-render cache (`ClipSpeedRenderService`), keyed by clip and speed
  /// and rebuilt on demand.
  static const speedClips = 'speed_clips';

  /// Bundled-asset and in-memory media that `divine_video_player` copies to
  /// disk because native players cannot read from memory. Rewritten by every
  /// `VideoClip.asset` / `VideoClip.memory` / `AudioTrack` call.
  static const List<String> playerScratch = [
    'divine_player_assets',
    'divine_player_memory',
    'divine_player_audio_assets',
    'divine_player_audio_memory',
  ];

  /// Every directory name that is safe to count and clear wholesale.
  static const List<String> all = [speedClips, ...playerScratch];
}

/// Best-effort janitor for regenerable temp render files.
abstract final class TempRenderJanitor {
  /// Files older than this are no longer expected to be owned by an in-flight
  /// render or platform handoff.
  static const staleRenderAge = Duration(hours: 1);

  /// Whether [name] matches any temp-render [patterns].
  static bool isTempRenderName(
    String name, {
    Iterable<TempRenderPattern> patterns = TempRenderPatterns.all,
  }) => patterns.any((pattern) => pattern.matches(name));

  /// Deletes stale temp renders in [tempDir]. Best-effort: never throws.
  static void deleteStaleTempRenders(
    Directory tempDir, {
    Iterable<TempRenderPattern> patterns = TempRenderPatterns.all,
    Set<String> protectedPaths = const {},
    DateTime? now,
    Duration staleAge = staleRenderAge,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(staleAge);
    final normalizedProtectedPaths = {
      for (final filePath in protectedPaths) _normalizePath(filePath),
    };
    try {
      for (final entity in tempDir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        if (!isTempRenderName(p.basename(entity.path), patterns: patterns)) {
          continue;
        }
        if (normalizedProtectedPaths.contains(_normalizePath(entity.path))) {
          continue;
        }
        try {
          if (entity.statSync().modified.isAfter(cutoff)) continue;
          entity.deleteSync();
        } on Object {
          // Best-effort; a file we cannot delete is retried on the next sweep.
        }
      }
    } on Object {
      // Best-effort; a listing failure must not block the caller.
    }
  }

  /// Deletes stale upload merge renders while preserving unpublished uploads.
  static void deleteStaleMergedUploadRenders(
    Directory tempDir,
    Iterable<PendingUpload> pendingUploads,
  ) => deleteStaleTempRenders(
    tempDir,
    patterns: const [TempRenderPatterns.mergedVideo],
    protectedPaths: {
      for (final upload in pendingUploads)
        if (upload.status != UploadStatus.published) upload.localVideoPath,
    },
  );

  static String _normalizePath(String filePath) =>
      p.normalize(p.absolute(filePath));
}
