// ABOUTME: Reads a video's poll and its votes, counted by Funnelcake or else
// ABOUTME: on the device, and publishes a viewer's NIP-88 kind:1018 vote.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter, PublishOutcome;
import 'package:poll_repository/src/poll.dart';
import 'package:poll_repository/src/poll_results.dart';

/// Signs an event of [kind] as the signed-in account, or gives `null` when it
/// cannot.
typedef PollEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
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
  /// Votes name [relayUrl] as where they are cast.
  PollRepository({
    required NostrClient nostrClient,
    required PollEventSigner signEvent,
    required String? Function() currentPubkey,
    FunnelcakeApiClient? funnelcakeApiClient,
    this.relayUrl,
  }) : _nostrClient = nostrClient,
       _signEvent = signEvent,
       _currentPubkey = currentPubkey,
       _funnelcakeApiClient = funnelcakeApiClient;

  final NostrClient _nostrClient;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final PollEventSigner _signEvent;
  final String? Function() _currentPubkey;

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
    if (tally == null) {
      return _countOnDevice(pollId, authorPubkey, viewerPubkey);
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

  Future<PollSnapshot?> _countOnDevice(
    String pollId,
    String authorPubkey,
    String? viewerPubkey,
  ) async {
    final events = await _nostrClient.queryEvents([
      Filter(ids: [pollId], kinds: [Poll.eventKind]),
      Filter(kinds: [Poll.voteKind], e: [pollId], limit: maxVotesRead),
    ]);
    final poll = _pollIn(events, pollId, authorPubkey);
    if (poll == null) return null;
    return PollSnapshot(
      poll: poll,
      results: PollResults.tally(poll, events, viewerPubkey: viewerPubkey),
    );
  }

  Poll? _pollIn(List<Event> events, String pollId, String authorPubkey) =>
      events
          .where((event) => event.id == pollId && event.pubkey == authorPubkey)
          .map(Poll.fromEvent)
          .nonNulls
          .firstOrNull;

  /// Votes for [optionId] on [poll] as the signed-in account.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if [optionId] names no answer of [poll].
  /// * [PollVoteException] if the vote cannot be signed or no relay takes it.
  Future<void> vote(Poll poll, String optionId) async {
    if (!poll.hasOption(optionId)) {
      throw ArgumentError.value(optionId, 'optionId', 'No answer of the poll');
    }
    final event = await _signEvent(
      kind: Poll.voteKind,
      content: '',
      tags: Poll.voteTags(poll.id, optionId, relayUrl: relayUrl),
    );
    if (event == null) {
      throw const PollVoteException('Could not sign the vote');
    }
    final outcome = await _nostrClient.publishEventAwaitOk(event);
    if (outcome.failed) {
      throw PollVoteException(
        'No relay took the vote: ${outcome.summary}',
        outcome: outcome,
      );
    }
  }
}
