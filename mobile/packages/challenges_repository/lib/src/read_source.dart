part of '../challenges_repository.dart';

/// Origin of a bounded observation; never publication authority.
enum ReadSource {
  /// Reviewed index adapter.
  indexedApi,

  /// Known challenge relay adapter, not global discovery.
  relay,
}

/// Whether the source delivered the entire requested known-coordinate set.
enum ReadCompleteness {
  /// Complete within the source's coverage.
  complete,

  /// Missing pages, dependencies, or relay responses.
  partial,

  /// No usable current observation.
  unavailable,
}

/// Raw signed JSON strings, copied before callers can mutate the collection.
final class RawChallengeRead {
  /// Creates an observation. Adapters must also bound transport allocations.
  RawChallengeRead({
    required List<String> records,
    required this.source,
    required this.completeness,
    this.indexedAt,
    this.retentionLimited = false,
    bool? revisionsComplete,
  }) : revisionsComplete =
           revisionsComplete ?? completeness == ReadCompleteness.complete,
       records = List.unmodifiable(records);

  /// Whether definition revision retrieval itself is complete. Partial entry
  /// pages retain verified rules only when the adapter sets this explicitly.
  final bool revisionsComplete;

  /// Entry history exceeded local capacity; rules may still be complete.
  final bool retentionLimited;

  /// Untrusted wire records, not index projections.
  final List<String> records;

  /// Where these records were observed.
  final ReadSource source;

  /// Coverage of this response.
  final ReadCompleteness completeness;

  /// Index watermark, separate from relay delivery.
  final int? indexedAt;
}

/// Adapter boundary; production API DTOs belong in funnelcake_api_client.
typedef ChallengeReadSource = Future<RawChallengeRead> Function(
  String coordinate,
);
