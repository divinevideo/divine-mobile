// ABOUTME: Opens the full-screen feed of the videos responding to a video: its
// ABOUTME: video replies, or the answers to its Add yours.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Opens [videos] in the full-screen feed at [index] under [title], counted
/// in the views as coming from [sourceDetail].
///
/// The feed itself applies only the viewer's blocks and source preferences.
/// Content filters and the content warnings it shows come with [videos]: pass
/// them through `stickerResponsesFilterProvider` first, as the stickers do.
Future<void> openVideoResponsesFeed(
  BuildContext context, {
  required FeedRepository feedRepository,
  required List<VideoEvent> videos,
  required String title,
  required String sourceDetail,
  int index = 0,
}) async {
  if (videos.isEmpty) return;
  final start = index.clamp(0, videos.length - 1);
  await context.pushWithVideoPause<void>(
    PooledFullscreenVideoFeedRouteData(video: videos[start].id).location,
    extra: PooledFullscreenVideoFeedArgs(
      source: VideoListViewSource(videos),
      feedRepository: feedRepository,
      initialIndex: start,
      initialVideoId: videos[start].id,
      contextTitle: title,
      sourceDetail: sourceDetail,
    ),
  );
}
