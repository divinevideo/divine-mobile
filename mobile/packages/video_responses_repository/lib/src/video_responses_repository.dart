// ABOUTME: Reads a video's video replies and the answers to its Add yours, from
// ABOUTME: Funnelcake or else the relays, and its creator's pins and hides.

import 'dart:async';
import 'dart:math' as math;

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart'
    show Event, Filter, NostrTimestamp, PublishOutcome, QueryEnd;
import 'package:video_responses_repository/src/replies_curation.dart';
import 'package:video_responses_repository/src/video_responses.dart';

/// Signs an event of [kind] as the signed-in account, at [createdAt] when
/// given, or gives `null` when it cannot.
typedef ResponsesEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
      int? createdAt,
    });

/// A curation that could not be saved: the signed-in account changed or
/// signed out, it could not be signed as that account, or no relay took it.
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

/// A creator's curation that could not be read in full: the relays timed out
/// or none could be asked. [VideoResponsesRepository.fetchCuration] throws it
/// only when nothing came back; [VideoResponsesRepository.saveCuration]
/// throws it whatever came back.
///
/// Kept apart from an empty curation, which means the creator pinned and hid
/// nothing. Treating a failed read as empty would let the creator's next pin
/// or hide publish a curation without the replies they hid before.
class RepliesCurationUnavailableException implements Exception {
  /// Creates the exception.
  const RepliesCurationUnavailableException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'RepliesCurationUnavailableException: $message';
}

/// Whether the video an Add yours names as its chain's first starts that
/// chain, as [VideoResponsesRepository.chainStart] reads it.
enum AddYoursChainStart {
  /// It carries an Add yours of its own with the hashtag.
  starts,

  /// Every relay answered, and it carries no such Add yours, or is not there.
  doesNotStart,

  /// It was not read starting the chain, and a relay did not answer in full:
  /// that relay may hold it.
  unconfirmed,
}

/// Whether a video starts an Add yours chain could not be read: no relay
/// could be asked, and nothing came back.
///
/// Kept apart from a video read without a chain of its own. Treating a failed
/// read as no chain would start the chain at the viewer's video instead, and
/// an answer they publish would join that chain for good.
class AddYoursChainUnavailableException implements Exception {
  /// Creates the exception.
  const AddYoursChainUnavailableException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'AddYoursChainUnavailableException: $message';
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
  ///
  /// [latestEvents] holds the newest curations seen. Share it with the
  /// comment moderation writer of `comments_repository`, which replaces the
  /// same per-video event, so neither builds on a version older than the
  /// other just published.
  VideoResponsesRepository({
    required NostrClient nostrClient,
    required ResponsesEventSigner signEvent,
    FunnelcakeApiClient? funnelcakeApiClient,
    LatestAddressableEvents? latestEvents,
  }) : _nostrClient = nostrClient,
       _signEvent = signEvent,
       _funnelcakeApiClient = funnelcakeApiClient,
       _latestEvents = latestEvents ?? LatestAddressableEvents();

  final NostrClient _nostrClient;
  final ResponsesEventSigner _signEvent;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// When the latest curation this read or signed for each account and video
  /// was signed. Of two signed in the same second NIP-01 keeps the one
  /// with the lower id, so a quick pin and unpin could leave the relays
  /// holding the first; the next one is signed after it instead.
  final _curationSignedAt = <String, int>{};

  /// The newest authenticated curations read or saved, here or by a writer
  /// sharing the store, retained when a later read returns only older
  /// revisions.
  final LatestAddressableEvents _latestEvents;

  /// The most responses one read from the relays asks for.
  static const int maxResponsesRead = 500;

  /// The marker on the `a` tag an Add yours answer names its chain with.
  static const String _mentionMarker = 'mention';

  /// The video replies to the video [videoId] names, published at
  /// [videoAddress] when it is addressable: the newest first, at most
  /// [limit] of them, and how many there are.
  Future<VideoResponses> fetchReplies({
    required String videoId,
    String? videoAddress,
    int limit = 20,
  }) async {
    // By event id, never the d tag: the server resolves a d tag to the newest
    // video carrying it, whoever published it, so a copy of this video's d tag
    // would take over its replies. The server derives the address from the
    // event, so replies to any version of the video still count.
    final server = await _fetchFromServer(
      videoId: videoId,
      type: VideoResponseType.replies,
      limit: limit,
    );
    if (server != null) return server;

    final kinds = [NIP71VideoKinds.addressableShortVideo];
    final read = await _nostrClient.readEvents([
      Filter(kinds: kinds, uppercaseE: [videoId], limit: maxResponsesRead),
      if (videoAddress != null)
        Filter(
          kinds: kinds,
          uppercaseA: [videoAddress],
          limit: maxResponsesRead,
        ),
    ]);
    return _responsesIn(
      read.events,
      limit: limit,
      possiblyCapped: read.possiblyCapped,
      where: (reply) =>
          reply.replyRootEventId == videoId ||
          (videoAddress != null &&
              reply.replyRootAddressableId == videoAddress),
    );
  }

  /// The videos that joined the Add yours chain starting at the video at
  /// [chainRoot]: those that name it in an `a` tag marked `mention` and carry
  /// [hashtag]. One per person, the newest, at most [limit] of them, and how
  /// many people joined.
  ///
  /// [filter], the viewer's, runs before each person's answer is picked, so a
  /// person whose newest answer it leaves out still shows by an older one.
  Future<VideoResponses> fetchJoined({
    required String chainRoot,
    required String hashtag,
    int limit = 20,
    List<VideoEvent> Function(List<VideoEvent> answers)? filter,
  }) async {
    bool joined(VideoEvent answer) =>
        answer.addressableId != chainRoot &&
        answer.hashtags.contains(hashtag) &&
        answer.nostrEventTags.any(
          (tag) =>
              tag.length >= 4 &&
              tag[0] == 'a' &&
              tag[1] == chainRoot &&
              tag[3].toLowerCase() == _mentionMarker,
        );

    final dTag = chainRoot.split(':').skip(2).join(':');
    final server = await _fetchFromServer(
      videoId: dTag,
      type: VideoResponseType.joined,
      hashtag: hashtag,
      limit: limit,
    );
    // The server asks by the d tag, which another author's video may share,
    // so what it returns is checked as the relays' answers are.
    if (server != null) return _joinedOf(server, joined, filter: filter);

    final read = await _nostrClient.readEvents([
      Filter(
        kinds: [NIP71VideoKinds.addressableShortVideo],
        a: [chainRoot],
        t: [hashtag],
        limit: maxResponsesRead,
      ),
    ]);
    return _responsesIn(
      read.events,
      limit: limit,
      possiblyCapped: read.possiblyCapped,
      where: joined,
      onePerAuthor: true,
      filter: filter,
    );
  }

  /// Whether the video at [chainRoot] starts an Add yours chain with
  /// [hashtag]: it carries an Add yours of its own with that hashtag, not one
  /// answering another video's.
  ///
  /// [AddYoursChainStart.unconfirmed] when it was not read starting the chain
  /// and a relay stayed silent, refused or dropped. The read does not wait
  /// for such a relay, so a chain whose first video is read stays prompt.
  ///
  /// Throws an [AddYoursChainUnavailableException] when no relay could be
  /// asked and nothing came back.
  Future<AddYoursChainStart> chainStart(
    String chainRoot, {
    required String hashtag,
  }) async {
    if (!RepliesCuration.isAddress(chainRoot)) {
      return AddYoursChainStart.doesNotStart;
    }
    final read = await _nostrClient.readEvents([_filterFor(chainRoot)]);
    if (read.events.isEmpty && read.endedBy == QueryEnd.noRelay) {
      throw const AddYoursChainUnavailableException('No relay could be asked');
    }
    final first = _responsesIn(
      read.events,
      limit: 1,
      where: (video) => video.addressableId == chainRoot,
    ).videos.firstOrNull;
    final starts =
        first?.stickerRegions.any(
          (region) =>
              region.promptChainRoot(chainRoot) == chainRoot &&
              region.promptHashtag == hashtag,
        ) ??
        false;
    if (starts) return AddYoursChainStart.starts;
    return read.endedBy == QueryEnd.complete
        ? AddYoursChainStart.doesNotStart
        : AddYoursChainStart.unconfirmed;
  }

  /// The reply to the video [videoId] names, published at [videoAddress],
  /// that [key] names, its [RepliesCuration.keyOf]: the newest version of it.
  /// `null` when there is none, or it does not reply to that video.
  Future<VideoEvent?> fetchReply(
    String key, {
    required String videoId,
    String? videoAddress,
  }) async {
    final events = await _nostrClient.queryEvents([_filterFor(key)]);
    final replies = _responsesIn(
      events,
      limit: 1,
      where: (reply) => RepliesCuration.keyOf(reply) == key || reply.id == key,
    );
    final reply = replies.videos.firstOrNull;
    if (reply == null) return null;
    final repliesToVideo =
        reply.replyRootEventId == videoId ||
        (videoAddress != null && reply.replyRootAddressableId == videoAddress);
    return repliesToVideo ? reply : null;
  }

  /// The filter reading the video [key] names: its address, or its event id.
  static Filter _filterFor(String key) {
    if (!RepliesCuration.isAddress(key)) return Filter(ids: [key]);
    final address = key.split(':');
    return Filter(
      kinds: [int.parse(address[0])],
      authors: [address[1]],
      d: [address.skip(2).join(':')],
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

  /// [responses] without those [where] or [filter] rejects, one per person,
  /// counted without those left out too; the rest of the count was not read,
  /// so it stays as it is.
  VideoResponses _joinedOf(
    VideoResponses responses,
    bool Function(VideoEvent) where, {
    List<VideoEvent> Function(List<VideoEvent>)? filter,
  }) {
    final matching = responses.videos.where(where).toList();
    final kept = _onePerAuthor(
      List.of(filter?.call(matching) ?? matching)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
    final leftOut = responses.videos.length - kept.length;
    return VideoResponses(
      total: math.max(kept.length, responses.total - leftOut),
      videos: kept,
    );
  }

  /// The parsed [events] that [where] and then [filter] keep, the newest
  /// first, one per person when [onePerAuthor]: at most [limit] of them,
  /// counted in all. The count is only a floor when [possiblyCapped]: a relay
  /// may have stopped at its result-size limit.
  VideoResponses _responsesIn(
    List<Event> events, {
    required int limit,
    required bool Function(VideoEvent) where,
    bool possiblyCapped = false,
    bool onePerAuthor = false,
    List<VideoEvent> Function(List<VideoEvent>)? filter,
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
    final read = byId.values.toList();
    final newestFirst = List.of(filter?.call(read) ?? read)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final videos = onePerAuthor ? _onePerAuthor(newestFirst) : newestFirst;
    return VideoResponses(
      total: videos.length,
      videos: videos.take(limit).toList(),
      totalIsAtLeast: possiblyCapped,
    );
  }

  /// The newest of [newestFirst] by each author.
  static List<VideoEvent> _onePerAuthor(List<VideoEvent> newestFirst) {
    final authors = <String>{};
    return [
      for (final video in newestFirst)
        if (authors.add(video.pubkey.toLowerCase())) video,
    ];
  }

  /// The reply its creator, [creatorPubkey], pinned to the front of the
  /// replies to the video at [videoAddress], the ones they hid, and the
  /// accounts whose replies they hide on all their videos.
  ///
  /// Throws a [RepliesCurationUnavailableException] when the relays timed out
  /// or none could be asked and nothing came back.
  Future<RepliesCuration> fetchCuration({
    required String creatorPubkey,
    required String videoAddress,
  }) async {
    final dTag = RepliesCuration.dTagFor(videoAddress);
    final key = '$creatorPubkey:$dTag';
    final (:events, :timedOut, :noRelays) = await _nostrClient
        .queryEventsDetailed([
          Filter(
            kinds: [RepliesCuration.kind],
            authors: [creatorPubkey],
            d: [dTag, RepliesCuration.hiddenAuthorsDTag],
          ),
        ]);
    final eligible = events
        .where((event) => _isCurationBy(event, creatorPubkey, dTag))
        .toList();
    final authorLists = events
        .where(
          (event) => _isCurationBy(
            event,
            creatorPubkey,
            RepliesCuration.hiddenAuthorsDTag,
          ),
        )
        .toList();
    // The hidden accounts alone say nothing about this video's pins and
    // hides, so a read that missed the curation fails as before.
    if (eligible.isEmpty && (timedOut || noRelays)) {
      throw RepliesCurationUnavailableException(
        noRelays ? 'No relay could be asked' : 'The relays did not answer',
      );
    }
    final latest = [...eligible, ?_known(creatorPubkey, dTag)]
      ..sort(_compareCurationRevisions);
    if (latest.firstOrNull case final newest?) {
      _latestEvents.remember(newest);
      _noteCurationSignedAt(key, newest.createdAt);
    }
    final latestAuthors = [
      ...authorLists,
      ?_known(creatorPubkey, RepliesCuration.hiddenAuthorsDTag),
    ]..sort(_compareCurationRevisions);
    if (latestAuthors.firstOrNull case final newest?) {
      _latestEvents.remember(newest);
    }
    final curation =
        latest.map(RepliesCuration.fromEvent).nonNulls.firstOrNull ??
        const RepliesCuration();
    return curation.withHiddenAuthors(
      latestAuthors.isEmpty
          ? const {}
          : RepliesCuration.hiddenAuthorsIn(latestAuthors.first),
    );
  }

  static bool _isCurationBy(Event event, String owner, String dTag) =>
      event.pubkey == owner &&
      event.kind == RepliesCuration.kind &&
      event.dTagValue == dTag &&
      event.isValid &&
      event.isSigned;

  static int _compareCurationRevisions(Event a, Event b) =>
      a.createdAt != b.createdAt
      ? b.createdAt.compareTo(a.createdAt)
      : a.id.compareTo(b.id);

  Event? _known(String pubkey, String dTag) => _latestEvents.latest(
    pubkey: pubkey,
    kind: RepliesCuration.kind,
    dTag: dTag,
  );

  void _noteCurationSignedAt(String key, int createdAt) =>
      _curationSignedAt[key] = math.max(
        createdAt,
        _curationSignedAt[key] ?? createdAt,
      );

  /// Saves [curation], the creator's edit of [previous], for the replies to
  /// the video at [videoAddress] as the signed-in account, and returns the
  /// curation a relay took.
  ///
  /// The edit is applied to the newest of the account's curations the relays
  /// return and the newest this repository read or saved, so pins and hides on
  /// another device are kept; with neither, it is applied to [previous]. It is
  /// signed after the curation it replaces. Saves by the same account to the
  /// same video run one at a time.
  ///
  /// Throws:
  ///
  /// * [RepliesCurationUnavailableException] if the read timed out or no
  ///   relay could be asked, since a curation it missed may hold pins or
  ///   hides this save would drop.
  /// * [RepliesCurationException] if the account changes or signs out during
  ///   the save, the curation cannot be signed as that account, or no relay
  ///   takes it.
  Future<RepliesCuration> saveCuration(
    RepliesCuration curation, {
    required String videoAddress,
    required RepliesCuration previous,
  }) {
    final owner = _nostrClient.publicKey;
    final key = '$owner:${RepliesCuration.dTagFor(videoAddress)}';
    return _latestEvents.run(
      pubkey: owner,
      kind: RepliesCuration.kind,
      dTag: RepliesCuration.dTagFor(videoAddress),
      operation: () => _saveCuration(
        curation,
        previous: previous,
        videoAddress: videoAddress,
        owner: owner,
        key: key,
      ),
    );
  }

  Future<RepliesCuration> _saveCuration(
    RepliesCuration curation, {
    required RepliesCuration previous,
    required String videoAddress,
    required String owner,
    required String key,
  }) async {
    _requireCurationOwner(owner);
    final dTag = RepliesCuration.dTagFor(videoAddress);
    final read = await _nostrClient.queryEventsDetailed(
      [
        Filter(kinds: [RepliesCuration.kind], authors: [owner], d: [dTag]),
      ],
      useCache: false,
      requireAllRelaysSettled: true,
    );
    _requireCurationOwner(owner);
    if (read.timedOut || read.noRelays) {
      throw const RepliesCurationUnavailableException(
        'The latest curation could not be established',
      );
    }
    final revisions = [
      for (final event in read.events)
        if (_isCurationBy(event, owner, dTag)) event,
      ?_known(owner, dTag),
    ]..sort(_compareCurationRevisions);
    final source = revisions.firstOrNull;
    final latest = source == null
        // With no authenticated source available, keep the caller's baseline.
        ? previous
        : RepliesCuration.fromEvent(source)!;
    final hidden = {...latest.hiddenIds}
      ..addAll(curation.hiddenIds.difference(previous.hiddenIds))
      ..removeAll(previous.hiddenIds.difference(curation.hiddenIds));
    final restored = {...latest.restoredIds}
      ..addAll(curation.restoredIds.difference(previous.restoredIds))
      ..removeAll(previous.restoredIds.difference(curation.restoredIds));
    // Hiding a reply takes back its restored mark, and showing it again a
    // hide by the same key, also when the other mark came from another
    // device. A hide by address stays; the restore of one version wins over
    // it until the reply is replaced.
    hidden.removeAll(curation.restoredIds.difference(previous.restoredIds));
    restored.removeAll(curation.hiddenIds.difference(previous.hiddenIds));
    final pinChanged = curation.pinnedId != previous.pinnedId;
    var pinned = latest.pinnedId;
    if (pinChanged) {
      final requestedPin = curation.pinnedId;
      if (requestedPin != null) {
        // Pinning also shows this reply, including a hide learned in this read.
        hidden.remove(requestedPin);
        pinned = requestedPin;
      } else if (latest.pinnedId == previous.pinnedId) {
        // Clearing the old pin must not clear another device's different pin.
        pinned = null;
      }
    }
    final replacement = RepliesCuration(
      pinnedId: hidden.contains(pinned) ? null : pinned,
      hiddenIds: hidden,
      restoredIds: restored,
      // Not part of this event; kept for the caller to go on showing.
      hiddenAuthors: curation.hiddenAuthors,
    );
    if (source != null) {
      _latestEvents.remember(source);
      _noteCurationSignedAt(key, source.createdAt);
    }
    final now = NostrTimestamp.now(
      driftTolerance: NostrTimestamp.getDriftToleranceForKind(
        RepliesCuration.kind,
      ),
    );
    final event = await _signEvent(
      kind: RepliesCuration.kind,
      content: source?.content ?? '',
      tags: replacement.toTags(
        videoAddress,
        // The signer stamps attribution from the current setting, so the
        // replaced curation's `client` tag is not carried forward (#8176).
        sourceTags: source == null
            ? null
            : Nip89ClientTag.withoutClientTag(source.tags),
      ),
      createdAt: math.max(now, (_curationSignedAt[key] ?? 0) + 1),
    );
    _requireCurationOwner(owner);
    if (event == null || event.pubkey != owner) {
      throw const RepliesCurationException('Could not sign the curation');
    }
    _noteCurationSignedAt(key, event.createdAt);
    final outcome = await _nostrClient.publishEventAwaitOk(event);
    if (outcome.failed) {
      throw RepliesCurationException(
        'No relay took the curation: ${outcome.summary}',
        outcome: outcome,
      );
    }
    if (_isCurationBy(event, owner, dTag)) _latestEvents.remember(event);
    return replacement;
  }

  void _requireCurationOwner(String owner) {
    if (owner.isEmpty ||
        _nostrClient.isDisposed ||
        _nostrClient.publicKey != owner) {
      throw const RepliesCurationException(
        'The signed-in account changed or signed out',
      );
    }
  }
}
