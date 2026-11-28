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
    bool Function(VideoEvent video) isHidden = _neverHidden,
    String? Function() currentAccount = _noAccount,
  }) : _target = target,
       _videosRepository = videosRepository,
       _isHidden = isHidden,
       _currentAccount = currentAccount,
       super(const VideoLinkPreviewLoading()) {
    // Schedule as microtask so the first emit happens after callers
    // (BlocProvider, blocTest) have subscribed to the stream.
    resolved = Future.microtask(_resolve);
  }

  static bool _neverHidden(VideoEvent video) => false;

  static String? _noAccount() => null;

  final DmVideoTarget _target;
  final VideosRepository _videosRepository;
  final bool Function(VideoEvent video) _isHidden;
  final String? Function() _currentAccount;

  /// The same canonical result is used when the play button is tapped during
  /// loading. A disposed card must never open a replacement target.
  late final Future<VideoEvent?> resolved;

  Future<VideoEvent?> get playable =>
      _videosRepository.pendingPlayableRoute(
        _target.routeId,
        expectedAuthor: _target.routeAuthor,
      ) ??
      resolved;

  /// Whether moderation or a known deletion keeps [video] off the card.
  bool hides(VideoEvent video) => _isHidden(video);

  /// The video a Play tap opens, waiting for the lookup when the card is
  /// still loading. Null when nothing resolves, the video is hidden, or the
  /// signed-in account changed while the lookup was pending.
  Future<VideoEvent?> videoToOpen() async {
    final account = _currentAccount();
    final video = switch (state) {
      VideoLinkPreviewResolved(:final video) => video,
      _ => await playable,
    };
    if (video == null || _isHidden(video) || _currentAccount() != account) {
      return null;
    }
    return video;
  }

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
