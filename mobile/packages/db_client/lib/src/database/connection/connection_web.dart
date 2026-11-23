// ABOUTME: Web database connection through Drift's WasmDatabase: SQLite in a
// ABOUTME: Web Worker on OPFS or IndexedDB, in memory when neither is usable

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
/// Uses [WasmDatabase.open], which hosts SQLite in a Web Worker on OPFS or
/// IndexedDB when the browser allows it and otherwise falls back to an
/// in-memory database on the main thread that does not survive a reload.
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

/// On web, returns the Drift database name: an OPFS directory or an IndexedDB
/// database, whichever [WasmDatabase.open] picked.
Future<String> getSharedDatabasePath() async {
  return 'divine_db';
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
