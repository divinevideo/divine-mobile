/// A unified stale-while-revalidate cache for divine.
///
/// Usage:
/// ```dart
/// await CacheSync.init();
///
/// final stream = CacheSync.watchOne<MyModel>(
///   key: 'my_key',
///   ttl: const Duration(hours: 1),
///   fetch: () => myApi.load(),
///   fromJson: (s) => MyModel.fromJson(jsonDecode(s)),
///   toJson: (m) => jsonEncode(m.toJson()),
/// );
///
/// stream.listen((result) {
///   if (result.isLive) { /* fresh from network */ }
///   else { /* served from cache */ }
/// });
/// ```
library;

export 'src/cache_dao.dart';
export 'src/cache_fetch_policy.dart';
export 'src/cache_result.dart';
export 'src/cache_sync.dart';
export 'src/sqlite_cache_store.dart';
