// ABOUTME: Provides singleton AppDatabase instance with proper lifecycle management
// ABOUTME: Database auto-closes when provider container is disposed

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/database/app_database.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true) // Singleton - lives for app lifetime
AppDatabase database(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
}
