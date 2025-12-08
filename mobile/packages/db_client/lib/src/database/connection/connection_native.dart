// ABOUTME: Native platform database connection using SQLite
// ABOUTME: Provides file-based SQLite storage for iOS, Android, macOS, etc.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Open a database connection for native platforms
/// Uses file-based SQLite through drift's native implementation
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbPath = await getSharedDatabasePath();
    return NativeDatabase(
      File(dbPath),
      logStatements: false, // Disabled - too verbose for production
    );
  });
}

/// Get path to shared database file
///
/// Uses same pattern as nostr_sdk:
/// {appDocuments}/openvine/database/local_relay.db
Future<String> getSharedDatabasePath() async {
  final docDir = await getApplicationDocumentsDirectory();
  return p.join(docDir.path, 'openvine', 'database', 'local_relay.db');
}
