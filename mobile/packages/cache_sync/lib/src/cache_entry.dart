import 'package:meta/meta.dart';

/// A cached payload together with whether its TTL has passed.
///
/// A stale entry is still valid data: callers serve it and refresh in the
/// background. The TTL only decides when to refresh, never whether the entry
/// may be shown.
@immutable
class CacheEntry {
  /// Creates a cache entry.
  const CacheEntry({required this.payload, required this.isStale});

  /// The serialized value as written.
  final String payload;

  /// Whether the entry's `expiresAt` deadline has passed.
  final bool isStale;

  @override
  bool operator ==(Object other) =>
      other is CacheEntry &&
      other.payload == payload &&
      other.isStale == isStale;

  @override
  int get hashCode => Object.hash(payload, isStale);

  @override
  String toString() => 'CacheEntry(isStale: $isStale, payload: $payload)';
}
