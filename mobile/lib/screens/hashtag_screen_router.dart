// ABOUTME: Router-aware hashtag screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Router-aware hashtag screen that shows grid or feed based on route
class HashtagScreenRouter extends ConsumerWidget {
  const HashtagScreenRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;

    if (routeCtx == null || routeCtx.type != RouteType.hashtag) {
      Log.warning('HashtagScreenRouter: Invalid route context',
          name: 'HashtagRouter', category: LogCategory.ui);
      return const Scaffold(
        body: Center(child: Text('Invalid hashtag route')),
      );
    }

    final hashtag = routeCtx.hashtag ?? 'trending';
    final videoIndex = routeCtx.videoIndex;

    // Grid mode: no video index
    if (videoIndex == null) {
      Log.info('HashtagScreenRouter: Showing grid for #$hashtag',
          name: 'HashtagRouter', category: LogCategory.ui);
      return HashtagFeedScreen(hashtag: hashtag);
    }

    // Feed mode: show video at specific index
    Log.info('HashtagScreenRouter: Showing feed for #$hashtag at index $videoIndex',
        name: 'HashtagRouter', category: LogCategory.ui);

    // Watch the hashtag feed provider to get videos
    final feedStateAsync = ref.watch(videosForHashtagRouteProvider);

    return feedStateAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error loading hashtag videos: $err')),
      ),
      data: (feedState) {
        final videos = feedState.videos;

        if (videos.isEmpty) {
          return Scaffold(
            body: Center(child: Text('No videos found for #$hashtag')),
          );
        }

        // Clamp index to valid range
        final safeIndex = videoIndex.clamp(0, videos.length - 1);

        return ExploreVideoScreenPure(
          startingVideo: videos[safeIndex],
          videoList: videos,
          contextTitle: '#$hashtag',
          startingIndex: safeIndex,
          // TODO: Add pagination callback when we implement loadMore for hashtags
        );
      },
    );
  }
}
