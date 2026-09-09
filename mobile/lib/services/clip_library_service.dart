// ABOUTME: Service for persisting video clips to the clip library
// ABOUTME: Handles save, load, delete operations with JSON serialization

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:openvine/constants/clip_library_constants.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

class ClipLibraryService {
  ClipLibraryService({
    required ClipsDao clipsDao,
    required DraftsDao draftsDao,
    required ClipCategoriesDao clipCategoriesDao,
    this.ownerPubkey,
  }) : _clipsDao = clipsDao,
       _draftsDao = draftsDao,
       _clipCategoriesDao = clipCategoriesDao;

  /// How long a soft-deleted clip stays in the trash bin before the
  /// startup purge sweep permanently removes it. Aliases
  /// [ClipLibraryConstants.trashRetention], which the trash UI reads too so
  /// the user-facing "Auto-deletes in N days" copy stays in sync with the
  /// actual cutoff.
  static const Duration trashRetention = ClipLibraryConstants.trashRetention;

  final ClipsDao _clipsDao;
  final DraftsDao _draftsDao;
  final ClipCategoriesDao _clipCategoriesDao;

  /// Hex pubkey of the current account. When set, new clips are tagged
  /// with this owner and queries filter by it (plus legacy NULL rows).
  final String? ownerPubkey;

  static const String _storageKey = 'clip_library';

  static const _uuid = Uuid();

  /// Migrate clips from SharedPreferences to Drift database.
  ///
  /// TODO(hm21): Remove migration in the future.
  /// That migration was created at 03.03.2026.
  Future<void> migrateOldClips() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return;

    final documentsPath = await getDocumentsPath();
    final jsonList = json.decode(jsonString) as List<dynamic>;

    final failedClips = <dynamic>[];
    var successCount = 0;

    for (final rawJson in jsonList) {
      try {
        final clipMap = rawJson as Map<String, dynamic>;
        final clip = DivineVideoClip.fromJson(clipMap, documentsPath);

        await _clipsDao.upsertClip(
          id: clip.id,
          orderIndex: 0,
          durationMs: clip.duration.inMilliseconds,
          recordedAt: clip.recordedAt,
          data: json.encode(clip.toJson()),
          filePath: clip.video?.file?.path != null
              ? p.basename(clip.video!.file!.path)
              : null,
          thumbnailPath: clip.thumbnailPath != null
              ? p.basename(clip.thumbnailPath!)
              : null,
        );
        successCount++;
      } catch (e) {
        Log.error(
          'Failed to migrate clip: $e',
          name: 'ClipLibraryService',
          category: LogCategory.video,
        );
        failedClips.add(rawJson);
      }
    }

    if (failedClips.isEmpty) {
      // All clips migrated successfully - remove the legacy key
      await prefs.remove(_storageKey);
      Log.info(
        '📂 Migrated $successCount clips from SharedPreferences to Drift',
        name: 'ClipLibraryService',
      );
    } else {
      // Keep only failed clips for retry on next app launch
      await prefs.setString(_storageKey, json.encode(failedClips));
      Log.warning(
        '⚠️ Migrated $successCount clips, ${failedClips.length} failed and '
        'will be retried on next launch',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
    }
  }

  /// Save a clip to the library. Updates existing clip if ID matches.
  Future<void> saveClip(DivineVideoClip clip) async {
    Log.debug(
      '💾 Saving clip to library: ${clip.id}',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );

    final existingLibraryRow = await _clipsDao.getClipById(clip.id);
    final existingAutosaveRow = existingLibraryRow == null
        ? await _clipsDao.getClipById(_autosaveDraftRowId(clip.id))
        : null;

    await _clipsDao.upsertClip(
      id: clip.id,
      orderIndex: 0,
      durationMs: clip.duration.inMilliseconds,
      recordedAt: clip.recordedAt,
      data: json.encode(clip.toJson()),
      filePath: clip.video?.file?.path != null
          ? p.basename(clip.video!.file!.path)
          : null,
      thumbnailPath: clip.thumbnailPath != null
          ? p.basename(clip.thumbnailPath!)
          : null,
      ownerPubkey: ownerPubkey,
    );

    if (existingLibraryRow == null && existingAutosaveRow != null) {
      if (existingAutosaveRow.categoryId != null) {
        await _clipsDao.setClipCategory(
          id: clip.id,
          categoryId: existingAutosaveRow.categoryId,
        );
      }
      if (existingAutosaveRow.archivedAt != null) {
        await _clipsDao.setClipArchived(
          id: clip.id,
          archivedAt: existingAutosaveRow.archivedAt,
        );
      }
    }
  }

  /// Get all clips from the library, sorted by creation date (newest first).
  ///
  /// A single corrupt row (e.g. a clip persisted without a file path) is
  /// skipped and logged rather than discarding the entire library — one bad
  /// row must never hide every other clip.
  Future<List<DivineVideoClip>> getAllClips() async {
    try {
      // Include the autosave draft so a just-recorded clip (which the editor
      // immediately holds in its autosave draft) stays visible in the library.
      // Clips saved into a named project keep their own draftId and stay hidden.
      final rows = await _clipsDao.getLibraryClips(
        ownerPubkey: ownerPubkey,
        includeAutosaveDraftId: VideoEditorConstants.autoSaveId,
      );

      final documentsPath = await getDocumentsPath();

      // The clips table keys draft clips by `<draftId>:<clipId>` (composite row
      // id) but library clips by the plain clip id, so the same clip can have a
      // library row (draftId == null) and an autosave-draft row. Both parse to
      // the same `clip.id`; keep one per clip id — preferring the library row —
      // so a just-recorded clip shows exactly once.
      final byClipId = <String, ({String? draftId, DivineVideoClip clip})>{};
      for (final row in rows) {
        final clip = _tryParseClipRow(row, documentsPath, label: 'clip');
        if (clip == null) continue;
        // A placeholder is the colour or still holding the slot a detached
        // clip left behind. It is part of the composition, so the autosave
        // draft has to carry it — but it is a backdrop the editor generated,
        // not footage the user shot, and it has no meaning outside the
        // composition it stands in. Listing it would put a flat colour in the
        // library next to real recordings.
        if (clip.isPlaceholder) continue;
        final existing = byClipId[clip.id];
        if (existing == null ||
            (existing.draftId != null && row.draftId == null)) {
          byClipId[clip.id] = (draftId: row.draftId, clip: clip);
        }
      }

      return byClipId.values.map((e) => e.clip).toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    } catch (e) {
      Log.error(
        '❌ Failed to load clips: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Deserialize a single clip [row], returning `null` (and logging) when the
  /// row is corrupt so one bad clip can't abort the whole list load.
  ///
  /// The organization columns (`category_id`, `archived_at`) live on the row
  /// rather than inside the JSON blob, so they are copied onto the parsed
  /// clip here — the column stays the single source of truth.
  DivineVideoClip? _tryParseClipRow(
    ClipRow row,
    String documentsPath, {
    required String label,
  }) {
    try {
      final clipJson = json.decode(row.data) as Map<String, dynamic>;
      return DivineVideoClip.fromJson(
        clipJson,
        documentsPath,
      ).copyWith(categoryId: row.categoryId, archivedAt: row.archivedAt);
    } catch (e) {
      Log.error(
        '❌ Skipping corrupt $label ${row.id}: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Get a single clip by ID.
  ///
  /// Returns `null` when the row is missing or corrupt, matching the
  /// list loaders' skip-and-log behaviour so a single bad row can't throw
  /// out of a lookup. Callers already treat `null` as "no clip".
  Future<DivineVideoClip?> getClipById(String id) async {
    final row = await _clipsDao.getClipById(id);
    if (row == null) return null;

    final documentsPath = await getDocumentsPath();
    return _tryParseClipRow(row, documentsPath, label: 'clip');
  }

  /// Move a clip to the trash. The clip is hidden from active queries
  /// but its files remain on disk until [purgeExpiredTrash] sweeps them
  /// (default 30-day retention) or [hardDelete] is called explicitly.
  ///
  /// When [clearDraftId] is true the clip's `draft_id` is also nulled,
  /// decoupling it from any session it was recorded into so a restored
  /// clip lands in the library rather than a stale draft. The recorder
  /// path uses `clearDraftId: true`; the library tab leaves it false
  /// since those clips already have no draft.
  ///
  /// Returns true if the clip was found and trashed.
  Future<bool> softDelete(String id, {bool clearDraftId = false}) async {
    final now = DateTime.now();
    final deletedLibraryRow = await _clipsDao.softDeleteClip(
      id: id,
      deletedAt: now,
      clearDraftId: clearDraftId,
    );
    // A set that has been through the editor also has an autosave-draft copy
    // (row id `<autoSaveId>:<clipId>`) which the library surfaces via
    // getLibraryClips(includeAutosaveDraftId:). Trash that row too, or the clip
    // reappears from it the moment the library reloads after deletion.
    final deletedAutosaveRow = await _clipsDao.softDeleteClip(
      id: _autosaveDraftRowId(id),
      deletedAt: now,
      clearDraftId: clearDraftId,
    );
    final ok = deletedLibraryRow || deletedAutosaveRow;
    if (ok) {
      Log.debug(
        '🗑️ Soft-deleted clip: $id',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
    }
    return ok;
  }

  /// Row id of the autosave-draft copy of the clip [clipId], mirroring the
  /// `<draftId>:<clipId>` scheme [DraftsDao.saveDraftWithClips] writes.
  String _autosaveDraftRowId(String clipId) =>
      '${VideoEditorConstants.autoSaveId}:$clipId';

  /// Restore a trashed clip. The clip becomes visible to active queries
  /// again with its previous `draft_id` (library if `draft_id` is NULL).
  ///
  /// Returns true if a trashed clip with [id] was restored.
  Future<bool> restore(String id) async {
    final restoredLibraryRow = await _clipsDao.restoreClip(id);
    // Mirror softDelete: restore the autosave-draft copy too, so an undo brings
    // the set back exactly as it was.
    final restoredAutosaveRow = await _clipsDao.restoreClip(
      _autosaveDraftRowId(id),
    );
    final ok = restoredLibraryRow || restoredAutosaveRow;
    if (ok) {
      Log.debug(
        '♻️ Restored clip: $id',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
    }
    return ok;
  }

  /// Every category owned by the current account, in chip-row order.
  Future<List<ClipCategory>> getCategories() async {
    try {
      final rows = await _clipCategoriesDao.getCategories(
        ownerPubkey: ownerPubkey,
      );
      return [
        for (final row in rows)
          ClipCategory(
            id: row.id,
            name: row.name,
            createdAt: row.createdAt,
            orderIndex: row.orderIndex,
          ),
      ];
    } catch (e) {
      Log.error(
        '❌ Failed to load clip categories: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Create a category named [rawName], appended after the existing ones.
  ///
  /// Returns the created category, or `null` when [rawName] holds no usable
  /// text after trimming — a blank name is rejected rather than stored.
  Future<ClipCategory?> createCategory(String rawName) async {
    final name = ClipCategory.sanitizeName(rawName);
    if (name == null) return null;

    final highest = await _clipCategoriesDao.highestOrderIndex(
      ownerPubkey: ownerPubkey,
    );
    final category = ClipCategory(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      orderIndex: (highest ?? -1) + 1,
    );
    await _clipCategoriesDao.upsertCategory(
      id: category.id,
      name: category.name,
      createdAt: category.createdAt,
      orderIndex: category.orderIndex,
      ownerPubkey: ownerPubkey,
    );
    Log.debug(
      '🗂️ Created clip category: ${category.id}',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );
    return category;
  }

  /// Rename the category [id] to [rawName].
  ///
  /// Returns false when the category is gone or [rawName] holds no usable
  /// text after trimming.
  Future<bool> renameCategory({
    required String id,
    required String rawName,
  }) async {
    final name = ClipCategory.sanitizeName(rawName);
    if (name == null) return false;
    return _clipCategoriesDao.renameCategory(id: id, name: name);
  }

  /// Delete the category [id]. Its clips are kept and fall back to the
  /// library's default view.
  ///
  /// Returns true if the category existed.
  Future<bool> deleteCategory(String id) async {
    final deleted = await _clipCategoriesDao.deleteCategory(id);
    if (deleted) {
      Log.debug(
        '🗂️ Deleted clip category: $id',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
    }
    return deleted;
  }

  /// File the clip [clipId] under [categoryId], or pass `null` to remove it
  /// from its current category.
  ///
  /// Filing and archiving are independent: changing a clip's category leaves
  /// its archive marker alone.
  Future<void> setClipCategory({
    required String clipId,
    required String? categoryId,
  }) async {
    await _writeToBothClipRows(
      clipId,
      (id) => _clipsDao.setClipCategory(
        id: id,
        categoryId: categoryId,
      ),
    );
  }

  /// Archive or unarchive the clip [clipId]. Archived clips stay in the
  /// library but are hidden from its default view.
  Future<void> setClipArchived({
    required String clipId,
    required bool archived,
  }) async {
    final archivedAt = archived ? DateTime.now() : null;
    await _writeToBothClipRows(
      clipId,
      (id) => _clipsDao.setClipArchived(id: id, archivedAt: archivedAt),
    );
  }

  /// Apply [write] to a clip's library row **and** its autosave-draft copy
  /// (row id `<autoSaveId>:<clipId>`).
  ///
  /// A set that has been through the editor exists as both rows, and
  /// [getAllClips] surfaces whichever is present. Writing only one leaves the
  /// other stale, so the clip's category or archive state would flip back the
  /// next time the surviving row is the one that gets loaded.
  Future<void> _writeToBothClipRows(
    String clipId,
    Future<bool> Function(String rowId) write,
  ) async {
    await write(clipId);
    await write(_autosaveDraftRowId(clipId));
  }

  /// Permanently removes a single clip's library row, leaving its on-disk
  /// files untouched.
  ///
  /// Used to drop an abandoned in-progress stop-motion session (all frames
  /// undone): the recorder owns and cleans up the frame files, so — unlike
  /// [hardDelete] — this must not delete them.
  Future<void> deleteClipRow(String id) => _clipsDao.deleteClip(id);

  /// Permanently delete a clip and its files. Skips the trash; use
  /// [softDelete] for the standard delete flow.
  Future<void> hardDelete(String id) async {
    Log.debug(
      '🗑️ Hard-deleting clip: $id',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );

    // A set that went through the editor also has an autosave-draft copy
    // (row id `<autoSaveId>:<clipId>`) which the library surfaces via
    // getLibraryClips(includeAutosaveDraftId:). Remove it alongside the plain
    // library row, or the DB row (and, since it still references the media, its
    // source files) survives "empty trash" and reappears on the next reload.
    final autosaveRowId = _autosaveDraftRowId(id);
    final clip = await getClipById(id);
    final autosaveClip = await getClipById(autosaveRowId);
    if (clip == null && autosaveClip == null) {
      Log.info(
        '🗑️ Clip already deleted, skipping: $id',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return;
    }

    await _clipsDao.deleteClip(id);
    await _clipsDao.deleteClip(autosaveRowId);

    // Reap files only after both rows are gone, so a leftover row can't keep
    // the media referenced.
    await FileCleanupService.deleteRecordingClipsFiles(
      [?clip, ?autosaveClip],
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
  }

  /// Get all trashed library clips, newest-deleted-first.
  Future<List<DivineVideoClip>> getTrashedClips() async {
    try {
      final rows = await _clipsDao.getTrashedLibraryClips(
        ownerPubkey: ownerPubkey,
      );
      final documentsPath = await getDocumentsPath();
      // A set that went through the editor has both a library row and an
      // autosave-draft row; softDelete(clearDraftId: true) nulls draft_id on
      // both, so both match the trashed (draftId IS NULL) query and parse to
      // the same clip.id. Keep one per clip id — mirroring getAllClips — so a
      // trashed set shows (and counts) exactly once. Rows arrive newest-deleted
      // first, so the retained (first) entry keeps that ordering.
      final byClipId = <String, DivineVideoClip>{};
      for (final row in rows) {
        final clip = _tryParseClipRow(
          row,
          documentsPath,
          label: 'trashed clip',
        );
        if (clip == null) continue;
        // Kept out of the trash for the same reason it is kept out of the
        // library: a backdrop the editor generated is not something the user
        // can restore into a composition on its own.
        if (clip.isPlaceholder) continue;
        byClipId.putIfAbsent(
          clip.id,
          () => clip.copyWith(deletedAt: row.deletedAt),
        );
      }
      return byClipId.values.toList();
    } catch (e) {
      Log.error(
        '❌ Failed to load trashed clips: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Hard-delete every trashed clip older than [retention] (default 30
  /// days). Idempotent and safe to run repeatedly on app startup.
  ///
  /// Returns the number of clips purged.
  Future<int> purgeExpiredTrash({Duration retention = trashRetention}) async {
    final cutoff = DateTime.now().subtract(retention);
    final expired = await _clipsDao.getTrashedClipsOlderThan(
      cutoff,
      ownerPubkey: ownerPubkey,
    );
    if (expired.isEmpty) return 0;

    final documentsPath = await getDocumentsPath();
    var purged = 0;
    for (final row in expired) {
      try {
        final clipJson = json.decode(row.data) as Map<String, dynamic>;
        final clip = DivineVideoClip.fromJson(clipJson, documentsPath);
        await _clipsDao.deleteClip(row.id);
        await FileCleanupService.deleteRecordingClipFiles(
          clip,
          draftsDao: _draftsDao,
          clipsDao: _clipsDao,
        );
        purged++;
      } catch (e, s) {
        Log.error(
          '⚠️ Failed to purge trashed clip ${row.id}: $e',
          name: 'ClipLibraryService',
          category: LogCategory.video,
          error: e,
          stackTrace: s,
        );
      }
    }

    Log.info(
      '🧹 Purged $purged trashed clip(s) older than ${retention.inDays}d',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );
    return purged;
  }

  /// Clear all clips from the library and delete associated files
  Future<void> clearAllClips() async {
    Log.info(
      '🧹 Clearing all clips from library',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );
    final activeClips = await getAllClips();
    final trashedClips = await getTrashedClips();
    final clips = [...activeClips, ...trashedClips];

    // Clear active + trashed library rows first, then delete files.
    // clearLibraryClips only removes `draft_id IS NULL` rows, so the
    // autosave-draft copies a set picks up in the editor (row id
    // `<autoSaveId>:<clipId>`) — which getAllClips surfaces as library clips —
    // would otherwise survive with their media. Drop those rows too.
    await _clipsDao.clearLibraryClips();
    await _clipsDao.deleteClipsByDraftId(VideoEditorConstants.autoSaveId);

    // Delete files only if not referenced by drafts
    await FileCleanupService.deleteSavedClipsFiles(
      clips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
  }

  /// Recovers missing thumbnails and ghost frames for clips that were
  /// persisted before their assets had been generated.
  ///
  /// Returns the updated list if any clips were recovered, or the original
  /// list unchanged.
  Future<List<DivineVideoClip>> recoverMissingAssets(
    List<DivineVideoClip> clips,
  ) async {
    final incomplete = clips
        .where((c) => c.thumbnailPath == null || c.ghostFramePath == null)
        .toList();

    if (incomplete.isEmpty) return clips;

    Log.info(
      '📚 Recovering assets for ${incomplete.length} clip(s)',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );

    var updated = false;

    for (final clip in incomplete) {
      try {
        // Stop-motion clips have no rendered video to recover assets from;
        // their thumbnail is the first captured frame.
        if (clip.isStopMotion) continue;
        final videoPath = await clip.video!.safeFilePath();
        var updatedClip = clip;

        if (clip.thumbnailPath == null) {
          final result = await VideoThumbnailService.extractThumbnail(
            videoPath: videoPath,
          );
          if (result != null) {
            updatedClip = updatedClip.copyWith(
              thumbnailPath: result.path,
              thumbnailTimestamp: result.timestamp,
            );
          }
        }

        if (clip.ghostFramePath == null) {
          final ghostPath = await VideoThumbnailService.extractLastFrame(
            videoPath: videoPath,
            videoDuration: clip.duration,
          );
          if (ghostPath != null) {
            updatedClip = updatedClip.copyWith(ghostFramePath: ghostPath);
          }
        }

        if (updatedClip != clip) {
          await saveClip(updatedClip);
          updated = true;
          Log.debug(
            '📚 Recovered assets for clip ${clip.id}',
            name: 'ClipLibraryService',
            category: LogCategory.video,
          );
        }
      } catch (e, s) {
        Log.error(
          '📚 Failed to recover assets for clip ${clip.id}: $e',
          name: 'ClipLibraryService',
          category: LogCategory.video,
          error: e,
          stackTrace: s,
        );
      }
    }

    if (updated) {
      return getAllClips();
    }
    return clips;
  }
}
