/// Controls how CacheSync balances freshness vs. latency.
enum CacheFetchPolicy {
  /// Emit cached data first (if present, fresh or stale), then fetch from the
  /// network and emit the live result.
  cacheAndNetwork,

  /// Return cached data when present and fresh; otherwise fetch from network.
  ///
  /// Unlike [cacheAndNetwork], this never performs a background refresh when
  /// a fresh cached value exists. A stale value is still emitted first and
  /// then refreshed; a missing value goes straight to the fetch.
  cacheFirst,

  /// Return cached data only, including a stale entry.  Never performs a
  /// network call.
  cacheOnly,

  /// Always fetch from the network.  Ignores any cached data.
  networkOnly,
}
