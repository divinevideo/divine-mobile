import 'dart:math' as math;

import 'package:user_ranking/src/user_ranking_signals.dart';
import 'package:user_ranking/src/user_ranking_weights.dart';

/// Scores a snapshot at [now], treating absent signals as zero.
///
/// Future timestamps have age zero and negative video counts contribute zero.
/// Mutual, following, and follower relationship contributions never stack.
double scoreUser(UserRankingSignals s, {required DateTime now}) {
  final relationship = switch ((s.youFollow, s.followsYou)) {
    (true, true) => UserRankingWeights.mutual,
    (true, _) => UserRankingWeights.youFollow,
    (_, true) => UserRankingWeights.followsYou,
    _ => 0.0,
  };
  final count = math.max(0, s.videoCount ?? 0).toDouble();
  final videoCount =
      UserRankingWeights.videoCountMax *
      math.min(1, math.log(1 + count) / math.ln10 / 3);
  return _recency(
        s.lastInteractionAt,
        now: now,
        maximum: UserRankingWeights.interactionMax,
        halfLife: UserRankingWeights.interactionHalfLife,
      ) +
      relationship +
      _recency(
        s.lastPostedAt,
        now: now,
        maximum: UserRankingWeights.postingMax,
        halfLife: UserRankingWeights.postingHalfLife,
      ) +
      videoCount +
      (s.hasVerifiedNip05 ? UserRankingWeights.verifiedNip05 : 0);
}

double _recency(
  DateTime? timestamp, {
  required DateTime now,
  required double maximum,
  required Duration halfLife,
}) {
  if (timestamp == null) return 0;
  final age = math.max(0, now.difference(timestamp).inMicroseconds);
  return maximum * math.pow(0.5, age / halfLife.inMicroseconds);
}

/// Whether the viewer has messaged or follows this account.
///
/// Following the viewer does not count: anyone can follow anyone, so a
/// lookalike account could otherwise buy promotion over the real one.
bool isKnown(UserRankingSignals s) =>
    s.lastInteractionAt != null || s.youFollow;

/// Orders public keys by score, then case-insensitive name, then full key.
///
/// When [interactionTierFirst] is true, accounts with interactions lead the
/// list, ordered by timestamp descending before the standard tiebreakers.
/// Computes each candidate's score once and leaves [candidates] untouched.
List<String> rankUsers(
  Iterable<UserRankingSignals> candidates, {
  required DateTime now,
  required String Function(String pubkey) nameOf,
  bool interactionTierFirst = false,
}) {
  final ranked =
      candidates
          .map(
            (s) => (
              signals: s,
              score: scoreUser(s, now: now),
              name: nameOf(s.pubkey).toLowerCase(),
            ),
          )
          .toList()
        ..sort((a, b) {
          if (interactionTierFirst) {
            final first = a.signals.lastInteractionAt;
            final second = b.signals.lastInteractionAt;
            if (first != null && second != null) {
              final byInteraction = second.compareTo(first);
              if (byInteraction != 0) return byInteraction;
            } else if (first != null) {
              return -1;
            } else if (second != null) {
              return 1;
            }
          }
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) return byScore;
          final byName = a.name.compareTo(b.name);
          if (byName != 0) return byName;
          return a.signals.pubkey.compareTo(b.signals.pubkey);
        });
  return ranked.map((candidate) => candidate.signals.pubkey).toList();
}

/// Promotes known accounts within a page while preserving other arrival order.
///
/// Signals for accounts outside [pageOrder] never add accounts to the result.
List<String> promoteKnown(
  List<String> pageOrder,
  Map<String, UserRankingSignals> signals, {
  required DateTime now,
  required String Function(String) nameOf,
}) {
  final known = <UserRankingSignals>[];
  final unknown = <String>[];
  for (final pubkey in pageOrder) {
    final signal = signals[pubkey];
    if (signal != null && isKnown(signal)) {
      known.add(signal);
    } else {
      unknown.add(pubkey);
    }
  }
  return [...rankUsers(known, now: now, nameOf: nameOf), ...unknown];
}
