// ABOUTME: Web database connection through Drift's WasmDatabase: SQLite in a
// ABOUTME: Web Worker on OPFS or IndexedDB, in memory when neither is usable

import 'dart:js_interop';

import 'package:db_client/src/database/connection/legacy_web_database_snapshot.dart';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

@JS('window.localStorage')
external _WebStorage? get _localStorage;

extension type _WebStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void removeItem(String key);
}

const _databaseName = 'divine_db';
const _legacyDataKey = 'moor_db_str_$_databaseName';
const _legacyVersionKey = 'moor_db_version_$_databaseName';

// web/_headers serves *.wasm as immutable for a year, so the URL carries the
// sqlite3 version: otherwise a returning browser reuses an older wasm that the
// current drift_worker.js cannot link. update_web_sqlite_assets.sh rewrites it.
// The worker URL stays fixed so every tab shares one drift worker.
const _sqlite3Wasm = 'sqlite3.wasm?v=3.3.4';

/// Open a database connection for web platform.
///
/// Hosts SQLite in a worker when browser support allows it. The legacy SQLite
/// file includes local writes such as queued DMs, not just relay-backed cache.
QueryExecutor openConnection({Uri? assetBase}) {
  return DatabaseConnection.delayed(
    Future(() async {
      final probe = await WasmDatabase.probe(
        databaseName: _databaseName,
        sqlite3Uri: assetBase?.resolve(_sqlite3Wasm) ?? Uri.parse(_sqlite3Wasm),
        driftWorkerUri:
            assetBase?.resolve('drift_worker.js') ??
            Uri.parse('drift_worker.js'),
      );
      // Preserve Drift's usual preference for any existing durable database.
      final available = WasmStorageImplementation.values.where(
        probe.availableStorages.contains,
      );
      final selected = available.firstWhere(
        (mode) =>
            probe.existingDatabases.contains((mode.storageApi, _databaseName)),
        orElse: () =>
            available.firstOrNull ?? WasmStorageImplementation.inMemory,
      );
      if (selected.storageApi == null) {
        // Importing into memory would replay the old outbox on every reload.
        return probe.open(selected, _databaseName);
      }

      final migration = _LegacyDatabaseMigration();
      final connection = await probe.open(
        selected,
        _databaseName,
        initializeDatabase: migration.restore,
      );
      return connection.interceptWith(migration);
    }),
  );
}

class _LegacyDatabaseMigration extends QueryInterceptor {
  String? _importedSnapshot;
  String? _importedVersion;

  Uint8List? restore() {
    try {
      final storage = _localStorage;
      final snapshot = storage?.getItem(_legacyDataKey);
      if (snapshot == null) return null;
      final version = storage?.getItem(_legacyVersionKey);
      final bytes = decodeLegacyWebDatabaseSnapshot(snapshot, version);
      _importedSnapshot = snapshot;
      _importedVersion = version;
      return bytes;
    } on Object catch (_) {
      // Storage may be inaccessible in restricted contexts. Leave it untouched.
      return null;
    }
  }

  @override
  Future<bool> ensureOpen(
    QueryExecutor executor,
    QueryExecutorUser user,
  ) async {
    final opened = await executor.ensureOpen(user);
    final snapshot = _importedSnapshot;
    if (opened && snapshot != null) {
      _importedSnapshot = null;
      try {
        final storage = _localStorage;
        // Do not remove a snapshot another tab replaced during the upgrade.
        if (storage != null &&
            storage.getItem(_legacyDataKey) == snapshot &&
            storage.getItem(_legacyVersionKey) == _importedVersion) {
          storage
            ..removeItem(_legacyDataKey)
            ..removeItem(_legacyVersionKey);
        }
      } on Object catch (_) {
        // The new database is open; cleanup can fail if access was revoked.
      }
    }
    return opened;
  }
}

/// On web, returns the Drift database name: an OPFS directory or an IndexedDB
/// database, whichever [WasmDatabase.open] picked.
Future<String> getSharedDatabasePath() async {
  return _databaseName;
}

/// Native at-rest encryption is unsupported on web.
///
/// Web at-rest encryption is not implemented. The app guards encryption with
/// `kIsWeb`, so this is never reached at runtime — it exists only so app code
/// compiles for web. See the native variant.
QueryExecutor openEncryptedConnection({
  required String rawKeyHex,
  String? databasePath,
}) {
  throw UnsupportedError(
    'Native at-rest encryption is not supported on web',
  );
}

/// Web never opens native encrypted databases; startup skips DB encryption
/// there.
Future<bool> encryptedDatabaseOpensWithKey({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError(
    'Native at-rest encryption is not supported on web',
  );
}

/// The web app does not access native Mac database paths.
Future<bool> hasAlternateMacOsSharedDatabase() async => false;

/// Startup skips native database encryption on web.
Future<bool> encryptedDatabaseKeyDecrypts({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError(
    'Native at-rest encryption is not supported on web',
  );
}

/// Corruption salvage is native-only; startup skips DB encryption on web.
/// Never reached at runtime (guarded by `kIsWeb` in the app).
Future<bool> salvageCorruptEncryptedDatabase({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError(
    'Native at-rest encryption is not supported on web',
  );
}

/// No-op on web (key-loss recovery is native-only). Never reached at runtime.
Future<void> backUpAndRemoveSharedDatabase() async {}

/// No-op on web (native database deletion is native-only). Never reached at
/// runtime.
Future<void> deleteSharedDatabase() async {}

/// Outcome of [migratePlaintextToEncrypted]. Mirrors the native enum so app
/// code that switches on it compiles for web.
enum CipherMigrationOutcome {
  noDatabase,
  alreadyEncrypted,
  encryptedButCorrupt,
  removedEmptyPlaintext,
  migrated,
  failed,
  unreadable,
}

enum DatabaseClassificationStage { openDatabase, readSchema }

class DatabaseClassificationException implements Exception {
  const DatabaseClassificationException({
    required this.stage,
    required this.resultCode,
    required this.extendedResultCode,
  });

  final DatabaseClassificationStage stage;
  final int resultCode;
  final int extendedResultCode;
}

/// Native plaintext→encrypted migration does not apply on web. Never reached
/// at runtime (guarded by `kIsWeb` in the app).
Future<CipherMigrationOutcome> migratePlaintextToEncrypted({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError(
    'Native at-rest encryption is not supported on web',
  );
}
