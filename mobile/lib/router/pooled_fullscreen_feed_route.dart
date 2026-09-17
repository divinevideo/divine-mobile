// ABOUTME: Builder + redirect for the /pooled-video-feed fullscreen route.
// ABOUTME: Extracted from app_router.dart to keep that file under its size ceiling.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';

/// Redirect target for the fullscreen video feed route.
///
/// The route receives its feed through in-memory `extra` args, which can be
/// discarded on page reload or mobile lifecycle restoration. When that
/// happens, recover the selected video through its durable URL identity.
/// Falls back to the home feed only for legacy URLs with no video identity.
String? fullscreenFeedRedirect(Object? extra, {String? fallbackVideoId}) {
  if (extra is PooledFullscreenVideoFeedArgs ||
      extra is ProfilePooledFullscreenVideoFeedArgs) {
    return null;
  }
  if (fallbackVideoId != null && fallbackVideoId.isNotEmpty) {
    return VideoDetailScreen.pathForId(fallbackVideoId);
  }
  return VideoFeedPage.pathForIndex(0);
}

/// Builds the fullscreen video feed for the matched route, resolving the
/// in-memory `extra` args. The URL identity is also handled here because route
/// state can change between redirect evaluation and builder execution.
Widget buildPooledFullscreenFeed(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  if (extra is PooledFullscreenVideoFeedArgs) {
    return PooledFullscreenVideoFeedScreen(
      source: extra.source,
      feedRepository: extra.feedRepository,
      initialIndex: extra.initialIndex,
      initialVideoId: extra.initialVideoId,
      initialStableId: extra.initialStableId,
      contextTitle: extra.contextTitle,
      sponsorName: extra.sponsorName,
      trafficSource: extra.trafficSource,
      sourceDetail: extra.sourceDetail,
      autoOpenComments: extra.autoOpenComments,
      onPageChanged: extra.onPageChanged,
    );
  }
  if (extra is ProfilePooledFullscreenVideoFeedArgs) {
    return ProfileVideoFeedView(
      userIdHex: extra.userIdHex,
      videoIndex: extra.initialIndex,
      videos: extra.seedVideos,
      initialVideoId: extra.initialVideoId,
      initialStableId: extra.initialStableId,
      contextTitleOverride: extra.contextTitle,
      onPageChanged: extra.onPageChanged,
    );
  }
  final fallbackVideoId = state
      .uri
      .queryParameters[PooledFullscreenVideoFeedScreen.videoQueryParameter];
  if (fallbackVideoId != null && fallbackVideoId.isNotEmpty) {
    return VideoDetailScreen(videoId: fallbackVideoId);
  }
  return RouteErrorScreen(
    message: context.l10n.routeNoVideosToDisplay,
    showBackButton: true,
    onBackPressed: () => context.go(VideoFeedPage.pathForIndex(0)),
  );
}
