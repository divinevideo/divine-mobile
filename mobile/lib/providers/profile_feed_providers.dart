// ABOUTME: Route-aware profile feed provider (reactive, no lifecycle writes)
// ABOUTME: Returns videos for a specific user's profile based on route context

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Route-aware profile feed (reactive, no lifecycle writes).
final videosForProfileRouteProvider = Provider<AsyncValue<VideoFeedState>>((
  ref,
) {
  final ctx = ref.watch(pageContextProvider).asData?.value;
  Log.info(
    'PROFILE_FEED enter: ctx.npub=${ctx?.npub}',
    name: 'Provider',
    category: LogCategory.system,
  );
  if (ctx == null || ctx.type != RouteType.profile) {
    return AsyncValue.data(
      VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      ),
    );
  }

  // Route param: /profile/:npub/:index
  final npub = (ctx.npub ?? '').trim();
  final hex = npubToHexOrNull(npub);
  if (hex == null) {
    return AsyncValue.data(
      VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      ),
    );
  }

  // Subscribe (service manages lifecycle internally; this is idempotent)
  final svc = ref.watch(videoEventServiceProvider);
  svc.subscribeToUserVideos(hex, limit: 100);
  Log.info(
    'ProfileFeedProvider: subscribed to user=$hex',
    name: 'ProfileFeedProvider',
    category: LogCategory.system,
  );

  // REACTIVE selection: rebuilds when service updates the list for this author
  final items = ref.watch(
    videoEventServiceProvider.select((s) => s.authorVideos(hex)),
  );
  Log.info(
    'PROFILE_FEED selected items=${items.length}',
    name: 'Provider',
    category: LogCategory.system,
  );

  return AsyncValue.data(
    VideoFeedState(videos: items, hasMoreContent: false, isLoadingMore: false),
  );
});
