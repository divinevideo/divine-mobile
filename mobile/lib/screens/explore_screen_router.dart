// ABOUTME: Router-driven ExploreScreen proof-of-concept
// ABOUTME: Demonstrates URL ↔ PageView sync without lifecycle mutations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _ExploreScreenRouterState extends ConsumerState<ExploreScreenRouter> {
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

    return pageContext.when(
      data: (ctx) {
        // Only handle explore routes
        if (ctx.type != RouteType.explore) {
          return const Center(child: Text('Not an explore route'));
        }

        final urlIndex = ctx.videoIndex ?? 0;

        // Get video data
        final videosAsync = ref.watch(videoEventsProvider);

        return videosAsync.when(
          data: (videos) {
            if (videos.isEmpty) {
              return const Center(child: Text('No videos available'));
            }

            final itemCount = videos.length;

            // Initialize controller once with URL index
            if (_controller == null) {
              final safeIndex = urlIndex.clamp(0, itemCount - 1);
              _controller = PageController(initialPage: safeIndex);
              _lastUrlIndex = safeIndex;
            }

            // Sync controller when URL changes externally (back/forward/deeplink)
            // Use post-frame to avoid calling jumpToPage during build
            if (urlIndex != _lastUrlIndex && _controller!.hasClients) {
              _lastUrlIndex = urlIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_controller!.hasClients) return;
                final safeIndex = urlIndex.clamp(0, itemCount - 1);
                final currentPage = _controller!.page?.round() ?? 0;
                if (currentPage != safeIndex) {
                  _controller!.jumpToPage(safeIndex);
                }
              });
            }

            return PageView.builder(
              controller: _controller,
              itemCount: itemCount,
              onPageChanged: (newIndex) {
                // Guard: only navigate if URL doesn't match
                if (newIndex != urlIndex) {
                  context.go(buildRoute(
                    RouteContext(type: RouteType.explore, videoIndex: newIndex),
                  ));
                }
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
