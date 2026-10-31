// ABOUTME: Reads a video's video replies and the answers to its Add yours, from
// ABOUTME: Funnelcake or else the relays, and its creator's pins and hides.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter, PublishOutcome;
import 'package:video_responses_repository/src/replies_curation.dart';
import 'package:video_responses_repository/src/video_responses.dart';

/// Signs an event of [kind] as the signed-in account, or gives `null` when it
/// cannot.
typedef ResponsesEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
    });

/// A curation that could not be signed or that no relay took.
class RepliesCurationException implements Exception {
  /// Creates the exception.
  const RepliesCurationException(this.message, {this.outcome});

  /// What went wrong.
  final String message;

  /// How the relays answered, when the curation was signed and sent.
  final PublishOutcome? outcome;

  @override
  String toString() => 'RepliesCurationException: $message';
}

/// The videos responding to a video, and its creator's pins and hides.
///
/// Funnelcake counts the responses and returns the latest when it can. When
/// it is not configured or does not answer, the responses are read from the
/// relays, at most [maxResponsesRead] in one request, and counted here.
class VideoResponsesRepository {
  /// Creates the repository, reading and publishing through [nostrClient]
  /// and signing curations with [signEvent]. [funnelcakeApiClient] counts the
  /// responses when given.
  VideoResponsesRepository({
    required NostrClient nostrClient,
    required ResponsesEventSigner signEvent,
    FunnelcakeApiClient? funnelcakeApiClient,
  }) : _nostrClient = nostrClient,
       _signEvent = signEvent,
       _funnelcakeApiClient = funnelcakeApiClient;

  final NostrClient _nostrClient;
  final ResponsesEventSigner _signEvent;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// The most responses one read from the relays asks for.
  static const int maxResponsesRead = 500;

  /// The video replies to the video [videoId] names, published at
  /// [videoAddress] when it is addressable: the newest first, at most
  /// [limit] of them, and how many there are.
  Future<VideoResponses> fetchReplies({
    required String videoId,
    String? videoAddress,
    int limit = 20,
  }) async {
    final dTag = videoAddress?.split(':').skip(2).join(':');
    final server = await _fetchFromServer(
      videoId: (dTag?.isEmpty ?? true) ? videoId : dTag!,
      type: VideoResponseType.replies,
      limit: limit,
    );
    if (server != null) return server;

    final kinds = [NIP71VideoKinds.addressableShortVideo];
    final events = await _nostrClient.queryEvents([
      Filter(kinds: kinds, uppercaseE: [videoId], limit: maxResponsesRead),
      if (videoAddress != null)
        Filter(
          kinds: kinds,
          uppercaseA: [videoAddress],
          limit: maxResponsesRead,
        ),
    ]);
    return _responsesIn(
      events,
      limit: limit,
      where: (reply) =>
          reply.replyRootEventId == videoId ||
          (videoAddress != null &&
              reply.replyRootAddressableId == videoAddress),
    );
  }

  /// The videos that joined the Add yours chain starting at the video at
  /// [chainRoot]: those that name it as what inspired them and carry
  /// [hashtag]. The newest first, at most [limit] of them, and how many
  /// there are.
  Future<VideoResponses> fetchJoined({
    required String chainRoot,
    required String hashtag,
    int limit = 20,
  }) async {
    final dTag = chainRoot.split(':').skip(2).join(':');
    final server = await _fetchFromServer(
      videoId: dTag,
      type: VideoResponseType.joined,
      hashtag: hashtag,
      limit: limit,
    );
    if (server != null) return server;

    final events = await _nostrClient.queryEvents([
      Filter(
        kinds: [NIP71VideoKinds.addressableShortVideo],
        a: [chainRoot],
        t: [hashtag],
        limit: maxResponsesRead,
      ),
    ]);
    return _responsesIn(
      events,
      limit: limit,
      where: (answer) =>
          answer.inspiredByVideo?.addressableId == chainRoot &&
          answer.addressableId != chainRoot &&
          answer.hashtags.contains(hashtag),
    );
  }

  Future<VideoResponses?> _fetchFromServer({
    required String videoId,
    required VideoResponseType type,
    required int limit,
    String? hashtag,
  }) async {
    final client = _funnelcakeApiClient;
    if (client == null || !client.isAvailable) return null;
    try {
      final page = await client.getVideoResponses(
        videoId: videoId,
        type: type,
        hashtag: hashtag,
        limit: limit,
      );
      return VideoResponses(
        total: page.total,
        videos: page.videos.toVideoEvents(),
      );
    } on FunnelcakeException {
      // The relays answer the same question, only slower.
      return null;
    }
  }

  VideoResponses _responsesIn(
    List<Event> events, {
    required int limit,
    required bool Function(VideoEvent) where,
  }) {
    final byId = <String, VideoEvent>{};
    for (final event in events) {
      final VideoEvent video;
      try {
        video = VideoEvent.fromNostrEvent(event);
      } on Object {
        // Not a video this app can show.
        continue;
      }
      if (where(video)) byId[video.id] = video;
    }
    final videos = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return VideoResponses(
      total: videos.length,
      videos: videos.take(limit).toList(),
    );
  }

  /// The reply its creator, [creatorPubkey], pinned to the front of the
  /// replies to the video at [videoAddress], and the ones they hid.
  Future<RepliesCuration> fetchCuration({
    required String creatorPubkey,
    required String videoAddress,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        kinds: [RepliesCuration.kind],
        authors: [creatorPubkey],
        d: [RepliesCuration.dTagFor(videoAddress)],
      ),
    ]);
    final latest =
        events.where((event) => event.pubkey == creatorPubkey).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return latest.map(RepliesCuration.fromEvent).nonNulls.firstOrNull ??
        const RepliesCuration();
  }

  /// Publishes [curation] of the replies to the video at [videoAddress] as
  /// the signed-in account, its creator, replacing the one before.
  ///
  /// Throws a [RepliesCurationException] if it cannot be signed or no relay
  /// takes it.
  Future<void> saveCuration(
    RepliesCuration curation, {
    required String videoAddress,
  }) async {
    final event = await _signEvent(
      kind: RepliesCuration.kind,
      content: '',
      tags: curation.toTags(videoAddress),
    );
    if (event == null) {
      throw const RepliesCurationException('Could not sign the curation');
    }
    final outcome = await _nostrClient.publishEventAwaitOk(event);
    if (outcome.failed) {
      throw RepliesCurationException(
        'No relay took the curation: ${outcome.summary}',
        outcome: outcome,
      );
    }
  }
}
