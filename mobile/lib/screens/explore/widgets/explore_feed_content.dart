// ABOUTME: In-explore fullscreen feed that streams exploreTabVideosProvider
// ABOUTME: updates into the pooled fullscreen video feed.

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';

/// Streams [exploreTabVideosProvider] updates into
/// [PooledFullscreenVideoFeedScreen] so pagination appends are visible.
class ExploreFeedContent extends ConsumerStatefulWidget {
  /// Creates the in-explore fullscreen feed starting at [startIndex].
  const ExploreFeedContent({required this.startIndex, super.key});

  /// Index of the video to open first.
  final int startIndex;

  @override
  ConsumerState<ExploreFeedContent> createState() => _ExploreFeedContentState();
}

class _ExploreFeedContentState extends ConsumerState<ExploreFeedContent> {
  @override
  Widget build(BuildContext context) {
    // Both counters, because filterVideoList below applies the Divine-host,
    // content-label, and video-shape preferences, and exploreTabVideosProvider
    // is a plain StateProvider that a toggle does not invalidate.
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(contentFilterVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    final videos = videoEventService.filterVideoList(
      ref.watch(exploreTabVideosProvider) ?? const <VideoEvent>[],
    );

    if (videos.isEmpty) {
      return Center(
        child: Text(
          context.l10n.exploreNoVideosAvailable,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
      );
    }

    final safeIndex = widget.startIndex.clamp(0, videos.length - 1);

    return PooledFullscreenVideoFeedScreen(
      source: const ExploreViewSource(),
      feedRepository: ref.read(feedRepositoryProvider),
      initialIndex: safeIndex,
      initialVideoId: videos[safeIndex].id,
      contextTitle: '',
      onPageChanged: (index) => context.go(ExploreScreen.pathForIndex(index)),
    );
  }
}
