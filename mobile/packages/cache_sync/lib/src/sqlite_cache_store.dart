import 'package:cache_sync/src/cache_dao.dart';
import 'package:cache_sync/src/cache_dao_impl.dart';
import 'package:cache_sync/src/cache_database.dart';
import 'package:cache_sync/src/cache_sync.dart';
import 'package:drift/drift.dart';

/// A caller-owned SQLite cache with an explicit resource lifetime.
///
/// Inject [dao] into [CacheSync.init] to use the existing cache facade with a
/// caller-provided executor, including a real in-memory native database.
/// Stop all cache consumers before awaiting [close]. Reinitializing [CacheSync]
/// with another DAO does not close this store.
final class SqliteCacheStore {
  /// Creates a cache store and takes ownership of [executor].
  ///
  /// [maxSizeBytes] uses the same size limit as [CacheSync.init]. Pass `null`
  /// to disable eviction based on payload size. Closing the store also closes
  /// the supplied executor.
  SqliteCacheStore(
    QueryExecutor executor, {
    int? maxSizeBytes = CacheSync.defaultMaxSizeBytes,
  }) : _database = CacheDatabase.test(executor) {
    _dao = CacheDaoImpl(_database, maxSizeBytes: maxSizeBytes);
  }

  final CacheDatabase _database;
  late final CacheDao _dao;
  Future<void>? _closeFuture;

  /// The real SQLite-backed DAO to inject into [CacheSync.init].
  CacheDao get dao => _dao;

  /// Closes the owned database and executor after cache consumers have stopped.
  ///
  /// Repeated calls await the same closure result, including any failure.
  Future<void> close() => _closeFuture ??= _database.close();
}
