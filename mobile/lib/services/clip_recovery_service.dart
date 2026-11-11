// ABOUTME: Developer-only rescue for locally recorded clips that went missing.
// ABOUTME: Finds rows under other owners and unreferenced files, and reattaches
// ABOUTME: both to the signed-in account.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_editor/clip_media_duration.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Thrown when a claim is attempted with no account to move the rows to.
class NoAccountToRecoverToException implements Exception {
  /// Creates the exception.
  const NoAccountToRecoverToException();

  @override
  String toString() =>
      'NoAccountToRecoverToException: no signed-in account to recover to';
}

/// Recovers recordings the app can no longer show.
///
/// Two failure modes leave a user staring at an empty library while the
/// recordings are still on the device, and this service addresses both:
///
/// * **Rows under another owner.** Every drafts/clips query filters by
///   `ownerPubkey`, so a session that resolved to a different account — or a
///   recording stamped before a session had resolved at all — is invisible
///   rather than gone. [scanRecoverableClips] reports those groups and
///   [claimOwnerGroup] restamps one to the signed-in account.
/// * **Rows gone, files left.** A database reset drops every clip row while
///   the mp4s stay in the documents directory. [scanRecoverableClips] lists
///   the unreferenced files and [importOrphanFiles] rebuilds library rows for
///   them.
///
/// Both are developer-tool operations: they write, and the owner restamp in
/// particular hands another account's rows to the current one. The caller is
/// expected to show the scan before offering either.
class ClipRecoveryService {
  /// Creates a service.
  ///
  /// [clipLibrary] is scoped to the signed-in account and supplies both the
  /// owner to recover *to* and the save path that stamps it. The DAOs are
  /// deliberately unscoped — the whole point is to see rows the scoped queries
  /// hide.
  ClipRecoveryService({
    required ClipsDao clipsDao,
    required DraftsDao draftsDao,
    required ClipCategoriesDao clipCategoriesDao,
    required ClipLibraryService clipLibrary,
    @visibleForTesting Future<Directory> Function()? documentsDirectoryProvider,
    @visibleForTesting
    Future<VideoMetadata> Function(String videoPath)? metadataProvider,
    @visibleForTesting
    Future<String?> Function(String videoPath)? thumbnailProvider,
  }) : _clipsDao = clipsDao,
       _draftsDao = draftsDao,
       _clipCategoriesDao = clipCategoriesDao,
       _clipLibrary = clipLibrary,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _metadataProvider = metadataProvider ?? _readMetadata,
       _thumbnailProvider = thumbnailProvider ?? _extractThumbnail;

  final ClipsDao _clipsDao;
  final DraftsDao _draftsDao;
  final ClipCategoriesDao _clipCategoriesDao;
  final ClipLibraryService _clipLibrary;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<VideoMetadata> Function(String videoPath) _metadataProvider;
  final Future<String?> Function(String videoPath) _thumbnailProvider;

  static const String _logName = 'ClipRecoveryService';

  /// The camera's own output filename, and the only shape this tool will
  /// restore.
  ///
  /// An allowlist rather than a blacklist of known artefacts, because the
  /// documents directory is full of derived mp4s and they cannot be
  /// enumerated: alongside `c2pa_signed_*`, `<clipId>_reversed_*`, `trimmed_`,
  /// `cropped_`, `normalized_`, `divine_`, `stop_motion_`, `merged_` and
  /// `watermarked_`, the chroma-key bake and transform services write a bare
  /// `<microseconds>.mp4` with no prefix at all. A blacklist misses those and
  /// offers the user a list of unrestorable junk; the camera's own output is
  /// also the only family that is irreplaceable, since every other file is
  /// derived from a clip or (for an import) from media that still exists
  /// elsewhere.
  ///
  /// Both timestamp shapes the camera produces have to match, because they
  /// differ per platform: Android formats `yyyyMMdd_HHmmss`
  /// (`VID_20260814_113531.mp4`, see `CameraController.kt`) while iOS and
  /// macOS use epoch milliseconds (`VID_1786700133469.mp4`, see
  /// `CameraController.swift`). Matching only the millisecond shape made this
  /// whole feature a no-op on Android.
  static final RegExp _recordingFileName = RegExp(
    r'^VID_(\d{8}_\d{6}|\d+)\.mp4$',
    caseSensitive: false,
  );

  static Future<VideoMetadata> _readMetadata(String videoPath) =>
      ProVideoEditor.instance.getMetadata(EditorVideo.file(File(videoPath)));

  static Future<String?> _extractThumbnail(String videoPath) async {
    final result = await VideoThumbnailService.extractThumbnail(
      videoPath: videoPath,
    );
    return result?.path;
  }

  /// Reports every locally stored recording, split into what the signed-in
  /// account can already see and what is hidden under another owner, plus the
  /// video files no row references.
  Future<ClipRecoveryReport> scanRecoverableClips() async {
    final currentOwner = _clipLibrary.ownerPubkey;

    // Unscoped on purpose: a null owner makes the DAO's owner predicate a
    // constant true, which is the only way to see the rows the scoped queries
    // filter out. Trashed rows are included — a clip in the bin is still a
    // clip the user can restore.
    final clipRows = await _clipsDao.getAllClips(includeTrashed: true);
    final draftRows = await _draftsDao.getAllDrafts();

    var ownedClipCount = 0;
    var ownedDraftCount = 0;
    final clipCounts = <String, int>{};
    final newestRecordedAt = <String, DateTime>{};
    // Counted per recording, not per row: one recording occupies two clip rows
    // while the editor's autosave draft holds it, and reporting both would put
    // the tool at odds with the library it is meant to explain.
    final seenVisible = <String>{};
    final seenPerOwner = <String, Set<String>>{};
    for (final row in clipRows) {
      final owner = row.ownerPubkey;
      final clipId = _clipIdOf(row);
      if (_isVisibleTo(currentOwner, owner)) {
        if (seenVisible.add(clipId)) ownedClipCount++;
        continue;
      }
      if (!(seenPerOwner[owner!] ??= <String>{}).add(clipId)) continue;
      clipCounts.update(owner, (v) => v + 1, ifAbsent: () => 1);
      final newest = newestRecordedAt[owner];
      if (newest == null || row.recordedAt.isAfter(newest)) {
        newestRecordedAt[owner] = row.recordedAt;
      }
    }

    final draftCounts = <String, int>{};
    for (final row in draftRows) {
      final owner = row.ownerPubkey;
      if (_isVisibleTo(currentOwner, owner)) {
        ownedDraftCount++;
        continue;
      }
      draftCounts.update(owner!, (v) => v + 1, ifAbsent: () => 1);
    }

    final foreignGroups =
        [
          for (final owner in {...clipCounts.keys, ...draftCounts.keys})
            ClipOwnerGroup(
              ownerPubkey: owner,
              clipCount: clipCounts[owner] ?? 0,
              draftCount: draftCounts[owner] ?? 0,
              newestRecordedAt: newestRecordedAt[owner],
            ),
        ]..sort((a, b) {
          final byClips = b.clipCount.compareTo(a.clipCount);
          return byClips != 0 ? byClips : b.draftCount.compareTo(a.draftCount);
        });

    return ClipRecoveryReport(
      currentOwnerPubkey: currentOwner,
      ownedClipCount: ownedClipCount,
      ownedDraftCount: ownedDraftCount,
      foreignGroups: foreignGroups,
      orphanFiles: await _findOrphanFiles(),
    );
  }

  /// Whether a row stamped [rowOwner] is already visible to [currentOwner].
  ///
  /// Mirrors the DAOs' `owner = ? OR owner IS NULL` predicate exactly, and the
  /// `IS NULL` half is why this is not a plain equality check: a row carrying
  /// no owner at all is visible to *every* account, so counting it as hidden
  /// would report a clip the user can already see as one to recover — and offer
  /// a claim that changes nothing about its visibility. A null [currentOwner]
  /// turns the same predicate into a constant true, so nothing is hidden from
  /// it either.
  static bool _isVisibleTo(String? currentOwner, String? rowOwner) =>
      currentOwner == null || rowOwner == null || rowOwner == currentOwner;

  /// The recording a clip row belongs to.
  ///
  /// A library row is keyed by the plain clip id, while a draft-held copy is
  /// keyed `<draftId>:<clipId>` (`DraftsDao.saveDraftWithClips`). The editor
  /// autosaves right after a recording, so for most of a clip's life *both*
  /// rows exist and a per-row count reports one recording as two.
  /// `ClipLibraryService.getAllClips` collapses the pair for the same reason;
  /// this derives the id from the row key rather than decoding the JSON blob,
  /// since the scan reads every row in the database.
  static String _clipIdOf(ClipRow row) {
    final draftId = row.draftId;
    if (draftId == null) return row.id;
    final prefix = '$draftId:';
    return row.id.startsWith(prefix) ? row.id.substring(prefix.length) : row.id;
  }

  /// Camera recordings in the documents directory that no clip or draft row
  /// references, newest first, each with a preview frame and its length.
  ///
  /// Unreferenced is judged against *every* row rather than the current
  /// account's, so a file belonging to a hidden owner group is not offered
  /// here as well — claiming that group is the right fix for it, and importing
  /// would duplicate the clip under a second row.
  ///
  /// Empty files are dropped rather than listed as unrestorable: a failed
  /// render or an aborted signing pass leaves zero-byte mp4s behind, and
  /// offering them buries the recordings that can actually be restored.
  Future<List<OrphanClipFile>> _findOrphanFiles() async {
    final documents = await _documentsDirectoryProvider();
    if (!documents.existsSync()) return const [];

    final candidates = <File>[];
    try {
      // Non-recursive: the camera writes recordings straight into the
      // documents root, and descending would drag in the database directory
      // and every package's private storage.
      await for (final entity in documents.list(followLinks: false)) {
        if (entity is! File) continue;
        if (!_recordingFileName.hasMatch(p.basename(entity.path))) continue;
        candidates.add(entity);
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: listing ${documents.path} failed: $error',
        name: _logName,
        category: LogCategory.video,
      );
      return const [];
    }
    if (candidates.isEmpty) return const [];

    final referenced = await _clipsDao.referencedFilenames(
      candidates.map((file) => p.basename(file.path)).toSet(),
    );

    final orphans = <OrphanClipFile>[];
    for (final file in candidates) {
      final name = p.basename(file.path);
      if (referenced.contains(name)) continue;
      if (await _draftsDao.isDraftFileReferenced(name)) continue;

      // One stat rather than a length + lastModified pair, so a file deleted
      // mid-scan cannot report a size from before and a timestamp from after.
      final stat = file.statSync();
      // statSync does not throw for a missing path — unlike lengthSync, it
      // returns a notFound sentinel whose size is -1 and whose timestamp is
      // the epoch. So a file that vanished between documents.list() and here
      // has to be filtered on the sentinel: `== 0` let -1 through, and it was
      // then listed as an orphan at "-1 B", dated 1970, subtracting from
      // orphanBytes in the copied report and offering a rebuild that could
      // only fail.
      if (stat.type == FileSystemEntityType.notFound || stat.size <= 0) {
        continue;
      }

      orphans.add(
        OrphanClipFile(
          path: file.path,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          duration: await _durationOrNull(file.path),
          previewPath: await _previewOrNull(file.path),
        ),
      );
    }

    orphans.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return orphans;
  }

  /// Playing length of [videoPath], or null when it cannot be read — which is
  /// how the UI marks a file that will probably not restore into anything
  /// playable.
  Future<Duration?> _durationOrNull(String videoPath) async {
    try {
      final metadata = await _metadataProvider(videoPath);
      return commonTrackEnd(metadata) ?? metadata.duration;
    } on Object catch (error) {
      Log.warning(
        '$_logName: could not read metadata for $videoPath: $error',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// A frame from [videoPath] for the scan listing, or null when none could be
  /// taken. Best-effort: a missing preview must not drop a restorable file.
  Future<String?> _previewOrNull(String videoPath) async {
    try {
      return await _thumbnailProvider(videoPath);
    } on Object catch (error) {
      Log.warning(
        '$_logName: could not extract a preview for $videoPath: $error',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Restamps every row owned by [group] onto the signed-in account, so its
  /// clips and drafts become visible again.
  ///
  /// Rows carrying no owner at all are swept up alongside it — that is the
  /// contract of the DAO's claim, and the same one sign-in already applies to
  /// them. It changes nothing the operator can see: those rows were already
  /// visible to this account (see [_isVisibleTo]) and the scan counts them as
  /// such, so the claim only attributes them.
  ///
  /// Returns how many recordings became visible — counted per recording rather
  /// than per row, and over [group]'s own rows only, so it matches both the
  /// group's reported count and what the library gains. The swept-up unowned
  /// rows are excluded because they were already visible.
  ///
  /// Throws [NoAccountToRecoverToException] when there is no account to move
  /// the rows to.
  Future<int> claimOwnerGroup(ClipOwnerGroup group) async {
    final newOwner = _clipLibrary.ownerPubkey;
    if (newOwner == null ||
        newOwner.isEmpty ||
        newOwner == DraftStorageService.anonymousOwnerPubkey) {
      // The marker is the reachable case, and the reason this is not a plain
      // null check: the owner resolver falls back to it rather than to null, so
      // a null/empty owner only happens in a test that constructs the library
      // by hand. Claiming onto the marker would move a real account's rows into
      // the bucket every owner-scoped query hides — the failure this whole
      // feature exists to undo — and hand them to whoever signs in next.
      throw const NoAccountToRecoverToException();
    }

    final source = group.ownerPubkey;
    // Counted before the write, because afterwards the rows are
    // indistinguishable from everything else the account owns.
    final recordings = <String>{
      for (final row in await _clipsDao.getAllClips(includeTrashed: true))
        if (row.ownerPubkey == source) _clipIdOf(row),
    };

    final movedRows = await _clipsDao.claimLegacyRows(
      newOwner,
      sourceOwnerPubkey: source,
    );
    await _draftsDao.claimLegacyRows(newOwner, sourceOwnerPubkey: source);
    await _clipCategoriesDao.claimLegacyRows(
      newOwner,
      sourceOwnerPubkey: source,
    );

    Log.info(
      '$_logName: claimed ${recordings.length} recording(s) across '
      '$movedRows clip row(s) from $source (plus any unowned) for $newOwner',
      name: _logName,
      category: LogCategory.video,
    );
    return recordings.length;
  }

  /// Rebuilds a library clip for each of [files] and saves it to the signed-in
  /// account's library.
  ///
  /// Only the video survives a database reset, so the rebuilt clip carries
  /// what can be read back off the file — duration, source resolution, a fresh
  /// thumbnail, and the file's modification time as the recording time.
  /// Everything the row used to hold about *intent* is gone for good: the lens
  /// metadata, the proof attestation, the ghost frame, and the aspect ratio the
  /// user had selected (a recording is stored at the sensor's ratio, so the
  /// crop choice left no trace in the file).
  ///
  /// Returns the clips that were rebuilt. A file whose metadata cannot be read
  /// is skipped and logged rather than failing the whole import.
  Future<List<DivineVideoClip>> importOrphanFiles(
    List<OrphanClipFile> files,
  ) async {
    final imported = <DivineVideoClip>[];
    for (final file in files) {
      try {
        final clip = await _rebuildClip(file);
        await _clipLibrary.saveClip(clip);
        imported.add(clip);
        Log.info(
          '$_logName: recovered ${file.path} as ${clip.id}',
          name: _logName,
          category: LogCategory.video,
        );
      } on Object catch (error, stackTrace) {
        Log.error(
          '$_logName: could not recover ${file.path}: $error',
          name: _logName,
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return imported;
  }

  Future<DivineVideoClip> _rebuildClip(OrphanClipFile file) async {
    final metadata = await _metadataProvider(file.path);
    // The scan already read both; prefer its values so what the operator saw
    // in the listing is what the restored clip carries.
    final duration =
        file.duration ?? commonTrackEnd(metadata) ?? metadata.duration;
    final resolution = metadata.resolution;
    final sourceAspectRatio = resolution.height == 0
        ? null
        : resolution.width / resolution.height;

    return DivineVideoClip(
      // Namespaced and stamped with the source file so a second import of the
      // same file updates its row instead of stacking duplicates.
      id: 'recovered_${p.basenameWithoutExtension(file.path)}',
      video: EditorVideo.file(File(file.path)),
      duration: duration,
      recordedAt: file.modifiedAt,
      // The user's crop choice is unrecoverable; default to the app's own
      // default rather than inventing one from the sensor's ratio.
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: sourceAspectRatio,
      thumbnailPath: file.previewPath ?? await _thumbnailProvider(file.path),
    );
  }
}
