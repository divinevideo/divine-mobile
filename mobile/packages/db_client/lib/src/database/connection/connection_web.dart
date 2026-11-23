// ABOUTME: Web-specific database connection using Drift's WasmDatabase
// ABOUTME: Runs SQLite off the main thread in a Web Worker backed by OPFS/IndexedDB

import 'dart:js_interop';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

@JS('window.localStorage')
external _WebStorage? get _localStorage;

extension type _WebStorage._(JSObject _) implements JSObject {
  external void removeItem(String key);
}

void _clearLegacyLocalStorageDb() {
  try {
    final storage = _localStorage;
    if (storage == null) return;
    // Reclaim localStorage quota left behind by the deprecated drift/web.dart
    // WebDatabase('divine_db') backend, which serialized the entire SQLite file
    // into localStorage on every write.
    storage
      ..removeItem('moor_db_str_divine_db')
      ..removeItem('moor_db_version_divine_db');
  } on Object catch (_) {
    // Best-effort cleanup; ignore storage access errors in restricted contexts.
  }
}

/// Open a database connection for web platform.
///
/// Uses [WasmDatabase.open] with `sqlite3.wasm` and `drift_worker.js` so SQLite
/// runs in a Web Worker backed by OPFS/IndexedDB instead of blocking the UI
/// thread or serializing the whole database into `localStorage`.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    _clearLegacyLocalStorageDb();
    final result = await WasmDatabase.open(
      databaseName: 'divine_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}

/// Get path to shared database file
/// On web, this returns a logical name for IndexedDB
Future<String> getSharedDatabasePath() async {
  return 'divine_db'; // IndexedDB database name
}

/// Native at-rest encryption is unsupported on web.
///
/// Web at-rest encryption is deferred behind the OPFS migration (#373). The
/// app guards encryption with `kIsWeb`, so this is never reached at runtime —
/// it exists only so app code compiles for web. See the native variant.
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

/// Corruption salvage is native-only; startup skips DB encryption on web.
/// Never reached at runtime (guarded by `kIsWeb` in the app).
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
