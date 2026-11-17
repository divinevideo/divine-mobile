// ABOUTME: Reactive corruption probe that opens the real encrypted AppDatabase.
// ABOUTME: Forces beforeOpen startup cleanup so on-disk corruption surfaces at
// ABOUTME: the recovery gate instead of bricking the session on first query.

import 'package:db_client/db_client.dart';

/// Whether the shared encrypted database opens **and its Drift `beforeOpen`
/// startup cleanup runs** under [rawKeyHex].
///
/// This is the reactive corruption gate for the app-layer startup recovery.
/// Rather than pre-scanning the whole database with `PRAGMA quick_check` on
/// every launch — an added, size-unbounded cost on the startup hot path — it
/// opens the real [AppDatabase] and forces `beforeOpen` (which runs
/// `runStartupCleanup` → `DELETE FROM event …`) via a trivial query. That
/// cleanup is the exact operation that trips on the field corruption. On a
/// healthy database the added cost is one extra `beforeOpen` pass (the same
/// idempotent missing-table checks + expiry cleanup the real open runs) plus
/// this probe's isolate open — bounded work, deliberately not the whole-DB
/// `PRAGMA quick_check` scan a pre-scan gate would add.
///
/// On a v36 upgrade, the old event/metrics caches are retired before cleanup.
/// Their payload pages are not read by this gate; only the active database is
/// exercised. Idle maintenance later reclaims the disposable retired rows.
///
/// Returns `false` when the open fails with SQLITE_CORRUPT (structural
/// corruption past the schema page) or SQLITE_NOTADB (the key cannot decrypt
/// the file); the caller then salvages or recreates. Any other error
/// propagates.
///
/// The caller only reaches this gate for a database file that already exists
/// (`CipherMigrationOutcome.alreadyEncrypted`). On a missing file this opens
/// an empty [AppDatabase] via Drift's `onCreate` and returns `true`; that
/// side effect is out of the startup contract but noted for any future caller.
///
/// [databasePath] defaults to the shared database and exists so tests can point
/// at a specific file.
Future<bool> encryptedDatabaseOpensCleanly({
  required String rawKeyHex,
  String? databasePath,
}) async {
  final db = AppDatabase(
    openEncryptedConnection(rawKeyHex: rawKeyHex, databasePath: databasePath),
  );
  try {
    // Forces the lazy open → migration.beforeOpen → runStartupCleanup, which is
    // where field corruption throws. A healthy open returns the literal row.
    await db.customSelect('SELECT 1;').get();
    return true;
  } on Object catch (error) {
    if (indicatesDatabaseCorruption(error)) return false;
    rethrow;
  } finally {
    await _closeQuietly(db);
  }
}

/// Closes [db] without letting a close-time failure escape the probe.
///
/// Closing a database whose open failed can itself throw; the probe result is
/// already decided, so a close error must not become the probe's outcome.
Future<void> _closeQuietly(AppDatabase db) async {
  try {
    await db.close();
  } on Object {
    // Best effort: the open already failed and the result is decided.
  }
}
