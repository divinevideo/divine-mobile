// ABOUTME: Router-aware hashtag screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Router-aware hashtag screen that shows grid or feed based on route
class HashtagScreenRouter extends ConsumerStatefulWidget {
  const HashtagScreenRouter({super.key});

  @override
  ConsumerState<HashtagScreenRouter> createState() =>
      _HashtagScreenRouterState();
}

class _HashtagScreenRouterState extends ConsumerState<HashtagScreenRouter>
    with AsyncValueUIHelpersMixin {
  @override
  Widget build(BuildContext context) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;

    if (routeCtx == null || routeCtx.type != RouteType.hashtag) {
      Log.warning(
        'HashtagScreenRouter: Invalid route context',
        name: 'HashtagRouter',
        category: LogCategory.ui,
      );
      return const Scaffold(body: Center(child: Text('Invalid hashtag route')));
    }

    final hashtag = routeCtx.hashtag ?? 'trending';
    final videoIndex = routeCtx.videoIndex;

    // Grid mode: no video index
    if (videoIndex == null) {
      Log.info(
        'HashtagScreenRouter: Showing grid for #$hashtag',
        name: 'HashtagRouter',
        category: LogCategory.ui,
      );
      return HashtagFeedScreen(hashtag: hashtag, embedded: true);
    }

    // Feed mode: show video at specific index
    Log.info(
      'HashtagScreenRouter: Showing feed for #$hashtag (index=$videoIndex)',
      name: 'HashtagRouter',
      category: LogCategory.ui,
    );

    // Watch the hashtag feed provider to get videos
    final feedStateAsync = ref.watch(hashtagFeedProvider);

    return buildAsyncUI(
      feedStateAsync,
      onLoading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      onError: (err, stack) => Center(
        child: Text(
          'Error loading hashtag videos: $err',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
      ),
      onData: (feedState) {
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

        // Determine target index from route context (index-based routing)
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
          // Add navigation callback to keep hashtag context when swiping
          onNavigate: (index) => context.goHashtag(hashtag, index),
        );
      },
    );
  }
}
