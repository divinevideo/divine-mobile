// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:unified_logger/unified_logger.dart';

class HashtagFeedScreen extends ConsumerStatefulWidget {
  const HashtagFeedScreen({
    required this.hashtag,
    this.embedded = false,
    this.onVideoTap,
    super.key,
  });
  final String hashtag;
  // If true, don't show Scaffold/AppBar (for embedding in explore)
  final bool embedded;
  // Callback for video navigation when embedded
  final void Function(List<VideoEvent> videos, int index)? onVideoTap;

  @override
  ConsumerState<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends ConsumerState<HashtagFeedScreen> {
  /// Tracks whether we've completed the initial subscription attempt.
  /// Used to show loading state until subscription has been tried.
  bool _subscriptionAttempted = false;

  /// Cached videos from Funnelcake REST API for popularity ordering.
  /// When available, these provide engagement-based sorting.
  List<VideoEvent>? _popularVideos;

  @override
  void initState() {
    super.initState();
    // Subscribe to videos with this hashtag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      _loadHashtagVideos();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Load the fast initial hashtag results first, then detach realtime updates.
  /// This keeps the first paint honest: no empty-state flash before the
  /// initial source has answered, while the websocket subscription still starts
  /// in the background.
  Future<void> _loadHashtagVideos() async {
    if (!mounted) return;

    Log.info(
      '🏷️ HashtagFeedScreen: Loading #${widget.hashtag}',
      category: LogCategory.video,
    );

    final hashtagService = ref.read(hashtagServiceProvider);

    // Wait for the fast initial source before leaving the loading gate.
    // The websocket can continue in the background once the first pass has
    // answered.
    await _fetchFromFunnelcake();
    if (!mounted) return;

    unawaited(_subscribeViaWebSocket(hashtagService));

    setState(() => _subscriptionAttempted = true);
  }

  /// Fetch the interleaved trending+classic hashtag feed from the
  /// repository and update state immediately.
  ///
  /// The repository owns the REST fetch, the trending/classic interleave,
  /// and the block/mute parse-gate, so blocked authors never reach
  /// [_popularVideos] (#948).
  Future<void> _fetchFromFunnelcake() async {
    final repository = ref.read(videosRepositoryProvider);
    final result = await repository.getHashtagFeedVideos(
      hashtag: widget.hashtag,
    );

    if (!mounted) return;

    if (!result.succeeded && _popularVideos != null) {
      Log.debug(
        '🏷️ HashtagFeedScreen: preserving cached Funnelcake videos after '
        'failed refresh for #${widget.hashtag}',
        category: LogCategory.video,
      );
      return;
    }

    final interleaved = result.videos;
    Log.info(
      '🏷️ HashtagFeedScreen: Got ${interleaved.length} interleaved videos '
      'from Funnelcake for #${widget.hashtag}',
      category: LogCategory.video,
    );

    // Update immediately - don't wait for WebSocket
    setState(() {
      _popularVideos = interleaved;
      // Mark as ready to show content if we have videos
      if (interleaved.isNotEmpty) {
        _subscriptionAttempted = true;
      }
    });
  }

  /// Subscribe to hashtag via WebSocket for real-time updates.
  Future<void> _subscribeViaWebSocket(HashtagService hashtagService) async {
    try {
      await hashtagService.subscribeToHashtagVideos([widget.hashtag]);
      if (!mounted) return;
      Log.debug(
        '🏷️ HashtagFeedScreen: WebSocket subscription complete for #${widget.hashtag}',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '🏷️ HashtagFeedScreen: WebSocket subscription failed: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Applies the shared feed filters, including blocked/muted authors and
  /// reposters.
  ///
  /// The REST source is already parse-gated by the repository, so this
  /// seam mainly covers the WebSocket source and hides a just-blocked
  /// account immediately (the [blocklistVersionProvider] watch in [build]
  /// re-runs it). Unblocked authors reappear via the version-triggered
  /// REST refetch in [build]. See #4782, #948.
  List<VideoEvent> _applyFeedFilters(List<VideoEvent> videos) {
    if (videos.isEmpty) return videos;
    final videoEventService = ref.read(videoEventServiceProvider);
    return videoEventService.filterVideoList(
      videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
    );
  }

  /// Combine and sort videos from Funnelcake and WebSocket sources.
  /// Funnelcake videos are shown first (already sorted by popularity).
  /// WebSocket-only videos are appended and sorted by local metrics.
  List<VideoEvent> _combineAndSortVideos(List<VideoEvent> webSocketVideos) {
    // If no Funnelcake data, just sort WebSocket videos locally
    if (_popularVideos == null || _popularVideos!.isEmpty) {
      webSocketVideos.sort(VideoEvent.compareByLoopsThenTime);
      return _applyFeedFilters(webSocketVideos);
    }

    final funnelcakeIds = <String>{};
    for (final v in _popularVideos!) {
      if (v.id.isNotEmpty) funnelcakeIds.add(v.id.toLowerCase());
      if (v.vineId != null && v.vineId!.isNotEmpty) {
        funnelcakeIds.add(v.vineId!.toLowerCase());
      }
    }

    // Find WebSocket videos NOT in Funnelcake results (new/real-time videos)
    // Use case-insensitive comparison to prevent duplicates
    final additionalVideos = <VideoEvent>[];
    for (final video in webSocketVideos) {
      final isInFunnelcake =
          funnelcakeIds.contains(video.id.toLowerCase()) ||
          (video.vineId != null &&
              funnelcakeIds.contains(video.vineId!.toLowerCase()));
      if (!isInFunnelcake) {
        additionalVideos.add(video);
      }
    }

    // Sort additional videos by local popularity
    additionalVideos.sort(VideoEvent.compareByLoopsThenTime);

    // Return Funnelcake videos (already sorted by API) + additional WebSocket
    // videos, with blocked/muted authors removed from both sources.
    return _applyFeedFilters([..._popularVideos!, ...additionalVideos]);
  }

  /// Navigate to fullscreen video feed through the hashtag [ViewSource].
  /// The tapped video id anchors playback when the repository-resolved list
  /// differs from the grid order (fixes #1751).
  void _navigateToFullscreenFeed(
    BuildContext context,
    List<VideoEvent> videoList,
    int index,
  ) {
    Log.info(
      '🏷️ HashtagFeedScreen TAP: gridIndex=$index, '
      'videoId=${videoList[index].id}',
      category: LogCategory.video,
    );
    context.push(
      PooledFullscreenVideoFeedScreen.pathForVideoId(videoList[index].id),
      extra: PooledFullscreenVideoFeedArgs(
        source: HashtagViewSource(widget.hashtag),
        feedRepository: ref.read(feedRepositoryProvider),
        initialIndex: index,
        initialVideoId: videoList[index].id,
        contextTitle: '#${widget.hashtag}',
        trafficSource: ViewTrafficSource.search,
        sourceDetail: widget.hashtag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The repository parse-gates the REST results, so the cached
    // _popularVideos never hold a blocked author — an unblock can only
    // re-show their videos through a refetch. See #948.
    ref.listen<int>(blocklistVersionProvider, (previous, next) {
      if (previous == next || !mounted) return;
      unawaited(_fetchFromFunnelcake());
    });

    final body = Builder(
      builder: (context) {
        Log.debug(
          '🏷️ Building HashtagFeedScreen for #${widget.hashtag}',
          category: LogCategory.video,
        );
        final hashtagService = ref.watch(hashtagServiceProvider);

        // Rebuild when block/unblock/mute actions occur so blocked authors
        // disappear immediately (via _filterBlockedAuthors). See #4782.
        ref.watch(blocklistVersionProvider);

        // Combine Funnelcake videos (fast, pre-sorted) with WebSocket videos
        final webSocketVideos = List<VideoEvent>.from(
          hashtagService.getVideosByHashtags([widget.hashtag]),
        );
        final videos = _combineAndSortVideos(webSocketVideos);

        Log.debug(
          '🏷️ Found ${videos.length} videos for #${widget.hashtag} '
          '(Funnelcake: ${_popularVideos?.length ?? 0}, WebSocket: ${webSocketVideos.length})',
          category: LogCategory.video,
        );

        // Show a full-screen loader only before the initial startup attempt.
        // Once background loading has started, render empty or cached state
        // instead of blocking on relay subscription setup.
        final shouldShowLoading = !_subscriptionAttempted;

        if (shouldShowLoading && videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DivineCircularProgressIndicator(
                  color: VineTheme.vineGreen,
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.hashtagFeedLoadingTitle(widget.hashtag),
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.hashtagFeedLoadingSubtitle,
                  style: TextStyle(
                    color: context.vineColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.tag,
                  size: 64,
                  color: context.vineColors.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.hashtagFeedEmptyTitle(widget.hashtag),
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.hashtagFeedEmptySubtitle,
                  style: TextStyle(
                    color: context.vineColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ComposableVideoGrid(
          videos: videos,
          useMasonryLayout: true,
          onVideoTap:
              widget.onVideoTap ??
              (videoList, index) {
                _navigateToFullscreenFeed(context, videoList, index);
              },
          onRefresh: _loadHashtagVideos,
        );
      },
    );

    // If embedded, return body only; otherwise wrap with Scaffold
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: '#${widget.hashtag}',
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: body,
    );
  }
}
