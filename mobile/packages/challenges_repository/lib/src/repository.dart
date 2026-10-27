part of '../challenges_repository.dart';

/// Reduces bounded retained signed records using the current visibility policy.
final class ChallengesRepository {
  /// Connects bounded observations and durable retained state to replay.
  ChallengesRepository({
    required this.source,
    required this.store,
    required this.clock,
    required this.isVisible,
    this.limits = const ReadLimits(),
    this.work = _inlineChallengeWork,
  });

  /// Current known-coordinate observation source.
  final ChallengeReadSource source;

  /// Owner-scoped retained authenticated records.
  final RetainedChallengeStore store;

  /// Current Unix seconds.
  final int Function() clock;

  /// Current policy for each signed source and embedded snapshot.
  final bool Function(NostrEvent) isVisible;

  /// Resource bounds for each input and retained batch.
  final ReadLimits limits;

  /// CPU execution boundary; apps use [isolatedChallengeWork].
  final ChallengeWork work;
  Future<void> _tail = Future<void>.value();

  /// Serializes refreshes so retention and policy results cannot race.
  Future<ChallengeRead> refresh(String coordinate) {
    final result = _tail.then((_) => _refresh(coordinate));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ChallengeRead> _refresh(String coordinate) async {
    var observation = RawChallengeRead(
      records: const [],
      source: ReadSource.relay,
      completeness: ReadCompleteness.unavailable,
    );
    try {
      observation = await source(coordinate);
      if (!limits.accepts(observation.records)) {
        return _unavailable(coordinate, observation);
      }
      final retained = await store.load(coordinate);
      // Bound each input independently before verification. Invalid historical
      // junk cannot be persisted again or trusted for deduplication.
      if (!limits.accepts(retained)) {
        return _unavailable(coordinate, observation);
      }
      final fresh = await work(_VerifyJob(observation.records, coordinate).run);
      final merged = await work(
        _VerifyJob([...retained, ...fresh.records], coordinate).run,
      );
      final boundedStore = store is BoundedRetainedChallengeStore
          ? store as BoundedRetainedChallengeStore
          : null;
      var limited =
          !(boundedStore == null) && await boundedStore.isLimited(coordinate);
      final overflow = !limits.accepts(merged.records);
      final durableLimited = limited || overflow;
      limited = durableLimited || observation.retentionLimited;
      var records = merged.records;
      if (overflow) {
        // Keep current signed rules independently from entry history. Capacity
        // exhaustion pauses entry playback/counts, not fresh rules retrieval.
        final selected = <String>[];
        for (final body in records) {
          if (limits.accepts([...selected, body])) selected.add(body);
        }
        records = selected;
      }
      if (boundedStore != null) {
        await boundedStore.replace(
          coordinate,
          records,
          limited: durableLimited,
        );
      } else {
        await store.retain(coordinate, fresh.records);
      }
      if (fresh.invalidInput ||
          observation.completeness == ReadCompleteness.unavailable) {
        return _unavailable(coordinate, observation);
      }
      observation = RawChallengeRead(
        records: observation.records,
        source: observation.source,
        completeness: limited
            ? ReadCompleteness.partial
            : observation.completeness,
        revisionsComplete: observation.revisionsComplete,
        indexedAt: observation.indexedAt,
        retentionLimited: limited,
      );
      final events = !observation.revisionsComplete
          ? <NostrEvent>[]
          : limited
          ? merged.events.where((e) => e.kind == 31923).toList()
          : merged.events;
      // Policy is evaluated on the app isolate immediately before and after
      // worker execution. An intervening hide never grants playback permission.
      for (var attempt = 0; attempt < 3; attempt++) {
        final hidden = {
          for (final e in merged.policyEvents)
            if (!isVisible(e)) e.id,
        };
        final now = clock();
        final view = await work(
          _ReduceJob(events, coordinate, now, hidden).run,
        );
        final current = {
          for (final e in merged.policyEvents)
            if (!isVisible(e)) e.id,
        };
        if (current.length == hidden.length &&
            current.containsAll(hidden) &&
            clock() == now) {
          return ChallengeRead(view: view, observation: observation);
        }
      }
      return _unavailable(coordinate, observation);
    } on Object {
      return _unavailable(coordinate, observation);
    }
  }

  ChallengeRead _unavailable(String coordinate, RawChallengeRead read) =>
      ChallengeRead(
        view: reduceChallenge(const [], coordinate, clock(), (_) => false),
        observation: RawChallengeRead(
          records: const [],
          source: read.source,
          completeness: ReadCompleteness.unavailable,
          indexedAt: read.indexedAt,
        ),
      );
}
