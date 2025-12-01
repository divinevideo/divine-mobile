// ABOUTME: Platform-agnostic database connection interface
// ABOUTME: Uses conditional imports to select native or web implementation

import 'package:drift/drift.dart';

// Conditional imports - compiler will choose the correct one based on platform

/// Open a database connection appropriate for the current platform
/// - Native platforms (iOS, Android, macOS, etc.): File-based SQLite
/// - Web platform: IndexedDB
QueryExecutor openConnection() => openConnection();

/// Get the database path/name appropriate for the current platform
/// - Native platforms: File system path
/// - Web platform: IndexedDB database name
Future<String> getSharedDatabasePath() => getSharedDatabasePath();
