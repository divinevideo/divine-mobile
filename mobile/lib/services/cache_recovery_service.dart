// ABOUTME: In-app service to clear corrupted cache and recover from database issues
// ABOUTME: Works on all platforms including iOS devices where shell scripts don't work

import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service to recover from corrupted app data and caches
class CacheRecoveryService {
  static const String _logName = 'CacheRecoveryService';

  static const Set<String> _disposableHiveBoxNames = {
    HiveBoxNames.hashtagStats,
    HiveBoxNames.peopleLists,
  };

  /// Clear all app caches and databases to recover from corruption
  /// This works on iOS devices, Android, and desktop platforms
  ///
  /// [clearPersonalEvents] clears the `personal_events` Drift table. It is a
  /// callback rather than a box name because #6986 moved that data out of Hive,
  /// and the database directory is protected wholesale (see
  /// [_durableDatabaseDirSegments]) — so without an explicit clear the user's
  /// own events would silently become the one disposable cache that a repair
  /// wipe cannot reach.
  static Future<bool> clearAllCaches({
    Future<void> Function()? clearPersonalEvents,
  }) async {
    try {
      Log.info(
        '🧹 Starting cache recovery process',
        name: _logName,
        category: LogCategory.system,
      );

      int clearedItems = 0;

      // 1. Clear all Hive boxes
      clearedItems += await _clearHiveBoxes();

      // 1b. Clear the disposable Drift tables that live inside the protected
      // database directory.
      if (clearPersonalEvents != null) {
        try {
          await clearPersonalEvents();
          clearedItems++;
        } catch (e) {
          Log.warning(
            'Failed to clear personal events: $e',
            name: _logName,
            category: LogCategory.system,
          );
        }
      }

      // 2. Clear app support directory (sandboxed, safe)
      clearedItems += await _clearAppSupportDirectory();

      // 3. Clear temporary files
      clearedItems += await _clearTempDirectory();

      // 4. Clear specific cache directories
      clearedItems += await _clearCacheDirectory();

      Log.info(
        '✅ Cache recovery completed - cleared $clearedItems items',
        name: _logName,
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        '❌ Cache recovery failed: $e',
        name: _logName,
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Clear disposable Hive cache boxes.
  static Future<int> _clearHiveBoxes() async {
    int cleared = 0;

    try {
      // Get all open boxes and clear them. We iterate over known disposable box
      // names instead of trying to access all open boxes.
      final boxNames = _disposableHiveBoxNames.difference(_durableHiveBoxNames);

      for (final boxName in boxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.clear();
            cleared++;
            Log.debug(
              'Cleared Hive box: $boxName',
              name: _logName,
              category: LogCategory.system,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to clear Hive box $boxName: $e',
            name: _logName,
            category: LogCategory.system,
          );
        }
      }

      // Also try to delete known box files from disk
      for (final boxName in boxNames) {
        try {
          await Hive.deleteBoxFromDisk(boxName);
          cleared++;
        } catch (e) {
          // Box might not exist, which is fine
          Log.debug(
            'Box $boxName not found or already deleted',
            name: _logName,
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.warning(
        'Error clearing Hive boxes: $e',
        name: _logName,
        category: LogCategory.system,
      );
    }

    return cleared;
  }

  @visibleForTesting
  static Future<int> clearHiveBoxesForTesting() => _clearHiveBoxes();

  @visibleForTesting
  static Set<String> get disposableHiveBoxNamesForTesting =>
      _disposableHiveBoxNames;

  /// Durable database directory under Application Support that must NEVER be
  /// deleted by cache clearing. It holds the live SQLite database
  /// ({appSupport}/openvine/database/divine_db.db) — local-only user data
  /// (drafts, DMs, pending uploads/actions, reactions, reposts) that cannot be
  /// re-fetched. Segments mirror db_client's `buildSharedDatabasePath`.
  ///
  /// Deleting this directory while the Drift connection is open unlinks the
  /// file's inode, so every later write returns SqliteException(1032 DBMOVED)
  /// and is silently swallowed until the app restarts (#4968), on top of
  /// destroying the durable data.
  static const List<String> _durableDatabaseDirSegments = [
    'openvine',
    'database',
  ];

  /// Hive boxes holding local-only state that cache clearing must preserve.
  ///
  /// `notifications` is named for the feature, not its contents: its only key
  /// is `push_preferences`, the notification settings the user chose. The
  /// notification inbox is a Drift table inside the protected database dir.
  /// Wiping this box drops the user back to all-on defaults, which the next
  /// toggle republishes over the choices they made (#6919).
  /// `push_notification_preferences_dirty` holds edits that have not reached
  /// the push service yet plus the published-kinds schema marker, so losing it
  /// strands an unsynced edit.
  ///
  /// Their files sit under `{appSupport}/openvine/` — the one home path
  /// `HiveStorageService` gives Hive — which is why
  /// [_clearAppSupportDirectory] has to protect them by path as well as
  /// skipping them above.
  static const Set<String> _durableHiveBoxNames = {
    HiveBoxNames.pendingUploads,
    HiveBoxNames.notifications,
    HiveBoxNames.pushNotificationPreferencesDirty,
  };

  @visibleForTesting
  static Set<String> get durableHiveBoxNamesForTesting => _durableHiveBoxNames;

  /// `.hivec` is protected alongside `.hive` because it is box data, not a
  /// scratch file: compaction writes the compacted box there before renaming
  /// it over the box file, and Hive restores from it when the box file is
  /// missing. A compaction interrupted between those two steps leaves it as
  /// the only copy of the box, so clearing it would lose exactly the state
  /// these boxes are protected for.
  static final List<List<String>> _durableHiveBoxFileSegments = [
    for (final boxName in _durableHiveBoxNames) ...[
      ['openvine', '$boxName.hive'],
      ['openvine', '$boxName.hivec'],
      ['openvine', '$boxName.lock'],
    ],
  ];

  /// Clear app support directory (NOT Documents - that's sandboxed on macOS),
  /// preserving the durable database directory (see [_durableDatabaseDirSegments]).
  static Future<int> _clearAppSupportDirectory() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      if (!appSupportDir.existsSync()) return 0;
      return await deleteDirectoryContentsExcept(
        appSupportDir,
        protectedPath: _durableDatabasePath(appSupportDir),
        additionalProtectedPaths: _durableHiveBoxPaths(appSupportDir),
      );
    } catch (e) {
      Log.warning(
        'Error clearing app support directory: $e',
        name: _logName,
        category: LogCategory.system,
      );
      return 0;
    }
  }

  /// Recursively deletes the contents of [dir], preserving [protectedPath] and
  /// its subtree wherever it sits beneath [dir]. Directories that are ancestors
  /// of [protectedPath] are recursed into (so their other children are still
  /// cleared) rather than deleted wholesale; everything else is removed.
  ///
  /// This is how cache clearing avoids unlinking the open database file (#4968):
  /// the live `openvine/database` directory is skipped while the rest of
  /// Application Support — including the disposable cache_sync database under
  /// `openvine/cache` — is cleared.
  @visibleForTesting
  static Future<int> deleteDirectoryContentsExcept(
    Directory dir, {
    required String protectedPath,
    List<String> additionalProtectedPaths = const [],
  }) async {
    final protectedPaths = [
      protectedPath,
      ...additionalProtectedPaths,
    ].where(_pathExists).toList();
    if (protectedPaths.any((path) => p.equals(dir.path, path))) {
      return 0;
    }
    var cleared = 0;
    for (final entity in dir.listSync()) {
      final path = entity.path;
      if (protectedPaths.any(
        (protectedPath) => p.equals(path, protectedPath),
      )) {
        continue;
      }
      if (entity is Directory &&
          protectedPaths.any(
            (protectedPath) => p.isWithin(path, protectedPath),
          )) {
        cleared += await deleteDirectoryContentsExcept(
          entity,
          protectedPath: protectedPaths.first,
          additionalProtectedPaths: protectedPaths.skip(1).toList(),
        );
        continue;
      }
      try {
        await entity.delete(recursive: true);
        cleared++;
      } catch (e) {
        Log.debug(
          'Could not delete $path: $e',
          name: _logName,
          category: LogCategory.system,
        );
      }
    }
    return cleared;
  }

  static String _durableDatabasePath(Directory appSupportDir) => p.joinAll([
    appSupportDir.path,
    ..._durableDatabaseDirSegments,
  ]);

  static List<String> _durableHiveBoxPaths(Directory appSupportDir) => [
    for (final segments in _durableHiveBoxFileSegments)
      p.joinAll([appSupportDir.path, ...segments]),
  ];

  static bool _pathExists(String path) =>
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  /// Clear temporary files directory
  static Future<int> _clearTempDirectory() async {
    int cleared = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync();
        for (final file in files) {
          try {
            await file.delete(recursive: true);
            cleared++;
          } catch (e) {
            Log.debug(
              'Could not delete temp file ${file.path}: $e',
              name: _logName,
              category: LogCategory.system,
            );
          }
        }
      }
    } catch (e) {
      Log.warning(
        'Error clearing temp directory: $e',
        name: _logName,
        category: LogCategory.system,
      );
    }

    return cleared;
  }

  /// Clear application cache directory
  static Future<int> _clearCacheDirectory() async {
    int cleared = 0;

    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (cacheDir.existsSync()) {
        final files = cacheDir.listSync();
        for (final file in files) {
          try {
            await file.delete(recursive: true);
            cleared++;
          } catch (e) {
            Log.debug(
              'Could not delete cache file ${file.path}: $e',
              name: _logName,
              category: LogCategory.system,
            );
          }
        }
      }
    } catch (e) {
      Log.warning(
        'Error clearing cache directory: $e',
        name: _logName,
        category: LogCategory.system,
      );
    }

    return cleared;
  }

  /// Total bytes held by everything [clearAllCaches] would remove.
  ///
  /// Best-effort: a directory that cannot be read contributes zero. Throws if
  /// the platform cannot resolve one of the directories at all.
  static Future<int> cacheSizeBytes() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final tempDir = await getTemporaryDirectory();
    final cacheDir = await getApplicationCacheDirectory();

    var totalSize = 0;
    if (appSupportDir.existsSync()) {
      totalSize += await _getDirectorySize(
        appSupportDir,
        excludedPaths: [
          _durableDatabasePath(appSupportDir),
          ..._durableHiveBoxPaths(appSupportDir),
        ],
      );
    }
    for (final dir in [tempDir, cacheDir]) {
      if (dir.existsSync()) totalSize += await _getDirectorySize(dir);
    }
    return totalSize;
  }

  /// Calculate directory size recursively
  static Future<int> _getDirectorySize(
    Directory directory, {
    List<String> excludedPaths = const [],
  }) async {
    int size = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (_isExcluded(entity.path, excludedPaths)) continue;
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (e) {
      // Ignore permission errors
    }
    return size;
  }

  static bool _isExcluded(String path, List<String> excludedPaths) =>
      excludedPaths.any(
        (excludedPath) =>
            p.equals(path, excludedPath) || p.isWithin(excludedPath, path),
      );
}
