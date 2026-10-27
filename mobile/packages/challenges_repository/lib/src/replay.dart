part of '../challenges_repository.dart';

/// CPU execution boundary. App sessions use [isolatedChallengeWork]. Jobs
/// carry sendable immutable wire/policy values, never services or closures
/// capturing an account provider, signer, database or socket.
typedef ChallengeWork = Future<T> Function<T>(T Function() job);

/// Real worker isolate for envelope verification and deterministic replay.
Future<T> isolatedChallengeWork<T>(T Function() job) =>
    Isolate.run(job, debugName: 'challenge-replay');

Future<T> _inlineChallengeWork<T>(T Function() job) async => job();

final class _VerifyJob {
  const _VerifyJob(this.records, this.coordinate);
  final List<String> records;
  final String coordinate;
  AuthenticatedChallengeBatch run() =>
      AuthenticatedChallengeBatch.verify(records, coordinate);
}

final class _ReduceJob {
  const _ReduceJob(this.events, this.coordinate, this.now, this.hidden);
  final List<NostrEvent> events;
  final String coordinate;
  final int now;
  final Set<String> hidden;
  ChallengeView run() =>
      reduceChallenge(events, coordinate, now, (e) => !hidden.contains(e.id));
}
