// ABOUTME: Web-specific database connection using IndexedDB
// ABOUTME: Provides web-compatible storage through drift's WASM implementation

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Open a database connection for web platform
/// Uses IndexedDB through drift's web implementation
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: getSharedDatabasePath(),
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return result.resolvedExecutor;
  });
}

/// Get path to shared database file
/// On web, this returns a logical name for IndexedDB
String getSharedDatabasePath() {
  return 'local_relay_db'; // IndexedDB database name
}
