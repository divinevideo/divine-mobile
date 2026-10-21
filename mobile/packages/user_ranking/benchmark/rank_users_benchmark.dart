import 'dart:io';

import 'package:user_ranking/user_ranking.dart';

/// Measures scoring and sorting only; fixture setup is outside the stopwatch.
void main() {
  const candidateCount = 5000;
  const warmRuns = 20;
  final now = DateTime.utc(2026, 10, 14);
  final candidates = List.generate(candidateCount, (index) {
    return UserRankingSignals(
      pubkey: (index + 1).toRadixString(16).padLeft(64, '0'),
      youFollow: index.isEven,
      followsYou: index % 3 == 0,
      lastInteractionAt: index % 5 == 0
          ? now.subtract(Duration(hours: index % 1000))
          : null,
      lastPostedAt: now.subtract(Duration(hours: index % 500)),
      videoCount: index % 2000,
      hasVerifiedNip05: index % 7 == 0,
    );
  });
  final names = {
    for (var index = 0; index < candidateCount; index++)
      candidates[index].pubkey: 'Person ${candidateCount - index}',
  };
  int measure() {
    final stopwatch = Stopwatch()..start();
    final ranked = rankUsers(
      candidates,
      now: now,
      nameOf: (pubkey) => names[pubkey]!,
    );
    stopwatch.stop();
    if (ranked.length != candidateCount ||
        ranked.toSet().length != candidateCount) {
      throw StateError('Ranking lost or duplicated a candidate');
    }
    return stopwatch.elapsedMicroseconds;
  }

  final cold = measure();
  final samples = List.generate(warmRuns, (_) => measure())..sort();
  String milliseconds(num microseconds) =>
      (microseconds / 1000).toStringAsFixed(3);
  stdout
    ..writeln('$candidateCount synthetic candidates; scoring + sorting only')
    ..writeln('Runtime: ${Platform.version}; ${Platform.operatingSystem}')
    ..writeln('First invocation: ${milliseconds(cold)} ms')
    ..writeln(
      '$warmRuns subsequent invocations: '
      'median ${milliseconds((samples[9] + samples[10]) / 2)} ms, '
      'min ${milliseconds(samples.first)} ms, '
      'max ${milliseconds(samples.last)} ms',
    )
    ..writeln('Host JIT timings do not establish the 50 ms phone budget.');
}
