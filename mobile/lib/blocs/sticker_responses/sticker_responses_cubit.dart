// ABOUTME: Reads who joined an Add yours or replied to a video for its sticker,
// ABOUTME: filtered like any feed, without the replies its creator hid.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/blocs/close_guard.dart';
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
class StickerResponsesCubit extends Cubit<StickerResponsesState>
    with CloseGuardedEmit<StickerResponsesState> {
  StickerResponsesCubit({
    required VideoResponsesRepository repository,
    required StickerResponsesFilter filter,
    required VideoEvent video,
    required VideoStickerRegion region,
  }) : _repository = repository,
       _filter = filter,
       _video = video,
       _region = region,
       super(const StickerResponsesState());

  final VideoResponsesRepository _repository;
  final StickerResponsesFilter _filter;
  final VideoEvent _video;
  final VideoStickerRegion _region;

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
      _emitShown(responses, curation, chainRoot: chainRoot);
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
    String? chainRoot,
  }) {
    final shown = curation.apply(_filter(responses.videos));
    // What is left out among those read is left out of the count too; the
    // rest of the count was not read, so it stays as it is.
    final leftOut = responses.videos.length - shown.length;
    emitIfOpen(
      StickerResponsesState(
        status: StickerResponsesStatus.loaded,
        total: math.max(shown.length, responses.total - leftOut),
        totalIsAtLeast: responses.totalIsAtLeast,
        videos: shown,
        curation: curation,
        chainRoot: chainRoot,
      ),
    );
  }
}
