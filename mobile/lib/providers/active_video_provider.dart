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
import 'package:openvine/utils/video_controller_cleanup.dart';

/// Active video ID derived from router state and app lifecycle
/// Returns null when app is backgrounded or no valid video at current index
/// Route-aware: switches feed provider based on route type
final activeVideoIdProvider = Provider<String?>((ref) {
  // Check app foreground state - be defensive and require explicit foreground signal
  final isFg = ref.watch(appForegroundProvider).maybeWhen(
    data: (v) => v,
    orElse: () => false,  // Default to background if provider not ready
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
    case RouteType.search:
      videosAsync = ref.watch(videosForSearchRouteProvider);
      break;
    case RouteType.notifications:
    case RouteType.camera:
    case RouteType.settings:
    case RouteType.editProfile:
    case RouteType.drafts:
    case RouteType.importKey:
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

/// Auto-cleanup provider that disposes all video controllers when active video changes
/// This ensures only one video can be playing at a time
/// Must be watched at app level to activate
final videoControllerAutoCleanupProvider = Provider<void>((ref) {
  String? previousActiveVideoId;

  // Listen to active video changes and dispose all controllers when it changes
  ref.listen<String?>(
    activeVideoIdProvider,
    (previous, next) {
      // When active video changes, dispose all controllers to ensure clean state
      if (previous != next && previous != null) {
        Log.info(
          '🧹 Active video changed ($previous → $next), disposing all video controllers',
          name: 'VideoControllerCleanup',
          category: LogCategory.video,
        );

        // Dispose all controllers to force clean state
        // The new active video will create its controller fresh
        disposeAllVideoControllers(ref.container);
      }
      previousActiveVideoId = next;
    },
    fireImmediately: false,
  );
});
