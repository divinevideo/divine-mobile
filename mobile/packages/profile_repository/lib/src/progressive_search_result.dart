// ABOUTME: Per-source provenance types for progressive user search.
// ABOUTME: Lets the bloc/UI distinguish true-empty from any-source-failed.
//
// The repository's `searchUsersProgressive` consults three sources in
// order: local SQLite cache, the Funnelcake REST API, and NIP-50 relay
// search. Each phase records its outcome in a `Map<SearchSource,
// SearchSourceStatus>` that travels with every progressive yield. The
// bloc reads this map to derive `isDegradedEmpty` — the state that drives
// the UI to show a retry affordance instead of a misleading
// "No results found" when every source failed.
//
// See: mobile/docs/PEOPLE_SEARCH.md

import 'package:models/models.dart';

/// Data source consulted by `searchUsersProgressive`.
enum SearchSource {
  /// Local SQLite profile cache. Consulted only on the first page
  /// (offset == 0).
  localCache,

  /// Funnelcake REST API. Consulted on every page; skipped when the
  /// client is configured without a base URL.
  funnelcakeApi,

  /// NIP-50 relay search. Consulted only on the first page
  /// (offset == 0); subject to a fixed query timeout.
  nip50Relay,
}

/// Reason a source failed to produce results.
enum SearchSourceFailureReason {
  /// The source did not respond within its budget (e.g. NIP-50 5 s
  /// query timeout or the bloc's outer stream timeout).
  timeout,

  /// The source threw a network-shaped exception
  /// (HTTP error, connection refused, etc.).
  network,

  /// Any other failure — typically a `StateError` from the WebSocket
  /// layer or an unexpected runtime error.
  other,
}

/// Outcome of consulting a single search source.
sealed class SearchSourceStatus {
  const SearchSourceStatus();
}

/// Source has not yet reported a result.
///
/// Emitted in progressive envelopes for sources the repository has not
/// consulted yet. When the outer stream timeout fires, every entry still
/// in `pending` is promoted to [SearchSourceFailed] with reason
/// [SearchSourceFailureReason.timeout].
class SearchSourcePending extends SearchSourceStatus {
  /// Creates a pending status.
  const SearchSourcePending();
}

/// Source was intentionally not consulted for this query.
///
/// Local cache and NIP-50 are skipped on paginated requests
/// (offset > 0); Funnelcake is skipped when the client is unavailable.
class SearchSourceSkipped extends SearchSourceStatus {
  /// Creates a skipped status.
  const SearchSourceSkipped();
}

/// Source returned a result successfully.
class SearchSourceSuccess extends SearchSourceStatus {
  /// Creates a success status with [resultCount] and [latencyMs].
  const SearchSourceSuccess({
    required this.resultCount,
    required this.latencyMs,
  });

  /// Number of new distinct profiles this source contributed to the
  /// accumulated result set.
  final int resultCount;

  /// Wall-clock latency for the source's call, in milliseconds.
  final int latencyMs;
}

/// Source failed to produce results.
class SearchSourceFailed extends SearchSourceStatus {
  /// Creates a failed status with [reason] and [latencyMs].
  const SearchSourceFailed({required this.reason, required this.latencyMs});

  /// Coarse failure category. Free-form error messages live in logs,
  /// not in this type — keeping the type cheap and PII-free.
  final SearchSourceFailureReason reason;

  /// Wall-clock latency between starting the call and observing the
  /// failure, in milliseconds.
  final int latencyMs;
}

/// One progressive yield from `searchUsersProgressive`.
///
/// Carries both the accumulated deduplicated profile list and the
/// running per-source outcome map. The final yield sets [isComplete]
/// to `true`.
class ProgressiveSearchResult {
  /// Creates a progressive search result snapshot.
  const ProgressiveSearchResult({
    required this.profiles,
    required this.sources,
    required this.isComplete,
    this.nextRestOffset,
    this.restHasMore = false,
    this.usernameOwnerPubkey,
  });

  /// Accumulated, deduplicated, filter+boost-applied profile list.
  final List<UserProfile> profiles;

  /// Outcome of each search source at this snapshot. Progressive
  /// intermediate yields may still contain [SearchSourcePending] for
  /// phases the repository has not reached yet.
  final Map<SearchSource, SearchSourceStatus> sources;

  /// `true` when no further yields will arrive for this query.
  final bool isComplete;

  /// Offset for the next Funnelcake REST page, independent of profiles
  /// contributed by the local cache or NIP-50 relay.
  final int? nextRestOffset;

  /// Whether Funnelcake may have another page.
  final bool restHasMore;

  /// The account the name server says owns the Divine username searched
  /// for, which leads [profiles] when it is listed. Callers that reorder the
  /// results keep it first.
  final String? usernameOwnerPubkey;
}
