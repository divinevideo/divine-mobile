// ABOUTME: Stub implementation - should never be used
// ABOUTME: Conditional imports will replace this with native or web version

import 'package:drift/drift.dart';

/// Stub implementation - will be replaced by conditional imports
QueryExecutor openConnection() {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Stub implementation - will be replaced by conditional imports
Future<String> getSharedDatabasePath() async {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Stub implementation - will be replaced by conditional imports
QueryExecutor openEncryptedConnection({
  required String rawKeyHex,
  String? databasePath,
}) {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Stub implementation - will be replaced by conditional imports
Future<bool> encryptedDatabaseOpensWithKey({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Stub implementation - will be replaced by conditional imports
Future<bool> salvageCorruptEncryptedDatabase({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Stub implementation - will be replaced by conditional imports
Future<bool> encryptedDatabaseKeyDecrypts({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Outcome of [migratePlaintextToEncrypted]. Mirrors the native enum so app
/// code that switches on it compiles when only the stub is available.
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

/// Stub implementation - will be replaced by conditional imports
Future<CipherMigrationOutcome> migratePlaintextToEncrypted({
  required String rawKeyHex,
  String? databasePath,
}) async {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Stub implementation - will be replaced by conditional imports
Future<void> backUpAndRemoveSharedDatabase() async {
  throw UnsupportedError('No database implementation found for this platform');
}

/// Stub implementation - will be replaced by conditional imports
Future<void> deleteSharedDatabase() async {
  throw UnsupportedError('No database implementation found for this platform');
}
