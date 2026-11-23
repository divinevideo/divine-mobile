// ABOUTME: Reads who joined an Add yours or replied to a video for its sticker,
// ABOUTME: filtered like any feed, without the replies its creator hid.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
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
/// whether [viewer] is one of them.
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

  /// Reads the responses.
  Future<void> load() async {
    emit(state.copyWith(status: StickerResponsesStatus.loading));
    try {
      final address = _video.addressableId;
      final VideoResponses responses;
      var curation = const RepliesCuration();
      String? chainRoot;
      // Whoever started the chain an Add yours counts owns who may answer it.
      var owner = _video.pubkey;
      if (_region.kind == VideoStickerKind.replies) {
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
        if (results.length > 1) curation = results[1] as RepliesCuration;
        responses = await _withPinned(replies, curation);
      } else {
        final hashtag = _region.promptHashtag;
        // Answers cite the chain by the key Divine always gave it.
        final chainAddress = _video.divineAddress;
        final chain = chainAddress == null || hashtag == null
            ? null
            : await _chain(chainAddress, hashtag);
        chainRoot = chain?.join;
        if (chain != null) owner = chain.read.split(':')[1];
        responses = chain == null || hashtag == null
            ? const VideoResponses()
            : await _repository.fetchJoined(
                chainRoot: chain.read,
                hashtag: hashtag,
                limit: feedLimit,
                // Before each person's answer is picked; filtering again
                // below changes nothing.
                filter: _filter,
              );
      }
      final answerers = await StickerAnswerers.read(
        _followRepository,
        audience: _region.audience,
        owner: owner,
        viewer: _viewer,
      );
      _emitShown(
        responses,
        curation,
        answerers: answerers,
        chainRoot: chainRoot,
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: StickerResponsesStatus.failure));
    }
  }

  /// [replies] with the reply the creator pinned, read on its own when it is
  /// older than those read: it shows first whatever its age. It is counted
  /// among [replies] already.
  Future<VideoResponses> _withPinned(
    VideoResponses replies,
    RepliesCuration curation,
  ) async {
    final pinnedId = curation.pinnedId;
    if (pinnedId == null ||
        replies.videos.any(
          (reply) =>
              RepliesCuration.keyOf(reply) == pinnedId || reply.id == pinnedId,
        )) {
      return replies;
    }
    final pinned = await _repository.fetchReply(
      pinnedId,
      videoId: _video.id,
      videoAddress: _video.addressableId,
    );
    if (pinned == null) return replies;
    return VideoResponses(
      total: replies.total,
      videos: [...replies.videos, pinned],
      totalIsAtLeast: replies.totalIsAtLeast,
    );
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
  Future<({String read, String? join})> _chain(
    String address,
    String hashtag,
  ) async {
    final named = _region.promptChainRoot(address);
    if (named == null || named == address) {
      return (read: address, join: address);
    }
    return switch (await _repository.chainStart(named, hashtag: hashtag)) {
      AddYoursChainStart.starts => (read: named, join: named),
      AddYoursChainStart.doesNotStart => (read: address, join: address),
      AddYoursChainStart.unconfirmed => (read: named, join: null),
    };
  }

  void _emitShown(
    VideoResponses responses,
    RepliesCuration curation, {
    required StickerAnswerers answerers,
    String? chainRoot,
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
      ),
    );
  }
}
