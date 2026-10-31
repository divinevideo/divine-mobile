// ABOUTME: Opens the full-screen feed of the videos responding to a video: its
// ABOUTME: video replies, or the answers to its Add yours.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Opens [videos] in the full-screen feed at [index], counted in the views
/// as coming from [sourceDetail]. The feed applies the viewer's blocks and
/// content filters, as every feed does.
Future<void> openVideoResponsesFeed(
  BuildContext context, {
  required FeedRepository feedRepository,
  required List<VideoEvent> videos,
  required String sourceDetail,
  int index = 0,
}) async {
  if (videos.isEmpty) return;
  final start = index.clamp(0, videos.length - 1);
  await context.pushWithVideoPause<void>(
    PooledFullscreenVideoFeedScreen.pathForVideoId(videos[start].id),
    extra: PooledFullscreenVideoFeedArgs(
      source: VideoListViewSource(videos),
      feedRepository: feedRepository,
      initialIndex: start,
      initialVideoId: videos[start].id,
      sourceDetail: sourceDetail,
    ),
  );
}
