// ABOUTME: Fullscreen playback mode for a video tapped in a list's grid.
// ABOUTME: Shared by the video-list and people-list screens.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:rxdart/rxdart.dart';

/// Fullscreen playback of [videos] from [activeIndex], embedded as a list
/// screen's "video mode".
///
/// Both the feed's own app-bar back button and the system back gesture call
/// [onExit], which returns the screen to its grid instead of popping the
/// whole route, so the user sees a single back button and hardware back
/// stays consistent with it. The feed's bar carries [listName]; nothing else
/// is drawn over the player.
///
/// [unavailableMessage] takes the player's place when [activeIndex] no
/// longer names a video, as after the list shrank under it.
class ListVideoPlayerMode extends StatefulWidget {
  const ListVideoPlayerMode({
    required this.videos,
    required this.activeIndex,
    required this.listName,
    required this.onExit,
    required this.unavailableMessage,
    this.trafficSource = ViewTrafficSource.unknown,
    this.followListUpdates = false,
    super.key,
  });

  final List<VideoEvent> videos;
  final int activeIndex;
  final String listName;
  final VoidCallback onExit;
  final String unavailableMessage;
  final ViewTrafficSource trafficSource;

  /// Feeds newly resolved videos into the existing playback session.
  final bool followListUpdates;

  @override
  State<ListVideoPlayerMode> createState() => _ListVideoPlayerModeState();
}

class _ListVideoPlayerModeState extends State<ListVideoPlayerMode> {
  late final int _initialIndex = widget.activeIndex;
  late final VideoEvent _initialVideo = widget.videos[_initialIndex];
  BehaviorSubject<List<VideoEvent>>? _videoUpdates;
  FeedRepository? _liveRepository;

  @override
  void initState() {
    super.initState();
    if (widget.followListUpdates && _initialIndex < widget.videos.length) {
      final updates = BehaviorSubject.seeded(widget.videos);
      _videoUpdates = updates;
      _liveRepository = StreamFeedRepository(videos: updates.stream);
    }
  }

  @override
  void didUpdateWidget(covariant ListVideoPlayerMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.videos, widget.videos)) {
      _videoUpdates?.add(widget.videos);
    }
  }

  @override
  void dispose() {
    unawaited(_videoUpdates?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveRepository = _liveRepository;
    if (liveRepository == null && widget.activeIndex >= widget.videos.length) {
      return Center(
        child: Text(
          widget.unavailableMessage,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onExit();
      },
      child: PooledFullscreenVideoFeedScreen(
        source: VideoListViewSource(widget.videos),
        feedRepository: liveRepository ?? StaticFeedRepository(),
        initialIndex: liveRepository == null
            ? widget.activeIndex
            : _initialIndex,
        initialVideoId: liveRepository == null ? null : _initialVideo.id,
        contextTitle: widget.listName,
        trafficSource: widget.trafficSource,
        onBack: widget.onExit,
      ),
    );
  }
}
