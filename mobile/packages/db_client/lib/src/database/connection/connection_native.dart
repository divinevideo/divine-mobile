// ABOUTME: Native platform database connection using SQLite
// ABOUTME: Provides file-based SQLite storage for iOS, Android, macOS, etc.

import 'dart:io';
import 'package:collection/collection.dart';
import 'package:db_client/src/database/connection/database_backup_retention.dart';
import 'package:db_client/src/database/connection/database_integrity.dart';
import 'package:db_client/src/database/connection/database_sidecars.dart';
import 'package:db_client/src/database/connection/hot_journal_recovery.dart';
import 'package:db_client/src/database/connection/hot_journal_recovery_models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart'
    show CommonDatabase, CommonPreparedStatement;
import 'package:sqlite3/sqlite3.dart';

/// Open a database connection for native platforms
/// Uses file-based SQLite through drift's native implementation
QueryExecutor openConnection() {
  if (_isFlutterTestProcess) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return NativeDatabase.memory();
  }

  return LazyDatabase(() async {
    final dbPath = await getSharedDatabasePath();
    final dbFile = prepareDatabaseFile(dbPath);
    // Background isolate keeps all SQLite work off the UI isolate; see the
    // encrypted variant below for the perf rationale.
    return NativeDatabase.createInBackground(
      dbFile,
      // A device whose cipher migration keeps deferring never reaches the
      // encrypted open, and it is exactly the device a legacy-migration
      // backup sits beside. The plaintext migration backup is deliberately
      // not swept here: only a keyed open proves it is safe to drop.
      setup: (_) => sweepPreservedDatabaseCopies(dbPath),
    );
  });
}

bool get _isFlutterTestProcess =>
    Platform.executable.contains('flutter_tester');

// ---------------------------------------------------------------------------
// SQLite3MultipleCiphers at-rest encryption (#570, finding C2).
//
// db_client stays low-level: it never reads the platform keystore. The app
// layer resolves the 64-hex (raw 32-byte) cipher key and injects it here. The
// real encrypted open + the plaintext→encrypted migration require the
// sqlite3mc native build selected by package:sqlite3 hooks. See
// `mobile/docs/sqlcipher_at_rest_plan.md`.
// ---------------------------------------------------------------------------

/// Opens an at-rest-encrypted database connection for native platforms.
///
/// [rawKeyHex] is a 64-character hex (raw 32-byte) cipher key supplied by
/// the app layer. The key is applied in [applyCipherKey], which **fails
/// closed**: if SQLite3MultipleCiphers is not the active SQLite build the open
/// throws
/// rather than silently writing plaintext.
///
/// [databasePath] overrides the shared database location; it defaults to
/// [getSharedDatabasePath] and exists so probes/tests
/// (`encryptedDatabaseOpensCleanly`) can point at a specific file.
///
/// Throws [ArgumentError] if [rawKeyHex] is malformed (the error never embeds
/// the key — see [formatCipherKeyPragma]).
QueryExecutor openEncryptedConnection({
  required String rawKeyHex,
  String? databasePath,
}) {
  // Validate eagerly so a malformed key fails fast at construction time.
  _rawKeyLiteral(rawKeyHex);

  return LazyDatabase(() async {
    final dbPath = databasePath ?? await getSharedDatabasePath();
    final dbFile = prepareDatabaseFile(dbPath);
    // Open on a background isolate so the SQLite3MultipleCiphers per-page
    // AES-256-CBC + HMAC-SHA512 work (every read and write) never runs on the
    // UI isolate. The [setup] closure — including the raw key string and the
    // top-level helpers — is sendable, so it runs on the spawned isolate and
    // still fails closed if sqlite3mc is not the active build.
    return NativeDatabase.createInBackground(
      dbFile,
      setup: (rawDb) {
        applyCipherKey(rawDb, rawKeyHex);
        cleanUpPreCipherMigrationBackups(dbPath);
        sweepPreservedDatabaseCopies(dbPath);
      },
    );
  });
}

/// Returns whether the encrypted database at [databasePath] opens with
/// [rawKeyHex] and is structurally intact, via
/// [databasePassesIntegrityCheck].
///
/// This verifies a freshly-rebuilt salvage copy before
/// [salvageCorruptEncryptedDatabase] swaps it into place: it must open under
/// the same key and pass a full `PRAGMA quick_check`. The whole-database scan
/// is appropriate here because the salvage copy is small (local-only rows plus
/// empty caches).
///
/// It is intentionally **not** used as the startup guard for the large
/// production database — that would add an unbounded whole-DB scan to every
/// launch. The app-layer startup recovery instead uses the reactive
/// `encryptedDatabaseOpensCleanly`, which forces Drift's `beforeOpen` cleanup
/// (the operation that trips on the field corruption) rather than pre-scanning.
Future<bool> encryptedDatabaseOpensWithKey({
  required String rawKeyHex,
  String? databasePath,
}) async {
  _rawKeyLiteral(rawKeyHex);

  final dbPath = databasePath ?? await getSharedDatabasePath();
  if (!File(dbPath).existsSync()) return true;

  Database? db;
  try {
    db = sqlite3.open(dbPath);
    applyCipherKey(db, rawKeyHex);
    return databasePassesIntegrityCheck(db);
  } on SqliteException catch (e) {
    if (e.resultCode == _sqliteNotADb || e.resultCode == _sqliteCorrupt) {
      return false;
    }
    rethrow;
  } finally {
    db?.close();
  }
}

/// Whether [rawKeyHex] can decrypt the database at [databasePath] — i.e. it is
/// the correct cipher key, independent of deeper b-tree integrity.
///
/// [applyCipherKey] reads `sqlite_master` (the schema page), so this returns
/// `true` for a decryptable-but-corrupt database — including SQLITE_CORRUPT,
/// which means the key decrypted the page far enough to hit a *structural*
/// error, so the key is valid. It returns `false` only on SQLITE_NOTADB (the
/// key cannot decrypt the file). The app-layer recovery uses it to tell
/// "salvage failed under a working key" (keep the key so the
/// `.pre_key_loss_wipe_backup` stays readable) apart from real key loss
/// (rotate); classifying schema-page corruption as key loss would rotate a
/// still-valid key and orphan that backup. Returns `false` when the file is
/// missing.
Future<bool> encryptedDatabaseKeyDecrypts({
  required String rawKeyHex,
  String? databasePath,
}) async {
  _rawKeyLiteral(rawKeyHex);

  final dbPath = databasePath ?? await getSharedDatabasePath();
  if (!File(dbPath).existsSync()) return false;

  Database? db;
  try {
    db = sqlite3.open(dbPath);
    applyCipherKey(db, rawKeyHex);
    return true;
  } on SqliteException catch (e) {
    if (e.resultCode == _sqliteNotADb) return false;
    // SQLITE_CORRUPT means the key decrypted the page but the b-tree is
    // structurally damaged — the key is valid, so keep it (don't rotate).
    if (e.resultCode == _sqliteCorrupt) return true;
    rethrow;
  } finally {
    db?.close();
  }
}

/// Suffix for the in-progress salvage copy built by
/// [salvageCorruptEncryptedDatabase].
const _salvageSuffix = '.corruption_salvage';

/// Tables whose rows are local-only and cannot be re-fetched from relays, so
/// they are copied during salvage.
///
/// The large relay-backed caches (`event`, `video_metrics`, profile/hashtag
/// stats, `user_profiles`, `notifications`, `nip05_verifications`) are
/// intentionally omitted: they resync from relays and copying them would be
/// unbounded. `direct_messages` / `conversations` are also omitted — they
/// re-drain from gift wraps on relays, which the app-layer recovery triggers by
/// clearing the DM sync state after a salvage. `pending_view_events` is omitted
/// as best-effort view telemetry.
///
/// `outgoing_dms` and `dm_message_reactions` are kept: an unsent outbound
/// message or a `failed`/`pending` reaction (`gift_wrap_id IS NULL`) was never
/// wrapped to any relay, and the reaction rumor lives **only** in
/// `dm_message_reactions.rumor_event_json` (read back by
/// `DmReactionsRepository` on retry). Re-draining restores the target message,
/// not the user's unsent reaction, so it is the same only-copy case as
/// `outgoing_dms`.
///
/// This overlaps the [_localOnlyDataQueries] legacy-migration probe but is not
/// identical: salvage drops `direct_messages` / `conversations` (re-drainable)
/// and adds `dm_message_reactions` (only-copy). A new local-only table added to
/// one list should be considered for the other.
@visibleForTesting
const salvageableLocalOnlyTables = <String>[
  'drafts',
  'clips',
  'pending_uploads',
  'pending_actions',
  'outgoing_dms',
  'personal_reactions',
  'personal_reposts',
  'dm_message_reactions',
];

/// Salvages a corrupt encrypted database in place, preserving the local-only
/// data ([salvageableLocalOnlyTables]) that cannot be re-fetched from relays.
///
/// The app-layer startup recovery calls this when [rawKeyHex] opens the
/// database but it fails [databasePassesIntegrityCheck]. Reading a *table* does
/// not traverse a corrupt *index*, so rows on intact pages are recovered even
/// when `PRAGMA quick_check` fails. Readable rows are copied into a fresh
/// database keyed with the **same** [rawKeyHex]; the fresh database replaces
/// the corrupt one, which is renamed to a `.pre_corruption_recovery_backup`
/// backup (still readable under the same key). Re-fetchable caches are dropped
/// and resync.
///
/// Returns `true` when a fresh, integrity-clean database was swapped into
/// place. Returns `false` when [rawKeyHex] cannot decrypt the file (genuine
/// key loss — nothing is salvageable) or the salvage copy could not be made
/// sound; in both cases the original file is left untouched and the caller
/// should rotate the key and recreate.
Future<bool> salvageCorruptEncryptedDatabase({
  required String rawKeyHex,
  String? databasePath,
}) async {
  _rawKeyLiteral(rawKeyHex);

  final dbPath = databasePath ?? await getSharedDatabasePath();
  if (!File(dbPath).existsSync()) return false;

  final salvagePath = '$dbPath$_salvageSuffix';
  deleteDatabaseAndSidecars(salvagePath);

  // Build the salvage copy, then only swap it in if it is itself sound. On any
  // failure (wrong key, unbuildable, unsound copy) leave the original intact.
  final built = _buildSalvageCopy(
    sourcePath: dbPath,
    salvagePath: salvagePath,
    rawKeyHex: rawKeyHex,
  );
  final usable =
      built &&
      await encryptedDatabaseOpensWithKey(
        rawKeyHex: rawKeyHex,
        databasePath: salvagePath,
      );
  if (!usable) {
    deleteDatabaseAndSidecars(salvagePath);
    return false;
  }

  _preserveDatabaseCopy(
    fromPath: dbPath,
    suffix: corruptionRecoveryBackupSuffix,
  );
  promoteEncryptedMigrationArtifact(encryptedPath: salvagePath, dbPath: dbPath);
  return true;
}

/// Opens the corrupt source and a fresh keyed target, recreates the schema, and
/// copies the salvageable rows. Returns `false` when the key cannot decrypt the
/// source (`SqliteException`) — a build-level cipher failure (`StateError`) is
/// left to propagate, matching the rest of this file.
bool _buildSalvageCopy({
  required String sourcePath,
  required String salvagePath,
  required String rawKeyHex,
}) {
  Database? source;
  Database? target;
  try {
    source = sqlite3.open(sourcePath);
    applyCipherKey(source, rawKeyHex);
    target = sqlite3.open(salvagePath);
    applyCipherKey(target, rawKeyHex);
    _copyDatabaseSchema(source: source, target: target);
    // Carry Drift's schema version so it opens the salvaged file as an existing
    // database (running beforeOpen) instead of a fresh one — a fresh open
    // re-runs onCreate and fails with "table already exists". Then wrap the row
    // copy in one transaction: without it each INSERT is its own fsync'd
    // autocommit, so salvaging thousands of rows can take many seconds on
    // device flash. The per-row skips inside [_copySalvageableRows] never
    // throw, so COMMIT is always reached; a schema/DDL failure above is caught
    // before BEGIN.
    target
      ..execute('PRAGMA user_version = ${_userVersion(source)};')
      ..execute('BEGIN;');
    for (final table in salvageableLocalOnlyTables) {
      _copySalvageableRows(source: source, target: target, table: table);
    }
    target.execute('COMMIT;');
    return true;
  } on SqliteException {
    return false;
  } finally {
    source?.close();
    target?.close();
  }
}

/// Recreates every schema object from [source] in [target] so the salvaged
/// database matches the schema Drift expects. Tables are created before the
/// views / indexes / triggers that depend on them.
void _copyDatabaseSchema({
  required CommonDatabase source,
  required CommonDatabase target,
}) {
  for (final type in const ['table', 'view', 'index', 'trigger']) {
    final rows = source.select(
      'SELECT sql FROM sqlite_master WHERE type = ? AND sql IS NOT NULL '
      "AND name NOT LIKE 'sqlite_%';",
      [type],
    );
    for (final row in rows) {
      target.execute(row['sql'] as String);
    }
  }
}

/// Copies the readable rows of [table] from [source] to [target], keeping every
/// row before a corrupt page and skipping any individual row that cannot be
/// re-inserted.
///
/// Iterates a statement **cursor** rather than materializing `SELECT *`
/// eagerly: an eager `select()` on a table whose own pages are corrupt throws
/// before yielding anything, salvaging **zero** rows — even for the
/// drafts/clips this exists to save. A cursor yields every row up to the
/// corrupt page, then
/// `moveNext()` throws and the readable prefix is kept.
void _copySalvageableRows({
  required CommonDatabase source,
  required CommonDatabase target,
  required String table,
}) {
  final CommonPreparedStatement select;
  try {
    select = source.prepare('SELECT * FROM "$table";');
  } on SqliteException {
    return;
  }
  try {
    final cursor = select.selectCursor();
    String? insert;
    List<String>? columns;
    while (_cursorHasNextRow(cursor)) {
      final row = cursor.current;
      final resolvedColumns = columns ??= cursor.columnNames;
      insert ??= _buildRowInsert(table, resolvedColumns);
      try {
        target.execute(insert, [for (final c in resolvedColumns) row[c]]);
      } on SqliteException {
        // Skip an individual unreadable / conflicting row; keep the rest.
      }
    }
  } finally {
    select.close();
  }
}

/// Advances [cursor], treating a mid-iteration corruption as end-of-data so the
/// readable prefix already copied is kept.
bool _cursorHasNextRow(IteratingCursor cursor) {
  try {
    return cursor.moveNext();
  } on SqliteException {
    return false;
  }
}

String _buildRowInsert(String table, List<String> columns) {
  final columnList = columns.map((c) => '"$c"').join(', ');
  final placeholders = List.filled(columns.length, '?').join(', ');
  return 'INSERT INTO "$table" ($columnList) VALUES ($placeholders);';
}

/// Keys [rawDb] with [rawKeyHex] and verifies SQLite3MultipleCiphers is active.
///
/// The cipher selection pragmas and `PRAGMA key` must run before any real
/// database use. On plain SQLite these pragmas are unknown no-ops and
/// `PRAGMA cipher` returns no rows — meaning the database would be
/// **unencrypted**. We refuse to open in that case (fail closed) instead of
/// silently storing plaintext.
@visibleForTesting
void applyCipherKey(CommonDatabase rawDb, String rawKeyHex) {
  keyCipherDatabase(rawDb, rawKeyHex);

  // `PRAGMA key` is processed lazily, so an incorrect key surfaces as
  // SQLITE_NOTADB on the first real read rather than above. Probe the schema
  // so a wrong key fails deterministically at open time.
  rawDb.execute('SELECT count(*) FROM sqlite_master;');
}

/// Applies the cipher key without reading database schema pages.
///
/// Hot-journal recovery uses this before SQLite has rolled back an interrupted
/// schema transaction. Ordinary opens use [applyCipherKey] so wrong keys still
/// fail deterministically during open.
@visibleForTesting
void keyCipherDatabase(CommonDatabase rawDb, String rawKeyHex) {
  _rawKeyLiteral(rawKeyHex);
  _applySqlCipherCompatibility(rawDb);
  try {
    rawDb.execute(formatCipherKeyPragma(rawKeyHex));
  } on SqliteException {
    // Never rethrow the original: SqliteException.toString() appends the
    // causing statement, which is the `PRAGMA key` containing the raw key.
    throw StateError('Failed to apply the local database cipher key.');
  }

  if (!_isMultipleCiphersAvailable(rawDb)) {
    throw StateError(
      'SQLite3MultipleCiphers is not the active SQLite library; refusing to '
      'open the database unencrypted. Ensure package:sqlite3 hooks select '
      'sqlite3mc and no dependency links plain sqlite3.',
    );
  }
}

void _applySqlCipherCompatibility(CommonDatabase rawDb) {
  rawDb
    ..execute("PRAGMA cipher = 'sqlcipher';")
    ..execute('PRAGMA legacy = 4;');
}

bool _isMultipleCiphersAvailable(CommonDatabase rawDb) =>
    rawDb.select('PRAGMA cipher;').isNotEmpty;

/// Builds the SQLCipher `PRAGMA key` statement for a **raw** 32-byte key.
///
/// [rawKeyHex] is 64 hex characters, wrapped in SQLCipher's raw-key form
/// (`x'...'`) so SQLCipher uses the bytes verbatim and skips PBKDF2 — correct
/// for a CSPRNG-generated 32-byte key held in the platform keystore, not a
/// human passphrase.
///
/// Throws [ArgumentError] if [rawKeyHex] is not exactly 64 hex characters.
/// The thrown error deliberately does **not** include [rawKeyHex]: it is
/// secret key material and must never reach logs, Crashlytics, or test output.
@visibleForTesting
String formatCipherKeyPragma(String rawKeyHex) =>
    'PRAGMA key = ${_rawKeyLiteral(rawKeyHex)};';

/// Returns the SQLCipher-compatible raw-key literal (`"x'<hex>'"`) for use in
/// `PRAGMA key` and `PRAGMA rekey` clauses. Inlining the validated hex is
/// injection-safe because the value is constrained to `[0-9a-fA-F]{64}`.
String _rawKeyLiteral(String rawKeyHex) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(rawKeyHex)) {
    throw ArgumentError(
      'rawKeyHex must be exactly 64 hex characters '
      '(a raw 32-byte database cipher key)',
    );
  }
  return '"x\'$rawKeyHex\'"';
}

/// Outcome of [migratePlaintextToEncrypted].
enum CipherMigrationOutcome {
  /// No database file existed (fresh install) — nothing to migrate.
  noDatabase,

  /// The existing database was already encrypted — nothing to do.
  alreadyEncrypted,

  /// An empty plaintext database was removed so a fresh encrypted one is
  /// created on first open.
  removedEmptyPlaintext,

  /// A populated plaintext database was rekeyed into an encrypted file.
  migrated,

  /// Migration was attempted on a **readable plaintext** database but could not
  /// complete; the source is left intact and the caller should retry on the
  /// next launch. Opening it with a null key in the meantime is safe — the file
  /// really is plaintext.
  failed,

  /// The database file exists but could not be classified or copied: a legible
  /// SQLite header over structurally corrupt pages. Unlike [failed] this is
  /// deterministic for a given file, so retrying next launch never recovers,
  /// and opening it with a null key yields SQLITE_CORRUPT on every statement
  /// for the whole session. The caller must fail closed. See #6897.
  ///
  /// Reached from either place the damage can surface: the keyless
  /// classification, which sees only page 1, and the `VACUUM INTO` copy that
  /// walks every remaining b-tree.
  unreadable,
}

/// The keyless classifier operation that could not determine the database
/// format.
enum DatabaseClassificationStage {
  openDatabase,
  readSchema,
}

/// SQLite could not safely determine the existing database format.
///
/// Callers must fail closed: the file may be plaintext or encrypted, so
/// opening it with either assumption can corrupt data or strand the session.
/// The diagnostic fields intentionally omit the database path and SQL text.
class DatabaseClassificationException implements Exception {
  const DatabaseClassificationException({
    required this.stage,
    required this.resultCode,
    required this.extendedResultCode,
  });

  final DatabaseClassificationStage stage;
  final int resultCode;
  final int extendedResultCode;

  @override
  String toString() =>
      'DatabaseClassificationException: stage=${stage.name}, '
      'resultCode=$resultCode, extendedResultCode=$extendedResultCode; '
      'refusing to open an unclassified database.';
}

/// One-time in-place rekey of the existing **plaintext** `divine_db.db` into a
/// SQLite3MultipleCiphers-encrypted database.
///
/// Safe by construction: a plaintext side-file copy is encrypted and verified
/// (key opens it; table/row counts match the source) **before** the plaintext
/// original is swapped out, and the original is renamed to a backup rather
/// than deleted. On any failure the plaintext database is left exactly as it
/// was so the app keeps working and the migration retries next launch.
///
/// Wipe-and-resync is intentionally rejected: `divine_db.db` is shared with
/// drafts, pending uploads/actions, reactions, reposts, etc., which cannot be
/// re-fetched. See `mobile/docs/sqlcipher_at_rest_plan.md`.
///
/// Returns [CipherMigrationOutcome.unreadable] when the existing file is
/// structurally corrupt — whether that surfaces while classifying page 1 or
/// while copying the rest of it — which no retry can fix, so the caller must
/// fail closed rather than open it unkeyed.
///
/// Throws [DatabaseClassificationException] when SQLite cannot safely identify
/// the existing file format. Throws [DatabaseHotJournalRecoveryError] when a
/// hot rollback journal cannot be safely replayed. Requires
/// SQLite3MultipleCiphers;
/// returns [CipherMigrationOutcome.failed] when it is not linked, leaving the
/// proven-readable plaintext source intact.
Future<CipherMigrationOutcome> migratePlaintextToEncrypted({
  required String rawKeyHex,
  String? databasePath,
  @visibleForTesting void Function()? onHotJournalRecoveryCompletedForTesting,
}) async {
  _rawKeyLiteral(rawKeyHex); // validate shape up front (never embeds the key)

  final dbPath = databasePath ?? await getSharedDatabasePath();
  final encryptedPath = '$dbPath$_migratingSuffix';

  // Resume an interrupted swap. A force-kill between renaming the plaintext
  // original to its backup and moving the verified encrypted copy into place
  // leaves the (already-verified) encrypted file at [encryptedPath] with no
  // file at [dbPath]. Completing the rename is the lossless recovery.
  if (!File(dbPath).existsSync() && File(encryptedPath).existsSync()) {
    promoteEncryptedMigrationArtifact(
      encryptedPath: encryptedPath,
      dbPath: dbPath,
    );
    return CipherMigrationOutcome.migrated;
  }

  // Resume an interrupted salvage swap (see [salvageCorruptEncryptedDatabase]).
  // A force-kill after the corrupt original was renamed to its backup but
  // before the verified salvage copy was promoted leaves the salvage file with
  // no file at [dbPath] — the same window the migration resume above covers.
  // Promoting the still-sound salvage completes the swap instead of stranding
  // the recovered drafts/clips and creating a fresh empty database.
  if (!File(dbPath).existsSync() &&
      await _resumeInterruptedSalvage(dbPath: dbPath, rawKeyHex: rawKeyHex)) {
    return CipherMigrationOutcome.alreadyEncrypted;
  }

  if (!File(dbPath).existsSync()) return CipherMigrationOutcome.noDatabase;

  switch (_classifyDatabase(
    dbPath,
    rawKeyHex: rawKeyHex,
    onRecoveryCompleted: onHotJournalRecoveryCompletedForTesting,
  )) {
    case _DbClassification.encrypted:
      return CipherMigrationOutcome.alreadyEncrypted;
    case _DbClassification.corrupt:
      return CipherMigrationOutcome.unreadable;
    case _DbClassification.emptyPlaintext:
      deleteDatabaseAndSidecars(dbPath);
      return CipherMigrationOutcome.removedEmptyPlaintext;
    case _DbClassification.populatedPlaintext:
      return _rekeyPlaintextInPlace(dbPath: dbPath, rawKeyHex: rawKeyHex);
  }
}

/// Completes a salvage swap that was interrupted after the corrupt original was
/// backed up but before the verified salvage copy was promoted into place.
/// Mirrors the `.sqlcipher_migrating` resume in [migratePlaintextToEncrypted].
///
/// The salvage copy is re-verified under [rawKeyHex] before promotion; an
/// unusable leftover is discarded so startup falls through to creating a fresh
/// database. Returns whether a salvage copy was promoted into [dbPath].
Future<bool> _resumeInterruptedSalvage({
  required String dbPath,
  required String rawKeyHex,
}) async {
  final salvagePath = '$dbPath$_salvageSuffix';
  if (!File(salvagePath).existsSync()) return false;

  if (await encryptedDatabaseOpensWithKey(
    rawKeyHex: rawKeyHex,
    databasePath: salvagePath,
  )) {
    promoteEncryptedMigrationArtifact(
      encryptedPath: salvagePath,
      dbPath: dbPath,
    );
    return true;
  }

  deleteDatabaseAndSidecars(salvagePath);
  return false;
}

const _migratingSuffix = '.sqlcipher_migrating';
const _sqliteNotADb = 26; // SQLITE_NOTADB
// Primary result code for every SQLITE_CORRUPT_* extended code (e.g. 779
// SQLITE_CORRUPT_INDEX), so this matches whichever variant SQLite reports.
const _sqliteCorrupt = 11; // SQLITE_CORRUPT

enum _DbClassification {
  encrypted,
  emptyPlaintext,
  populatedPlaintext,

  /// Structurally damaged: the keyless open read a legible SQLite header and
  /// then failed with `SQLITE_CORRUPT` rather than `SQLITE_NOTADB`. An
  /// encrypted file cannot land here — its page 1 starts with the cipher salt,
  /// not `SQLite format 3`, so it always reports `SQLITE_NOTADB` — which makes
  /// this a plaintext-shaped file that no key can rescue.
  corrupt,
}

/// Classifies [dbPath] by opening it **without** a key. A plaintext database
/// reads its schema fine.
///
/// Only `SQLITE_NOTADB` is treated as a positive "encrypted" signal, so a
/// transient failure on a readable plaintext DB never masquerades as encrypted
/// (which would trigger the destructive key-loss path). `SQLITE_CORRUPT` is
/// split out from the transient errors: it is a property of the file, not of
/// the moment, so it repeats on every launch and needs the caller to fail
/// closed rather than defer.
_DbClassification _classifyDatabase(
  String dbPath, {
  required String rawKeyHex,
  void Function()? onRecoveryCompleted,
}) {
  try {
    return _classifyDatabaseOnce(dbPath);
  } on DatabaseClassificationException catch (error) {
    if (!isHotRollbackJournalFailure(error)) {
      rethrow;
    }

    try {
      recoverHotRollbackJournal(
        databasePath: dbPath,
        configureEncryptedDatabase: (database) =>
            keyCipherDatabase(database, rawKeyHex),
      );
    } on DatabaseHotJournalRecoveryError catch (recoveryError) {
      // A wrong key proves this is encrypted but must never trigger journal
      // replay. Returning the ordinary encrypted classification preserves the
      // existing key-loss recovery path in DatabaseEncryptionBootstrap.
      if (recoveryError.stage ==
              DatabaseHotJournalRecoveryStage.validateCipherKey &&
          recoveryError.resultCode == _sqliteNotADb) {
        return _DbClassification.encrypted;
      }
      rethrow;
    }
    onRecoveryCompleted?.call();

    try {
      return _classifyDatabaseOnce(dbPath);
    } on DatabaseClassificationException catch (retryError) {
      if (retryError.extendedResultCode == sqliteReadOnlyRollback) {
        throw const DatabaseHotJournalRecoveryError(
          stage: DatabaseHotJournalRecoveryStage.retryClassification,
          extendedResultCode: sqliteReadOnlyRollback,
        );
      }
      rethrow;
    }
  }
}

@visibleForTesting
bool isHotRollbackJournalFailure(DatabaseClassificationException error) =>
    error.resultCode == sqliteReadOnly &&
    error.extendedResultCode == sqliteReadOnlyRollback;

_DbClassification _classifyDatabaseOnce(String dbPath) {
  Database db;
  try {
    db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  } on SqliteException catch (e) {
    return _classifyKeylessFailure(
      e,
      stage: DatabaseClassificationStage.openDatabase,
    );
  }

  try {
    final rows = db.select(
      "SELECT count(*) AS c FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%';",
    );
    final tableCount = rows.first['c'] as int;
    return tableCount == 0
        ? _DbClassification.emptyPlaintext
        : _DbClassification.populatedPlaintext;
  } on SqliteException catch (e) {
    return _classifyKeylessFailure(
      e,
      stage: DatabaseClassificationStage.readSchema,
    );
  } finally {
    db.close();
  }
}

_DbClassification _classifyKeylessFailure(
  SqliteException error, {
  required DatabaseClassificationStage stage,
}) => switch (error.resultCode) {
  _sqliteNotADb => _DbClassification.encrypted,
  _sqliteCorrupt => _DbClassification.corrupt,
  _ => throw DatabaseClassificationException(
    stage: stage,
    resultCode: error.resultCode,
    extendedResultCode: error.extendedResultCode,
  ),
};

/// Maps a rekey failure to an outcome, on the same result-code split
/// [_classifyKeylessFailure] applies one step earlier.
///
/// [_classifyDatabase] reads only `sqlite_master`, so it can only ever see
/// damage on page 1; everything past it classifies as readable plaintext and
/// first surfaces here, where `VACUUM INTO` copies the whole database and walks
/// every b-tree. That is the larger share of a real database, and the same
/// permanent condition: the bytes classify identically on every launch, so
/// deferring retries them forever while the app runs unkeyed against a file
/// that throws on the damaged pages. Fail closed for it too (#6897).
///
/// Everything else — busy, locked, I/O, a missing SQLite3MultipleCiphers — is
/// genuinely transient and keeps deferring.
CipherMigrationOutcome _rekeyFailureOutcome(SqliteException e) =>
    e.resultCode == _sqliteCorrupt
    ? CipherMigrationOutcome.unreadable
    : CipherMigrationOutcome.failed;

CipherMigrationOutcome _rekeyPlaintextInPlace({
  required String dbPath,
  required String rawKeyHex,
}) {
  final encryptedPath = '$dbPath$_migratingSuffix';
  // Remove any partial artifact from an interrupted previous attempt.
  deleteDatabaseAndSidecars(encryptedPath);

  Database source;
  try {
    // The source must be opened UNKEYED. It remains untouched until a verified
    // encrypted side-file is ready to promote.
    source = sqlite3.open(dbPath);
  } on SqliteException catch (e) {
    return _rekeyFailureOutcome(e);
  }

  try {
    if (!_isMultipleCiphersAvailable(source)) {
      // SQLite3MultipleCiphers not linked — cannot encrypt. Leave plaintext
      // intact.
      return CipherMigrationOutcome.failed;
    }
    source.execute('VACUUM INTO ?;', [encryptedPath]);
  } on SqliteException catch (e) {
    deleteDatabaseAndSidecars(encryptedPath);
    return _rekeyFailureOutcome(e);
  } finally {
    source.close();
  }

  if (!_encryptPlaintextMigrationArtifact(
    encryptedPath: encryptedPath,
    rawKeyHex: rawKeyHex,
  )) {
    deleteDatabaseAndSidecars(encryptedPath);
    return CipherMigrationOutcome.failed;
  }

  if (!encryptedCopyMatchesSource(
    plaintextPath: dbPath,
    encryptedPath: encryptedPath,
    rawKeyHex: rawKeyHex,
  )) {
    deleteDatabaseAndSidecars(encryptedPath);
    return CipherMigrationOutcome.failed;
  }

  // Keep the plaintext original as a backup until the next successful launch,
  // then move the verified encrypted copy into place.
  _preserveDatabaseCopy(
    fromPath: dbPath,
    suffix: preCipherMigrationBackupSuffix,
  );
  promoteEncryptedMigrationArtifact(
    encryptedPath: encryptedPath,
    dbPath: dbPath,
  );
  return CipherMigrationOutcome.migrated;
}

bool _encryptPlaintextMigrationArtifact({
  required String encryptedPath,
  required String rawKeyHex,
}) {
  Database? db;
  try {
    db = sqlite3.open(encryptedPath);
    _applySqlCipherCompatibility(db);
    db
      ..execute('PRAGMA rekey = ${_rawKeyLiteral(rawKeyHex)};')
      ..execute('SELECT count(*) FROM sqlite_master;');
    return true;
  } on SqliteException {
    return false;
  } finally {
    db?.close();
  }
}

/// Promotes the verified encrypted migration artifact into the canonical DB
/// path, carrying its rollback-journal, WAL, and SHM sidecars with it.
@visibleForTesting
void promoteEncryptedMigrationArtifact({
  required String encryptedPath,
  required String dbPath,
}) {
  File(encryptedPath).renameSync(dbPath);
  _moveSidecars(fromPath: encryptedPath, toPath: dbPath);
}

/// Verifies the encrypted copy opens with [rawKeyHex], that its `user_version`
/// (drift's schema version) and user-table row counts match the plaintext
/// source, and that it is structurally sound — the gate before swapping files.
///
/// The structural check ([integrityCheck], defaulting to
/// [databasePassesIntegrityCheck] which runs `PRAGMA quick_check`) is the
/// load-bearing addition: `user_version` + row counts can match on an encrypted
/// artifact whose index b-tree is corrupt, and promoting such a file throws
/// `SqliteException(779)` ("database disk image is malformed") on the first
/// index-traversing write. [integrityCheck] is injectable only so the gate's
/// fail-closed behaviour can be exercised deterministically in tests.
@visibleForTesting
bool encryptedCopyMatchesSource({
  required String plaintextPath,
  required String encryptedPath,
  required String rawKeyHex,
  bool Function(CommonDatabase db) integrityCheck =
      databasePassesIntegrityCheck,
}) {
  Database? encrypted;
  Database? plaintext;
  try {
    encrypted = sqlite3.open(encryptedPath);
    applyCipherKey(encrypted, rawKeyHex);

    plaintext = sqlite3.open(plaintextPath, mode: OpenMode.readOnly);

    if (_userVersion(encrypted) != _userVersion(plaintext)) return false;

    if (!const MapEquality<String, int>().equals(
      _userTableRowCounts(encrypted),
      _userTableRowCounts(plaintext),
    )) {
      return false;
    }

    return integrityCheck(encrypted);
  } on SqliteException {
    return false;
  } finally {
    encrypted?.close();
    plaintext?.close();
  }
}

int _userVersion(Database db) =>
    db.select('PRAGMA user_version;').first['user_version'] as int? ?? 0;

/// Backs up (rather than hard-deletes) the shared database for the #570 §6
/// key-loss recovery.
///
/// When the platform keystore is cleared (OS reset / restore without keychain
/// migration) the cipher key is gone and the encrypted database is
/// cryptographically unrecoverable, so it must be replaced. It is renamed to a
/// timestamped backup (with its rollback-journal, WAL, and SHM sidecars)
/// rather than deleted, so a misclassification or a future recovery path is
/// never catastrophic. A fresh encrypted database is created under the new
/// key on first open; DMs resync from relays. See
/// `mobile/docs/sqlcipher_at_rest_plan.md`.
///
/// The copy is superseded by the next one of its kind and expires after
/// [preservedDatabaseCopyRetention]; it is a window in which the bytes are
/// still there, not a permanent second database.
Future<void> backUpAndRemoveSharedDatabase() async {
  final dbPath = await getSharedDatabasePath();
  if (!File(dbPath).existsSync()) return;
  _preserveDatabaseCopy(fromPath: dbPath, suffix: keyLossWipeBackupSuffix);
}

/// Deletes the shared database and sidecars without preserving a backup.
///
/// Use only when the caller has already proved the file is unusable plaintext.
/// Encrypted database resets should keep using [backUpAndRemoveSharedDatabase]
/// so the preserved backup remains readable under the retained cipher key.
Future<void> deleteSharedDatabase() async {
  final dbPath = await getSharedDatabasePath();
  deleteDatabaseAndSidecars(dbPath);
}

/// Removes plaintext backups left by a successful plaintext→encrypted
/// migration once the encrypted database has opened with its key.
///
/// The migration keeps the plaintext source as
/// `.pre_cipher_migration_backup*` until a later keyed open proves the
/// encrypted database is usable. At that point the backup would otherwise
/// leave the old plaintext database readable at rest, defeating #570 C2 — so
/// this one gets no retention window at all, unlike the encrypted copies
/// [sweepPreservedDatabaseCopies] ages out.
@visibleForTesting
void cleanUpPreCipherMigrationBackups(String dbPath) =>
    deletePreservedDatabaseCopies(
      dbPath,
      suffix: preCipherMigrationBackupSuffix,
    );

Map<String, int> _userTableRowCounts(Database db) {
  final counts = <String, int>{};
  final tables = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name;",
  );
  for (final row in tables) {
    final name = row['name'] as String;
    final result = db.select('SELECT count(*) AS c FROM "$name";');
    counts[name] = result.first['c'] as int;
  }
  return counts;
}

/// Get path to shared database file
///
/// Path: {appSupport}/openvine/database/divine_db.db
///
/// The database lived under `getApplicationDocumentsDirectory()` until the
/// change that shipped in PR #2840. When it moved to Application Support,
/// no migration was included, which orphans every user's local data on
/// upgrade (DMs, drafts, clips, upload queue, reactions, reposts,
/// notifications, bookmarks, NIP-05 verifications, etc.). This function
/// migrates the legacy file on first run after upgrade.
Future<String> getSharedDatabasePath() async {
  final appSupportDir = await getApplicationSupportDirectory();
  final newPath = buildSharedDatabasePath(appSupportDir.path);

  // Check cache version and wipe stale database if needed.
  applyDbCacheVersionReset(newPath);

  final docDir = await getApplicationDocumentsDirectory();
  final legacyPath = p.join(
    docDir.path,
    'openvine',
    'database',
    'divine_db.db',
  );
  await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

  return newPath;
}

/// Bump this version when startup needs to mark that a database compatibility
/// check has run. Version adoption must not delete the database: it contains
/// local-only user data such as drafts and pending actions.
///
/// Version history:
///   1 — initial (implicit, no version file exists yet)
///   2 — force reset to recover from PR #2840 path-change data loss
@visibleForTesting
const int dbCacheVersion = 2;

/// File name written next to the database to track [dbCacheVersion].
@visibleForTesting
const String dbVersionFileName = 'divine_db.version';

/// Reads the stored cache version from a file next to the database.
/// Returns `null` when the version file does not exist (first run with
/// this mechanism).
@visibleForTesting
int? readDbCacheVersion(String dbDir) {
  final file = File(p.join(dbDir, dbVersionFileName));
  if (!file.existsSync()) return null;
  return int.tryParse(file.readAsStringSync().trim());
}

/// Writes [version] to the version file next to the database.
@visibleForTesting
void writeDbCacheVersion(String dbDir, int version) {
  final dir = Directory(dbDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File(p.join(dbDir, dbVersionFileName)).writeAsStringSync('$version');
}

/// Writes the current [dbCacheVersion] when the stored version is stale.
///
/// On first run (no version file), also writes the current version without
/// deleting anything.
@visibleForTesting
void applyDbCacheVersionReset(String dbPath) {
  final dbDir = p.dirname(dbPath);
  final stored = readDbCacheVersion(dbDir);

  if (stored == null) {
    // First run with version tracking — adopt current version, no wipe.
    writeDbCacheVersion(dbDir, dbCacheVersion);
    return;
  }

  if (stored < dbCacheVersion) {
    writeDbCacheVersion(dbDir, dbCacheVersion);
  }
}

/// One-time migration from the pre-PR #2840 Documents-directory location
/// to the current Application Support location.
///
/// Handles three cases:
/// 1. Legacy does not exist → no-op (fresh install or already migrated).
/// 2. Legacy exists, new does not → rename legacy to new.
/// 3. Both exist → migrate legacy only if the destination has no actionable
///    local-only rows and legacy does. If neither side has actionable local
///    data, delete the orphaned legacy file. Otherwise preserve both;
///    replacing a populated destination can discard local-only data.
///
/// Also migrates SQLite rollback-journal, WAL, and SHM sidecar files if
/// present, so recovery data and unsynced writes stay with the database.
@visibleForTesting
Future<void> migrateLegacyDatabase({
  required String legacyPath,
  required String newPath,
}) async {
  final legacyFile = File(legacyPath);
  if (!legacyFile.existsSync()) return;

  Map<String, List<int>>? legacySidecars;
  final newFile = File(newPath);
  if (newFile.existsSync()) {
    legacySidecars = _readDatabaseSidecars(legacyPath);
    final newHasActionableData = _databaseHasActionableLocalOnlyData(newPath);
    final legacyHasActionableData = _databaseHasActionableLocalOnlyData(
      legacyPath,
    );

    if (!newHasActionableData && legacyHasActionableData) {
      _backupDestinationDatabase(newPath);
    } else if (newHasActionableData && legacyHasActionableData) {
      _backupLegacyConflictDatabase(
        legacyPath: legacyPath,
        newPath: newPath,
        sidecars: legacySidecars,
      );
      return;
    } else {
      deleteDatabaseAndSidecars(legacyPath);
      return;
    }
  }

  Directory(p.dirname(newPath)).createSync(recursive: true);
  legacyFile.renameSync(newPath);
  _moveSidecars(
    fromPath: legacyPath,
    toPath: newPath,
    preservedSidecars: legacySidecars,
  );
}

void _backupDestinationDatabase(String dbPath) {
  _preserveDatabaseCopy(fromPath: dbPath, suffix: legacyMigrationBackupSuffix);
}

void _backupLegacyConflictDatabase({
  required String legacyPath,
  required String newPath,
  required Map<String, List<int>> sidecars,
}) {
  Directory(p.dirname(newPath)).createSync(recursive: true);
  _preserveDatabaseCopy(
    fromPath: legacyPath,
    anchorPath: newPath,
    suffix: legacyConflictBackupSuffix,
    preservedSidecars: sidecars,
  );
}

Map<String, List<int>> _readDatabaseSidecars(String dbPath) {
  final sidecars = <String, List<int>>{};
  for (final suffix in databaseSidecarSuffixes) {
    final sidecar = File('$dbPath$suffix');
    if (sidecar.existsSync()) {
      sidecars[suffix] = sidecar.readAsBytesSync();
    }
  }
  return sidecars;
}

void _moveSidecars({
  required String fromPath,
  required String toPath,
  Map<String, List<int>>? preservedSidecars,
}) {
  for (final suffix in databaseSidecarSuffixes) {
    final sidecar = File('$fromPath$suffix');
    if (sidecar.existsSync()) {
      sidecar.renameSync('$toPath$suffix');
    } else if (preservedSidecars?.containsKey(suffix) ?? false) {
      File('$toPath$suffix').writeAsBytesSync(preservedSidecars![suffix]!);
    }
  }
}

@visibleForTesting
void deleteDatabaseAndSidecars(String dbPath) {
  for (final suffix in const ['', ...databaseSidecarSuffixes]) {
    final file = File('$dbPath$suffix');
    if (file.existsSync()) file.deleteSync();
  }
}

/// Renames [fromPath] and its sidecars to a stamped preserved copy, then
/// applies [sweepPreservedDatabaseCopies] so the copies this one supersedes go
/// with it.
///
/// [anchorPath] is the database the copy is named after. That is [fromPath]
/// everywhere except the legacy conflict, where the *legacy* database is set
/// aside beside the destination it could not replace, so the name has to
/// follow the destination.
///
/// Sweeping here as well as on the next keyed open is what bounds a device
/// that takes a recovery path on every launch — an Android keystore reading
/// back empty each time, say. Left to the open alone, every one of those
/// launches would add a whole database and none would take one away.
void _preserveDatabaseCopy({
  required String fromPath,
  required String suffix,
  String? anchorPath,
  Map<String, List<int>>? preservedSidecars,
}) {
  final anchor = anchorPath ?? fromPath;
  final backupPath = nextPreservedDatabaseCopyPath(anchor, suffix: suffix);
  File(fromPath).renameSync(backupPath);
  _moveSidecars(
    fromPath: fromPath,
    toPath: backupPath,
    preservedSidecars: preservedSidecars,
  );
  sweepPreservedDatabaseCopies(anchor);
}

bool _databaseHasActionableLocalOnlyData(String dbPath) {
  Database db;
  try {
    db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  } on SqliteException {
    return true;
  }

  try {
    for (final query in _localOnlyDataQueries) {
      if (!_databaseHasTable(db, query.tableName)) continue;

      final rows = db.select(query.sql);
      if (rows.isNotEmpty) return true;
    }
    return false;
  } on SqliteException {
    return true;
  } finally {
    db.close();
  }
}

bool _databaseHasTable(Database db, String tableName) {
  final rows = db.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [tableName],
  );
  return rows.isNotEmpty;
}

const _localOnlyDataQueries = [
  _LocalOnlyDataQuery(
    'pending_uploads',
    'SELECT 1 FROM pending_uploads WHERE status NOT IN '
        "('published', 'failed') LIMIT 1",
  ),
  _LocalOnlyDataQuery(
    'pending_actions',
    "SELECT 1 FROM pending_actions WHERE status != 'completed' LIMIT 1",
  ),
  _LocalOnlyDataQuery(
    'outgoing_dms',
    "SELECT 1 FROM outgoing_dms WHERE recipient_wrap_status != 'sent' "
        "OR self_wrap_status != 'sent' LIMIT 1",
  ),
  _LocalOnlyDataQuery(
    'personal_reactions',
    'SELECT 1 FROM personal_reactions LIMIT 1',
  ),
  _LocalOnlyDataQuery(
    'personal_reposts',
    'SELECT 1 FROM personal_reposts LIMIT 1',
  ),
  _LocalOnlyDataQuery('drafts', 'SELECT 1 FROM drafts LIMIT 1'),
  _LocalOnlyDataQuery('clips', 'SELECT 1 FROM clips LIMIT 1'),
  _LocalOnlyDataQuery(
    'direct_messages',
    'SELECT 1 FROM direct_messages LIMIT 1',
  ),
  _LocalOnlyDataQuery('conversations', 'SELECT 1 FROM conversations LIMIT 1'),
];

class _LocalOnlyDataQuery {
  const _LocalOnlyDataQuery(this.tableName, this.sql);

  final String tableName;
  final String sql;
}

/// Builds the shared database path from a platform-specific writable base.
///
/// Application Support is preferred for sandboxed app data on macOS/iOS.
@visibleForTesting
String buildSharedDatabasePath(String basePath) {
  return p.join(basePath, 'openvine', 'database', 'divine_db.db');
}

/// Ensures the database parent directory exists before SQLite opens the file.
///
/// Fresh installs and clean sandbox containers may not have the nested
/// `openvine/database` directory tree yet. Without creating it first,
/// SQLite can fail with `SqliteException(14): unable to open database file`.
@visibleForTesting
File prepareDatabaseFile(String dbPath) {
  final dbFile = File(dbPath);
  dbFile.parent.createSync(recursive: true);
  return dbFile;
}
