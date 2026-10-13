// ABOUTME: Web-specific database connection using IndexedDB
// ABOUTME: Provides web-compatible storage through drift's web implementation

import 'package:drift/drift.dart';
// TODO(any): Migrate from deprecated drift/web.dart https://github.com/divinevideo/divine-mobile/issues/373
// ignore_for_file: deprecated_member_use
import 'package:drift/web.dart';

/// Open a database connection for web platform
/// Uses IndexedDB through drift's web implementation
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    return WebDatabase('divine_db');
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
