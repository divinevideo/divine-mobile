// ABOUTME: Reads a video's poll and its votes, counted by Funnelcake or else
// ABOUTME: on the device, and publishes a viewer's NIP-88 kind:1018 vote.

import 'dart:math' as math;

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart'
    show Event, Filter, NostrTimestamp, PublishOutcome;
import 'package:poll_repository/src/poll.dart';
import 'package:poll_repository/src/poll_results.dart';

/// Signs an event of [kind] as the signed-in account, stamped [createdAt]
/// when given, or gives `null` when it cannot.
typedef PollEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
      int? createdAt,
    });

/// A vote that could not be signed or that no relay took.
class PollVoteException implements Exception {
  /// Creates the exception.
  const PollVoteException(this.message, {this.outcome});

  /// What went wrong.
  final String message;

  /// How the relays answered, when the vote was signed and sent.
  final PublishOutcome? outcome;

  @override
  String toString() => 'PollVoteException: $message';
}

/// Polls on videos and the votes on them.
///
/// Funnelcake counts the votes when it can, and the relays then only tell the
/// viewer's own. When Funnelcake is not configured or does not answer, the
/// votes are counted here from the `kind:1018` events the relays hold, read in
/// one request of at most [maxVotesRead].
class PollRepository {
  /// Creates the repository, reading and publishing through [nostrClient],
  /// signing votes with [signEvent] and telling the viewer's own vote by
  /// [currentPubkey]. [funnelcakeApiClient] counts the votes when given.
  /// Votes name [relayUrl] as where they are cast. [now] is the Nostr time a
  /// vote is stamped with by default.
  PollRepository({
    required NostrClient nostrClient,
    required PollEventSigner signEvent,
    required String? Function() currentPubkey,
    FunnelcakeApiClient? funnelcakeApiClient,
    this.relayUrl,
    int Function() now = NostrTimestamp.now,
  }) : _nostrClient = nostrClient,
       _signEvent = signEvent,
       _currentPubkey = currentPubkey,
       _funnelcakeApiClient = funnelcakeApiClient,
       _now = now;

  final NostrClient _nostrClient;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final PollEventSigner _signEvent;
  final String? Function() _currentPubkey;
  final int Function() _now;

  /// When each viewer's latest vote on each poll is stamped, as far as read
  /// or cast here, by [_voteKey].
  final Map<String, int> _ownVoteTimes = {};

  /// The relay a vote names in its `e` tag.
  final String? relayUrl;

  /// The most votes one read asks for, the most the Divine relays answer.
  static const int maxVotesRead = 5000;

  /// The poll [pollId] names and the votes on it, or `null` when no relay
  /// has a poll of that id by [authorPubkey], the one whose video shows it.
  Future<PollSnapshot?> fetchPoll(
    String pollId, {
    required String authorPubkey,
  }) async {
    final viewerPubkey = _currentPubkey();
    final client = _funnelcakeApiClient;
    if (client == null || !client.isAvailable) {
      return _countOnDevice(pollId, authorPubkey, viewerPubkey);
    }

    final serverTally = _fetchServerTally(client, pollId);
    final events = await _nostrClient.queryEvents([
      Filter(ids: [pollId], kinds: [Poll.eventKind]),
      if (viewerPubkey != null)
        Filter(kinds: [Poll.voteKind], e: [pollId], authors: [viewerPubkey]),
    ]);
    final poll = _pollIn(events, pollId, authorPubkey);
    final tally = await serverTally;
    if (poll == null) return null;
    _noteOwnVotes(events, pollId, viewerPubkey);
    if (tally == null) {
      return _countOnDevice(pollId, authorPubkey, viewerPubkey, known: events);
    }
    return PollSnapshot(
      poll: poll,
      results: PollResults.counted(
        tally.votes,
        ownVoteId: PollResults.tally(
          poll,
          events,
          viewerPubkey: viewerPubkey,
        ).ownVoteId,
        replacedVoteId: viewerPubkey == null
            ? null
            : PollResults.replacedPick(
                poll,
                events,
                viewerPubkey: viewerPubkey,
              ),
      ),
    );
  }

  Future<PollVoteTally?> _fetchServerTally(
    FunnelcakeApiClient client,
    String pollId,
  ) async {
    try {
      return await client.getPollResults(pollId);
    } on FunnelcakeException {
      // Counting on the device answers the same question, only slower.
      return null;
    }
  }

  /// Counts the votes on the device. What an earlier read found is [known],
  /// which a read that comes back short cannot lose.
  Future<PollSnapshot?> _countOnDevice(
    String pollId,
    String authorPubkey,
    String? viewerPubkey, {
    List<Event> known = const [],
  }) async {
    final events = [
      ...known,
      ...await _nostrClient.queryEvents([
        Filter(ids: [pollId], kinds: [Poll.eventKind]),
        Filter(kinds: [Poll.voteKind], e: [pollId], limit: maxVotesRead),
        // The viewer's own vote may be older than every vote read above.
        if (viewerPubkey != null)
          Filter(kinds: [Poll.voteKind], e: [pollId], authors: [viewerPubkey]),
      ]),
    ];
    final poll = _pollIn(events, pollId, authorPubkey);
    if (poll == null) return null;
    _noteOwnVotes(events, pollId, viewerPubkey);
    return PollSnapshot(
      poll: poll,
      results: PollResults.tally(poll, events, viewerPubkey: viewerPubkey),
    );
  }

  static String _voteKey(String? viewerPubkey, String pollId) =>
      '$viewerPubkey:$pollId';

  /// Notes when [viewerPubkey]'s latest vote among [events] on [pollId] is
  /// stamped, so a vote they change it to is stamped later.
  void _noteOwnVotes(List<Event> events, String pollId, String? viewerPubkey) {
    if (viewerPubkey == null) return;
    for (final event in events) {
      if (event.kind != Poll.voteKind || event.pubkey != viewerPubkey) continue;
      if (!event.tags.any(
        (tag) => tag.length >= 2 && tag[0] == 'e' && tag[1] == pollId,
      )) {
        continue;
      }
      _noteOwnVote(_voteKey(viewerPubkey, pollId), event.createdAt);
    }
  }

  void _noteOwnVote(String key, int createdAt) {
    final known = _ownVoteTimes[key];
    if (known == null || createdAt > known) _ownVoteTimes[key] = createdAt;
  }

  Poll? _pollIn(List<Event> events, String pollId, String authorPubkey) =>
      events
          .where((event) => event.id == pollId && event.pubkey == authorPubkey)
          .map(Poll.fromEvent)
          .nonNulls
          .firstOrNull;

  /// Votes for [optionId] on [poll] as the signed-in account.
  ///
  /// A vote that changes an earlier one is stamped after it, even within the
  /// same second: the latest vote counts, and a tie would be decided by the
  /// events' ids.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if [optionId] names no answer of [poll].
  /// * [PollVoteException] if the vote cannot be signed or no relay takes it.
  Future<void> vote(Poll poll, String optionId) async {
    if (!poll.hasOption(optionId)) {
      throw ArgumentError.value(optionId, 'optionId', 'No answer of the poll');
    }
    final key = _voteKey(_currentPubkey(), poll.id);
    final previous = _ownVoteTimes[key];
    final Event? event;
    final PublishOutcome outcome;
    try {
      event = await _signEvent(
        kind: Poll.voteKind,
        content: '',
        tags: Poll.voteTags(poll.id, optionId, relayUrl: relayUrl),
        createdAt: previous == null ? null : math.max(previous + 1, _now()),
      );
      if (event == null) {
        throw const PollVoteException('Could not sign the vote');
      }
      _noteOwnVote(key, event.createdAt);
      outcome = await _nostrClient.publishEventAwaitOk(event);
    } on PollVoteException {
      rethrow;
    } on Exception catch (error) {
      throw PollVoteException('Could not send the vote: $error');
    }
    if (outcome.failed) {
      throw PollVoteException(
        'No relay took the vote: ${outcome.summary}',
        outcome: outcome,
      );
    }
  }
}
