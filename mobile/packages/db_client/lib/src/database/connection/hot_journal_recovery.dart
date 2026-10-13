import 'dart:convert';
import 'dart:io';

import 'package:db_client/src/database/connection/database_integrity.dart';
import 'package:db_client/src/database/connection/database_sidecars.dart';
import 'package:db_client/src/database/connection/hot_journal_recovery_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

const sqliteReadOnly = 8;
const sqliteReadOnlyRollback = 776;
const _sqliteCorrupt = 11;

const _sqliteHeader = 'SQLite format 3\x00';

// The directory beside a database that holds its safety copy while a hot
// journal is replayed. One found at launch was left by a recovery that did
// not get to delete it: it is deleted, never put back.
const _snapshotDirectorySuffix = '.hot_journal_snapshot';

// The directory beside a database that holds the copy a failed replay is
// being put back from. It is there from the moment that restore begins until
// both files are back, so a copy found in it means a restore is unfinished.
const _restoreDirectorySuffix = '.hot_journal_restore';

const _snapshotDatabaseName = 'database';
const _snapshotJournalName = 'journal';

// TODO(any): Stop reading the temp directory once no supported build makes
// its copy there. This prefix, [_restoreMarkerName], [_restoreMarker],
// [_databaseIdentity], [_tempSnapshotDirectories], [_adoptMarkedSnapshot]
// and [_HotJournalSnapshot.markedFor] can then go.
// https://github.com/divinevideo/divine-mobile/issues/10117
//
// Builds that made their copy in the temp directory left directories under
// this name there, so it must not change.
const _tempSnapshotDirectoryPrefix = 'divine_hot_journal_recovery_';

// Those builds wrote this into a snapshot before putting it back, naming the
// database it belonged to. Nothing writes it now; [_adoptMarkedSnapshot]
// still reads it.
const _restoreMarkerName = 'restoring';

/// Replays a hot rollback journal through SQLite without ever editing the
/// journal directly.
///
/// Non-plaintext files must first open under [configureEncryptedDatabase]
/// through an immutable view. That proves the existing key can decrypt the
/// database before the writable connection is allowed to begin rollback.
///
/// The database and journal are copied aside first, into a directory beside
/// the database, when the copy can be made. A copy that cannot be made, for
/// want of space, does not stop the replay: SQLite keeps the journal until
/// the rollback is flushed, so an interrupted replay repeats on the next
/// launch, whereas refusing here would refuse on every launch.
///
/// A replay that fails while the journal is still there puts the database
/// and journal back from that copy, when there is one. The copy is flushed
/// and its directory renamed first, which records that a restore is under
/// way: one that does not finish is finished at the next launch by
/// [completeUnfinishedHotJournalRestore]. A copy that cannot be flushed or
/// renamed is not put back; the journal is still in place for the next launch
/// to replay.
///
/// Once SQLite has deleted the journal the rollback is done, so the replay is
/// final even when the statement that ran it failed afterwards. The file is
/// then checked with `PRAGMA quick_check`, and
/// [HotJournalRecoveryResult.failedIntegrityCheck] tells the caller it is
/// damaged.
///
/// Throws [DatabaseHotJournalRecoveryError] naming the stage that stopped.
HotJournalRecoveryResult recoverHotRollbackJournal({
  required String databasePath,
  required void Function(CommonDatabase db) configureEncryptedDatabase,
}) {
  final isPlaintext = _hasPlaintextHeader(databasePath);
  if (!isPlaintext) {
    _validateEncryptedDatabaseIgnoringJournal(
      databasePath,
      configureEncryptedDatabase,
    );
  }

  sweepStrandedHotJournalSnapshots(databasePath);
  final snapshot = _HotJournalSnapshot.tryCreate(databasePath);
  try {
    _replayJournal(
      databasePath,
      isPlaintext: isPlaintext,
      configureEncryptedDatabase: configureEncryptedDatabase,
    );
  } on DatabaseHotJournalRecoveryError {
    // SQLite deletes the journal only once the rollback is on disk, so a
    // missing journal means the statement failed afterwards, typically on a
    // damaged schema. Restoring it would replay into that failure forever.
    if (!File('$databasePath$rollbackJournalSuffix').existsSync()) {
      return HotJournalRecoveryResult.failedIntegrityCheck;
    }
    if (snapshot != null && snapshot.keepForRestore(databasePath)) {
      _finishRestore(databasePath);
    }
    rethrow;
  } finally {
    snapshot?.dispose();
  }

  // The file is now what any writable open would have made of it. Restoring
  // the snapshot after a failed check only handed every later launch the same
  // journal and the same verdict: a permanent db-journal-unrecovered screen.
  return _recoveredDatabaseIsSound(
        databasePath,
        isPlaintext: isPlaintext,
        configureEncryptedDatabase: configureEncryptedDatabase,
      )
      ? HotJournalRecoveryResult.sound
      : HotJournalRecoveryResult.failedIntegrityCheck;
}

/// Finishes a restore that an earlier launch began and did not finish.
///
/// A restore that has begun keeps its copy in a directory beside the
/// database until both files are back, so a copy found there is the record
/// that one is unfinished. This puts back what is left of it and removes the
/// directory.
///
/// Call it before the database is classified or opened: the live files are
/// not the ones to read while that directory holds a copy. This either puts
/// back all that is in it or throws, so no launch goes on with a restore
/// still unfinished there.
///
/// With no such directory it also looks in the temp directory for a copy
/// that an earlier build marked as an unfinished restore, and finishes that
/// one the same way; see [_adoptMarkedSnapshot] for what that cannot promise.
///
/// A build that does not know the directory leaves it alone. If one has used
/// the database since the restore began, this still puts the older copy
/// back.
///
/// Throws [DatabaseHotJournalRecoveryError] at
/// [DatabaseHotJournalRecoveryStage.restoreSnapshot] when the directory
/// cannot be read, the copy cannot be put back, or a marked copy is found
/// and cannot be taken. The copy is kept for the next launch.
void completeUnfinishedHotJournalRestore({required String databasePath}) {
  if (_finishRestore(databasePath)) return;
  if (_adoptMarkedSnapshot(databasePath)) _finishRestore(databasePath);
}

/// Makes a snapshot that an earlier build marked as an unfinished restore of
/// [databasePath], and left in the temp directory, the copy that restore is
/// put back from. Returns whether there was one.
///
/// A launch that cannot list the temp directory finds nothing and goes on, as
/// those builds did. If the sweep cannot list it either, a mark that outlived
/// its restore is put back by a later launch, over newer data. A snapshot
/// whose mark cannot be read is not taken either, and goes with the sweep.
///
/// The snapshot is taken by renaming it out of the temp directory, so on
/// Android its files keep that directory's cache group, and a temp directory
/// on another volume fails the rename on every launch. Both are accepted for
/// a path that is to be removed.
///
/// Throws [DatabaseHotJournalRecoveryError] at
/// [DatabaseHotJournalRecoveryStage.restoreSnapshot] when a snapshot is found
/// and cannot be taken: those builds put it back by copying over the live
/// files, which can leave them truncated, so the launch must not go on
/// without it.
bool _adoptMarkedSnapshot(String databasePath) {
  final marked = _HotJournalSnapshot.markedFor(databasePath);
  if (marked.isEmpty) return false;
  if (!marked.first.keepForRestore(databasePath)) {
    throw const DatabaseHotJournalRecoveryError(
      stage: DatabaseHotJournalRecoveryStage.restoreSnapshot,
    );
  }
  return true;
}

/// Where the safety copy of [databasePath] sits while its journal is replayed.
Directory _snapshotDirectory(String databasePath) =>
    Directory('$databasePath$_snapshotDirectorySuffix');

/// Where the copy of [databasePath] sits while it is being put back.
Directory _restoreDirectory(String databasePath) =>
    Directory('$databasePath$_restoreDirectorySuffix');

/// Puts back whatever is left in the restore directory of [databasePath],
/// then removes the directory. Returns whether anything was left in it.
///
/// What is left is read from a listing of the directory: asking whether each
/// file exists would report one that cannot be examined as already put back.
/// Each file is renamed into place, so it is either wholly back or not back
/// at all. The journal goes first: with it in place the live pair can be
/// replayed again, whether the database beside it is the one the failed
/// replay left or the copy.
///
/// Throws [DatabaseHotJournalRecoveryError] at
/// [DatabaseHotJournalRecoveryStage.restoreSnapshot], leaving the directory
/// for the next launch, when it cannot be read or a file cannot be put back.
bool _finishRestore(String databasePath) {
  final directory = _restoreDirectory(databasePath);
  final Set<String> left;
  try {
    if (!directory.existsSync()) return false;
    left = {
      for (final entry in directory.listSync(followLinks: false))
        p.basename(entry.path),
    };
    if (left.contains(_snapshotJournalName)) {
      File(
        p.join(directory.path, _snapshotJournalName),
      ).renameSync('$databasePath$rollbackJournalSuffix');
    }
    if (left.contains(_snapshotDatabaseName)) {
      File(
        p.join(directory.path, _snapshotDatabaseName),
      ).renameSync(databasePath);
    }
  } on FileSystemException catch (error) {
    throw _recoveryError(
      DatabaseHotJournalRecoveryStage.restoreSnapshot,
      error,
    );
  }
  _deleteCopyDirectory(directory);
  return left.contains(_snapshotJournalName) ||
      left.contains(_snapshotDatabaseName);
}

/// Deletes the copies that interrupted recoveries left behind.
///
/// A launch killed between copying the database aside and deleting the copy
/// strands a full-size copy, and nothing else removes it: the snapshot
/// directory beside [databasePath], and the snapshot directories that builds
/// which made their copy in the temp directory left there. The app runs
/// recovery synchronously, before it opens any connection, so nothing swept
/// here can still be in use.
///
/// A restore that did not finish is not swept; its directory has another
/// name. A snapshot in the temp directory that an earlier build marked as an
/// unfinished restore is, so call this only after
/// [completeUnfinishedHotJournalRestore] has had its turn in the launch: a
/// marked snapshot it did not take cannot be put back by a later launch
/// without overwriting what this one goes on to write.
///
/// Best effort: it never throws, because a directory that cannot be listed
/// or deleted must not fail startup.
void sweepStrandedHotJournalSnapshots(String databasePath) {
  _deleteCopyDirectory(_snapshotDirectory(databasePath));
  try {
    _tempSnapshotDirectories().forEach(_deleteCopyDirectory);
  } on FileSystemException {
    // The temp directory is unusable, so there is nothing to sweep in it.
  }
}

/// Deletes the copies recovery keeps beside [databasePath]: the snapshot of
/// a replay, and a restore that did not finish.
///
/// For a caller that is about to delete that database or set it aside: a
/// restore left behind would be put back over whatever takes its place.
///
/// The restore directory is first renamed to the snapshot's name, under
/// which nothing is ever put back. Deleting it file by file could stop
/// part-way and leave half a copy to be taken for a restore half finished.
void discardHotJournalCopies(String databasePath) {
  final snapshot = _snapshotDirectory(databasePath);
  _deleteCopyDirectory(snapshot);
  final restore = _restoreDirectory(databasePath);
  try {
    if (restore.existsSync()) restore.renameSync(snapshot.path);
  } on FileSystemException {
    // The rename is what makes this safe against a delete that stops
    // part-way; without it the delete is still the best that can be done.
    _deleteCopyDirectory(restore);
  }
  _deleteCopyDirectory(snapshot);
}

/// Throws [FileSystemException] when the temp directory cannot be listed.
Iterable<Directory> _tempSnapshotDirectories() => Directory.systemTemp
    .listSync(followLinks: false)
    .whereType<Directory>()
    .where(
      (entry) =>
          p.basename(entry.path).startsWith(_tempSnapshotDirectoryPrefix),
    )
    // `listSync` builds its entries without consulting [IOOverrides].
    .map((entry) => Directory(entry.path));

File _restoreMarker(Directory snapshot) =>
    File(p.join(snapshot.path, _restoreMarkerName));

/// Names [databasePath] the way a marked snapshot names the database it
/// belongs to.
///
/// The app's container can move between launches (iOS moves it on an update),
/// so this is the path from the temp directory to the database, with links
/// resolved so that both ends are spelled the same way.
///
/// Throws [FileSystemException] when either directory cannot be resolved.
String _databaseIdentity(String databasePath) => p.relative(
  p.join(
    Directory(p.dirname(databasePath)).resolveSymbolicLinksSync(),
    p.basename(databasePath),
  ),
  from: Directory.systemTemp.resolveSymbolicLinksSync(),
);

/// Best effort: a directory that cannot be removed now must not fail the
/// recovery. A snapshot goes with a later sweep, and an emptied restore
/// directory when the next launch finds nothing left in it.
void _deleteCopyDirectory(Directory directory) {
  try {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  } on FileSystemException {
    // Left for a later launch.
  }
}

void _replayJournal(
  String databasePath, {
  required bool isPlaintext,
  required void Function(CommonDatabase db) configureEncryptedDatabase,
}) {
  Database? database;
  try {
    database = sqlite3.open(databasePath, mode: OpenMode.readWrite);
    if (!isPlaintext) configureEncryptedDatabase(database);
    database.select('SELECT count(*) FROM sqlite_master;');
  } on Object catch (error) {
    throw _recoveryError(DatabaseHotJournalRecoveryStage.replayJournal, error);
  } finally {
    database?.close();
  }
}

bool _hasPlaintextHeader(String databasePath) {
  try {
    final file = File(databasePath);
    if (file.lengthSync() < _sqliteHeader.length) {
      throw const DatabaseHotJournalRecoveryError(
        stage: DatabaseHotJournalRecoveryStage.inspectHeader,
      );
    }
    final bytes = file.openSync()..setPositionSync(0);
    try {
      return ascii.decode(bytes.readSync(_sqliteHeader.length)) ==
          _sqliteHeader;
    } on FormatException {
      // A torn plaintext page-1 header is deliberately treated as ambiguous.
      // Recovery then refuses it rather than risking an unkeyed writable open.
      return false;
    } finally {
      bytes.closeSync();
    }
  } on DatabaseHotJournalRecoveryError {
    rethrow;
  } on Object catch (error) {
    throw _recoveryError(DatabaseHotJournalRecoveryStage.inspectHeader, error);
  }
}

void _validateEncryptedDatabaseIgnoringJournal(
  String databasePath,
  void Function(CommonDatabase db) configureEncryptedDatabase,
) {
  Database? database;
  try {
    final uri = Uri.file(
      databasePath,
    ).replace(queryParameters: const {'immutable': '1'}).toString();
    database = sqlite3.open(uri, mode: OpenMode.readOnly, uri: true);
    configureEncryptedDatabase(database);
    // A commit writes page 1, which records the grown page count, before the
    // pages it appends. Killed in between, the file is shorter than page 1
    // claims and SQLite rejects it as corrupt although the key decrypted it.
    // Writable-schema mode takes the size from the file instead; a wrong key
    // still fails page 1 itself with SQLITE_NOTADB.
    database
      ..execute('PRAGMA writable_schema = ON;')
      ..select('PRAGMA user_version;');
  } on Object catch (error) {
    throw _recoveryError(
      DatabaseHotJournalRecoveryStage.validateCipherKey,
      error,
    );
  } finally {
    database?.close();
  }
}

/// Whether the replayed file passes `PRAGMA quick_check`.
///
/// A check that cannot run at all is not a verdict on the file, so it throws
/// instead; the journal is already consumed, so the next launch classifies the
/// file normally.
bool _recoveredDatabaseIsSound(
  String databasePath, {
  required bool isPlaintext,
  required void Function(CommonDatabase db) configureEncryptedDatabase,
}) {
  Database? database;
  try {
    database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
    if (!isPlaintext) configureEncryptedDatabase(database);
    return databaseQuickCheckPasses(database);
  } on Object catch (error) {
    if (error is SqliteException && error.resultCode == _sqliteCorrupt) {
      return false;
    }
    throw _recoveryError(
      DatabaseHotJournalRecoveryStage.validateIntegrity,
      error,
    );
  } finally {
    database?.close();
  }
}

class _HotJournalSnapshot {
  _HotJournalSnapshot._({
    required this.directory,
    required this.database,
    required this.journal,
  });

  final Directory directory;
  final File database;
  final File journal;

  /// The snapshots in the temp directory that an earlier build marked as an
  /// unfinished restore of [databasePath].
  static List<_HotJournalSnapshot> markedFor(String databasePath) {
    final marked = <_HotJournalSnapshot>[];
    try {
      String? identity;
      for (final directory in _tempSnapshotDirectories()) {
        final marker = _restoreMarker(directory);
        try {
          if (!marker.existsSync()) continue;
          identity ??= _databaseIdentity(databasePath);
          if (marker.readAsStringSync() != identity) continue;
        } on FileSystemException {
          // A mark that cannot be read cannot be matched; it must not hide
          // the snapshots listed after it.
          continue;
        }
        final snapshot = _HotJournalSnapshot._(
          directory: directory,
          database: File(p.join(directory.path, _snapshotDatabaseName)),
          journal: File(p.join(directory.path, _snapshotJournalName)),
        );
        // The system may clear files out of the temp directory. A snapshot
        // that lost one cannot be put back, and must not stop every launch.
        if (!snapshot.database.existsSync() || !snapshot.journal.existsSync()) {
          continue;
        }
        marked.add(snapshot);
      }
    } on FileSystemException {
      // A temp directory that cannot be listed gives nothing that can be put
      // back, so the launch goes on as it would without this step.
    }
    return marked;
  }

  /// Returns null when the copy cannot be made.
  ///
  /// The copy is made beside the database and not in the temp directory: the
  /// system may empty that directory at any time, and on Android a file made
  /// in it keeps its cache group when it is later renamed into place.
  static _HotJournalSnapshot? tryCreate(String databasePath) {
    final directory = _snapshotDirectory(databasePath);
    try {
      directory.createSync();
      return _HotJournalSnapshot._(
        directory: directory,
        database: File(
          databasePath,
        ).copySync(p.join(directory.path, _snapshotDatabaseName)),
        journal: File(
          '$databasePath$rollbackJournalSuffix',
        ).copySync(p.join(directory.path, _snapshotJournalName)),
      );
    } on Object {
      _deleteCopyDirectory(directory);
      return null;
    }
  }

  /// Keeps the snapshot as the copy a restore of [databasePath] is put back
  /// from.
  ///
  /// Both files are flushed first, so that a power cut cannot leave a file
  /// renamed into place without its contents. The directory is then renamed
  /// to the restore directory beside the database, which is what records
  /// that a restore is under way.
  ///
  /// Returns false, with nothing of the database touched, when the snapshot
  /// cannot be flushed or renamed.
  bool keepForRestore(String databasePath) {
    try {
      _flushToDisk(journal);
      _flushToDisk(database);
      directory.renameSync(_restoreDirectory(databasePath).path);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Deletes the snapshot. Once [keepForRestore] has renamed it there is
  /// nothing under its old name to delete.
  void dispose() => _deleteCopyDirectory(directory);
}

/// Throws [FileSystemException] when [file] is missing: it is opened for
/// reading because a mode that can write would create it empty, to be put
/// back in place of the real one.
void _flushToDisk(File file) {
  final handle = file.openSync();
  try {
    handle.flushSync();
  } finally {
    handle.closeSync();
  }
}

DatabaseHotJournalRecoveryError _recoveryError(
  DatabaseHotJournalRecoveryStage stage,
  Object error,
) => DatabaseHotJournalRecoveryError(
  stage: stage,
  extendedResultCode: error is SqliteException
      ? error.extendedResultCode
      : null,
);
