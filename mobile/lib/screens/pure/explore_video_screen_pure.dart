// ABOUTME: Pure explore video screen using VideoFeedItem directly in PageView
// ABOUTME: Simplified implementation with direct VideoFeedItem usage

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/mixins/pagination_mixin.dart';

/// Pure explore video screen using VideoFeedItem directly in PageView
class ExploreVideoScreenPure extends ConsumerStatefulWidget {
  const ExploreVideoScreenPure({
    super.key,
    required this.startingVideo,
    required this.videoList,
    required this.contextTitle,
    this.startingIndex,
    this.onLoadMore,
    this.onNavigate,
    this.useLocalActiveState = false,
  });

  final VideoEvent startingVideo;
  final List<VideoEvent> videoList;
  final String contextTitle;
  final int? startingIndex;
  final VoidCallback? onLoadMore;
  final void Function(int index)? onNavigate;

  /// When true, manages active video state locally instead of via URL routing.
  /// Used for custom contexts like lists that don't have router support.
  /// When true, videos will auto-play based on page position without URL changes.
  final bool useLocalActiveState;

  @override
  ConsumerState<ExploreVideoScreenPure> createState() =>
      _ExploreVideoScreenPureState();
}

class _ExploreVideoScreenPureState extends ConsumerState<ExploreVideoScreenPure>
    with PaginationMixin, VideoPrefetchMixin {
  late int _initialIndex;
  late int _currentPage; // Track current page for local active state management

  @override
  void initState() {
    super.initState();

    // Find starting video index in the tab-specific list passed from parent
    _initialIndex =
        widget.startingIndex ??
        widget.videoList.indexWhere(
          (video) => video.id == widget.startingVideo.id,
        );

    if (_initialIndex == -1) {
      _initialIndex = 0; // Fallback to first video
    }

    _currentPage = _initialIndex;

    Log.info(
      '🎯 ExploreVideoScreenPure: Initialized with ${widget.videoList.length} videos, starting at index $_initialIndex, useLocalActiveState=${widget.useLocalActiveState}',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    // Router-driven state - no manual cleanup needed, URL navigation handles it
    Log.info(
      '🛑 ExploreVideoScreenPure disposing - router handles state cleanup',
      name: 'ExploreVideoScreen',
      category: LogCategory.video,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the tab-specific sorted list from parent (maintains sort order from grid)
    // Apply broken video filter if available
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    final videos = brokenTrackerAsync.maybeWhen(
      data: (tracker) => widget.videoList
          .where((video) => !tracker.isVideoBroken(video.id))
          .toList(),
      orElse: () => widget.videoList, // No filtering if tracker not ready
    );

    if (videos.isEmpty) {
      return const Center(child: Text('No videos available'));
    }

    // Use tab-specific video list from parent (preserves grid sort order)
    return Container(
      color: Colors.black,
      child: PageView.builder(
        itemCount: videos.length,
        controller: PageController(initialPage: _initialIndex),
        scrollDirection: Axis.vertical,
        onPageChanged: (index) {
          Log.debug(
            '📄 Page changed to index $index (${videos[index].id}...)',
            name: 'ExploreVideoScreen',
            category: LogCategory.video,
          );

          // Update current page for local state management
          if (widget.useLocalActiveState) {
            setState(() {
              _currentPage = index;
            });
          }

          // Update URL to trigger reactive video playback via router
          // Use custom navigation callback if provided, otherwise default to explore
          // Skip URL navigation when using local active state
          if (widget.onNavigate != null) {
            widget.onNavigate!(index);
          } else if (!widget.useLocalActiveState) {
            context.goExplore(index);
          }

          // Trigger pagination when near the end if callback provided
          if (widget.onLoadMore != null) {
            checkForPagination(
              currentIndex: index,
              totalItems: videos.length,
              onLoadMore: widget.onLoadMore!,
            );
          }

          // Prefetch videos around current index
          checkForPrefetch(currentIndex: index, videos: videos);
        },
        itemBuilder: (context, index) {
          return VideoFeedItem(
            key: ValueKey('video-${videos[index].id}'),
            video: videos[index],
            index: index,
            hasBottomNavigation: false,
            contextTitle: widget.contextTitle,
            // When using local active state, override provider-based activation
            isActiveOverride: widget.useLocalActiveState
                ? (_currentPage == index)
                : null,
            disableTapNavigation: widget.useLocalActiveState,
          );
        },
      ),
    );
  }
}
