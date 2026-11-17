// ABOUTME: Provides singleton AppDatabase instance with proper lifecycle management
// ABOUTME: Database auto-closes when provider container is disposed
// ABOUTME: Also hosts the durable vanished-profile pubkey stream read off Drift
import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/database_corruption_provider.dart';
import 'package:openvine/providers/db_cipher_key_provider.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:openvine/utils/startup_timing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true) // Singleton - lives for app lifetime
AppDatabase database(Ref ref) {
  // In production every container overrides this provider with the shared
  // DeviceScope database (so an account switch never opens a second
  // connection). This factory is the fallback for tests / any container built
  // without a DeviceScope override.
  final cipherKey = ref.watch(dbCipherKeyProvider);
  // A null cipher key leaves the connection uninstrumented — the startup
  // bootstrap only knows how to recover an encrypted database. (#570)
  final corruptionService = cipherKey == null
      ? null
      : ref.watch(databaseCorruptionServiceProvider);
  final db = createAppDatabase(
    cipherKey: cipherKey,
    corruptionService: corruptionService,
  );
  ref.onDispose(db.close);
  return db;
}

/// Opens an [AppDatabase] the same way [database] does, without a container.
///
/// Used by `main()` to construct the single device-lifetime connection that
/// [DeviceScope] shares across container swaps. When [cipherKey] is present an
/// at-rest-encrypted native connection is opened (routed through
/// [corruptionService] when given so a runtime `SQLITE_CORRUPT` schedules a
/// next-launch salvage, #570); otherwise the default connection is used (web,
/// tests, or a deferred migration).
AppDatabase createAppDatabase({
  required String? cipherKey,
  required DatabaseCorruptionService? corruptionService,
}) {
  final executor =
      (cipherKey == null
              ? openConnection()
              : openEncryptedConnection(rawKeyHex: cipherKey))
          .interceptWith(_StartupDatabaseTiming());
  return AppDatabase(
    cipherKey == null || corruptionService == null
        ? executor
        : reportCorruptionFrom(executor, corruptionService.report),
  );
}

/// AppDbClient wrapping the database for NostrClient integration.
/// Enables optimistic caching of Nostr events in the local database.
@Riverpod(keepAlive: true)
AppDbClient appDbClient(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Note: DbClient constructor with generatedDatabase is @visibleForTesting
  // but works correctly for production use
  final dbClient = DbClient(generatedDatabase: db);
  return AppDbClient(dbClient, db);
}

/// Live view of the durable NIP-62 `vanished_profiles` table.
///
/// Housed with the database handle rather than with either consumer: building
/// the profile repository primes it and `profileVanishedProvider` derives from
/// it, so a home owned by either of those files would close an import cycle.
final vanishedProfilePubkeysProvider = StreamProvider<Set<String>>((ref) {
  return ref
      .watch(databaseProvider)
      .vanishedProfilesDao
      .watchAllPubkeys()
      .map((pubkeys) => pubkeys.toSet());
});

/// Times the lazy open (including Drift migrations and cleanup), once per DB.
class _StartupDatabaseTiming extends QueryInterceptor {
  bool _started = false;

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    if (_started) return executor.ensureOpen(user);
    _started = true;
    return traceStartupStage(
      StartupStage.databaseOpen,
      () => executor.ensureOpen(user),
    );
  }
}
