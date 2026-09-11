// ABOUTME: Manual storage maintenance for the settings "Storage" screen.
// ABOUTME: Clears regenerable caches, measures the user's own content, sweeps
// ABOUTME: media no clip or draft references, and audits the library.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/storage_footprint.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Usage and optional budget for one cache category.
class CacheUsageCategory extends Equatable {
  /// Creates cache category usage.
  const CacheUsageCategory({required this.usedBytes, this.limitBytes});

  /// Bytes currently held by this category.
  final int usedBytes;

  /// Category budget in bytes, or null when the category is unbudgeted.
  final int? limitBytes;

  @override
  List<Object?> get props => [usedBytes, limitBytes];
}

/// Clearable cache usage split by the categories that own their budgets.
class CacheUsage extends Equatable {
  /// Creates a cache usage breakdown.
  const CacheUsage({
    required this.video,
    required this.images,
    required this.transitionSeams,
    required this.tempRenders,
  });

  /// Empty cache usage for initial UI state.
  static const empty = CacheUsage(
    video: CacheUsageCategory(
      usedBytes: 0,
      limitBytes: kCacheLimitDefaultBytes,
    ),
    images: CacheUsageCategory(usedBytes: 0),
    transitionSeams: CacheUsageCategory(
      usedBytes: 0,
      limitBytes: kSeamCacheLimitBytes,
    ),
    tempRenders: CacheUsageCategory(usedBytes: 0),
  );

  /// Feed video download cache.
  final CacheUsageCategory video;

  /// Image and thumbnail cache.
  final CacheUsageCategory images;

  /// Persisted transition previews: the seam renders, whose budget
  /// [CacheUsageCategory.limitBytes] reports, plus the boundary frames the
  /// transition picker extracts beside them.
  final CacheUsageCategory transitionSeams;

  /// Regenerable temp renders and render scratch directories; intentionally
  /// unbudgeted.
  final CacheUsageCategory tempRenders;

  /// Total bytes currently held by all clearable categories.
  int get totalBytes =>
      video.usedBytes +
      images.usedBytes +
      transitionSeams.usedBytes +
      tempRenders.usedBytes;

  @override
  List<Object?> get props => [video, images, transitionSeams, tempRenders];
}

/// Documents-directory usage split by who can reclaim it.
///
/// The documents directory is where the app keeps what it cannot re-create:
/// recordings, drafts, renders, stills, and sounds. [contentBytes] is what a
/// clip, draft, pending upload, or sound-library entry still owns; the
/// orphaned figures are media files nothing points at any more, which the
/// Storage screen can remove (#7641). The two add up to everything under the
/// directory except the regenerable caches [CacheUsage] already covers.
class DocumentsUsage extends Equatable {
  /// Creates a documents usage breakdown.
  const DocumentsUsage({
    required this.contentBytes,
    required this.orphanedFileCount,
    required this.orphanedBytes,
  });

  /// Empty usage for initial UI state.
  static const empty = DocumentsUsage(
    contentBytes: 0,
    orphanedFileCount: 0,
    orphanedBytes: 0,
  );

  /// Bytes the user's clips, drafts, and sounds own — plus anything the app
  /// cannot classify, which is deliberately reported here rather than as
  /// reclaimable.
  final int contentBytes;

  /// Media files under the documents root that no clip, draft, or pending
  /// upload references and that are old enough not to belong to an in-flight
  /// render.
  final int orphanedFileCount;

  /// Bytes held by the orphaned files.
  final int orphanedBytes;

  /// Everything under the documents directory that is not a regenerable cache.
  int get totalBytes => contentBytes + orphanedBytes;

  @override
  List<Object?> get props => [contentBytes, orphanedFileCount, orphanedBytes];
}

class _DirectorySize {
  const _DirectorySize({required this.bytes, this.isIncomplete = false});

  final int bytes;
  final bool isIncomplete;
}

/// A regular file under the documents root with the size it had when listed.
class _DocumentsFile {
  const _DocumentsFile({required this.file, required this.bytes});

  final File file;
  final int bytes;

  String get name => p.basename(file.path);
}

/// One pass over the documents root: what the user's content holds and which
/// files no row references.
class _DocumentsScan {
  const _DocumentsScan({required this.contentBytes, required this.orphans});

  final int contentBytes;
  final List<_DocumentsFile> orphans;

  int get orphanedBytes => orphans.fold(0, (sum, file) => sum + file.bytes);
}

/// Clears re-downloadable / regenerable media caches, measures and sweeps the
/// documents directory, and audits the clip library for broken entries.
///
/// What [clearCaches] clears: the feed video download cache, the
/// image/thumbnail cache, leftover temp render files and scratch directories,
/// and the regenerable transition previews. What it never touches: the user's
/// clip-library files (recorded/imported videos), drafts, sounds, keys, or
/// preferences — those live outside the cleared directories.
///
/// What [removeOrphanedFiles] removes: media files directly under the
/// documents root that no clip row, draft row, or pending upload references —
/// the abandoned, interrupted, and failed renders that were unreachable from
/// every other screen. A file younger than [orphanGraceAge] is never swept,
/// so a render still being written is safe even though its row does not
/// exist yet.
///
/// `docs/STORAGE_MANAGEMENT.md` lists every Storage action with what it
/// removes and what it leaves alone.
class StorageManagementService {
  /// Creates a service.
  ///
  /// [videoCache] and [imageCache] are the app's download caches;
  /// [clipLibrary] is scoped to the current account. [clipsDao] and
  /// [draftsDao] are deliberately unscoped: the orphan sweep judges a file
  /// against *every* row, so media belonging to a signed-out account is never
  /// mistaken for junk. The directory providers are injectable for tests and
  /// otherwise resolve the OS temp and documents directories.
  /// [protectedPaths] supplies upload inputs that must survive both a cache
  /// clear and an orphan sweep.
  StorageManagementService({
    required MediaCacheManager videoCache,
    required MediaCacheManager imageCache,
    required ClipLibraryService clipLibrary,
    required ClipsDao clipsDao,
    required DraftsDao draftsDao,
    required SharedPreferences prefs,
    @visibleForTesting Future<Directory> Function()? temporaryDirectoryProvider,
    @visibleForTesting Future<Directory> Function()? documentsDirectoryProvider,
    @visibleForTesting
    Future<Directory> Function()? applicationSupportDirectoryProvider,
    @visibleForTesting
    Future<Directory> Function()? applicationCacheDirectoryProvider,
    @visibleForTesting Future<int> Function(File file)? fileLengthProvider,
    @visibleForTesting DateTime Function()? now,
    Set<String> Function()? protectedPaths,
  }) : _videoCache = videoCache,
       _imageCache = imageCache,
       _clipLibrary = clipLibrary,
       _clipsDao = clipsDao,
       _draftsDao = draftsDao,
       _prefs = prefs,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _applicationSupportDirectoryProvider =
           applicationSupportDirectoryProvider ??
           getApplicationSupportDirectory,
       _applicationCacheDirectoryProvider =
           applicationCacheDirectoryProvider ?? getApplicationCacheDirectory,
       _fileLengthProvider = fileLengthProvider,
       _now = now ?? DateTime.now,
       _protectedPaths = protectedPaths ?? _noProtectedPaths;

  final MediaCacheManager _videoCache;
  final MediaCacheManager _imageCache;
  final ClipLibraryService _clipLibrary;
  final ClipsDao _clipsDao;
  final DraftsDao _draftsDao;
  final SharedPreferences _prefs;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _applicationSupportDirectoryProvider;
  final Future<Directory> Function() _applicationCacheDirectoryProvider;
  final Future<int> Function(File file)? _fileLengthProvider;
  final DateTime Function() _now;
  final Set<String> Function() _protectedPaths;

  /// A documents-root file modified more recently than this is never treated
  /// as orphaned, whatever the database says about it.
  ///
  /// A render writes its output before any row points at it — the publish
  /// flow creates the pending upload only once `divine_<micros>.mp4` is
  /// complete, and the camera holds a fresh recording in memory until the
  /// session is saved. Every one of those looks unreferenced for a while, and
  /// the modification time is the one signal that survives the app being
  /// backgrounded mid-render. Matches [TempRenderJanitor.staleRenderAge]: an
  /// hour is longer than any render and shorter than any abandoned session
  /// the sweep is for.
  static const Duration orphanGraceAge = TempRenderJanitor.staleRenderAge;

  static const String _logName = 'StorageManagementService';
  static const String _imageCacheDir = 'openvine_image_cache';
  static const String _seamDir = 'transition_seams';

  /// Boundary frames the transition picker extracts beside the seams; keyed
  /// by clip, trim and side, and re-extracted on the next open when missing.
  static const String _transitionFramesDir = 'transition_frames';

  /// Documents subdirectories that hold only regenerable previews. Counted
  /// and cleared as cache, never as the user's content.
  static const Set<String> _documentsCacheDirs = {
    _seamDir,
    _transitionFramesDir,
  };

  /// Extensions of the media the app writes to the documents root — the only
  /// files the orphan sweep will ever remove. Anything else there (legacy Hive
  /// boxes, lock files, a database left by an old build) is counted as content
  /// and left alone, because a wrong guess deletes something irreplaceable
  /// while a conservative one merely under-reports.
  static const Set<String> _sweepableMediaExtensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.wav',
    '.m4a',
    '.aac',
    '.mp3',
  };

  static Set<String> _noProtectedPaths() => const {};

  /// Total bytes currently held by the clearable caches. Best-effort; a
  /// directory that cannot be read contributes zero rather than throwing.
  Future<int> cacheSizeBytes() async => (await cacheUsage()).totalBytes;

  /// Clearable cache usage split by category and matching budget.
  Future<CacheUsage> cacheUsage() async {
    final temp = await _temporaryDirectoryProvider();
    final docs = await _documentsDirectoryProvider();
    final protectedPaths = _normalizedProtectedPaths();
    var transitionBytes = 0;
    for (final dir in _documentsCacheDirs) {
      transitionBytes += (await _dirSize(Directory(p.join(docs.path, dir))))
          .bytes;
    }
    var tempRenderBytes = await _tempRenderBytes(temp, protectedPaths);
    for (final dir in TempRenderDirectories.all) {
      tempRenderBytes += (await _dirSize(Directory(p.join(temp.path, dir))))
          .bytes;
    }
    return CacheUsage(
      video: CacheUsageCategory(
        usedBytes: (await _dirSize(
          Directory(p.join(temp.path, kVideoCacheDirectoryName)),
        )).bytes,
        limitBytes: videoCacheLimitBytes(),
      ),
      images: CacheUsageCategory(
        usedBytes: (await _dirSize(
          Directory(p.join(temp.path, _imageCacheDir)),
        )).bytes,
        limitBytes: _imageCache.maxCacheSizeBytes,
      ),
      transitionSeams: CacheUsageCategory(
        usedBytes: transitionBytes,
        limitBytes: kSeamCacheLimitBytes,
      ),
      tempRenders: CacheUsageCategory(usedBytes: tempRenderBytes),
    );
  }

  /// Clears every re-downloadable / regenerable cache. The clip library and
  /// all other user content are left untouched.
  Future<void> clearCaches() async {
    await _guard(_videoCache.clearCache);
    await _guard(_imageCache.clearCache);
    final temp = await _temporaryDirectoryProvider();
    // clearCache() only removes DB-tracked entries; orphaned/leaked files in
    // the cache directories survive (the leak from #5986). Delete the
    // directory contents so the freed size matches what cacheSizeBytes counts.
    await _deleteDirContents(
      Directory(p.join(temp.path, kVideoCacheDirectoryName)),
    );
    await _deleteDirContents(Directory(p.join(temp.path, _imageCacheDir)));
    final protectedPaths = _normalizedProtectedPaths();
    await _forEachTempRender(
      temp,
      protectedPaths: protectedPaths,
      action: _deleteQuietly,
    );
    for (final dir in TempRenderDirectories.all) {
      await _deleteDirContents(Directory(p.join(temp.path, dir)));
    }
    final docs = await _documentsDirectoryProvider();
    for (final dir in _documentsCacheDirs) {
      await _deleteDirContents(Directory(p.join(docs.path, dir)));
    }
  }

  /// What the documents directory holds, split into the user's content and
  /// the media files nothing references any more.
  ///
  /// Walks the documents root one level deep: subdirectories other than the
  /// caches [cacheUsage] covers are the user's content wholesale (sounds,
  /// voice-overs, extracted audio), and each top-level file is either owned
  /// by a row, protected, too fresh to judge, not media — all content — or an
  /// orphan. Throws when the reference check itself fails, because a scan
  /// that cannot ask the database must not report anything as reclaimable.
  Future<DocumentsUsage> documentsUsage() async {
    final scan = await _scanDocuments();
    return DocumentsUsage(
      contentBytes: scan.contentBytes,
      orphanedFileCount: scan.orphans.length,
      orphanedBytes: scan.orphanedBytes,
    );
  }

  /// Deletes every orphaned file [documentsUsage] would report, re-checking
  /// references right before deleting so a file that gained a row since the
  /// last measurement is kept. Returns the bytes freed.
  Future<int> removeOrphanedFiles() async {
    final scan = await _scanDocuments();
    var freed = 0;
    for (final orphan in scan.orphans) {
      try {
        await orphan.file.delete();
        freed += orphan.bytes;
      } on Object catch (error) {
        Log.warning(
          '$_logName: deleting orphaned ${orphan.file.path} failed: $error',
          name: _logName,
          category: LogCategory.system,
        );
      }
    }
    Log.info(
      '$_logName: removed ${scan.orphans.length} orphaned file(s), '
      '$freed bytes',
      name: _logName,
      category: LogCategory.system,
    );
    return freed;
  }

  /// Every directory the app writes to, each with its largest immediate
  /// children — the diagnostic for "the OS reports tens of GB but the cache
  /// readout says megabytes".
  ///
  /// [cacheUsage] deliberately covers only what [clearCaches] can reclaim, so
  /// it cannot locate a footprint that sits anywhere else. This walks all four
  /// platform roots instead, including the ones no in-app action clears: the
  /// documents directory (clip library, drafts, rendered videos) and the
  /// durable database, which even the repair wipe preserves.
  ///
  /// Roots that resolve to the same directory are measured once — on Android
  /// the temporary and cache directories are both `getCacheDir()` — so the
  /// totals never double-count. Such a root is labelled with every name that
  /// pointed at it (`Caches + Temporary`) rather than silently dropping the
  /// later one, so a report that lists three roots on Android and four on iOS
  /// says why. A root the platform cannot resolve is omitted rather than
  /// failing the whole measurement.
  ///
  /// Walks the full tree of every root, so it is slow on a large install and
  /// belongs behind an explicit user action.
  Future<StorageFootprint> measureFootprint({int childrenPerRoot = 12}) async {
    final providers = <String, Future<Directory> Function()>{
      'Documents': _documentsDirectoryProvider,
      'Application Support': _applicationSupportDirectoryProvider,
      'Caches': _applicationCacheDirectoryProvider,
      'Temporary': _temporaryDirectoryProvider,
    };

    // Resolve every root before measuring any, so the ones that share a
    // directory can be collapsed into a single labelled walk.
    final byPath = <String, ({Directory dir, List<String> labels})>{};
    for (final entry in providers.entries) {
      final dir = await _resolveRoot(entry.key, entry.value);
      if (dir == null) continue;
      final resolved = byPath.putIfAbsent(
        _normalizePath(dir.path),
        () => (dir: dir, labels: <String>[]),
      );
      resolved.labels.add(entry.key);
    }

    final roots = <StorageFootprintRoot>[];
    for (final resolved in byPath.values) {
      roots.add(
        await _measureRoot(
          label: resolved.labels.join(' + '),
          dir: resolved.dir,
          childrenPerRoot: childrenPerRoot,
        ),
      );
    }
    return StorageFootprint(roots: roots);
  }

  /// The directory [provider] points at, or null when the platform has no
  /// such root — a missing root must not fail the whole measurement.
  Future<Directory?> _resolveRoot(
    String label,
    Future<Directory> Function() provider,
  ) async {
    try {
      return await provider();
    } on Object catch (error) {
      Log.warning(
        '$_logName: resolving $label failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
      return null;
    }
  }

  Future<StorageFootprintRoot> _measureRoot({
    required String label,
    required Directory dir,
    required int childrenPerRoot,
  }) async {
    final children = <StorageFootprintEntry>[];
    var totalBytes = 0;
    var isIncomplete = false;
    if (dir.existsSync()) {
      try {
        await for (final entity in dir.list(followLinks: false)) {
          final isDirectory = entity is Directory;
          final size = switch (entity) {
            Directory() => await _dirSize(entity),
            File() => _DirectorySize(bytes: await _fileLength(entity)),
            _ => const _DirectorySize(bytes: 0),
          };
          isIncomplete = isIncomplete || size.isIncomplete;
          final bytes = size.bytes;
          totalBytes += bytes;
          children.add(
            StorageFootprintEntry(
              name: p.basename(entity.path),
              bytes: bytes,
              isDirectory: isDirectory,
            ),
          );
        }
      } on Object catch (error) {
        isIncomplete = true;
        Log.warning(
          '$_logName: listing ${dir.path} failed: $error',
          name: _logName,
          category: LogCategory.system,
        );
      }
    }
    children.sort((a, b) => b.bytes.compareTo(a.bytes));
    return StorageFootprintRoot(
      label: label,
      path: dir.path,
      totalBytes: totalBytes,
      largestChildren: children.take(childrenPerRoot).toList(),
      childCount: children.length,
      isIncomplete: isIncomplete,
    );
  }

  /// Library clips whose backing media is gone — broken entries that can
  /// no longer play and should be cleaned up.
  Future<List<DivineVideoClip>> findBrokenClips() async {
    final clips = await _clipLibrary.getAllClips();
    return clips.where(_isUnrecoverable).toList();
  }

  /// Whether nothing playable remains for [clip]: a video clip whose file is
  /// gone, or a frames-only stop-motion set with no readable still left.
  ///
  /// A stop-motion set that still has at least one readable still is
  /// salvageable (see [StopMotionFrameOps.sanitizedClip], the same per-still
  /// policy the restore/editor paths use). Treating it as broken here would let
  /// [removeBrokenClips] hard-delete the row and destroy the surviving frames
  /// just because one still went missing.
  bool _isUnrecoverable(DivineVideoClip clip) {
    if (clip.isStopMotion) {
      return StopMotionFrameOps.sanitizedClip(clip) == null;
    }
    return !clip.hasResolvableVideoFile;
  }

  /// Permanently removes the given broken [clips] from the library.
  Future<void> removeBrokenClips(List<DivineVideoClip> clips) async {
    for (final clip in clips) {
      await _clipLibrary.hardDelete(clip.id);
    }
  }

  /// The user-configured video-cache byte budget, or
  /// [kCacheLimitDefaultBytes] when none is set.
  int videoCacheLimitBytes() =>
      _prefs.getInt(kCacheLimitPrefKey) ?? kCacheLimitDefaultBytes;

  /// Persists [bytes] (clamped to
  /// `[kCacheLimitMinBytes, kCacheLimitMaxBytes]`) as the video-cache budget,
  /// applies it, and trims immediately so a lowered limit shrinks the cache
  /// right away.
  Future<void> setVideoCacheLimit(int bytes) async {
    final clamped = bytes.clamp(kCacheLimitMinBytes, kCacheLimitMaxBytes);
    await _prefs.setInt(kCacheLimitPrefKey, clamped);
    _videoCache.maxCacheSizeBytes = clamped;
    await _videoCache.enforceCacheLimits(force: true);
  }

  Future<_DocumentsScan> _scanDocuments() async {
    final docs = await _documentsDirectoryProvider();
    if (!docs.existsSync()) {
      return const _DocumentsScan(contentBytes: 0, orphans: []);
    }
    // Pending uploads store the absolute path they were created with, and iOS
    // moves the container on every update — so protect by basename, the same
    // way every row reference is matched.
    final protectedNames = {
      for (final filePath in _protectedPaths()) p.basename(filePath),
    };
    final cutoff = _now().subtract(orphanGraceAge);
    var contentBytes = 0;
    final candidates = <_DocumentsFile>[];
    try {
      await for (final entity in docs.list(followLinks: false)) {
        if (entity is Directory) {
          if (_documentsCacheDirs.contains(p.basename(entity.path))) continue;
          contentBytes += (await _dirSize(entity)).bytes;
        } else if (entity is File) {
          // One stat rather than a length + modified pair, so a file deleted
          // mid-scan cannot report a size from before and a time from after.
          final stat = entity.statSync();
          if (stat.type == FileSystemEntityType.notFound) continue;
          final file = _DocumentsFile(file: entity, bytes: stat.size);
          if (_isSweepCandidate(file, stat, protectedNames, cutoff)) {
            candidates.add(file);
          } else {
            contentBytes += stat.size;
          }
        }
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: scanning ${docs.path} failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }

    final referenced = await _referencedBasenames(
      candidates.map((file) => file.name).toSet(),
    );
    final orphans = <_DocumentsFile>[];
    for (final candidate in candidates) {
      if (referenced.contains(candidate.name)) {
        contentBytes += candidate.bytes;
      } else {
        orphans.add(candidate);
      }
    }
    return _DocumentsScan(contentBytes: contentBytes, orphans: orphans);
  }

  /// Whether [file] is media the sweep may remove once no row claims it.
  ///
  /// Everything that fails here is the user's content by definition: a
  /// pending upload's input, a file still being written, or something the
  /// app did not write and cannot vouch for.
  bool _isSweepCandidate(
    _DocumentsFile file,
    FileStat stat,
    Set<String> protectedNames,
    DateTime cutoff,
  ) {
    if (!_sweepableMediaExtensions.contains(
      p.extension(file.name).toLowerCase(),
    )) {
      return false;
    }
    if (protectedNames.contains(file.name)) return false;
    return stat.modified.isBefore(cutoff);
  }

  /// The subset of [names] some clip row, draft row or pending upload still
  /// points at. Basenames, because that is how every row stores a path: iOS
  /// moves the container on update, so absolute paths are rejoined on load.
  Future<Set<String>> _referencedBasenames(Set<String> names) async {
    if (names.isEmpty) return const {};
    final referenced = await _clipsDao.referencedFilenames(names);
    final unresolved = names.difference(referenced);
    if (unresolved.isEmpty) return referenced;
    return referenced.union(
      await _draftsDao.referencedDraftFilenames(unresolved),
    );
  }

  /// Recursive size of [dir], counting every file the process can still read.
  ///
  /// Descends one level at a time rather than with `list(recursive: true)`,
  /// because a recursive listing surfaces the whole tree through a single
  /// stream: the first unreadable subdirectory throws and abandons everything
  /// not yet visited, which silently reported zero for an otherwise readable
  /// tree. Failures are isolated to the directory that caused them, and
  /// [_fileLength] absorbs a file that vanished between listing and stat —
  /// routine here, since the cache trim and the temp-render janitor delete
  /// files while a walk of the same root is still running.
  Future<_DirectorySize> _dirSize(Directory dir) async {
    if (!dir.existsSync()) return const _DirectorySize(bytes: 0);
    var size = 0;
    var isIncomplete = false;
    final pending = <Directory>[dir];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      try {
        await for (final entity in current.list(followLinks: false)) {
          if (entity is File) {
            size += await _fileLength(entity);
          } else if (entity is Directory) {
            pending.add(entity);
          }
        }
      } on Object catch (error) {
        isIncomplete = true;
        Log.warning(
          '$_logName: sizing ${current.path} failed: $error',
          name: _logName,
          category: LogCategory.system,
        );
      }
    }
    return _DirectorySize(bytes: size, isIncomplete: isIncomplete);
  }

  /// Length of [file], or zero when it vanished mid-walk or cannot be read.
  Future<int> _fileLength(File file) async {
    try {
      final lengthProvider = _fileLengthProvider;
      return lengthProvider == null
          ? await file.length()
          : await lengthProvider(file);
    } on Object {
      return 0;
    }
  }

  Future<int> _tempRenderBytes(
    Directory temp,
    Set<String> protectedPaths,
  ) async {
    var size = 0;
    await _forEachTempRender(
      temp,
      protectedPaths: protectedPaths,
      action: (file) async => size += await _fileLength(file),
    );
    return size;
  }

  Future<void> _forEachTempRender(
    Directory temp, {
    required Set<String> protectedPaths,
    required Future<void> Function(File file) action,
  }) async {
    if (!temp.existsSync()) return;
    try {
      await for (final entity in temp.list(followLinks: false)) {
        if (entity is File &&
            TempRenderJanitor.isTempRenderName(p.basename(entity.path))) {
          if (protectedPaths.contains(_normalizePath(entity.path))) continue;
          await action(entity);
        }
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: scanning temp renders failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }
  }

  Set<String> _normalizedProtectedPaths() => {
    for (final filePath in _protectedPaths()) _normalizePath(filePath),
  };

  String _normalizePath(String filePath) => p.normalize(p.absolute(filePath));

  Future<void> _deleteDirContents(Directory dir) async {
    if (!dir.existsSync()) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        await _deleteQuietly(entity);
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: clearing ${dir.path} failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } on Object {
      // Best-effort; a file we cannot delete is retried on the next clear.
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      Log.warning(
        '$_logName: clearCache failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }
  }
}
