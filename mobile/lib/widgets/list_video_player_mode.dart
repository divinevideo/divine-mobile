// ABOUTME: Fullscreen playback mode for a video tapped in a list's grid.
// ABOUTME: Shared by the video-list and people-list screens.

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';

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
class ListVideoPlayerMode extends StatelessWidget {
  const ListVideoPlayerMode({
    required this.videos,
    required this.activeIndex,
    required this.listName,
    required this.onExit,
    required this.unavailableMessage,
    this.trafficSource = ViewTrafficSource.unknown,
    super.key,
  });

  final List<VideoEvent> videos;
  final int activeIndex;
  final String listName;
  final VoidCallback onExit;
  final String unavailableMessage;
  final ViewTrafficSource trafficSource;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty || activeIndex >= videos.length) {
      return Center(
        child: Text(
          unavailableMessage,
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
        onExit();
      },
      child: PooledFullscreenVideoFeedScreen(
        source: VideoListViewSource(videos),
        feedRepository: StaticFeedRepository(),
        initialIndex: activeIndex,
        contextTitle: listName,
        trafficSource: trafficSource,
        onBack: onExit,
      ),
    );
  }
}
