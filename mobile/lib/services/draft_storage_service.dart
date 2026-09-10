// ABOUTME: Service for persisting vine drafts using Drift database
// ABOUTME: Handles save, load, delete, clear, and migration from SharedPreferences

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/draft_local_audio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/local_audio_cleanup_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class DraftStorageService {
  DraftStorageService({
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    this.ownerPubkey,
    SharedPreferences? preferences,
    CrashReporter? crashReporter,
  }) : _crashReporter = crashReporter ?? const SilentCrashReporter(),
       _draftsDao = draftsDao,
       _clipsDao = clipsDao,
       _localAudioCleanup = LocalAudioCleanupService(
         draftsDao: draftsDao,
         clipsDao: clipsDao,
         preferences: preferences,
       );

  final DraftsDao _draftsDao;

  /// Shared sweep over every store that can name a draft-local audio file.
  final LocalAudioCleanupService _localAudioCleanup;

  final CrashReporter _crashReporter;

  @visibleForTesting
  CrashReporter get crashReporterForTesting => _crashReporter;

  final ClipsDao _clipsDao;

  /// Hex pubkey of the current account. When set, new drafts are tagged
  /// with this owner and queries filter by it (plus legacy NULL rows).
  final String? ownerPubkey;

  /// Owner marker for drafts captured before a user is signed in.
  ///
  /// Do not store new signed-out drafts as NULL: NULL is the legacy migration
  /// shape that signed-in services intentionally claim for backward
  /// compatibility.
  static const anonymousOwnerPubkey = '__anonymous_offline_draft__';

  static const String _storageKey = 'vine_drafts';

  /// Migrate drafts from SharedPreferences to Drift database.
  ///
  /// TODO(hm21): Remove migration in the future.
  /// That migration was created at 03.03.2026.
  Future<void> migrateOldDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return;

    final documentsPath = await getDocumentsPath();
    final jsonList = json.decode(jsonString) as List<dynamic>;

    final failedDrafts = <dynamic>[];
    var successCount = 0;

    for (final rawJson in jsonList) {
      try {
        final draftMap = rawJson as Map<String, dynamic>;
        final draft = DivineVideoDraft.fromJson(draftMap, documentsPath);

        // Persist the draft and its clips atomically. A non-transactional
        // migration could be interrupted (e.g. the app is backgrounded or
        // killed right after an OS update) between writing the draft row
        // and its clip rows, leaving a draft with 0 clips. Readers treat
        // such rows as corrupted and permanently delete them, silently
        // destroying the user's drafts. Committing both in one transaction
        // guarantees a draft is never observed without its clips.
        final draftJson = draft.toJson();
        // Remove clips from JSON blob – they live in their own table.
        draftJson.remove('clips');

        final clipDataList = <DraftClipData>[];
        for (var i = 0; i < draft.clips.length; i++) {
          final clip = draft.clips[i];
          clipDataList.add(
            DraftClipData(
              id: clip.id,
              orderIndex: i,
              durationMs: clip.duration.inMilliseconds,
              recordedAt: clip.recordedAt,
              data: json.encode(clip.toJson()),
              filePath: clip.video?.file?.path != null
                  ? p.basename(clip.video!.file!.path)
                  : null,
              thumbnailPath: clip.thumbnailPath != null
                  ? p.basename(clip.thumbnailPath!)
                  : null,
            ),
          );
        }

        await _draftsDao.saveDraftWithClips(
          id: draft.id,
          title: draft.title,
          description: draft.description,
          publishStatus: draft.publishStatus.name,
          createdAt: draft.createdAt,
          lastModified: draft.lastModified,
          publishAttempts: draft.publishAttempts,
          publishError: draft.publishError,
          data: json.encode(draftJson),
          renderedFilePath: draft.finalRenderedClip?.video?.file?.path != null
              ? p.basename(draft.finalRenderedClip!.video!.file!.path)
              : null,
          renderedThumbnailPath: draft.finalRenderedClip?.thumbnailPath != null
              ? p.basename(draft.finalRenderedClip!.thumbnailPath!)
              : null,
          customThumbnailPath: draft.customThumbnailPath != null
              ? p.basename(draft.customThumbnailPath!)
              : null,
          clipDataList: clipDataList,
          ownerPubkey: ownerPubkey,
        );
        successCount++;
      } catch (e) {
        Log.error(
          'Failed to migrate draft: $e',
          name: 'DraftStorageService',
          category: LogCategory.video,
        );
        failedDrafts.add(rawJson);
      }
    }

    if (failedDrafts.isEmpty) {
      // All drafts migrated successfully - remove the legacy key
      await prefs.remove(_storageKey);
      Log.info(
        '📂 Migrated $successCount drafts from SharedPreferences to Drift',
        name: 'DraftStorageService',
      );
    } else {
      // Keep only failed drafts for retry on next app launch
      await prefs.setString(_storageKey, json.encode(failedDrafts));
      Log.warning(
        '⚠️ Migrated $successCount drafts, ${failedDrafts.length} failed and '
        'will be retried on next launch',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
    }
  }

  /// Save a draft to storage. If a draft with the same ID exists, it will be
  /// updated. When updating, clip/thumbnail files the old draft referenced but
  /// the new one no longer does are orphaned.
  ///
  /// By default those orphans are deleted immediately. Pass
  /// [deferOrphanCleanup] to instead hand the candidate paths to the caller —
  /// the active editor session uses this to keep files that are still reachable
  /// through its undo/redo history alive until teardown. Deleting them mid-
  /// session would land undo/redo on a clip whose source file is gone
  /// (`COMPOSITION_ERROR`); the session reaps them once that history is gone.
  ///
  /// Throws a `SqliteException` if the underlying Drift read/write fails —
  /// e.g. the database is locked, the disk is full, or the file is corrupt.
  /// These are environmental IO failures (an `Exception`, not an `Error`), so
  /// per the reportability matrix they are expected rather than bugs. Orphaned
  /// clip-file deletions are best-effort: their failures are logged and
  /// swallowed, never thrown.
  Future<void> saveDraft(
    DivineVideoDraft draft, {
    void Function(List<String?> orphanPaths)? deferOrphanCleanup,
  }) async {
    Log.debug(
      '💾 Saving draft: ${draft.id}',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );

    // Check for orphaned files before overwriting. Delete them only after the
    // new row is committed, so this draft's old indexed file references no
    // longer protect files it just stopped using. Read across accounts: the
    // upsert below is keyed on `id` alone and destroys whatever row is there,
    // so an owner-scoped read here would skip the cleanup for the very files
    // it just orphaned.
    final documentsPath = await getDocumentsPath();
    final existingDraft = await _loadDraftAcrossAccounts(draft.id);
    final newOwnedFilePaths = _ownedFilePaths(draft, documentsPath);
    final detachedOwnedFilePaths = _detachedOwnedFilePaths(
      draft,
      documentsPath,
    );
    var orphanedFiles = const <String?>[];
    if (existingDraft != null) {
      // Both halves diff [DivineVideoClip.ownedFilePaths]. The local list this
      // replaced had fallen behind the model — no reverse caches, no ghost
      // frame — so a render a transform dropped was invisible to this sweep.
      orphanedFiles = <String?>[
        ..._ownedFilePaths(
          existingDraft,
          documentsPath,
        ).where((path) => !newOwnedFilePaths.contains(path)),
      ];
    }

    // Upsert draft and clips atomically in a single transaction
    final draftJson = draft.toJson();
    // Indexed draft and clip columns already own ordinary timeline media.
    // Only layer-owned assets need the JSON manifest; including indexed clip
    // media here would keep it alive after its clip rows are deliberately
    // removed (for example by a library hard-delete).
    draftJson[draftOwnedFileBasenamesKey] = detachedOwnedFilePaths
        .map(p.basename)
        .toSet()
        .toList();
    // Remove clips from JSON blob – they live in their own table
    draftJson.remove('clips');

    final clipDataList = <DraftClipData>[];
    for (var i = 0; i < draft.clips.length; i++) {
      final clip = draft.clips[i];
      clipDataList.add(
        DraftClipData(
          id: clip.id,
          orderIndex: i,
          durationMs: clip.duration.inMilliseconds,
          recordedAt: clip.recordedAt,
          data: json.encode(clip.toJson()),
          filePath: clip.video?.file?.path != null
              ? p.basename(clip.video!.file!.path)
              : null,
          thumbnailPath: clip.thumbnailPath != null
              ? p.basename(clip.thumbnailPath!)
              : null,
          categoryId: clip.categoryId,
          archivedAt: clip.archivedAt,
        ),
      );
    }

    await _draftsDao.saveDraftWithClips(
      id: draft.id,
      title: draft.title,
      description: draft.description,
      publishStatus: draft.publishStatus.name,
      createdAt: draft.createdAt,
      lastModified: draft.lastModified,
      publishAttempts: draft.publishAttempts,
      publishError: draft.publishError,
      data: json.encode(draftJson),
      renderedFilePath: draft.finalRenderedClip?.video?.file?.path != null
          ? p.basename(draft.finalRenderedClip!.video!.file!.path)
          : null,
      renderedThumbnailPath: draft.finalRenderedClip?.thumbnailPath != null
          ? p.basename(draft.finalRenderedClip!.thumbnailPath!)
          : null,
      customThumbnailPath: draft.customThumbnailPath != null
          ? p.basename(draft.customThumbnailPath!)
          : null,
      clipDataList: clipDataList,
      ownerPubkey: ownerPubkey,
    );

    // Reap orphaned files only after the new draft/clip rows are committed, so
    // this draft's old indexed references no longer protect them. When the
    // caller defers, hand over the candidates instead — they may still be
    // reachable through the editor's live undo/redo history.
    if (deferOrphanCleanup != null) {
      deferOrphanCleanup(orphanedFiles);
    } else {
      await FileCleanupService.deleteFilesIfUnreferenced(
        orphanedFiles,
        draftsDao: _draftsDao,
        clipsDao: _clipsDao,
      );
    }
  }

  Set<String> _ownedFilePaths(DivineVideoDraft draft, String documentsPath) => {
    for (final clip in draft.clips)
      ...clip.ownedFilePaths.whereType<String>().where(
        (path) => path.isNotEmpty,
      ),
    if (draft.finalRenderedClip != null)
      ...draft.finalRenderedClip!.ownedFilePaths.whereType<String>().where(
        (path) => path.isNotEmpty,
      ),
    if (draft.customThumbnailPath case final path? when path.isNotEmpty) path,
    ...DetachedClipLayerData.ownedFilePathsInHistory(
      draft.editorStateHistory,
      documentsPath,
    ),
  };

  Set<String> _detachedOwnedFilePaths(
    DivineVideoDraft draft,
    String documentsPath,
  ) => DetachedClipLayerData.ownedFilePathsInHistory(
    draft.editorStateHistory,
    documentsPath,
  );

  /// Get total count of drafts without loading their data.
  Future<int> getDraftCount() => _draftsDao.getCount(ownerPubkey: ownerPubkey);

  /// Returns drafts matching any of the given [statuses].
  ///
  /// Queries the database directly by `publish_status` column instead of
  /// loading all drafts into memory. Corrupted rows (0 clips) are cleaned
  /// up automatically. Drafts whose clip source files are missing are excluded
  /// from playable lists without mutating their rows.
  Future<List<DivineVideoDraft>> getDraftsByPublishStatuses(
    Set<PublishStatus> statuses,
  ) async {
    final documentsPath = await getDocumentsPath();
    final drafts = <DivineVideoDraft>[];
    final corruptedDraftIds = <String>[];

    for (final status in statuses) {
      final rows = await _draftsDao.getDraftsByStatus(
        status.name,
        ownerPubkey: ownerPubkey,
      );

      for (final row in rows) {
        final clipRows = await _clipsDao.getClipsByDraftId(row.id);

        if (clipRows.isEmpty) {
          corruptedDraftIds.add(row.id);
          continue;
        }

        final draft = _tryParseDraftRow(
          row: row,
          clipRows: clipRows,
          documentsPath: documentsPath,
        );
        final validatedDraft = draft == null ? null : _validatedDraft(draft);
        if (validatedDraft != null) {
          drafts.add(validatedDraft);
        }
      }
    }

    if (corruptedDraftIds.isNotEmpty) {
      Log.warning(
        '🧹 Removing ${corruptedDraftIds.length} corrupted '
        'draft(s) with 0 clips: $corruptedDraftIds',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      for (final id in corruptedDraftIds) {
        await _draftsDao.deleteDraft(id);
      }
    }

    return drafts;
  }

  /// Updates the publish status of a draft directly in the database.
  ///
  /// More efficient than loading the full draft, mutating, and saving.
  Future<bool> updatePublishStatus({
    required String draftId,
    required PublishStatus status,
    String? publishError,
    int? publishAttempts,
  }) {
    return _draftsDao.updatePublishStatus(
      id: draftId,
      publishStatus: status.name,
      publishError: publishError,
      publishAttempts: publishAttempts,
    );
  }

  /// Whether the draft [id] exists but is owned by a different account.
  ///
  /// Returns `false` for an unknown id (a draft that was never persisted) and
  /// for legacy rows with no owner, so only a genuine cross-account read is
  /// reported. Used to stop a publish from posting another account's video
  /// under the signed-in identity after an account switch.
  Future<bool> isDraftOwnedByAnotherAccount(String id) async {
    final row = await _draftsDao.getDraftById(id);
    final owner = row?.ownerPubkey;
    if (owner == null) return false;
    return owner != ownerPubkey;
  }

  Future<DivineVideoDraft?> getDraftById(String id) =>
      _loadDraft(id, scopedToOwner: true);

  /// Reads the draft [id] regardless of who owns it.
  ///
  /// Row bookkeeping — deleting a row by primary key, or diffing the row an
  /// upsert is about to overwrite — is not an account-facing read: the write it
  /// pairs with (`DraftsDao.deleteDraft`, `saveDraftWithClips`) is keyed on
  /// `id` alone, so scoping only the read would leave the two disagreeing and
  /// silently skip the file cleanup. Anything the user sees goes through
  /// [getDraftById] instead.
  Future<DivineVideoDraft?> _loadDraftAcrossAccounts(String id) =>
      _loadDraft(id, scopedToOwner: false);

  Future<DivineVideoDraft?> _loadDraft(
    String id, {
    required bool scopedToOwner,
  }) async {
    final row = await _draftsDao.getDraftById(
      id,
      ownerPubkey: scopedToOwner ? ownerPubkey : null,
    );
    if (row == null) {
      Log.debug(
        '📝 Draft not found: $id',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      return null;
    }

    final clipRows = await _clipsDao.getClipsByDraftId(id);
    final documentsPath = await getDocumentsPath();
    return _tryParseDraftRow(
      row: row,
      clipRows: clipRows,
      documentsPath: documentsPath,
    );
  }

  /// Whether a draft row with [id] exists at all, whoever owns it.
  ///
  /// Bookkeeping probe, same rationale as [_loadDraftAcrossAccounts].
  Future<bool> draftExists(String id) async =>
      await _draftsDao.getDraftById(id) != null;

  /// Deserialize a single draft [row] with its [clipRows], returning `null`
  /// (and logging) when the row is corrupt so one bad draft can't abort a
  /// list load or throw out of a single-draft lookup.
  DivineVideoDraft? _tryParseDraftRow({
    required DraftRow row,
    required List<ClipRow> clipRows,
    required String documentsPath,
  }) {
    try {
      return DivineVideoDraft.fromDriftRow(
        row: row,
        clipRows: clipRows,
        documentsPath: documentsPath,
      );
    } catch (e) {
      Log.error(
        '🧹 Skipping corrupt draft ${row.id}: $e',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Get draft by ID with validation - filters out clips with missing video files.
  ///
  /// Returns null if draft not found or all clips are invalid.
  Future<DivineVideoDraft?> getValidatedDraftById(String id) async {
    final draft = await getDraftById(id);
    if (draft == null) return null;

    final validClips = _filterValidClips(draft.clips);
    if (validClips.isEmpty) {
      Log.warning(
        '📝 Draft $id has no valid clips - all video files missing',
        category: LogCategory.video,
      );
      return null;
    }

    if (validClips.length < draft.clips.length) {
      Log.info(
        '📝 Draft $id: ${validClips.length} valid clips '
        '(${draft.clips.length - validClips.length} removed)',
        category: LogCategory.video,
      );
    }

    return _clearMissingFinalRenderedClip(
      draft.copyWith(clips: validClips, skipUpdateLastModified: true),
    );
  }

  /// Get the autosaved draft with validation.
  ///
  /// Returns null if no autosave exists or all clips are invalid.
  Future<DivineVideoDraft?> getAutosaveDraft() async {
    return getValidatedDraftById(VideoEditorConstants.autoSaveId);
  }

  /// Hides unusable clips from a loaded draft without counting as an edit:
  /// the stored `lastModified` is kept, so reading the list can't restamp
  /// every draft with the current time (and scramble its newest-first order).
  DivineVideoDraft? _validatedDraft(DivineVideoDraft draft) {
    final validClips = _filterValidClips(draft.clips);
    if (validClips.isEmpty) {
      Log.warning(
        '📝 Draft ${draft.id} hidden because all clip files are missing',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      return null;
    }

    if (validClips.length < draft.clips.length) {
      Log.info(
        '📝 Draft ${draft.id}: ${validClips.length} playable clips '
        '(${draft.clips.length - validClips.length} missing)',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
    }

    return _clearMissingFinalRenderedClip(
      draft.copyWith(clips: validClips, skipUpdateLastModified: true),
    );
  }

  /// Filter clips to only those whose source media still exists.
  ///
  /// Normal video clips are kept only when their file resolves. Frames-only
  /// stop-motion clips are *sanitized* rather than dropped wholesale: unreadable
  /// stills are removed and the clip survives while at least one readable still
  /// remains (it drops out only when none do). This mirrors the per-frame
  /// salvage in `VideoEditorNotifier.restoreDraft`, so list/autosave validation
  /// can't hide a stop-motion draft before restore gets a chance to recover it.
  List<DivineVideoClip> _filterValidClips(List<DivineVideoClip> clips) {
    return [
      for (final clip in clips)
        if (clip.isStopMotion)
          ?StopMotionFrameOps.sanitizedClip(clip)
        else if (clip.hasResolvableVideoFile)
          clip,
    ];
  }

  DivineVideoDraft _clearMissingFinalRenderedClip(DivineVideoDraft draft) {
    final finalClip = draft.finalRenderedClip;
    if (finalClip == null) return draft;

    if (finalClip.hasResolvableVideoFile) return draft;

    Log.info(
      '📝 Draft ${draft.id}: final rendered clip missing, clearing reference',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );
    return draft.copyWith(
      clearFinalRenderedClip: true,
      skipUpdateLastModified: true,
    );
  }

  /// Get all drafts from storage
  Future<List<DivineVideoDraft>> getAllDrafts() async {
    try {
      final rows = await _draftsDao.getAllDrafts(ownerPubkey: ownerPubkey);
      final documentsPath = await getDocumentsPath();
      final drafts = <DivineVideoDraft>[];
      final corruptedDraftIds = <String>[];

      for (final row in rows) {
        final clipRows = await _clipsDao.getClipsByDraftId(row.id);

        if (clipRows.isEmpty) {
          corruptedDraftIds.add(row.id);
          continue;
        }

        final draft = _tryParseDraftRow(
          row: row,
          clipRows: clipRows,
          documentsPath: documentsPath,
        );
        final validatedDraft = draft == null ? null : _validatedDraft(draft);
        if (validatedDraft != null) {
          drafts.add(validatedDraft);
        }
      }

      // Clean up corrupted drafts (0 clips) in the background
      if (corruptedDraftIds.isNotEmpty) {
        Log.warning(
          '🧹 Removing ${corruptedDraftIds.length} corrupted '
          'draft(s) with 0 clips: $corruptedDraftIds',
          name: 'DraftStorageService',
          category: LogCategory.video,
        );
        for (final id in corruptedDraftIds) {
          await _draftsDao.deleteDraft(id);
        }
      }

      return drafts;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to load drafts: $e',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      await _crashReporter.recordError(
        e,
        stackTrace,
        reason: 'Failed to load drafts from database',
      );
      rethrow;
    }
  }

  /// Delete a draft by ID and remove associated video/thumbnail files
  Future<void> deleteDraft(String id) async {
    // Fetch draft before deleting so we can clean up files. Read across
    // accounts to stay consistent with DraftsDao.deleteDraft, which deletes by
    // primary key — an owner-scoped read would turn every deletion issued by a
    // service whose ownerPubkey no longer matches the row into a silent no-op.
    final draft = await _loadDraftAcrossAccounts(id);
    if (draft == null) return;
    final documentsPath = await getDocumentsPath();
    final detachedClipPaths = DetachedClipLayerData.ownedFilePathsInHistory(
      draft.editorStateHistory,
      documentsPath,
    );

    Log.debug(
      '🗑️ Deleting draft: $id',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );

    // Delete the draft and its clip rows first, then delete files — so the
    // reference scan in FileCleanupService no longer sees this draft's clips
    // and can reclaim their media (DraftsDao.deleteDraft removes both rows).
    await _draftsDao.deleteDraft(id);

    // Ghost frames live only in the clip `data` blob, so — like draft-local
    // audio — the indexed-column check can't tell that a surviving draft (e.g.
    // a duplicate sharing this draft's clips) still references them. This
    // draft's own rows are already gone, so every clip the scan sees is a
    // legitimate survivor whose ghost frame must stay alive.
    final referencedGhostFrames = await _referencedGhostFrameFilenames();

    // Delete clip files only if not referenced by clip library
    await FileCleanupService.deleteRecordingClipsFiles(
      draft.clips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
      referencedGhostFrameFilenames: referencedGhostFrames,
    );

    // Delete final rendered clip if present
    if (draft.finalRenderedClip != null) {
      await FileCleanupService.deleteRecordingClipFiles(
        draft.finalRenderedClip!,
        draftsDao: _draftsDao,
        clipsDao: _clipsDao,
        referencedGhostFrameFilenames: referencedGhostFrames,
      );
    }

    // Delete the user-selected cover, which lives outside the clips.
    await FileCleanupService.deleteFileIfUnreferenced(
      draft.customThumbnailPath,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );

    await FileCleanupService.deleteFilesIfUnreferenced(
      detachedClipPaths.toList(),
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );

    // Delete draft-local audio (imported audio + voice-over recordings) held
    // in the editor metadata, keeping any file a surviving draft still
    // references (e.g. a draft shared with its publish copy).
    final audioPaths = draft.localAudioFilePaths;
    if (audioPaths.isNotEmpty) {
      await FileCleanupService.deleteDraftAudioFiles(
        audioPaths,
        draftsDao: _draftsDao,
        clipsDao: _clipsDao,
        referencedAudioFilenames: await _referencedLocalAudioFilenames(),
      );
    }
  }

  /// Basenames of draft-local audio files referenced by any surviving draft or
  /// saved sound, across all accounts.
  ///
  /// The same local audio file can be shared by a draft and its publish copy —
  /// `copyWith` carries [DivineVideoDraft.editorStateHistory] and
  /// [DivineVideoDraft.selectedSound] — so this guard keeps shared audio until
  /// the last referencing draft is deleted.
  ///
  /// My Sounds is scanned too. Audio imported from the Library is written
  /// under whichever draft was open at the time, so deleting that draft would
  /// otherwise reclaim a file a saved sound still points at — and unlike a
  /// stale path, a deleted file cannot be healed on load (#7977).
  ///
  /// Callers run this *after* deleting the draft they are cleaning up, so
  /// every row it sees is a survivor and there is nothing to exclude.
  ///
  /// The sweep's completeness flag is deliberately ignored here: an unreadable
  /// store only ever costs this caller references it would have *kept*, so the
  /// worst case is the pre-#7977 behaviour for one file. Saved-sound removal
  /// deletes on the same set and must not ignore it.
  Future<Set<String>> _referencedLocalAudioFilenames() async =>
      (await _localAudioCleanup.referencedAudioFilenames()).filenames;

  /// Basenames of clip ghost-frame files referenced by any surviving clip,
  /// across all accounts — library clips, whose `draftId` is NULL, included.
  ///
  /// A clip's ghost frame is persisted only inside the clip `data` blob (no
  /// indexed column), so a draft that shares clips with another draft — a
  /// duplicate, or a publish copy — cannot be protected by the indexed-column
  /// check when the sibling is deleted. This scans every remaining clip's blob
  /// and collects the shared ghost basenames so deletion keeps them alive until
  /// the last referencing clip is gone. Never throws: a corrupt blob is logged
  /// and skipped.
  ///
  /// Trashed clips are included: a soft-deleted clip can still be restored, so
  /// a ghost frame it shares with the draft being deleted must survive. This
  /// mirrors [ClipsDao.isFileReferenced], which already protects the indexed
  /// video/thumbnail files of trashed clips.
  ///
  /// Uses [ClipsDao.getClipsWithGhostFrames] rather than reading the whole clip
  /// table: this scan runs on every draft deletion, and decoding every blob in
  /// the database made it grow with the size of the clip library (#6548).
  ///
  /// Callers run this *after* deleting the draft they are cleaning up, so
  /// every clip it sees is a survivor and there is nothing to exclude.
  Future<Set<String>> _referencedGhostFrameFilenames() async {
    final clipRows = await _clipsDao.getClipsWithGhostFrames();
    final filenames = <String>{};

    for (final row in clipRows) {
      try {
        final data = json.decode(row.data) as Map<String, dynamic>;
        final ghostFramePath = data['ghostFramePath'] as String?;
        if (ghostFramePath != null && ghostFramePath.isNotEmpty) {
          filenames.add(p.basename(ghostFramePath));
        }
      } catch (e) {
        Log.error(
          '🧹 Skipping clip ${row.id} during ghost-frame reference scan: $e',
          name: 'DraftStorageService',
          category: LogCategory.video,
        );
      }
    }

    return filenames;
  }

  /// Clear all drafts from storage and delete associated files
  Future<void> clearAllDrafts() async {
    Log.info(
      '🧹 Clearing all drafts',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );
    final drafts = await getAllDrafts();
    final allClips = drafts.expand((draft) => draft.clips).toList();
    final allFinalRenderedClips = drafts
        .map((draft) => draft.finalRenderedClip)
        .whereType<DivineVideoClip>()
        .toList();
    final allCustomThumbnailPaths = drafts
        .map((draft) => draft.customThumbnailPath)
        .toList();
    final allAudioPaths = drafts
        .expand((draft) => draft.localAudioFilePaths)
        .toSet();

    // Clear drafts and their clip rows first, then delete files — so the
    // reference scan can reclaim the media (DraftsDao.clearAll removes both;
    // library clips with a NULL draftId are preserved).
    await _draftsDao.clearAll();

    // Every draft and its clips are gone; the clips that survive are library
    // clips (active or trashed). Ghost frames live only in the clip `data`
    // blob, so protect any a surviving library clip still references.
    final referencedGhostFrames = await _referencedGhostFrameFilenames();

    // Delete clip files only if not referenced by clip library
    await FileCleanupService.deleteRecordingClipsFiles(
      allClips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
      referencedGhostFrameFilenames: referencedGhostFrames,
    );
    await FileCleanupService.deleteRecordingClipsFiles(
      allFinalRenderedClips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
      referencedGhostFrameFilenames: referencedGhostFrames,
    );
    await FileCleanupService.deleteFilesIfUnreferenced(
      allCustomThumbnailPaths,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
    // No draft survives a clear-all, but My Sounds does — and a saved sound
    // can point at a file the cleared drafts owned (#7977).
    await FileCleanupService.deleteDraftAudioFiles(
      allAudioPaths,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
      referencedAudioFilenames: _localAudioCleanup
          .savedSoundReferences()
          .filenames,
    );
  }
}
