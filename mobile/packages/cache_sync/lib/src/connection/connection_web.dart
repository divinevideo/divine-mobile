// ABOUTME: Web-specific database connection for cache_sync.
// ABOUTME: Provides web-compatible storage through drift's WasmDatabase.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a database connection for the web platform.
///
/// Requires two static assets in `mobile/web/` that must match the versions
/// resolved in `mobile/pubspec.lock`:
///   - `sqlite3.wasm`    — github.com/simolus3/sqlite3.dart/releases
///                         tag `sqlite3-<version>` (matches `sqlite3:` lock)
///   - `drift_worker.js` — github.com/simolus3/drift/releases
///                         tag `drift-<version>` (matches `drift:` lock)
///
/// Run `mobile/scripts/update_web_sqlite_assets.sh` to download the correct
/// versions whenever either package is updated.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'cache_sync_db',
      // Versioned because web/_headers caches *.wasm for a year (see the
      // db_client connection); the worker URL stays fixed.
      sqlite3Uri: Uri.parse('sqlite3.wasm?v=3.3.4'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
