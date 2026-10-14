import 'package:cache_sync/src/cache_dao.dart';
import 'package:cache_sync/src/cache_entry.dart';

/// In-memory [CacheDao] for use in tests.
class FakeCacheDao implements CacheDao {
  FakeCacheDao({this.maxSizeBytes, DateTime Function()? now})
    : now = now ?? _systemNow;

  /// Clock used for write timestamps and expiry checks. Reassign it in a test
  /// to move time deterministically.
  DateTime Function() now;

  static DateTime _systemNow() => DateTime.now().toUtc();

  /// Maximum total payload size in characters. `null` = unlimited.
  final int? maxSizeBytes;

  final Map<String, _Entry> _store = {};

  @override
  Future<CacheEntry?> readEntry(String key) async {
    final entry = _store[key];
    if (entry == null) return null;
    final expiresAt = entry.expiresAt;
    return CacheEntry(
      payload: entry.payload,
      isStale: expiresAt != null && now().isAfter(expiresAt),
    );
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    final written = now();
    _store[key] = _Entry(
      payload: payload,
      cachedAt: written,
      expiresAt: ttl != null ? written.add(ttl) : null,
    );
    final limit = maxSizeBytes;
    if (limit != null) {
      final total = await totalPayloadBytes();
      if (total > limit) await evictOldest(total - limit);
    }
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deletePrefix(String prefix) async {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<int> totalPayloadBytes() async =>
      _store.values.fold<int>(0, (sum, e) => sum + e.payload.runes.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {
    if (bytesToFree <= 0) return;
    var freed = 0;
    final sorted = _store.entries.toList()
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
    for (final entry in sorted) {
      if (freed >= bytesToFree) break;
      freed += entry.value.payload.runes.length;
      _store.remove(entry.key);
    }
  }

  /// Number of stored entries (for assertions).
  int get length => _store.length;

  /// All stored cache keys (for assertions on key shape).
  Iterable<String> get keys => _store.keys;

  /// Raw payload access that ignores expiry (for assertions).
  String? rawRead(String key) => _store[key]?.payload;
}

/// [CacheDao] test double that can fail individual storage operations.
class ThrowingCacheDao implements CacheDao {
  ThrowingCacheDao({
    this.readPayload,
    this.throwOnRead = false,
    this.throwOnWrite = false,
    this.throwOnDelete = false,
  });

  final String? readPayload;
  final bool throwOnRead;
  final bool throwOnWrite;
  final bool throwOnDelete;

  @override
  Future<CacheEntry?> readEntry(String key) async {
    if (throwOnRead) throw StateError('cache read failed');
    final payload = readPayload;
    return payload == null
        ? null
        : CacheEntry(payload: payload, isStale: false);
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    if (throwOnWrite) throw StateError('cache write failed');
  }

  @override
  Future<void> delete(String key) async {
    if (throwOnDelete) throw StateError('cache delete failed');
  }

  @override
  Future<void> deletePrefix(String prefix) async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

class _Entry {
  _Entry({required this.payload, required this.cachedAt, this.expiresAt});

  final String payload;
  final DateTime? expiresAt;
  final DateTime cachedAt;
}
