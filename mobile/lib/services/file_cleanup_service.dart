// ABOUTME: Central service for safe file deletion with reference checking
// ABOUTME: Only deletes files when not referenced by drafts OR clip library
// ABOUTME: Uses indexed file_path columns for efficient lookups

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// Service for safely deleting clip files while respecting references.
///
/// Files may be shared between drafts and the clip library. This service
/// checks both storage locations before deleting to prevent data loss.
///
/// Uses indexed `file_path` / `thumbnail_path` columns on the clips table
/// and draft-owned file reference columns on the drafts table for efficient
/// lookups without loading all rows.
class FileCleanupService {
  /// Checks if a file is referenced by any clip or draft.
  ///
  /// Extracts the basename from [filePath] and queries the indexed
  /// columns in both the clips and drafts tables.
  static Future<bool> _isFileReferenced(
    String filePath, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final filename = p.basename(filePath);
    if (await clipsDao.isFileReferenced(filename)) return true;
    if (await draftsDao.isDraftFileReferenced(filename)) return true;
    return false;
  }

  /// Deletes a file only if it's not referenced elsewhere.
  ///
  /// Throws:
  ///
  /// * Exceptions from filesystem existence checks or either reference query
  ///   are propagated to the caller. File deletion failures are logged and
  ///   otherwise ignored.
  static Future<void> deleteFileIfUnreferenced(
    String? filePath, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    if (filePath == null || filePath.isEmpty) return;
    if (!File(filePath).existsSync()) return;

    if (await _isFileReferenced(
      filePath,
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    )) {
      Log.info(
        '🔗 File still referenced, skipping delete: $filePath',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
      return;
    }

    await _deleteFile(filePath);
  }

  /// Deletes multiple files, only those not referenced elsewhere.
  ///
  /// A file is kept when its reference state cannot be established or its
  /// deletion fails. The returned paths were not safely processed and may be
  /// retried by callers that own a cleanup queue. Reference and filesystem
  /// failures are logged rather than thrown so one failure does not abandon
  /// the rest of the batch.
  static Future<Set<String>> deleteFilesIfUnreferenced(
    List<String?> filePaths, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final validPaths = filePaths
        .where((path) => path != null && path.isNotEmpty)
        .cast<String>()
        .toList();
    if (validPaths.isEmpty) return {};

    // Resolved as one set: a stop-motion clip hands every one of its stills to
    // this call, and the clip references that hold them are in an unindexed
    // JSON blob — asking per file would scan the table once per still.
    late final Set<String> referencedByClips;
    try {
      referencedByClips = await clipsDao.referencedFilenames(
        validPaths.map(p.basename).toSet(),
      );
    } catch (error) {
      Log.warning(
        '⚠️ Failed to check clip references for cleanup batch: $error',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
      return validPaths.toSet();
    }

    final unprocessed = <String>{};

    for (final path in validPaths) {
      try {
        if (!File(path).existsSync()) continue;
      } catch (error) {
        Log.warning(
          '⚠️ Failed to check file existence during cleanup: '
          '$path - $error',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
        unprocessed.add(path);
        continue;
      }

      final filename = p.basename(path);
      if (referencedByClips.contains(filename)) {
        Log.info(
          '🔗 File still referenced, skipping delete: $path',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
        continue;
      }

      late final bool referencedByDraft;
      try {
        referencedByDraft = await draftsDao.isDraftFileReferenced(filename);
      } catch (error) {
        Log.warning(
          '⚠️ Failed to check draft references during cleanup: '
          '$path - $error',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
        unprocessed.add(path);
        continue;
      }
      if (referencedByDraft) {
        Log.info(
          '🔗 File still referenced, skipping delete: $path',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
        continue;
      }

      if (!await _deleteFile(path)) unprocessed.add(path);
    }

    return unprocessed;
  }

  /// [DivineVideoClip.ownedFilePaths] minus the ghost frame, which the callers
  /// hand to [deleteGhostFrameFiles] instead — that path additionally guards
  /// against a sibling clip sharing the same ghost file, which the plain
  /// reference check below cannot see.
  static List<String?> _recordingClipFilePaths(DivineVideoClip clip) {
    final ghostFramePath = clip.ghostFramePath;
    return clip.ownedFilePaths
        .where((path) => ghostFramePath == null || path != ghostFramePath)
        .toList();
  }

  /// [DivineVideoClip.ownedFilePaths] with the video resolved rather than read
  /// raw: a library clip can carry an iOS container path from a previous
  /// install, and `safeFilePath()` re-resolves it against the current one.
  static Future<List<String?>> _savedClipFilePaths(DivineVideoClip clip) async {
    final rawVideoPath = clip.video?.file?.path;
    return [
      if (clip.video != null) await clip.video!.safeFilePath(),
      ...clip.ownedFilePaths.where((path) => path != rawVideoPath),
    ];
  }

  /// Deletes draft-local audio files in [audioFilePaths], skipping any still
  /// referenced elsewhere.
  ///
  /// Imported audio and voice-over recordings live in a draft's editor
  /// metadata rather than an indexed file column, so a surviving draft that
  /// shares the same file (e.g. a draft and its publish copy) cannot be
  /// detected by the indexed-column check. The caller therefore supplies
  /// [referencedAudioFilenames] — the basenames of local audio still
  /// referenced by other drafts — and a file is kept when its basename is in
  /// that set. The indexed clip/draft reference check still runs as a
  /// defensive backstop.
  ///
  /// Throws:
  ///
  /// * Exceptions from filesystem existence checks or either reference query
  ///   are propagated to the caller. File deletion failures are logged and
  ///   otherwise ignored.
  static Future<void> deleteDraftAudioFiles(
    Iterable<String> audioFilePaths, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    Set<String> referencedAudioFilenames = const {},
  }) async {
    for (final path in audioFilePaths) {
      if (path.isEmpty) continue;
      if (referencedAudioFilenames.contains(p.basename(path))) {
        Log.info(
          '🔗 Audio still referenced by another draft, skipping delete: $path',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
        continue;
      }
      await deleteFileIfUnreferenced(
        path,
        draftsDao: draftsDao,
        clipsDao: clipsDao,
      );
    }
  }

  /// Deletes clip ghost-frame files in [ghostFramePaths], skipping any still
  /// referenced by another clip.
  ///
  /// A clip's ghost frame (the last-frame overlay used for continue-recording
  /// alignment and transitions) is persisted only inside the clip `data` blob,
  /// not an indexed file column, so a surviving clip that shares the same ghost
  /// file (e.g. a draft and its duplicate) cannot be detected by the
  /// indexed-column check. The caller supplies [referencedGhostFrameFilenames]
  /// — the basenames of ghost frames still referenced by other clips — and a
  /// file is kept when its basename is in that set. The indexed clip/draft
  /// reference check still runs as a defensive backstop.
  ///
  /// Throws:
  ///
  /// * Exceptions from filesystem existence checks or either reference query
  ///   are propagated to the caller. File deletion failures are logged and
  ///   otherwise ignored.
  static Future<void> deleteGhostFrameFiles(
    Iterable<String?> ghostFramePaths, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    Set<String> referencedGhostFrameFilenames = const {},
  }) async {
    for (final path in ghostFramePaths) {
      if (path == null || path.isEmpty) continue;
      if (referencedGhostFrameFilenames.contains(p.basename(path))) {
        Log.info(
          '🔗 Ghost frame still referenced by another clip, skipping delete: '
          '$path',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
        continue;
      }
      await deleteFileIfUnreferenced(
        path,
        draftsDao: draftsDao,
        clipsDao: clipsDao,
      );
    }
  }

  /// Deletes files for a RecordingClip if not referenced.
  ///
  /// Video and thumbnail files are protected by their indexed columns; ghost
  /// frames live only in the clip `data` blob and are guarded instead by
  /// [referencedGhostFrameFilenames] (see [deleteGhostFrameFiles]).
  static Future<void> deleteRecordingClipFiles(
    DivineVideoClip clip, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    Set<String> referencedGhostFrameFilenames = const {},
  }) async {
    await deleteFilesIfUnreferenced(
      _recordingClipFilePaths(clip),
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
    await deleteGhostFrameFiles(
      [clip.ghostFramePath],
      draftsDao: draftsDao,
      clipsDao: clipsDao,
      referencedGhostFrameFilenames: referencedGhostFrameFilenames,
    );
  }

  /// Deletes files for multiple RecordingClips if not referenced.
  ///
  /// Video and thumbnail files are protected by their indexed columns; ghost
  /// frames live only in the clip `data` blob and are guarded instead by
  /// [referencedGhostFrameFilenames] (see [deleteGhostFrameFiles]).
  static Future<void> deleteRecordingClipsFiles(
    List<DivineVideoClip> clips, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    Set<String> referencedGhostFrameFilenames = const {},
  }) async {
    final indexedPaths = clips.expand(_recordingClipFilePaths).toList();

    await deleteFilesIfUnreferenced(
      indexedPaths,
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
    await deleteGhostFrameFiles(
      clips.map((clip) => clip.ghostFramePath),
      draftsDao: draftsDao,
      clipsDao: clipsDao,
      referencedGhostFrameFilenames: referencedGhostFrameFilenames,
    );
  }

  /// Deletes files for multiple SavedClips if not referenced
  static Future<void> deleteSavedClipsFiles(
    List<DivineVideoClip> clips, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final paths = <String?>[
      for (final clip in clips) ...await _savedClipFilePaths(clip),
    ];

    await deleteFilesIfUnreferenced(
      paths,
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
  }

  /// Internal helper to delete a single file
  static Future<bool> _deleteFile(String filePath) async {
    try {
      await File(filePath).delete();
      Log.info(
        '🗑️ Deleted file: $filePath',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
      return true;
    } on PathNotFoundException {
      Log.info(
        '🗑️ File already deleted: $filePath',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
      return true;
    } catch (e) {
      Log.warning(
        '⚠️ Failed to delete file: $filePath - $e',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
      return false;
    }
  }
}
