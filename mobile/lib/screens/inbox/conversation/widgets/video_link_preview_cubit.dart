// ABOUTME: Cubit that resolves a video from a divine.video stableId.
// ABOUTME: Delegates to VideosRepository so the resolved event carries the
// ABOUTME: REST-hydrated loop/view counts, not a bare relay event.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

/// State for [VideoLinkPreviewCubit].
sealed class VideoLinkPreviewState extends Equatable {
  const VideoLinkPreviewState();

  @override
  List<Object?> get props => [];
}

class VideoLinkPreviewLoading extends VideoLinkPreviewState {
  const VideoLinkPreviewLoading();
}

class VideoLinkPreviewResolved extends VideoLinkPreviewState {
  const VideoLinkPreviewResolved(this.video);

  final VideoEvent video;

  @override
  List<Object?> get props => [video.id];
}

class VideoLinkPreviewNotFound extends VideoLinkPreviewState {
  const VideoLinkPreviewNotFound();
}

/// Resolves a [VideoEvent] from a `divine.video/video/{stableId}` reference.
///
/// Resolution is delegated to [VideosRepository.fetchVideoWithStatsForRouteId],
/// the same canonical resolver the video-detail screen and deep-link paths use.
/// That path runs local cache → Funnelcake REST → relay across every acceptable
/// video kind, and — crucially for the loop counter — enriches the event with
/// REST-sourced view/loop stats. Resolving a bare relay event here instead
/// (the previous implementation) left `rawTags['views']` empty, so a shared
/// video's card and detail screen showed `0 loops` (see #5844).
class VideoLinkPreviewCubit extends Cubit<VideoLinkPreviewState> {
  VideoLinkPreviewCubit({
    required String videoStableId,
    required VideosRepository videosRepository,
    String? authorPubkey,
    int? videoKind,
  }) : _videoStableId = videoStableId,
       _authorPubkey = authorPubkey,
       _videoKind = videoKind,
       _videosRepository = videosRepository,
       super(const VideoLinkPreviewLoading()) {
    // Schedule as microtask so the first emit happens after callers
    // (BlocProvider, blocTest) have subscribed to the stream.
    Future.microtask(_resolve);
  }

  final String _videoStableId;
  final String? _authorPubkey;
  final int? _videoKind;
  final VideosRepository _videosRepository;

  Future<void> _resolve() async {
    try {
      final target = DmVideoTarget(
        stableId: _videoStableId,
        authorPubkey: _authorPubkey,
        videoKind: _videoKind,
      );
      final video = await _videosRepository.fetchVideoWithStatsForRouteId(
        target.stableId,
        fallbackRouteIds: target.fallbackRouteIds,
      );
      if (isClosed) return;
      if (video != null) {
        emit(VideoLinkPreviewResolved(video));
        return;
      }
    } catch (e) {
      Log.warning(
        'Video link preview resolve failed for $_videoStableId: $e',
        name: 'VideoLinkPreviewCubit',
        category: LogCategory.ui,
      );
    }

    if (!isClosed) emit(const VideoLinkPreviewNotFound());
  }
}
