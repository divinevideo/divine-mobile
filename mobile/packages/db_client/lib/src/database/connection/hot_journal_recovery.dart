import 'dart:convert';
import 'dart:io';

import 'package:db_client/src/database/connection/database_integrity.dart';
import 'package:db_client/src/database/connection/database_sidecars.dart';
import 'package:db_client/src/database/connection/hot_journal_recovery_models.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

const sqliteReadOnly = 8;
const sqliteReadOnlyRollback = 776;
const _sqliteCorrupt = 11;

const _sqliteHeader = 'SQLite format 3\x00';

/// Replays a hot rollback journal through SQLite without ever editing the
/// journal directly.
///
/// Non-plaintext files must first open under [configureEncryptedDatabase]
/// through an immutable view. That proves the existing key can decrypt the
/// database before the writable connection is allowed to begin rollback.
///
/// A replay that fails while the journal is still there restores the
/// database and journal it started from. Once SQLite has deleted the journal
/// the rollback is done, so the replay is final even when the statement that
/// ran it failed afterwards. The file is then checked with
/// `PRAGMA quick_check`, and [HotJournalRecoveryResult.failedIntegrityCheck]
/// tells the caller it is damaged.
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

  final snapshot = _HotJournalSnapshot.create(databasePath);
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
    snapshot.restore(databasePath, copy: restoreCopyForTesting);
    rethrow;
  } finally {
    snapshot.dispose();
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

  static _HotJournalSnapshot create(String databasePath) {
    Directory? directory;
    try {
      directory = Directory.systemTemp.createTempSync(
        'divine_hot_journal_recovery_',
      );
      return _HotJournalSnapshot._(
        directory: directory,
        database: File(databasePath).copySync('${directory.path}/database'),
        journal: File(
          '$databasePath$rollbackJournalSuffix',
        ).copySync('${directory.path}/journal'),
      );
    } on Object {
      if (directory?.existsSync() ?? false) {
        directory!.deleteSync(recursive: true);
      }
      throw const DatabaseHotJournalRecoveryError(
        stage: DatabaseHotJournalRecoveryStage.createSnapshot,
      );
    }
  }

  void restore(
    String databasePath, {
    required File Function(File source, String destination) copy,
  }) {
    try {
      copy(journal, '$databasePath$rollbackJournalSuffix');
      copy(database, databasePath);
    } on Object catch (error) {
      throw _recoveryError(
        DatabaseHotJournalRecoveryStage.restoreSnapshot,
        error,
      );
    }
  }

  void dispose() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
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
