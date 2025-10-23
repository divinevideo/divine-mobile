// ABOUTME: Router-aware hashtag screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';
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
      return HashtagFeedScreen(hashtag: hashtag, embedded: true);
    }

    // Feed mode: show video at specific index
    Log.info('HashtagScreenRouter: Showing feed for #$hashtag at index $videoIndex',
        name: 'HashtagRouter', category: LogCategory.ui);

    // Watch the hashtag feed provider to get videos
    final feedStateAsync = ref.watch(hashtagFeedProvider);

    return feedStateAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (err, stack) => Center(
        child: Text(
          'Error loading hashtag videos: $err',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
      ),
      data: (feedState) {
        final videos = feedState.videos;

        if (videos.isEmpty) {
          // Empty state - show centered message
          // AppShell already provides AppBar with back button
          return Center(
            child: Text(
              'No videos found for #$hashtag',
              style: const TextStyle(color: VineTheme.whiteText),
            ),
          );
        }

        // Clamp index to valid range
        final safeIndex = videoIndex.clamp(0, videos.length - 1);

        // Feed mode - show fullscreen video player
        // AppShell already provides AppBar with back button, so no need for Scaffold here
        return ExploreVideoScreenPure(
          startingVideo: videos[safeIndex],
          videoList: videos,
          contextTitle: '#$hashtag',
          startingIndex: safeIndex,
          // Add pagination callback
          onLoadMore: () => ref.read(hashtagFeedProvider.notifier).loadMore(),
        );
      },
    );
  }
}
