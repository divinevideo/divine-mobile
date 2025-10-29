// ABOUTME: Router-driven active video provider
// ABOUTME: Derives active video ID from URL context, feed state, and app foreground state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Active video ID derived from router state and app lifecycle
/// Returns null when app is backgrounded or no valid video at current index
/// Route-aware: switches feed provider based on route type
final activeVideoIdProvider = Provider<String?>((ref) {
  // Check app foreground state
  final isFg = ref.watch(appForegroundProvider).maybeWhen(
    data: (v) => v,
    orElse: () => true,
  );
  if (!isFg) {
    Log.debug('[ACTIVE] ❌ App not in foreground',
        name: 'ActiveVideoProvider', category: LogCategory.system);
    return null;
  }

  // Get current page context from router
  final ctx = ref.watch(pageContextProvider).asData?.value;
  if (ctx == null) {
    Log.debug('[ACTIVE] ❌ No page context available',
        name: 'ActiveVideoProvider', category: LogCategory.system);
    return null;
  }

  Log.debug('[ACTIVE] 📍 Route context: type=${ctx.type}, videoIndex=${ctx.videoIndex}',
      name: 'ActiveVideoProvider', category: LogCategory.system);

  // Select feed provider based on route type
  AsyncValue<VideoFeedState> videosAsync;
  switch (ctx.type) {
    case RouteType.home:
      videosAsync = ref.watch(videosForHomeRouteProvider);
      break;
    case RouteType.profile:
      videosAsync = ref.watch(videosForProfileRouteProvider);
      break;
    case RouteType.hashtag:
      videosAsync = ref.watch(hashtagFeedProvider);
      break;
    case RouteType.explore:
      videosAsync = ref.watch(videosForExploreRouteProvider);
      break;
    case RouteType.notifications:
    case RouteType.search:
    case RouteType.camera:
    case RouteType.settings:
      // Non-video routes - return null
      Log.debug('[ACTIVE] ❌ Non-video route: ${ctx.type}',
          name: 'ActiveVideoProvider', category: LogCategory.system);
      return null;
  }

  final videos = videosAsync.maybeWhen(
    data: (state) => state.videos,
    orElse: () => const <VideoEvent>[],
  );

  Log.debug('[ACTIVE] 📊 Feed state: videosAsync.hasValue=${videosAsync.hasValue}, videos.length=${videos.length}',
      name: 'ActiveVideoProvider', category: LogCategory.system);

  if (videos.isEmpty) {
    Log.debug('[ACTIVE] ❌ No videos in feed',
        name: 'ActiveVideoProvider', category: LogCategory.system);
    return null;
  }

  // Grid mode (no videoIndex) - no active video
  if (ctx.videoIndex == null) {
    Log.debug('[ACTIVE] ❌ Grid mode (no videoIndex)',
        name: 'ActiveVideoProvider', category: LogCategory.system);
    return null;
  }

  // Get video at current index - videoIndex maps directly to list index
  final idx = ctx.videoIndex!.clamp(0, videos.length - 1);
  final activeVideoId = videos[idx].id;

  Log.info('[ACTIVE] ✅ Active video at index $idx: $activeVideoId',
      name: 'ActiveVideoProvider', category: LogCategory.system);

  return activeVideoId;
});

/// Per-video active state (for efficient VideoFeedItem updates)
/// Returns true if the given videoId matches the current active video
final isVideoActiveProvider = Provider.family<bool, String>((ref, videoId) {
  final activeVideoId = ref.watch(activeVideoIdProvider);
  return activeVideoId == videoId;
});
