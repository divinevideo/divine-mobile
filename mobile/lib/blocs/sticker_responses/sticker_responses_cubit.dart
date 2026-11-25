// ABOUTME: Reads who joined an Add yours or replied to a video for its sticker,
// ABOUTME: filtered like any feed, without the replies its creator hid.

import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerAudience, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/sticker_responses/sticker_answerers.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

part 'sticker_responses_state.dart';

/// Filters responses the way the feeds do, and puts on each the content
/// warnings the viewer's settings call for.
typedef StickerResponsesFilter = List<VideoEvent> Function(
  List<VideoEvent> responses,
);

/// Reads the responses an Add yours or replies sticker on [video] shows.
///
/// They pass through [StickerResponsesFilter], the feeds' blocks, mutes and
/// content filters, since they show on someone else's video and open in a
/// feed; the replies the video's creator hid, and those of the accounts they
/// blocked, are left out too, and the reply they pinned comes first.
///
/// When only some may answer the sticker, see [VideoStickerRegion.audience],
/// only their responses count, and [StickerResponsesState.canAnswer] tells
/// whether [viewer] is one of them. An Add yours only its creator may answer
/// is their own series: every part they added counts, not their newest alone,
/// and [StickerResponsesState.series] lays the parts out in order.
class StickerResponsesCubit extends Cubit<StickerResponsesState>
    with CloseGuardedEmit<StickerResponsesState> {
  StickerResponsesCubit({
    required VideoResponsesRepository repository,
    required StickerResponsesFilter filter,
    required FollowRepository followRepository,
    required VideoEvent video,
    required VideoStickerRegion region,
    String? viewer,
  }) : _repository = repository,
       _filter = filter,
       _followRepository = followRepository,
       _video = video,
       _region = region,
       _viewer = viewer,
       super(
         StickerResponsesState(
           // The owner may always answer, which they see before anything is
           // read: a replies sticker's, or an Add yours's starting its chain.
           canAnswer:
               !region.audience.isRestricted ||
               (viewer != null &&
                   viewer.toLowerCase() == video.pubkey.toLowerCase() &&
                   (region.kind == VideoStickerKind.replies ||
                       region.target.isEmpty)),
         ),
       );

  final VideoResponsesRepository _repository;
  final StickerResponsesFilter _filter;
  final FollowRepository _followRepository;
  final VideoEvent _video;
  final VideoStickerRegion _region;

  /// The hex public key of the signed-in viewer, or `null` signed out.
  final String? _viewer;

  /// The most responses read, enough for the feed a tap opens.
  static const int feedLimit = 50;

  ({VideoResponses replies, StickerAnswerers answerers})? _replySnapshot;
  RepliesCuration? _curation;
  final _fetchedPins = <String, VideoEvent>{};
  final _pinReads = <String, Future<VideoEvent?>>{};
  int _curationRevision = 0;

  /// Reads the responses and the rules for showing them.
  Future<void> load() async {
    emit(state.copyWith(status: StickerResponsesStatus.loading));
    try {
      if (_region.kind == VideoStickerKind.replies) {
        await _loadReplies();
        return;
      }
      final hashtag = _region.promptHashtag;
      // Answers cite the chain by the key Divine always gave it.
      final chainAddress = _video.divineAddress;
      final chain = chainAddress == null || hashtag == null
          ? null
          : await _chain(chainAddress, hashtag);
      // Whoever started the chain an Add yours counts owns who may answer it.
      final owner = chain?.read.split(':')[1] ?? _video.pubkey;
      var audience = _region.audience;
      final VideoResponses responses;
      VideoEvent? seriesStart;
      if (chain == null || hashtag == null) {
        responses = const VideoResponses();
      } else {
        final first = chain.first;
        audience = _stricter(
          audience,
          _chainAudience(first, chain.read, hashtag),
        );
        if (_isSeries(audience)) {
          responses = await _repository.fetchSeriesBy(
            chainRoot: chain.read,
            hashtag: hashtag,
            author: owner,
          );
          seriesStart = first;
        } else {
          responses = await _repository.fetchJoined(
            chainRoot: chain.read,
            hashtag: hashtag,
            limit: feedLimit,
            filter: _filter,
          );
        }
      }
      final answerers = await StickerAnswerers.read(
        _followRepository,
        audience: audience,
        owner: owner,
        viewer: _viewer,
      );
      _emitShown(
        responses,
        const RepliesCuration(),
        answerers: answerers,
        chainRoot: chain?.join,
        seriesStart: seriesStart,
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: StickerResponsesStatus.failure));
    }
  }

  Future<void> _loadReplies() async {
    final address = _video.addressableId;
    final results = await Future.wait<Object>([
      _repository.fetchReplies(
        videoId: _video.id,
        videoAddress: address,
        limit: feedLimit,
      ),
      if (address != null)
        _repository.fetchCuration(
          creatorPubkey: _video.pubkey,
          videoAddress: address,
        ),
    ]);
    final replies = results.first as VideoResponses;
    final curation = results.length > 1
        ? results[1] as RepliesCuration
        : const RepliesCuration();
    final answerers = await StickerAnswerers.read(
      _followRepository,
      audience: _region.audience,
      owner: _video.pubkey,
      viewer: _viewer,
    );
    if (isClosed) return;
    _replySnapshot = (replies: replies, answerers: answerers);
    // The initial relay read is required before displaying replies. An edit
    // observed while it was in flight takes precedence once it succeeds.
    await _showReplies(_curation ??= curation, waitForPin: true);
  }

  /// Applies the latest accepted edit to the replies already read.
  Future<void> applyCuration(RepliesCuration curation) async {
    if (isClosed || _curation == curation) return;
    _curation = curation;
    await _showReplies(curation);
  }

  Future<void> _showReplies(
    RepliesCuration curation, {
    bool waitForPin = false,
  }) async {
    final snapshot = _replySnapshot;
    if (snapshot == null) return;
    final (:replies, :answerers) = snapshot;
    final revision = ++_curationRevision;
    final pinnedId = curation.pinnedId;
    if (pinnedId == null ||
        replies.videos.any(
          (reply) =>
              RepliesCuration.keyOf(reply) == pinnedId || reply.id == pinnedId,
        )) {
      _emitShown(replies, curation, answerers: answerers);
      return;
    }
    var pinned = _fetchedPins[pinnedId];
    if (pinned == null) {
      // Apply hides immediately. An older pin can join the current replies
      // once it arrives, without blanking the previews in the meantime.
      if (!waitForPin) _emitShown(replies, curation, answerers: answerers);
      try {
        pinned = await _fetchPin(pinnedId);
      } catch (error, stackTrace) {
        if (isClosed || revision != _curationRevision) return;
        addError(error, stackTrace);
      }
      if (isClosed || revision != _curationRevision) return;
    }
    _emitShown(
      pinned == null
          ? replies
          : VideoResponses(
              // The pin is already among the total replies counted.
              total: replies.total,
              videos: [...replies.videos, pinned],
              totalIsAtLeast: replies.totalIsAtLeast,
            ),
      curation,
      answerers: answerers,
    );
  }

  Future<VideoEvent?> _fetchPin(String pinnedId) async {
    final read = _pinReads.putIfAbsent(
      pinnedId,
      () => _repository.fetchReply(
        pinnedId,
        videoId: _video.id,
        videoAddress: _video.addressableId,
      ),
    );
    try {
      final pinned = await read;
      if (pinned != null) _fetchedPins[pinnedId] = pinned;
      return pinned;
    } finally {
      if (identical(_pinReads[pinnedId], read)) {
        unawaited(_pinReads.remove(pinnedId));
      }
    }
  }

  /// The first video of the chain the Add yours on the video at [address]
  /// counts, [read], and the one a Join answers, [join]: the one it names,
  /// when that video starts a chain with [hashtag]. Otherwise anyone could
  /// name any video as a chain's first and pull answers onto it, so the chain
  /// starts here instead.
  ///
  /// When a relay that did not answer may hold the named video, its chain is
  /// counted but not joined: an answer would cite the wrong first video for
  /// good.
  Future<({String read, String? join, VideoEvent? first})> _chain(
    String address,
    String hashtag,
  ) async {
    final named = _region.promptChainRoot(address);
    if (named == null || named == address) {
      return (read: address, join: address, first: _video);
    }
    final start = await _repository.chainStart(named, hashtag: hashtag);
    if (start == AddYoursChainStart.doesNotStart) {
      return (read: address, join: address, first: _video);
    }
    final first = start.video;
    return (read: named, join: first == null ? null : named, first: first);
  }

  /// Whether the sticker is an Add yours only its creator may answer, by
  /// [audience], whose answers are the parts of their series.
  bool _isSeries(VideoStickerAudience audience) =>
      _region.kind == VideoStickerKind.prompt &&
      audience == VideoStickerAudience.creator;

  /// Who [first], the first video of the chain at [chainRoot], lets answer
  /// it: everyone when it was not read or starts no chain with [hashtag].
  static VideoStickerAudience _chainAudience(
    VideoEvent? first,
    String chainRoot,
    String hashtag,
  ) =>
      first?.stickerRegions
          .where(
            (region) =>
                region.promptChainRoot(chainRoot) == chainRoot &&
                region.promptHashtag == hashtag,
          )
          .firstOrNull
          ?.audience ??
      VideoStickerAudience.everyone;

  /// The one of [a] and [b] that lets fewer answer.
  static VideoStickerAudience _stricter(
    VideoStickerAudience a,
    VideoStickerAudience b,
  ) => _narrowness(a) >= _narrowness(b) ? a : b;

  static int _narrowness(VideoStickerAudience audience) => switch (audience) {
    VideoStickerAudience.everyone => 0,
    VideoStickerAudience.following => 1,
    VideoStickerAudience.creator => 2,
  };

  /// The parts of a series in the order they were posted: [start], the video
  /// it starts at, then [answers], with the video the sticker is on among
  /// them even when it is older than those read, if it passes the same feed
  /// and audience filters as the other parts.
  List<VideoEvent> _seriesOf(
    VideoEvent? start,
    List<VideoEvent> answers,
    StickerAnswerers answerers,
  ) {
    bool isVideo(VideoEvent part) =>
        part.id == _video.id ||
        (_video.addressableId != null &&
            part.addressableId == _video.addressableId);
    final included = (start != null && isVideo(start)) || answers.any(isVideo);
    final current = !included && answerers.admits(_video.pubkey)
        ? _filter([_video]).firstOrNull
        : null;
    final parts = [...answers, ?current]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [?start, ...parts];
  }

  void _emitShown(
    VideoResponses responses,
    RepliesCuration curation, {
    required StickerAnswerers answerers,
    String? chainRoot,
    VideoEvent? seriesStart,
  }) {
    final shown = [
      for (final response in curation.apply(_filter(responses.videos)))
        if (answerers.admits(response.pubkey)) response,
    ];
    final restricted = answerers.audience.isRestricted;
    // What is left out among those read is left out of the count too; the
    // rest of the count was not read, so it stays as it is. Who answered
    // among the rest is not known when only some may answer: those read
    // count, and more may follow.
    final leftOut = responses.videos.length - shown.length;
    emitIfOpen(
      StickerResponsesState(
        status: StickerResponsesStatus.loaded,
        total: restricted
            ? shown.length
            : math.max(shown.length, responses.total - leftOut),
        totalIsAtLeast:
            responses.totalIsAtLeast ||
            (restricted && responses.total > responses.videos.length),
        videos: shown,
        curation: curation,
        chainRoot: chainRoot,
        canAnswer: answerers.admits(_viewer),
        audience: answerers.audience,
        series: _isSeries(answerers.audience)
            ? _seriesOf(
                seriesStart == null ? null : _filter([seriesStart]).firstOrNull,
                shown,
                answerers,
              )
            : const [],
      ),
    );
  }
}
