// ABOUTME: Whether the viewer may reply to a video with a video of their own:
// ABOUTME: always, unless its replies sticker lets only some answer.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/sticker_responses/sticker_answerers.dart';

/// Whether the viewer may reply with a video.
enum VideoReplyGate {
  /// They may.
  allowed,

  /// Who may answer the video's replies sticker is being read.
  checking,

  /// They may not, or who may could not be read.
  denied,
}

/// Holds whether [viewer] may reply to [video] with a video.
///
/// Anyone may, unless the video's replies sticker lets only its creator or
/// the people they follow answer; see [VideoStickerRegion.audience]. A video
/// reply from anyone else would not show on the sticker anyway.
class VideoReplyGateCubit extends Cubit<VideoReplyGate>
    with CloseGuardedEmit<VideoReplyGate> {
  VideoReplyGateCubit({
    required FollowRepository followRepository,
    required VideoEvent video,
    String? viewer,
  }) : _followRepository = followRepository,
       _video = video,
       _viewer = viewer,
       super(_initial(video, viewer));

  final FollowRepository _followRepository;
  final VideoEvent _video;
  final String? _viewer;

  static VideoReplyGate _initial(VideoEvent video, String? viewer) {
    final region = _restrictedReplies(video);
    if (region == null) return VideoReplyGate.allowed;
    if (viewer == null) return VideoReplyGate.denied;
    return viewer.toLowerCase() == video.pubkey.toLowerCase()
        ? VideoReplyGate.allowed
        : VideoReplyGate.checking;
  }

  /// Whether only some may reply to [video] with a video.
  static bool isGated(VideoEvent video) => _restrictedReplies(video) != null;

  /// The video's replies sticker only some may answer, or `null`.
  static VideoStickerRegion? _restrictedReplies(VideoEvent video) => video
      .stickerRegions
      .where(
        (region) =>
            region.kind == VideoStickerKind.replies &&
            region.audience.isRestricted,
      )
      .firstOrNull;

  /// Reads whether the viewer may answer, while that is not known.
  Future<void> check() async {
    final region = _restrictedReplies(_video);
    if (state != VideoReplyGate.checking || region == null) return;
    try {
      final answerers = await StickerAnswerers.read(
        _followRepository,
        audience: region.audience,
        owner: _video.pubkey,
        viewer: _viewer,
      );
      emitIfOpen(
        answerers.admits(_viewer)
            ? VideoReplyGate.allowed
            : VideoReplyGate.denied,
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(VideoReplyGate.denied);
    }
  }
}
