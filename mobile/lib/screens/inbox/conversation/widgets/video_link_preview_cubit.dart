// ABOUTME: Cubit that resolves the video a DM links to or cites.
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

/// Resolves the [VideoEvent] a [DmVideoTarget] names, by its
/// [DmVideoTarget.routeId] and held to its [DmVideoTarget.routeAuthor].
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
    required DmVideoTarget target,
    required VideosRepository videosRepository,
  }) : _target = target,
       _videosRepository = videosRepository,
       super(const VideoLinkPreviewLoading()) {
    // Schedule as microtask so the first emit happens after callers
    // (BlocProvider, blocTest) have subscribed to the stream.
    resolved = Future.microtask(_resolve);
  }

  final DmVideoTarget _target;
  final VideosRepository _videosRepository;

  /// The same canonical result is used when the play button is tapped during
  /// loading. A disposed card must never open a replacement target.
  late final Future<VideoEvent?> resolved;

  Future<VideoEvent?> get playable =>
      _videosRepository.pendingPlayableRoute(
        _target.routeId,
        expectedAuthor: _target.routeAuthor,
      ) ??
      resolved;

  Future<VideoEvent?> _resolve() async {
    try {
      final video = await _videosRepository.fetchVideoWithStatsForRouteId(
        _target.routeId,
        expectedAuthor: _target.routeAuthor,
      );
      if (isClosed) return null;
      if (video != null) {
        emit(VideoLinkPreviewResolved(video));
        return video;
      }
    } catch (e) {
      Log.warning(
        'Video link preview resolve failed for ${_target.routeId}: $e',
        name: 'VideoLinkPreviewCubit',
        category: LogCategory.ui,
      );
    }

    if (!isClosed) emit(const VideoLinkPreviewNotFound());
    return null;
  }
}
