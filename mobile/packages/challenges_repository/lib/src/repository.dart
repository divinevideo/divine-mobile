part of '../challenges_repository.dart';

/// Reduces bounded retained signed records using the current visibility policy.
final class ChallengesRepository {
  /// Creates a repository with no production adapter assumptions.
  ChallengesRepository({
    required this.source,
    required this.store,
    required this.clock,
    required this.isVisible,
    this.limits = const ReadLimits(),
  });

  /// Raw read boundary.
  final ChallengeReadSource source;

  /// Durable retained replay boundary.
  final RetainedChallengeStore store;

  /// Unix seconds.
  final int Function() clock;

  /// Current policy, including deletion/blocking and media availability.
  final bool Function(NostrEvent) isVisible;

  /// Bounds before JSON parsing, including retained replay.
  final ReadLimits limits;
  Future<void> _tail = Future<void>.value();

  /// Refreshes known-coordinate state.
  Future<ChallengeRead> refresh(String coordinate) {
    final result = _tail.then((_) => _refresh(coordinate));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ChallengeRead> _refresh(String coordinate) async {
    var observation = RawChallengeRead(
      records: const [],
      source: ReadSource.indexedApi,
      completeness: ReadCompleteness.unavailable,
    );
    try {
      observation = await source(coordinate);
      if (!limits.accepts(observation.records)) {
        return _unavailable(coordinate, observation);
      }
      final retained = await store.load(coordinate);
      final merged = {...retained, ...observation.records}.toList();
      if (!limits.accepts(merged)) return _unavailable(coordinate, observation);
      // Decode independently so non-event wire input cannot permanently poison
      // retained replay. Keep JSON objects even when challenge parsing fails:
      // authenticated malformed replacements must invalidate older open rules.
      final decoded = <String, Map<String, Object?>>{};
      for (final body in merged) {
        try {
          final value = jsonDecode(body);
          if (value is Map<String, Object?>) decoded[body] = value;
        } on FormatException {
          // Ignore malformed JSON, including legacy persisted junk records.
        }
      }
      await store.retain(
        coordinate,
        observation.records.where(decoded.containsKey).toList(),
      );
      if (observation.records.any((body) => !decoded.containsKey(body)) ||
          observation.completeness == ReadCompleteness.unavailable) {
        return _unavailable(coordinate, observation);
      }
      return ChallengeRead(
        view: reduceChallenge(
          observation.revisionsComplete ? decoded.values.toList() : const [],
          coordinate,
          clock(),
          isVisible,
        ),
        observation: observation,
      );
    } on Exception {
      return _unavailable(coordinate, observation);
    }
  }

  ChallengeRead _unavailable(String coordinate, RawChallengeRead read) =>
      ChallengeRead(
        view: reduceChallenge(const [], coordinate, clock(), isVisible),
        observation: RawChallengeRead(
          records: const [],
          source: read.source,
          completeness: ReadCompleteness.unavailable,
          indexedAt: read.indexedAt,
        ),
      );
}
