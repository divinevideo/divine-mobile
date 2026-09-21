// ABOUTME: Resolves the at-rest DB cipher key + runs the one-time plaintext→encrypted migration.
// ABOUTME: App-layer bootstrap; db_client never reads the keystore, so the key is injected here.

import 'dart:math';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openvine/database/sqlcipher_runtime.dart';
import 'package:openvine/services/database_recovery_store.dart';
import 'package:unified_logger/unified_logger.dart';

/// Secure-storage key for the at-rest DB cipher key. Versioned so a future
/// rotation can introduce `.v3` without colliding.
///
/// `.v2` holds the same key material as `.v1` did; it is a new slot because
/// the iOS Keychain accessibility changed (#9343) and the plugin cannot report
/// which accessibility an existing item carries. A key found here has been
/// stored under the current options and needs no migration.
@visibleForTesting
const dbCipherKeyStorageKey = 'db.cipher.key.v2';

/// The slot the cipher key lived in before #9343. On iOS that item carries the
/// package-default `unlocked` accessibility, which the Keychain refuses
/// whenever the device is locked. It is only ever read once and moved to
/// [dbCipherKeyStorageKey], then deleted — through the storage instance that
/// still names its accessibility, because the iOS plugin puts the accessibility
/// into its delete query.
@visibleForTesting
const legacyDbCipherKeyStorageKey = 'db.cipher.key.v1';

/// Resolves the SQLite3MultipleCiphers key for the local database before the first
/// `AppDatabase` open and performs the one-time plaintext→encrypted migration.
///
/// db_client stays keystore-free: this app-layer service reads/generates the
/// key from [FlutterSecureStorage] and injects it via `db_cipher_key_provider`.
/// Native runtime hooks (the cipher-availability probe, the migration, the
/// key-loss backup/recreate path) are injected so the orchestration is
/// unit-testable.
class DatabaseEncryptionBootstrap {
  DatabaseEncryptionBootstrap({
    required FlutterSecureStorage secureStorage,
    required FlutterSecureStorage legacySecureStorage,
    Future<bool?> Function()? isProtectedDataAvailable,
    Future<void> Function()? ensureRuntime,
    bool Function()? isCipherAvailable,
    Future<CipherMigrationOutcome> Function(String rawKeyHex)? migrate,
    Future<void> Function()? deleteDatabase,
    Future<void> Function()? onDatabaseReset,
    Future<bool> Function(String rawKeyHex)? canOpenEncryptedDatabase,
    Future<bool> Function(String rawKeyHex)? salvageDatabase,
    Future<bool> Function(String rawKeyHex)? encryptedKeyMatches,
    Future<void> Function(Object error, StackTrace stack)? recordRecovery,
    Future<void> Function(DatabaseRecoveryOutcome outcome)?
    persistRecoveryOutcome,
    Future<bool> Function()? hasPendingCorruptionRecovery,
    Future<void> Function()? clearPendingCorruptionRecovery,
  }) : _secureStorage = secureStorage,
       _legacySecureStorage = legacySecureStorage,
       _isProtectedDataAvailable =
           isProtectedDataAvailable ??
           (() => _iosProtectedDataAvailable(secureStorage)),
       _recordRecovery = recordRecovery,
       _persistRecoveryOutcome = persistRecoveryOutcome,
       _hasPendingCorruptionRecovery =
           hasPendingCorruptionRecovery ?? (() async => false),
       _clearPendingCorruptionRecovery =
           clearPendingCorruptionRecovery ?? (() async {}),
       _ensureRuntime = ensureRuntime ?? ensureSqlCipherRuntime,
       _isCipherAvailable = isCipherAvailable ?? isSqlCipherAvailable,
       _migrate =
           migrate ??
           ((rawKeyHex) => migratePlaintextToEncrypted(rawKeyHex: rawKeyHex)),
       _deleteDatabase = deleteDatabase ?? backUpAndRemoveSharedDatabase,
       _onDatabaseReset = onDatabaseReset,
       _canOpenEncryptedDatabase =
           canOpenEncryptedDatabase ??
           ((rawKeyHex) => encryptedDatabaseOpensCleanly(rawKeyHex: rawKeyHex)),
       _salvageDatabase =
           salvageDatabase ??
           ((rawKeyHex) =>
               salvageCorruptEncryptedDatabase(rawKeyHex: rawKeyHex)),
       _encryptedKeyMatches =
           encryptedKeyMatches ??
           ((rawKeyHex) => encryptedDatabaseKeyDecrypts(rawKeyHex: rawKeyHex));

  /// Reads and writes [dbCipherKeyStorageKey] under the current options — on
  /// iOS `first_unlock_this_device`, see `appDbCipherKeyIosSecureStorageOptions`.
  final FlutterSecureStorage _secureStorage;

  /// Reaches [legacyDbCipherKeyStorageKey] under the pre-#9343 options. Read
  /// and delete only; nothing is ever written through it.
  final FlutterSecureStorage _legacySecureStorage;

  /// Whether the platform can currently decrypt `unlocked`-class data — iOS's
  /// `UIApplication.isProtectedDataAvailable`. `null` where the bootstrap has
  /// no such signal to consult (Android, web, and macOS — see
  /// [_iosProtectedDataAvailable]). Consulted before generating a key: see
  /// [_requireReadableKeystore].
  final Future<bool?> Function() _isProtectedDataAvailable;

  final Future<void> Function() _ensureRuntime;
  final bool Function() _isCipherAvailable;
  final Future<CipherMigrationOutcome> Function(String rawKeyHex) _migrate;
  final Future<void> Function() _deleteDatabase;
  final Future<bool> Function(String rawKeyHex) _canOpenEncryptedDatabase;

  /// Attempts to salvage the local-only data from a corrupt encrypted database
  /// (rebuilding it in place under the same key) before the destructive wipe.
  /// Returns `false` on key loss or when a sound copy could not be rebuilt;
  /// [_encryptedKeyMatches] then decides whether the wipe rotates the key.
  final Future<bool> Function(String rawKeyHex) _salvageDatabase;

  /// Whether the key still decrypts the corrupt DB's schema page. Used only
  /// when salvage fails, to keep a still-valid key (so the backup stays
  /// readable) instead of rotating it. Returns `false` on genuine key loss.
  final Future<bool> Function(String rawKeyHex) _encryptedKeyMatches;

  /// Whether a previous session's runtime corruption report scheduled a
  /// recovery. When it did, [resolveCipherKey] skips [_canOpenEncryptedDatabase]
  /// and salvages unconditionally: that probe is reactive (it forces Drift's
  /// `beforeOpen` cleanup rather than a whole-DB `PRAGMA quick_check`), so it
  /// cannot see corruption confined to pages the cleanup never reads — the exact
  /// case the runtime report exists to catch. Trusting the probe here would
  /// clear the database and leave the user stuck on it indefinitely.
  final Future<bool> Function() _hasPendingCorruptionRecovery;

  /// Clears the pending-recovery flag once this launch has settled it — either
  /// by recovering, or by proving there is nothing to recover. Called on every
  /// non-throwing path so a stuck flag cannot force a salvage every launch.
  final Future<void> Function() _clearPendingCorruptionRecovery;

  /// Records a startup DB recovery (salvage or wipe) as a non-fatal so the
  /// corruption rate — and a device recovering on every launch — is observable
  /// in Crashlytics. Recovery succeeds silently otherwise: it does not throw,
  /// so it never reaches the startup error reporter. Best-effort; `null` in
  /// tests that don't assert on it.
  final Future<void> Function(Object error, StackTrace stack)? _recordRecovery;

  /// Persists the completed outcome so a later support report can identify it
  /// after startup logs have rolled out of the in-memory window.
  final Future<void> Function(DatabaseRecoveryOutcome outcome)?
  _persistRecoveryOutcome;

  /// Invoked after the key-loss recreate wipes the Drift DB, so callers can
  /// clear local state that lives OUTSIDE the database (e.g. the DM sync
  /// cursors / `historyDrainComplete` flag in SharedPreferences). Without this
  /// the next inbox open would skip the full DM re-drain ("already complete")
  /// and leave recovered chats stranded under "Message requests". See #5304.
  final Future<void> Function()? _onDatabaseReset;

  static const _logName = 'DatabaseEncryptionBootstrap';

  /// Resolves the cipher key for the database provider, or `null` when the
  /// database should open unencrypted.
  ///
  /// Returns `null` for web (native DB encryption is out of scope, #373) and when a
  /// populated plaintext database could not be migrated this launch (the
  /// migration left it intact and retries on the next launch).
  ///
  /// Throws:
  ///
  /// * [DatabaseCipherUnavailableError] when SQLite3MultipleCiphers is not the
  ///   active SQLite build — a build misconfiguration that must fail loudly
  ///   rather than silently ship an unencrypted database.
  /// * [DatabaseCipherStorageUnavailableException] when the keystore holding
  ///   the cipher key cannot be read or written, or cannot be trusted to have
  ///   shown it, most often a launch before the device's first unlock. Raised
  ///   by the Keychain backends only — see the platform note on that class.
  /// * [DatabaseUnreadableError] when the database file is structurally
  ///   corrupt. Distinct from the deferral above: that one hands back a `null`
  ///   key for a database that genuinely is readable plaintext, this one has no
  ///   readable database to hand a key for.
  /// * [DatabaseClassificationException] when SQLite could not safely identify
  ///   the existing file format. Startup fails closed and preserves both the
  ///   database and cipher key for a later retry.
  /// * [DatabaseHotJournalRecoveryError] when SQLite found a rollback journal
  ///   but could not safely replay and validate it under the existing key.
  ///
  /// Must run before the first `AppDatabase` open.
  Future<String?> resolveCipherKey() async {
    final (key, settledRecovery) = await _resolveCipherKey();
    // Only clear once this launch has actually settled the flag: it either
    // salvaged/recreated, or established there was nothing to recover. A throw
    // skips this so the flag survives for the retry, and so does a deferred
    // migration, which leaves the database untouched for the next launch.
    if (settledRecovery) {
      await _clearPendingCorruptionRecovery();
    }
    return key;
  }

  /// Resolves the key, and reports whether this launch settled the
  /// pending-corruption flag — i.e. whether the database it hands back is one
  /// recovery has finished with.
  Future<(String? key, bool settledRecovery)> _resolveCipherKey() async {
    // Web never opens an encrypted database, so there is nothing to recover
    // and nothing that could have set the flag.
    if (kIsWeb) return (null, true);

    await _ensureRuntime();
    if (!_isCipherAvailable()) {
      throw DatabaseCipherUnavailableError();
    }

    final (key, wasGenerated) = await _readOrCreateKey();
    final outcome = await _migrate(key);

    switch (outcome) {
      case CipherMigrationOutcome.noDatabase:
      case CipherMigrationOutcome.removedEmptyPlaintext:
      case CipherMigrationOutcome.migrated:
        return (key, true);
      case CipherMigrationOutcome.alreadyEncrypted:
        if (wasGenerated) {
          return (
            await _recoverUnusableEncryptedDatabase(key, reason: 'missing'),
            true,
          );
        }
        // A runtime corruption report from a previous session bypasses the
        // probe: it is reactive by design and already failed to see this
        // corruption once, so asking it again would just clear the database and
        // strand the user on it for another session.
        if (!await _hasPendingCorruptionRecovery() &&
            await _canOpenEncryptedDatabase(key)) {
          return (key, true);
        }
        // The key either no longer opens the DB (stale) or opens it but
        // on-disk corruption surfaced when the Drift startup cleanup ran. Before
        // the destructive wipe, try to salvage the local-only data (drafts,
        // clips, pending queues) into a fresh DB rebuilt in place under the SAME
        // key. Local-only data cannot be re-fetched from relays, so preserving
        // it matters. Salvage returns false on key loss (nothing decryptable)
        // or a failure to rebuild a sound copy; the wipe below handles both.
        if (await _salvageDatabase(key)) {
          Log.warning(
            'Recovered a corrupt encrypted database by salvaging local-only '
            'data into a fresh database; the corrupt file was backed up. DMs '
            'and relay-backed caches resync.',
            name: _logName,
          );
          await _reportRecovery('salvaged local-only data into a fresh DB');
          await _persistOutcome(DatabaseRecoveryOutcome.salvaged);
          await _runPostDatabaseReset(_onDatabaseReset);
          return (key, true);
        }
        // Salvage failed. Only rotate the cipher key when it genuinely cannot
        // decrypt the file: rotating a still-valid key would overwrite the only
        // key that can read the `.pre_key_loss_wipe_backup` we are about to
        // create, silently breaking the "backup stays readable" guarantee. A
        // decryptable-but-unsalvageable DB (transient salvage failure, or a
        // rebuilt copy that failed its own integrity check) is recreated under
        // the SAME key so the backup stays recoverable.
        if (await _encryptedKeyMatches(key)) {
          return (
            await _recoverUnusableEncryptedDatabase(
              key,
              reason: 'corrupt and unsalvageable (key still valid)',
            ),
            true,
          );
        }
        final replacementKey = generateCipherKeyHex();
        await _writeCipherKey(replacementKey);
        return (
          await _recoverUnusableEncryptedDatabase(
            replacementKey,
            reason: 'key loss',
          ),
          true,
        );
      case CipherMigrationOutcome.failed:
        Log.warning(
          'At-rest DB migration did not complete; opening plaintext this '
          'launch and retrying next launch.',
          name: _logName,
        );
        // The database is left exactly as it was for the next launch to retry,
        // so nothing was settled. Preserving the flag matters: a corruption
        // report that arrived while the migration was deferred is the only
        // signal that forces the salvage once the retry finally classifies the
        // file as encrypted.
        return (null, false);
      case CipherMigrationOutcome.unreadable:
        // Deliberately NOT the deferral above: the file is structurally
        // corrupt, so returning `null` would open an unusable database and
        // break every statement for the whole session — the exact
        // silent-null-key state #5301 forbids — and the outcome is a property
        // of the bytes, so no later launch recovers on its own. Fail closed
        // instead; the startup failure screen offers the reset. See #6897.
        throw const DatabaseUnreadableError();
    }
  }

  Future<(String, bool)> _readOrCreateKey() async {
    final existing = await _readCipherKey(
      _secureStorage,
      dbCipherKeyStorageKey,
    );
    if (existing != null) {
      if (_isValidCipherKey(existing)) return (existing, false);
      return (await _createKey(), true);
    }

    final legacy = await _readCipherKey(
      _legacySecureStorage,
      legacyDbCipherKeyStorageKey,
    );
    if (legacy != null && _isValidCipherKey(legacy)) {
      await _migrateLegacyCipherKey(legacy);
      return (legacy, false);
    }
    // Both slots read back empty. Only a keystore that could have answered
    // makes that a fresh install rather than a key it refused to hand over.
    if (legacy == null) await _requireReadableKeystore();
    return (await _createKey(), true);
  }

  Future<String> _createKey() async {
    final key = generateCipherKeyHex();
    await _writeCipherKey(key);
    return key;
  }

  /// Moves a key stored before #9343 into [dbCipherKeyStorageKey] under the
  /// current options — on iOS from `unlocked` to `first_unlock_this_device`.
  ///
  /// Write first, delete second: a launch that dies in between finds the
  /// migrated key next time and only leaves the stale copy behind. The delete
  /// is best-effort for the same reason — the key is already in its new slot,
  /// so a leftover copy under the old accessibility cannot fail a launch.
  Future<void> _migrateLegacyCipherKey(String key) async {
    await _writeCipherKey(key);
    try {
      await _legacySecureStorage.delete(key: legacyDbCipherKeyStorageKey);
    } on Object catch (error) {
      Log.warning(
        'Migrated the DB cipher key to its new keystore slot but could not '
        'remove the old copy (non-fatal): $error',
        name: _logName,
      );
    }
  }

  /// Refuses to treat an empty keystore as a fresh install while the platform
  /// cannot decrypt `unlocked`-class data.
  ///
  /// On the Keychain backends an item the current device state cannot decrypt
  /// reads back as `null`, not as a throw: `flutter_secure_storage`'s iOS
  /// `read` drops the `errSecInteractionNotAllowed` (-25308) status when it
  /// retries the query as synchronizable, and that retry reports "not found".
  /// So before the device's first unlock — or, for a key not yet migrated off
  /// the `unlocked` class, whenever the device is locked — an absent key is
  /// indistinguishable from one that is merely locked away. Generating a
  /// replacement then would strand the database the real key opens (#9343).
  ///
  /// Throws [DatabaseCipherStorageUnavailableException] in that state; the
  /// launch fails closed and the next unlocked launch reads the key as usual.
  /// A `null` probe means the platform has no protected-data notion (Android,
  /// web), where a `null` read has to be trusted — see the platform note on
  /// [DatabaseCipherStorageUnavailableException].
  Future<void> _requireReadableKeystore() async {
    if (await _isProtectedDataAvailable() ?? true) return;
    throw DatabaseCipherStorageUnavailableException(
      const ProtectedDataUnavailableException(),
    );
  }

  /// The default probe, iOS only. macOS also answers
  /// `isCupertinoProtectedDataAvailable` (macOS 12+), but its key stays on the
  /// `unlocked` class (#5563), a Mac app never launches while the login
  /// session is locked, and a wrong `false` there would fail every fresh
  /// install closed for good — so macOS trusts a `null` read as it always has.
  static Future<bool?> _iosProtectedDataAvailable(
    FlutterSecureStorage storage,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    return storage.isCupertinoProtectedDataAvailable();
  }

  /// Reads the stored cipher key, translating a platform secure-storage
  /// failure into [DatabaseCipherStorageUnavailableException].
  ///
  /// Rethrows rather than degrading a failed read into "no key stored": the
  /// caller would generate a replacement and overwrite the only key that can
  /// open the existing database. Covers failures that surface as a thrown
  /// platform error; the ones that surface as `null` are caught by
  /// [_requireReadableKeystore] instead.
  Future<String?> _readCipherKey(
    FlutterSecureStorage storage,
    String storageKey,
  ) async {
    try {
      return await storage.read(key: storageKey);
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(
        DatabaseCipherStorageUnavailableException(error),
        stack,
      );
    }
  }

  Future<void> _writeCipherKey(String key) async {
    try {
      await _secureStorage.write(key: dbCipherKeyStorageKey, value: key);
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(
        DatabaseCipherStorageUnavailableException(error),
        stack,
      );
    }
  }

  Future<String> _recoverUnusableEncryptedDatabase(
    String key, {
    required String reason,
  }) async {
    // Terminal recovery (#570 §6): the DB could not be used and could not be
    // salvaged. It is backed up (not hard-deleted) and recreated under [key] —
    // which the caller has either rotated (genuine key loss) or kept unchanged
    // (decryptable-but-unsalvageable corruption, so the backup stays readable).
    // Local-only data is preserved in the backup; DMs resync from relays.
    Log.warning(
      'Encrypted database is unrecoverable ($reason). Backing it up and '
      'recreating.',
      name: _logName,
    );
    await _deleteDatabase();
    await _reportRecovery('backed up + recreated ($reason)');
    await _persistOutcome(switch (reason) {
      'missing' => DatabaseRecoveryOutcome.recreatedMissingKey,
      'key loss' => DatabaseRecoveryOutcome.recreatedKeyLoss,
      _ => DatabaseRecoveryOutcome.recreatedCorrupt,
    });
    await _runPostDatabaseReset(_onDatabaseReset);
    return key;
  }

  /// Records a recovery as a non-fatal Crashlytics event. Best-effort: a
  /// reporting failure must never fail startup now that recovery has succeeded.
  Future<void> _reportRecovery(String reason) async {
    try {
      await _recordRecovery?.call(
        DatabaseRecoveryEvent(reason),
        StackTrace.current,
      );
    } on Object catch (e) {
      Log.warning('Recovery reporting failed (non-fatal): $e', name: _logName);
    }
  }

  Future<void> _persistOutcome(DatabaseRecoveryOutcome outcome) async {
    try {
      await _persistRecoveryOutcome?.call(outcome);
    } on Object catch (error) {
      Log.warning(
        'Recovery outcome persistence failed (non-fatal): $error',
        name: _logName,
      );
    }
  }
}

/// Non-fatal marker recorded to Crashlytics when the startup DB recovery runs
/// (salvage or wipe), so the corruption/recovery rate — and a device recovering
/// on every launch — is observable. Not a programming error; it carries only
/// the recovery [reason] and never embeds key material or DB contents.
class DatabaseRecoveryEvent implements Exception {
  DatabaseRecoveryEvent(this.reason);

  final String reason;

  @override
  String toString() => 'DatabaseRecoveryEvent: $reason';
}

/// Thrown when the platform secure storage holding the DB cipher key cannot be
/// read or written during startup.
///
/// The key material is intact and only unreachable right now. The common cause
/// is a launch while the device is still locked — a push, a background fetch
/// or a prewarmed launch before the first unlock after boot — where the
/// Keychain refuses the read. The refusal surfaces either as a thrown platform
/// error or, because the iOS plugin drops the status on its read path, as a
/// `null` read while protected data is unavailable; [cause] is then a
/// [ProtectedDataUnavailableException].
///
/// Distinct from a corrupt or key-mismatched database, and deliberately NOT
/// repairable by clearing the local cache: that path deletes the cipher key
/// this error merely failed to reach, turning a transient lock into permanent
/// data loss. See [shouldRepairLocalDatabaseCacheAfterBootstrapError].
///
/// Platform note: only the Keychain backends (iOS, macOS) reach this type —
/// they either throw, or report protected data unavailable next to a `null`
/// read. Android's `encryptedSharedPreferences` backend falls back to
/// plaintext preferences when the keystore cannot be initialised and reads
/// back `null` with no availability signal, which this bootstrap cannot tell
/// apart from a fresh install.
class DatabaseCipherStorageUnavailableException implements Exception {
  DatabaseCipherStorageUnavailableException(this.cause);

  /// The underlying platform failure, typically a `PlatformException` raised by
  /// `flutter_secure_storage`.
  final Object cause;

  @override
  String toString() =>
      'DatabaseCipherStorageUnavailableException: '
      'secure storage is unavailable ($cause)';
}

/// The [DatabaseCipherStorageUnavailableException.cause] recorded when both
/// cipher-key slots read back empty while the device has not been unlocked
/// since boot, so the bootstrap refused to generate a replacement key.
///
/// Not a platform error: the Keychain reported nothing wrong, it merely could
/// not be trusted to have shown an existing item. Named separately so a
/// Crashlytics reader can tell this refusal from a `-25308` that the platform
/// did raise.
class ProtectedDataUnavailableException implements Exception {
  const ProtectedDataUnavailableException();

  @override
  String toString() =>
      'ProtectedDataUnavailableException: the cipher key read back empty '
      'while protected data was unavailable (device locked), so an absent '
      'key cannot be told apart from one the Keychain refused to read; '
      'refusing to generate a replacement';
}

/// Thrown when the local database file exists but is structurally corrupt: a
/// legible SQLite header over pages that fail with `SQLITE_CORRUPT`, so the file
/// is neither usable plaintext nor recognizably encrypted.
///
/// Not a key problem — an encrypted file reports `SQLITE_NOTADB` and takes the
/// salvage/recreate path instead. The stored cipher key is nonetheless kept
/// because nothing here proves it stale; the reset path decides what to do with
/// the damaged plaintext-shaped file.
///
/// Fails startup on purpose. The alternative the bootstrap used to take was to
/// hand back a `null` key and let the app open the damaged file anyway, which
/// looked like a normal launch and then failed every statement in the session
/// (#6897). Because the outcome depends only on the bytes on disk, the "retry
/// next launch" that the deferral promises never arrives.
class DatabaseUnreadableError implements Exception {
  const DatabaseUnreadableError();

  /// Names `SQLITE_CORRUPT` so a Crashlytics reader sees the underlying result
  /// code without the statement that raised it. That also puts this message
  /// inside the corruption allowlist in
  /// [shouldRepairLocalDatabaseCacheAfterBootstrapError], which is why that
  /// function has to deny this type before it reaches the message match.
  @override
  String toString() =>
      'DatabaseUnreadableError: the local database is damaged beyond '
      'classification (SQLITE_CORRUPT under a legible SQLite header); it is '
      'neither readable plaintext nor an encrypted database.';
}

class DatabaseCipherUnavailableError extends StateError {
  DatabaseCipherUnavailableError()
    : super(
        'SQLite3MultipleCiphers is not active; refusing to start with an '
        'unencrypted local database. Verify package:sqlite3 hooks select '
        'sqlite3mc and no dependency links plain sqlite3.',
      );
}

/// Resolves the startup DB cipher key and fails closed on bootstrap errors.
///
/// Native app startup must not continue with a `null` cipher key after a
/// secure-storage or cipher bootstrap failure: an existing encrypted DB
/// would be opened as plaintext and repeatedly surface SQLITE_NOTADB. Web and
/// intentional plaintext migration deferrals still return `null` from
/// [resolveCipherKey] — but only when the plaintext database is actually
/// readable; a damaged one throws [DatabaseUnreadableError] rather than
/// inheriting that carve-out (#6897).
Future<String?> resolveStartupDatabaseCipherKey({
  required Future<String?> Function() resolveCipherKey,
  required Future<void> Function(Object error, StackTrace stack) recordError,
}) async {
  try {
    return await resolveCipherKey();
  } catch (error, stack) {
    try {
      await recordError(error, stack);
    } catch (_) {
      // Startup still needs to fail with the bootstrap root cause even if
      // telemetry is unavailable during early app initialization.
    }
    Error.throwWithStackTrace(error, stack);
  }
}

bool _isValidCipherKey(String value) =>
    RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);

const _sqliteCorrupt = 11;
const _sqliteNotADb = 26;

/// Returns whether a startup bootstrap failure is safe to repair by backing up
/// the local encrypted DB cache and retrying once.
///
/// Keep this as an allowlist. Secure-storage, SQLite3MultipleCiphers linkage,
/// and other transient startup failures must fail closed because deleting or
/// rotating the DB cipher key can make an otherwise recoverable encrypted DB
/// unusable.
bool shouldRepairLocalDatabaseCacheAfterBootstrapError(Object error) {
  if (error is DatabaseCipherUnavailableError) return false;
  if (error is DatabaseClassificationException) return false;
  if (error is DatabaseHotJournalRecoveryError) return false;
  // The database is fine; only the keystore holding its key was unreachable.
  // Repairing would delete that key and strand a recoverable database.
  if (error is DatabaseCipherStorageUnavailableException) return false;
  // Load-bearing: this message names SQLITE_CORRUPT, so it would otherwise
  // match the allowlist below and auto-repair. The database really is unusable,
  // but the repair rotates the cipher key, and nothing here proves the stored
  // one is stale. The failure screen offers a diagnosis-aware reset instead, so
  // the user chooses the data loss instead of a silent wipe on a launch that
  // looked normal.
  if (error is DatabaseUnreadableError) return false;

  final message = error.toString();
  return message.contains('SqliteException($_sqliteNotADb)') ||
      message.contains('SqliteException($_sqliteCorrupt)') ||
      message.contains('SQLITE_NOTADB') ||
      message.contains('SQLITE_CORRUPT') ||
      message.contains('database disk image is malformed') ||
      message.contains('file is not a database');
}

/// Backs up the encrypted local database cache so the next bootstrap creates a
/// fresh one.
///
/// [deleteCipherKey] additionally removes the DB cipher key (and nothing else
/// from the keystore) from both of its slots — the current one through
/// [secureStorage] and the pre-#9343 one through [legacySecureStorage], which
/// on iOS is the only instance whose delete query matches that item. Pass
/// `false` when the caller cannot prove the stored key is stale: the backup
/// this call leaves behind is encrypted under that key, so deleting it makes
/// the backup permanently unreadable — while a retained key opens a fresh
/// database just as well as a rotated one.
///
/// [deleteDatabase] overrides that backup step. Callers that have proved the
/// file is plaintext-shaped pass [deleteSharedDatabase] via
/// [resetUnreadablePlaintextDatabaseCache], which leaves no backup at all.
Future<void> resetEncryptedDatabaseCache({
  required FlutterSecureStorage secureStorage,
  required FlutterSecureStorage legacySecureStorage,
  bool deleteCipherKey = true,
  Future<void> Function()? deleteDatabase,
  Future<void> Function()? onDatabaseReset,
  DatabaseRecoveryOutcome? recoveryOutcome,
  Future<void> Function(DatabaseRecoveryOutcome outcome)?
  persistRecoveryOutcome,
}) async {
  await (deleteDatabase ?? backUpAndRemoveSharedDatabase)();
  if (deleteCipherKey) {
    await secureStorage.delete(key: dbCipherKeyStorageKey);
    await legacySecureStorage.delete(key: legacyDbCipherKeyStorageKey);
  }
  if (recoveryOutcome != null) {
    try {
      await persistRecoveryOutcome?.call(recoveryOutcome);
    } on Object catch (error) {
      Log.warning(
        'Manual recovery outcome persistence failed (non-fatal): $error',
        name: DatabaseEncryptionBootstrap._logName,
      );
    }
  }
  await _runPostDatabaseReset(onDatabaseReset);
}

/// Deletes an unreadable plaintext-shaped database without preserving it.
///
/// [DatabaseUnreadableError] proves the current file is not an encrypted DB:
/// it has a legible SQLite header and structural corruption. Backing it up under
/// the key-loss suffix would leave plaintext at rest after the reset, so this
/// path keeps the cipher key but hard-deletes the database and sidecars.
Future<void> resetUnreadablePlaintextDatabaseCache({
  required FlutterSecureStorage secureStorage,
  required FlutterSecureStorage legacySecureStorage,
  @visibleForTesting Future<void> Function()? deleteDatabase,
  Future<void> Function()? onDatabaseReset,
  Future<void> Function(DatabaseRecoveryOutcome outcome)?
  persistRecoveryOutcome,
}) => resetEncryptedDatabaseCache(
  secureStorage: secureStorage,
  legacySecureStorage: legacySecureStorage,
  deleteCipherKey: false,
  deleteDatabase: deleteDatabase ?? deleteSharedDatabase,
  onDatabaseReset: onDatabaseReset,
  recoveryOutcome: DatabaseRecoveryOutcome.recreatedUnreadable,
  persistRecoveryOutcome: persistRecoveryOutcome,
);

Future<void> _runPostDatabaseReset(
  Future<void> Function()? onDatabaseReset,
) async {
  // The Drift DB is now empty but SharedPreferences survives, so the DM sync
  // cursors / `historyDrainComplete` flag would make the next inbox open skip
  // the full re-drain and strand recovered chats under "Message requests".
  // Clear DM sync state so recovery re-runs against the fresh DB. See #5304.
  //
  // Best-effort: a SharedPreferences IO failure here only re-strands requests
  // (itself healed by the drain-version bump) and must not escalate into a hard
  // cipher-key-resolution failure now that the DB has already been recreated.
  try {
    await onDatabaseReset?.call();
  } on Object catch (e) {
    Log.warning(
      'Post-recreate DM sync-state reset failed (non-fatal): $e',
      name: DatabaseEncryptionBootstrap._logName,
    );
  }
}

/// Generates a 64-character hex (raw 32-byte) cipher key from a CSPRNG.
///
/// Uses [Random.secure]; the key is never logged or derived from anything
/// guessable.
@visibleForTesting
String generateCipherKeyHex() {
  final rng = Random.secure();
  final bytes = Uint8List(32);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
