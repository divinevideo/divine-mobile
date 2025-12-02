// ABOUTME: Router-driven ExploreScreen proof-of-concept
// ABOUTME: Demonstrates URL ↔ PageView sync without lifecycle mutations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/providers/video_events_providers.dart';

/// Router-driven ExploreScreen - PageView syncs with URL bidirectionally
class ExploreScreenRouter extends ConsumerStatefulWidget {
  const ExploreScreenRouter({super.key});

  @override
  ConsumerState<ExploreScreenRouter> createState() =>
      _ExploreScreenRouterState();
}

class _ExploreScreenRouterState extends ConsumerState<ExploreScreenRouter>
    with VideoPrefetchMixin, PageControllerSyncMixin, AsyncValueUIHelpersMixin {
  PageController? _controller;
  int? _lastUrlIndex;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    return buildAsyncUI(
      pageContext,
      onData: (ctx) {
        // Only handle explore routes
        if (ctx.type != RouteType.explore) {
          return const Center(child: Text('Not an explore route'));
        }

        int urlIndex = 0;

        // Get video data
        final videosAsync = ref.watch(videoEventsProvider);

        return buildAsyncUI(
          videosAsync,
          onData: (videos) {
            if (videos.isEmpty) {
              return const Center(child: Text('No videos available'));
            }

            // Determine target index from route context (index-based routing)
            urlIndex = (ctx.videoIndex ?? 0).clamp(0, videos.length - 1);

            final itemCount = videos.length;

            // Initialize controller once with URL index
            if (_controller == null) {
              final safeIndex = urlIndex.clamp(0, itemCount - 1);
              _controller = PageController(initialPage: safeIndex);
              _lastUrlIndex = safeIndex;
            }

            // Sync controller when URL changes externally (back/forward/deeplink)
            // OR when videos list changes (e.g., provider reloads)
            if (shouldSync(
              urlIndex: urlIndex,
              lastUrlIndex: _lastUrlIndex,
              controller: _controller,
              targetIndex: urlIndex.clamp(0, itemCount - 1),
            )) {
              _lastUrlIndex = urlIndex;
              syncPageController(
                controller: _controller!,
                targetIndex: urlIndex,
                itemCount: itemCount,
              );
            }

            return PageView.builder(
              controller: _controller,
              itemCount: itemCount,
              onPageChanged: (newIndex) {
                // Guard: only navigate if URL doesn't match
                if (newIndex != urlIndex) {
                  // Use event-based routing
                  context.go(
                    buildRoute(
                      RouteContext(
                        type: RouteType.explore,
                        videoIndex: newIndex,
                      ),
                    ),
                  );
                }

                // Prefetch videos around current index
                checkForPrefetch(currentIndex: newIndex, videos: videos);
              },
              itemBuilder: (context, index) {
                final video = videos[index];
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Video ${index + 1}/${videos.length}',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 16),
                      Text('ID: ${video.id}'),
                      Text('Title: ${video.title ?? video.content}'),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
