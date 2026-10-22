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
      // Do not prefilter by challenge parse: malformed signed replacements
      // must remain in replay and can invalidate an older open definition.
      await store.retain(coordinate, observation.records);
      final decoded = merged.map<Object?>(jsonDecode).toList();
      if (observation.completeness == ReadCompleteness.unavailable) {
        return _unavailable(coordinate, observation);
      }
      return ChallengeRead(
        view: reduceChallenge(
          observation.revisionsComplete ? decoded : const [],
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
