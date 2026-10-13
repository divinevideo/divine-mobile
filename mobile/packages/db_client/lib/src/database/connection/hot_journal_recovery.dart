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

// Written into a snapshot when its restore begins.
const _restoreMarkerName = 'restoring';

/// Replays a hot rollback journal through SQLite without ever editing the
/// journal directly.
///
/// Non-plaintext files must first open under [configureEncryptedDatabase]
/// through an immutable view. That proves the existing key can decrypt the
/// database before the writable connection is allowed to begin rollback.
///
/// The database and journal are copied aside first when the copy can be made,
/// and put back if the replay or its integrity check fails. A copy that cannot
/// be made, for want of space or of a usable temp directory, does not stop the
/// replay: SQLite keeps the journal until the rollback is flushed, so an
/// interrupted replay repeats on the next launch, whereas refusing here would
/// refuse on every launch. Without the copy, a replay whose integrity check
/// then fails is not undone: the database stays rolled back and the journal
/// is gone, so the next launch goes through the ordinary open.
///
/// Throws [DatabaseHotJournalRecoveryError] naming the stage that stopped.
void recoverHotRollbackJournal({
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
    snapshot?.restore(databasePath, copy: restoreCopyForTesting);
    rethrow;
  } finally {
    snapshot?.dispose();
  }
}

/// Deletes snapshot directories that interrupted recoveries left behind.
///
/// A launch killed between copying the database aside and deleting the copy
/// strands a full-size copy in the temp directory, and nothing else removes
/// it. The app runs recovery synchronously, before it opens any connection,
/// so no directory it sweeps can still be in use.
///
/// A snapshot whose restore was interrupted is left alone: the restore
/// overwrites the live files, so that snapshot may be the only whole copy.
///
/// Best effort: it never throws, because a temp directory that cannot be
/// listed or an entry that cannot be deleted must not fail startup.
void sweepStrandedHotJournalSnapshots() {
  try {
    for (final entity in Directory.systemTemp.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      if (!p.basename(entity.path).startsWith(_snapshotDirectoryPrefix)) {
        continue;
      }
      if (File(p.join(entity.path, _restoreMarkerName)).existsSync()) continue;
      _deleteSnapshotDirectory(entity);
    }
  } on FileSystemException {
    // The temp directory is unusable, so there is nothing to sweep.
  }
}

/// Best effort: a snapshot that cannot be removed now is left for
/// [sweepStrandedHotJournalSnapshots], and must not fail the recovery.
void _deleteSnapshotDirectory(Directory directory) {
  try {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  } on FileSystemException {
    // Left for the next sweep.
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
  /// A restore that cannot first be marked is skipped, touching nothing, so
  /// the caller reports the stage that actually failed. The files are then
  /// left as a recovery without a snapshot leaves them.
  void restore(
    String databasePath, {
    required File Function(File source, String destination) copy,
  }) {
    try {
      File(p.join(directory.path, _restoreMarkerName)).createSync();
    } on FileSystemException {
      return;
    }
    try {
      copy(journal, '$databasePath$rollbackJournalSuffix');
      copy(database, databasePath);
    } on Object catch (error) {
      throw _recoveryError(
        DatabaseHotJournalRecoveryStage.restoreSnapshot,
        error,
      );
    }
    // The live files are whole again, so a snapshot [dispose] cannot remove
    // is an ordinary leftover for the sweep.
    try {
      File(p.join(directory.path, _restoreMarkerName)).deleteSync();
    } on FileSystemException {
      // The sweep keeps it; nothing else depends on the marker going.
    }
  }

  void dispose() => _deleteSnapshotDirectory(directory);
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
