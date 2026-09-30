// ABOUTME: Paginated videos by every currently accepted holder of one badge.

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:videos_repository/videos_repository.dart';

/// Browse public videos by the accepted holders of [coordinate].
class BadgeVideosScreen extends ConsumerStatefulWidget {
  /// Creates the badge video browser.
  const BadgeVideosScreen({required this.coordinate, super.key});

  /// Route name.
  static const routeName = 'badgeVideos';

  /// Route path.
  static const path = '/badges/b/:naddr/videos';

  /// Path for [coordinate].
  static String pathFor(BadgeCoordinate coordinate) =>
      '/badges/b/${coordinate.toNaddr()}/videos';

  /// Badge whose holders supply the videos.
  final BadgeCoordinate coordinate;

  @override
  ConsumerState<BadgeVideosScreen> createState() => _BadgeVideosScreenState();
}

class _BadgeVideosScreenState extends ConsumerState<BadgeVideosScreen> {
  BadgeVideoPager? _pager;
  List<VideoEvent> _videos = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_reload));
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final holders = await ref
          .read(badgeRepositoryProvider)
          .loadAcceptedHolders(widget.coordinate);
      final pager = ref
          .read(videosRepositoryProvider)
          .createBadgeVideoPager(holders);
      final firstPage = await pager.loadMore();
      if (!mounted) return;
      setState(() {
        _pager = pager;
        _videos = firstPage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final pager = _pager;
    if (pager == null || _loadingMore || !pager.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await pager.loadMore();
      if (!mounted) return;
      setState(() => _videos = [..._videos, ...next]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.feedFailedToLoadVideos,
          error: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(title: context.l10n.profileVideosLabel),
      backgroundColor: context.vineColors.background,
      body: switch ((_loading, _failed)) {
        (true, _) => const Center(child: BrandedLoadingIndicator(size: 60)),
        (_, true) => Center(
          child: DivineButton(
            onPressed: _reload,
            label: context.l10n.feedFailedToLoadVideos,
          ),
        ),
        _ => ComposableVideoGrid(
          videos: _videos,
          useMasonryLayout: true,
          isLoadingMore: _loadingMore,
          hasMoreContent: _pager?.hasMore ?? false,
          onLoadMore: _loadMore,
          onRefresh: _reload,
          emptyBuilder: () => Center(
            child: Text(context.l10n.exploreNoVideosAvailable),
          ),
          onVideoTap: (videos, index) => unawaited(
            context.push(
              PooledFullscreenVideoFeedScreen.pathForVideoId(videos[index].id),
              extra: PooledFullscreenVideoFeedArgs(
                source: VideoListViewSource(videos),
                feedRepository: ref.read(feedRepositoryProvider),
                initialIndex: index,
                initialVideoId: videos[index].id,
                trafficSource: ViewTrafficSource.discoveryBadges,
                sourceDetail: widget.coordinate.value,
              ),
            ),
          ),
        ),
      },
    );
  }
}
