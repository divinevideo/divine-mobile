// ABOUTME: The votes on a poll, one per pubkey: how many each answer has, the
// ABOUTME: viewer's own vote, a slider's average, and how they are tallied.

import 'package:equatable/equatable.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:poll_repository/src/poll.dart';

/// How many people picked each answer of a [Poll], and what the viewer
/// picked.
class PollResults extends Equatable {
  /// Creates results.
  const PollResults({this.counts = const {}, this.ownVoteId});

  /// The votes on [poll] among [votes], one per pubkey, and [viewerPubkey]'s
  /// own.
  ///
  /// Following NIP-88, a vote counts only its first `response` tag, and a
  /// pubkey's latest vote counts. A quiz counts its earliest instead, so an
  /// answer cannot be changed once given. A vote that names no answer of the
  /// poll counts for nothing.
  factory PollResults.tally(
    Poll poll,
    Iterable<Event> votes, {
    String? viewerPubkey,
  }) {
    final counted = <String, Event>{};
    final picks = <String, String>{};
    for (final vote in votes) {
      if (vote.kind != Poll.voteKind) continue;
      final repliesToPoll = vote.tags.any(
        (tag) => tag.length >= 2 && tag[0] == 'e' && tag[1] == poll.id,
      );
      if (!repliesToPoll) continue;
      final response = vote.tags
          .where((tag) => tag.length >= 2 && tag[0] == 'response')
          .firstOrNull;
      if (response == null || !poll.hasOption(response[1])) continue;
      final previous = counted[vote.pubkey];
      if (previous != null && !_replaces(vote, previous, poll.kind)) continue;
      counted[vote.pubkey] = vote;
      picks[vote.pubkey] = response[1];
    }
    final counts = <String, int>{};
    for (final pick in picks.values) {
      counts[pick] = (counts[pick] ?? 0) + 1;
    }
    return PollResults(counts: counts, ownVoteId: picks[viewerPubkey]);
  }

  /// Results from counts made elsewhere, [votes] by answer id, and the
  /// viewer's own vote [ownVoteId].
  ///
  /// A server's count can be a few seconds old, so a vote of the viewer's it
  /// has not seen yet still counts once.
  factory PollResults.counted(Map<String, int> votes, {String? ownVoteId}) {
    final counts = {
      for (final MapEntry(key: optionId, value: count) in votes.entries)
        if (count > 0) optionId: count,
    };
    if (ownVoteId != null) counts[ownVoteId] ??= 1;
    return PollResults(counts: counts, ownVoteId: ownVoteId);
  }

  /// Whether [vote] counts in place of [previous] from the same pubkey: the
  /// later one, or for a quiz the earlier, with the event id deciding a tie.
  static bool _replaces(Event vote, Event previous, PollKind kind) {
    final order = vote.createdAt != previous.createdAt
        ? vote.createdAt.compareTo(previous.createdAt)
        : vote.id.compareTo(previous.id);
    return kind == PollKind.quiz ? order < 0 : order > 0;
  }

  /// How many people picked each answer, by its id; an answer nobody picked
  /// is missing.
  final Map<String, int> counts;

  /// The id of the answer the viewer picked, or `null` before they vote.
  final String? ownVoteId;

  /// How many people voted.
  int get total => counts.values.fold(0, (sum, count) => sum + count);

  /// Whether the viewer has voted.
  bool get hasVoted => ownVoteId != null;

  /// How many people picked [optionId].
  int countOf(String optionId) => counts[optionId] ?? 0;

  /// The share of the votes [optionId] has, from 0 to 1.
  double shareOf(String optionId) {
    final total = this.total;
    return total == 0 ? 0 : countOf(optionId) / total;
  }

  /// Where the votes on the slider [poll] stand on average, from 0 to 1, or
  /// `null` before anyone voted.
  double? averageOn(Poll poll) {
    var sum = 0;
    var total = 0;
    for (final MapEntry(key: optionId, value: count) in counts.entries) {
      final value = poll.valueOf(optionId);
      if (value == null) continue;
      sum += value * count;
      total += count;
    }
    return total == 0 ? null : sum / total / Poll.maxSliderValue;
  }

  /// These results once the viewer's vote is [optionId] instead of what it
  /// was.
  PollResults withOwnVote(String optionId) {
    final counts = Map.of(this.counts);
    final previous = ownVoteId;
    if (previous != null) {
      final left = (counts[previous] ?? 1) - 1;
      if (left > 0) {
        counts[previous] = left;
      } else {
        counts.remove(previous);
      }
    }
    counts[optionId] = (counts[optionId] ?? 0) + 1;
    return PollResults(counts: counts, ownVoteId: optionId);
  }

  @override
  List<Object?> get props => [counts, ownVoteId];
}

/// A poll and the votes on it, as they were read.
class PollSnapshot extends Equatable {
  /// Creates a snapshot.
  const PollSnapshot({required this.poll, required this.results});

  /// The poll.
  final Poll poll;

  /// The votes on it.
  final PollResults results;

  @override
  List<Object?> get props => [poll, results];
}
