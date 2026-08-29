// ABOUTME: Sole owner of Hive's process-global home path, set once at startup
// ABOUTME: Migrates boxes stranded in the legacy documents directory into it

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Single owner of Hive's process-global home path.
///
/// `Hive.init` assigns a process-global home path and `openBox` resolves a
/// box's file from whatever that path holds at open time. A second `init`
/// therefore relocates every box opened after it. The app used to call it
/// twice per launch — `Hive.initFlutter()` (documents directory) in the
/// critical startup phase, then again from the uploads-box initializer
/// (`{appSupport}/openvine`) in the standard phase — so a box landed in
/// whichever directory happened to be current when it opened, and the same box
/// could exist in both places with different contents (#6958).
///
/// [initialize] is the only place the app sets the home path.
abstract final class HiveStorageService {
  static const String _logName = 'HiveStorage';

  /// Subdirectory of Application Support that holds every Hive box file.
  ///
  /// Boxes have lived here since the uploads-box initializer started
  /// re-pointing Hive at it, and `CacheRecoveryService` protects the durable
  /// ones from a cache wipe by absolute path underneath it.
  static const String homeDirectoryName = 'openvine';

  static Future<void>? _initialization;

  /// Points Hive at its one home directory, migrating stranded boxes first.
  ///
  /// Must complete before the first `Hive.openBox`: the startup coordinator
  /// runs it in the critical phase, and every box owner sits in a later phase.
  /// Repeat calls return the first call's future, so the home path is assigned
  /// exactly once per process and never reassigned.
  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    if (kIsWeb) {
      // Web keeps boxes in IndexedDB, so there is no home path to resolve.
      Hive.init(null);
      return;
    }

    final home = Directory(
      p.join((await getApplicationSupportDirectory()).path, homeDirectoryName),
    );
    if (!home.existsSync()) {
      await home.create(recursive: true);
    }

    await _migrateLegacyBoxes(home);
    await _deleteRetiredBoxes(home);

    Hive.init(home.path);

    Log.info(
      'Hive home path set to ${home.path}',
      name: _logName,
      category: LogCategory.storage,
    );
  }

  /// Box files whose owner has moved to Drift and which are now dead weight.
  ///
  /// `personal_events` / `personal_events_metadata` backed
  /// `PersonalEventCacheService` until #6986 moved it onto the `personal_events`
  /// Drift table. They are removed rather than migrated: the data is
  /// re-fetchable — `CacheRecoveryService` already classified both boxes
  /// disposable and deleted them on repair — and the events box was the
  /// unbounded one, so reading it here would pay the whole cost on the upgrade
  /// launch, which is the worst possible moment.
  static const Set<String> _retiredBoxNames = {
    'personal_events',
    'personal_events_metadata',
  };

  /// Deletes retired box files from both the home and the legacy home.
  ///
  /// Both locations, because a box stranded by the pre-#6958 split can still
  /// be sitting in the documents directory, and [_migrateLegacyBoxes] no
  /// longer sweeps these names now that they are out of [HiveBoxNames.all].
  ///
  /// Best-effort, like the migration above: a failure leaves the files for the
  /// next launch rather than blocking startup.
  static Future<void> _deleteRetiredBoxes(Directory home) async {
    try {
      final directories = <String>{home.path};
      final legacy = await getApplicationDocumentsDirectory();
      if (legacy.existsSync()) {
        directories.add(legacy.path);
      }

      var deleted = 0;
      for (final directory in directories) {
        for (final boxName in _retiredBoxNames) {
          for (final extension in const ['hive', 'hivec', 'lock']) {
            final file = File(p.join(directory, '$boxName.$extension'));
            if (file.existsSync()) {
              await file.delete();
              deleted++;
            }
          }
        }
      }

      if (deleted > 0) {
        Log.info(
          'Deleted $deleted retired Hive box file(s)',
          name: _logName,
          category: LogCategory.storage,
        );
      }
    } catch (e) {
      Log.warning(
        'Failed to delete retired Hive boxes: $e',
        name: _logName,
        category: LogCategory.storage,
      );
    }
  }

  /// Best-effort move of the boxes left in the legacy home into [home].
  ///
  /// The legacy home is the documents directory, where `Hive.initFlutter()`
  /// pointed. A split box can hold real writes on both sides, so one file wins
  /// and the other is deleted — chosen over quarantine because quarantined
  /// files would become permanent uncleaned orphans, while [_homeCopyWins]
  /// guards the known empty-file false winner before anything is destroyed.
  /// The surviving data lands in the home and nothing is left behind to be
  /// picked up again. [_boxFile] decides which file holds a side's data. Lock
  /// files carry no data and are recreated on open, so legacy ones are just
  /// removed.
  ///
  /// A failure here must not block startup: the files stay put and the next
  /// launch tries again.
  ///
  /// TODO(#7347): Remove this sweep once the fixed build has reached the
  /// installed base. Only a build from before #6958 can strand a box, so after
  /// that point this walks every box name in the critical startup phase on
  /// every launch and finds nothing.
  static Future<void> _migrateLegacyBoxes(Directory home) async {
    try {
      final legacy = await getApplicationDocumentsDirectory();
      if (!legacy.existsSync() || p.equals(legacy.path, home.path)) return;

      var migrated = 0;
      for (final boxName in HiveBoxNames.all) {
        await _deleteIfPresent(File(p.join(legacy.path, '$boxName.lock')));

        final legacyFile = _boxFile(legacy.path, boxName);
        if (legacyFile == null) continue;

        final targetFile = _boxFile(home.path, boxName);
        if (targetFile != null && _homeCopyWins(legacyFile, targetFile)) {
          await _deleteLegacyRemains(legacy.path, boxName);
          continue;
        }

        // Hive resolves `.hive` ahead of `.hivec` and deletes the compacted
        // copy when both are present, so the one in the home is superseded by
        // the file about to land on top of it.
        await _deleteIfPresent(File(p.join(home.path, '$boxName.hivec')));
        if (await _move(legacyFile, File(p.join(home.path, '$boxName.hive')))) {
          migrated++;
          await _deleteLegacyRemains(legacy.path, boxName);
        }
      }

      if (migrated > 0) {
        Log.info(
          'Migrated $migrated stranded Hive box file(s) into ${home.path}',
          name: _logName,
          category: LogCategory.storage,
        );
      }
    } catch (e) {
      Log.warning(
        'Failed to migrate stranded Hive boxes: $e',
        name: _logName,
        category: LogCategory.storage,
      );
    }
  }

  /// Whether the copy already in the home should be kept over [legacyFile].
  ///
  /// An empty file loses regardless of when it was touched. Hive creates
  /// `<box>.hive` whenever it opens a box that has no file yet — the
  /// `else { await hiveFile.create(); }` branch of `findHiveFileAndCleanUp` —
  /// so a session that only opened and read the stranded side left a 0-byte
  /// file there with mtime = now. That file is newer than the copy holding the
  /// real data, and comparing mtime alone would move it on top and take the
  /// box down to zero bytes.
  ///
  /// Only when both sides agree on emptiness does mtime decide, which is the
  /// original policy: the newer file is the one the last session to write used.
  static bool _homeCopyWins(File legacyFile, File targetFile) {
    final legacyEmpty = legacyFile.lengthSync() == 0;
    final targetEmpty = targetFile.lengthSync() == 0;
    if (legacyEmpty != targetEmpty) return legacyEmpty;
    return !targetFile.lastModifiedSync().isBefore(
      legacyFile.lastModifiedSync(),
    );
  }

  /// The file Hive would open for [boxName] in [directory], or null when the
  /// box has nothing there.
  ///
  /// Resolved the way `findHiveFileAndCleanUp` resolves it: `<box>.hive` when
  /// it exists, otherwise `<box>.hivec`. The latter is where compaction writes
  /// the compacted box before renaming it over the box file, and Hive restores
  /// it on open when the box file is missing — so it is box data, not a
  /// scratch file, and migrating only `.hive` would strand it.
  static File? _boxFile(String directory, String boxName) {
    final hiveFile = File(p.join(directory, '$boxName.hive'));
    if (hiveFile.existsSync()) return hiveFile;
    final compactedFile = File(p.join(directory, '$boxName.hivec'));
    return compactedFile.existsSync() ? compactedFile : null;
  }

  /// Clears whatever [boxName] still has in the legacy home once its contents
  /// are settled, so nothing is left for Hive to find there again.
  ///
  /// Both extensions, because the copy that lost — or the compacted leftover
  /// sitting beside the copy that won — is stale either way.
  static Future<void> _deleteLegacyRemains(
    String directory,
    String boxName,
  ) async {
    await _deleteIfPresent(File(p.join(directory, '$boxName.hive')));
    await _deleteIfPresent(File(p.join(directory, '$boxName.hivec')));
  }

  /// Renames [source] onto [target], falling back to copy + delete when the
  /// two sit on different filesystems. Returns whether the move happened.
  static Future<bool> _move(File source, File target) async {
    try {
      await source.rename(target.path);
      return true;
    } on FileSystemException {
      try {
        await source.copy(target.path);
        await source.delete();
        return true;
      } catch (e) {
        Log.warning(
          'Could not move ${source.path} to ${target.path}: $e',
          name: _logName,
          category: LogCategory.storage,
        );
        return false;
      }
    }
  }

  static Future<void> _deleteIfPresent(File file) async {
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } catch (e) {
      Log.debug(
        'Could not delete ${file.path}: $e',
        name: _logName,
        category: LogCategory.storage,
      );
    }
  }

  @visibleForTesting
  static void resetForTesting() => _initialization = null;
}
