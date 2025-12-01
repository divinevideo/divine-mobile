// ABOUTME: Route-aware feed providers that select correct video source per route
// ABOUTME: Enables router-driven screens to reactively get route-appropriate data

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';

/// Temporary provider to hold the explore tab's current video list
/// This is set by ExploreScreen when entering feed mode and consumed by both
/// ExploreVideoScreenPure and activeVideoIdProvider to ensure they use the same list
final exploreTabVideosProvider = StateProvider<List<VideoEvent>?>(
  (ref) => null,
);

/// Provider to persist the current tab index across widget recreation
/// Default to 1 (Popular Videos) as initial state
final exploreTabIndexProvider = StateProvider<int>((ref) => 1);

/// Temporary provider to hold the search screen's current video list
/// This is set by SearchScreenPure when search results are available and consumed
/// by activeVideoIdProvider to enable video playback from search results
final searchScreenVideosProvider = StateProvider<List<VideoEvent>?>(
  (ref) => null,
);

/// Home feed state (follows only)
/// Returns AsyncValue<VideoFeedState> for route-aware home screen
final videosForHomeRouteProvider = Provider<AsyncValue<VideoFeedState>>((ref) {
  final contextAsync = ref.watch(pageContextProvider);

  return contextAsync.when(
    data: (ctx) {
      if (ctx.type != RouteType.home) {
        // Not on home route - return loading
        return const AsyncValue.loading();
      }
      // On home route - return home feed state
      return ref.watch(homeFeedProvider);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Explore feed state (discovery/all videos)
/// Returns AsyncValue<VideoFeedState> for route-aware explore screen
/// Uses tab-specific list when in feed mode, otherwise sorted by loop count
/// Filters out broken videos to match grid UI behavior
final videosForExploreRouteProvider = Provider<AsyncValue<VideoFeedState>>((
  ref,
) {
  final contextAsync = ref.watch(pageContextProvider);

  return contextAsync.when(
    data: (ctx) {
      if (ctx.type != RouteType.explore) {
        // Not on explore route - return loading
        return const AsyncValue.loading();
      }

      // Check if we have a tab-specific list (set when user enters feed mode)
      final tabVideos = ref.watch(exploreTabVideosProvider);
      if (tabVideos != null && tabVideos.isNotEmpty) {
        // Use the tab's sorted list (preserves New Vines/Trending/Editor's Pick sort order)
        return AsyncValue.data(
          VideoFeedState(
            videos: tabVideos,
            hasMoreContent: true,
            lastUpdated: DateTime.now(),
          ),
        );
      }

      // No tab list - use default behavior (loop-count sorted)
      final eventsAsync = ref.watch(videoEventsProvider);
      final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

      return eventsAsync.when(
        data: (videos) {
          // Filter out broken videos to match ComposableVideoGrid behavior
          final filteredVideos = brokenTrackerAsync.maybeWhen(
            data: (tracker) => videos
                .where((video) => !tracker.isVideoBroken(video.id))
                .toList(),
            orElse: () => videos, // No filtering if tracker not ready
          );

          // Sort by loop count (descending) as default
          final sortedVideos = List<VideoEvent>.from(filteredVideos);
          sortedVideos.sort((a, b) {
            final aLoops = a.originalLoops ?? 0;
            final bLoops = b.originalLoops ?? 0;
            return bLoops.compareTo(aLoops); // Descending order
          });
          return AsyncValue.data(
            VideoFeedState(
              videos: sortedVideos,
              hasMoreContent: true,
              lastUpdated: DateTime.now(),
            ),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Search feed state (search results)
/// Returns AsyncValue<VideoFeedState> for route-aware search screen
/// Provides search results as a video feed when on search route
final videosForSearchRouteProvider = Provider<AsyncValue<VideoFeedState>>((
  ref,
) {
  final contextAsync = ref.watch(pageContextProvider);

  return contextAsync.when(
    data: (ctx) {
      if (ctx.type != RouteType.search) {
        // Not on search route - return loading
        return const AsyncValue.loading();
      }

      // Get search results from SearchScreenPure's state provider
      final searchVideos = ref.watch(searchScreenVideosProvider);

      // Return search results wrapped in VideoFeedState
      return AsyncValue.data(
        VideoFeedState(
          videos: searchVideos ?? const [],
          hasMoreContent: false, // Search results are finite
          lastUpdated: DateTime.now(),
        ),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
