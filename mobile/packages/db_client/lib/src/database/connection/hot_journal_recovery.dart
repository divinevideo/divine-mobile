import 'dart:convert';
import 'dart:io';

import 'package:db_client/src/database/connection/database_integrity.dart';
import 'package:db_client/src/database/connection/database_sidecars.dart';
import 'package:db_client/src/database/connection/hot_journal_recovery_models.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

const sqliteReadOnly = 8;
const sqliteReadOnlyRollback = 776;
const _sqliteCorrupt = 11;

const _sqliteHeader = 'SQLite format 3\x00';

// Shipped builds already left directories under this name, so it must not
// change: [sweepStrandedHotJournalSnapshots] finds them by it.
const _snapshotDirectoryPrefix = 'divine_hot_journal_recovery_';

// Written into a snapshot when its restore begins, naming the database it
// belongs to, and removed once both files are back.
const _restoreMarkerName = 'restoring';

/// Replays a hot rollback journal through SQLite without ever editing the
/// journal directly.
///
/// Non-plaintext files must first open under [configureEncryptedDatabase]
/// through an immutable view. That proves the existing key can decrypt the
/// database before the writable connection is allowed to begin rollback.
///
/// The database and journal are copied aside first when the copy can be made.
/// A copy that cannot be made, for want of space or of a usable temp
/// directory, does not stop the replay: SQLite keeps the journal until the
/// rollback is flushed, so an interrupted replay repeats on the next launch,
/// whereas refusing here would refuse on every launch.
///
/// A replay that fails while the journal is still there restores the
/// database and journal from that copy, when there is one. Once SQLite has
/// deleted the journal the rollback is done, so the replay is final even when
/// the statement that ran it failed afterwards. The file is then checked with
/// `PRAGMA quick_check`, and [HotJournalRecoveryResult.failedIntegrityCheck]
/// tells the caller it is damaged.
///
/// Throws [DatabaseHotJournalRecoveryError] naming the stage that stopped.
HotJournalRecoveryResult recoverHotRollbackJournal({
  required String databasePath,
  required void Function(CommonDatabase db) configureEncryptedDatabase,
  @visibleForTesting
  File Function(File source, String destination) restoreCopyForTesting =
      _copyFile,
}) {
  final isPlaintext = _hasPlaintextHeader(databasePath);
  if (!isPlaintext) {
    _validateEncryptedDatabaseIgnoringJournal(
      databasePath,
      configureEncryptedDatabase,
    );
  }

  sweepStrandedHotJournalSnapshots();
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
    snapshot?.restore(databasePath, copy: restoreCopyForTesting);
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
/// A restore overwrites the live database and journal. One that was
/// interrupted, or failed part-way, can leave them damaged while its snapshot
/// holds the only whole copy. This puts that copy back and releases the
/// snapshot.
///
/// Call it before anything reads or classifies the database. A launch that
/// finds a marked snapshot either clears the mark or throws, so the database
/// is not used while a mark this can see exists.
///
/// A launch that cannot list the temp directory, or cannot read a mark, goes
/// ahead without this step, because stopping there would refuse every launch
/// on an unusable temp directory. A mark that outlived its restore would then
/// be put back by a later launch, over newer data.
///
/// Throws [DatabaseHotJournalRecoveryError] at
/// [DatabaseHotJournalRecoveryStage.restoreSnapshot] when the copy cannot be
/// put back. The snapshot is kept for the next launch.
void completeUnfinishedHotJournalRestore({
  required String databasePath,
  @visibleForTesting
  File Function(File source, String destination) restoreCopyForTesting =
      _copyFile,
}) {
  final unfinished = _HotJournalSnapshot.unfinishedFor(databasePath);
  try {
    // Every mark has to go before the database is used: a snapshot left
    // marked would be put back again at a later launch, over newer data.
    for (final snapshot in unfinished) {
      snapshot
        .._copyBack(databasePath, copy: restoreCopyForTesting)
        .._unmark();
    }
  } on Object catch (error) {
    throw _recoveryError(
      DatabaseHotJournalRecoveryStage.restoreSnapshot,
      error,
    );
  }
  for (final snapshot in unfinished) {
    _deleteSnapshotDirectory(snapshot.directory);
  }
}

/// Deletes snapshot directories that interrupted recoveries left behind.
///
/// A launch killed between copying the database aside and deleting the copy
/// strands a full-size copy in the temp directory, and nothing else removes
/// it. The app runs recovery synchronously, before it opens any connection,
/// so no directory it sweeps can still be in use.
///
/// A snapshot whose restore did not finish is left alone: it may be the only
/// whole copy, and [completeUnfinishedHotJournalRestore] puts it back at the
/// next launch.
///
/// Best effort: it never throws, because a temp directory that cannot be
/// listed or an entry that cannot be deleted must not fail startup.
void sweepStrandedHotJournalSnapshots() {
  try {
    for (final directory in _snapshotDirectories()) {
      if (_restoreMarker(directory).existsSync()) continue;
      _deleteSnapshotDirectory(directory);
    }
  } on FileSystemException {
    // The temp directory is unusable, so there is nothing to sweep.
  }
}

/// Throws [FileSystemException] when the temp directory cannot be listed.
Iterable<Directory> _snapshotDirectories() => Directory.systemTemp
    .listSync(followLinks: false)
    .whereType<Directory>()
    .where(
      (entry) => p.basename(entry.path).startsWith(_snapshotDirectoryPrefix),
    )
    // `listSync` builds its entries without consulting [IOOverrides].
    .map((entry) => Directory(entry.path));

File _restoreMarker(Directory snapshot) =>
    File(p.join(snapshot.path, _restoreMarkerName));

/// Names [databasePath] so that a snapshot can be matched to its database at
/// a later launch.
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

/// Best effort: a snapshot that cannot be removed now is left for
/// [sweepStrandedHotJournalSnapshots], and must not fail the recovery.
void _deleteSnapshotDirectory(Directory directory) {
  try {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  } on FileSystemException {
    // Left for the next sweep.
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

  // Set while the snapshot is marked, so that it outlives this process.
  var _keep = false;

  /// The snapshots whose restore to [databasePath] began and did not finish.
  static List<_HotJournalSnapshot> unfinishedFor(String databasePath) {
    final unfinished = <_HotJournalSnapshot>[];
    try {
      String? identity;
      for (final directory in _snapshotDirectories()) {
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
          database: File(p.join(directory.path, 'database')),
          journal: File(p.join(directory.path, 'journal')),
        );
        // The system may clear files out of the temp directory. A snapshot
        // that lost one cannot be put back, and must not stop every launch.
        if (!snapshot.database.existsSync() || !snapshot.journal.existsSync()) {
          continue;
        }
        unfinished.add(snapshot);
      }
    } on FileSystemException {
      // A temp directory that cannot be listed gives nothing that can be put
      // back, so the launch goes on as it would without this step.
    }
    return unfinished;
  }

  /// Returns null when the copy cannot be made.
  static _HotJournalSnapshot? tryCreate(String databasePath) {
    Directory? directory;
    try {
      directory = Directory.systemTemp.createTempSync(
        _snapshotDirectoryPrefix,
      );
      return _HotJournalSnapshot._(
        directory: directory,
        database: File(databasePath).copySync('${directory.path}/database'),
        journal: File(
          '$databasePath$rollbackJournalSuffix',
        ).copySync('${directory.path}/journal'),
      );
    } on Object {
      if (directory != null) _deleteSnapshotDirectory(directory);
      return null;
    }
  }

  /// Puts the snapshot back over the live files.
  ///
  /// The snapshot is marked first and stays marked until both files are back,
  /// so a restore that is interrupted or fails part-way is finished at the
  /// next launch by [completeUnfinishedHotJournalRestore].
  ///
  /// A restore that cannot first be marked is skipped, touching nothing, so
  /// the caller reports the stage that actually failed. The files are then
  /// left as a recovery without a snapshot leaves them.
  void restore(
    String databasePath, {
    required File Function(File source, String destination) copy,
  }) {
    try {
      _restoreMarker(
        directory,
      ).writeAsStringSync(_databaseIdentity(databasePath), flush: true);
    } on FileSystemException {
      return;
    }
    _keep = true;
    try {
      _copyBack(databasePath, copy: copy);
    } on Object catch (error) {
      throw _recoveryError(
        DatabaseHotJournalRecoveryStage.restoreSnapshot,
        error,
      );
    }
    // The live files are whole again, so a snapshot [dispose] cannot remove
    // is an ordinary leftover for the sweep.
    try {
      _unmark();
      _keep = false;
    } on FileSystemException {
      // Still marked, so the next launch puts the same files back again.
    }
  }

  void _copyBack(
    String databasePath, {
    required File Function(File source, String destination) copy,
  }) {
    copy(journal, '$databasePath$rollbackJournalSuffix');
    copy(database, databasePath);
  }

  void _unmark() => _restoreMarker(directory).deleteSync();

  void dispose() {
    if (!_keep) _deleteSnapshotDirectory(directory);
  }
}

File _copyFile(File source, String destination) => source.copySync(destination);

DatabaseHotJournalRecoveryError _recoveryError(
  DatabaseHotJournalRecoveryStage stage,
  Object error,
) => DatabaseHotJournalRecoveryError(
  stage: stage,
  extendedResultCode: error is SqliteException
      ? error.extendedResultCode
      : null,
);
