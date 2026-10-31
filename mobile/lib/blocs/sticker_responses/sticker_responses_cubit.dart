// ABOUTME: Reads who joined an Add yours or replied to a video for its sticker,
// ABOUTME: leaving out the blocked, and the replies its creator hid.

import 'dart:math' as math;

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/blocs/close_guard.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

part 'sticker_responses_state.dart';

/// Reads the responses an Add yours or replies sticker on [video] shows.
///
/// Someone the viewer blocked, or who blocked them, is left out, and so are
/// the replies the video's creator hid; the reply they pinned comes first.
class StickerResponsesCubit extends Cubit<StickerResponsesState>
    with CloseGuardedEmit<StickerResponsesState> {
  StickerResponsesCubit({
    required VideoResponsesRepository repository,
    required ContentBlocklistRepository blocklistRepository,
    required VideoEvent video,
    required VideoStickerRegion region,
  }) : _repository = repository,
       _blocklistRepository = blocklistRepository,
       _video = video,
       _region = region,
       super(const StickerResponsesState());

  final VideoResponsesRepository _repository;
  final ContentBlocklistRepository _blocklistRepository;
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
        responses = results.first as VideoResponses;
        if (results.length > 1) curation = results[1] as RepliesCuration;
      } else {
        final chainRoot = _region.promptChainRoot(address ?? '');
        final hashtag = _region.promptHashtag;
        responses = chainRoot == null || chainRoot.isEmpty || hashtag == null
            ? const VideoResponses()
            : await _repository.fetchJoined(
                chainRoot: chainRoot,
                hashtag: hashtag,
                limit: feedLimit,
              );
      }
      _emitShown(responses, curation);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: StickerResponsesStatus.failure));
    }
  }

  void _emitShown(VideoResponses responses, RepliesCuration curation) {
    final shown = curation.apply([
      for (final video in responses.videos)
        if (!_blocklistRepository.isBlocked(video.pubkey) &&
            !_blocklistRepository.hasBlockedUs(video.pubkey))
          video,
    ]);
    // What is left out among those read is left out of the count too; the
    // rest of the count was not read, so it stays as it is.
    final leftOut = responses.videos.length - shown.length;
    emitIfOpen(
      StickerResponsesState(
        status: StickerResponsesStatus.loaded,
        total: math.max(shown.length, responses.total - leftOut),
        videos: shown,
        curation: curation,
      ),
    );
  }
}
