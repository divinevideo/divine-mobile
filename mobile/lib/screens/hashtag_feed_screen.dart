// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/hashtag_feed/hashtag_feed_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/features/hashtag_follows/view/hashtag_follow_button.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';
import 'package:rxdart/rxdart.dart';
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
  late HashtagFeedCubit _feed;

  @override
  void initState() {
    super.initState();
    _startFeed();
  }

  @override
  void didUpdateWidget(HashtagFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hashtag == widget.hashtag) return;
    _closeFeed();
    _startFeed();
  }

  void _startFeed() {
    final hashtag = widget.hashtag;
    final feed = HashtagFeedCubit(
      fetchPage: (cursor) => ref
          .read(videosRepositoryProvider)
          .getHashtagFeedVideos(hashtag: hashtag, cursor: cursor),
      filterVideos: _applyFeedFilters,
    );
    _feed = feed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _feed != feed) return;
      runDetached(
        _loadHashtagVideos(),
        'load hashtag videos',
        logName: 'HashtagFeedScreen',
        category: LogCategory.video,
      );
    });
  }

  @override
  void dispose() {
    _closeFeed();
    super.dispose();
  }

  void _closeFeed() {
    runDetached(
      _feed.close(),
      'close hashtag feed',
      logName: 'HashtagFeedScreen',
      category: LogCategory.video,
    );
  }

  /// Start independent sources together; neither gates the other.
  Future<void> _loadHashtagVideos({bool refresh = false}) async {
    if (refresh) _clearHashtagCache();
    final hashtagService = ref.read(hashtagServiceProvider);
    unawaited(_subscribeViaWebSocket(hashtagService, widget.hashtag));
    await _feed.refresh();
  }

  void _clearHashtagCache() {
    ref
        .read(videosRepositoryProvider)
        .clearInMemoryFeedCache(
          key: 'hashtag:${widget.hashtag.trim().toLowerCase()}',
        );
  }

  /// Subscribe to hashtag via WebSocket for real-time updates.
  Future<void> _subscribeViaWebSocket(
    HashtagService hashtagService,
    String hashtag,
  ) async {
    try {
      await hashtagService.subscribeToHashtagVideos([hashtag]);
      if (!mounted) return;
      Log.debug(
        '🏷️ HashtagFeedScreen: WebSocket subscription complete for #$hashtag',
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
  List<VideoEvent> _visibleVideos(List<VideoEvent> rankedVideos) {
    final hashtagService = ref.read(hashtagServiceProvider);
    final webSocketVideos = List<VideoEvent>.from(
      hashtagService.getVideosByHashtags([widget.hashtag]),
    );
    // If no Funnelcake data, just sort WebSocket videos locally
    if (rankedVideos.isEmpty) {
      webSocketVideos.sort(VideoEvent.compareByLoopsThenTime);
      return _applyFeedFilters(webSocketVideos);
    }

    final funnelcakeIds = <String>{};
    for (final v in rankedVideos) {
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
    return _applyFeedFilters([...rankedVideos, ...additionalVideos]);
  }

  /// Navigate to fullscreen video feed through the hashtag [ViewSource].
  /// The tapped video id anchors playback when the repository-resolved list
  /// differs from the grid order (fixes #1751).
  void _navigateToFullscreenFeed(
    BuildContext context,
    List<VideoEvent> videoList,
    int index,
    VideoTileOrigin? tileOrigin,
  ) {
    Log.info(
      '🏷️ HashtagFeedScreen TAP: gridIndex=$index, '
      'videoId=${videoList[index].id}',
      category: LogCategory.video,
    );
    final feed = _feed;
    List<VideoEvent> visibleVideos(HashtagFeedState state) =>
        mounted && _feed == feed ? _visibleVideos(state.videos) : videoList;

    final repository = StreamFeedRepository(
      videos: Rx.defer(
        () => feed.stream
            .where((state) => !state.isLoading)
            .map(visibleVideos)
            .startWith(visibleVideos(feed.state)),
      ),
      hasMore: Rx.defer(
        () => feed.stream
            .map((state) => state.nextCursor != null)
            .startWith(feed.state.nextCursor != null)
            .distinct(),
      ),
      onLoadMore: feed.loadMore,
    );
    runDetached(
      PooledFullscreenVideoFeedRouteData(
        video: videoList[index].id,
        $extra: PooledFullscreenVideoFeedArgs(
          source: HashtagViewSource(widget.hashtag),
          feedRepository: repository,
          initialIndex: index,
          initialVideoId: videoList[index].id,
          tileOrigin: tileOrigin,
          contextTitle: '#${widget.hashtag}',
          trafficSource: ViewTrafficSource.search,
          sourceDetail: widget.hashtag,
        ),
      ).push<void>(context),
      'open hashtag video',
      logName: 'HashtagFeedScreen',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The repository parse-gates the REST results, so the cached
    // ranked videos never hold a blocked author — an unblock can only
    // re-show their videos through a refetch. See #948.
    ref.listen<int>(blocklistVersionProvider, (previous, next) {
      if (previous == next || !mounted) return;
      _clearHashtagCache();
      runDetached(
        _feed.refresh(),
        'refresh hashtag videos',
        logName: 'HashtagFeedScreen',
        category: LogCategory.video,
      );
    });

    ref.watch(hashtagServiceProvider);
    // Reapply the visibility policy immediately on block or mute changes.
    ref.watch(blocklistVersionProvider);
    final body = ListenableBuilder(
      listenable: ref.watch(videoEventServiceProvider),
      builder: (context, _) => BlocBuilder<HashtagFeedCubit, HashtagFeedState>(
        bloc: _feed,
        builder: (context, state) {
          final videos = _visibleVideos(state.videos);
          final hasMore = state.nextCursor != null;

          // Cached and live relay results can render while REST is pending.
          if (state.isLoading && videos.isEmpty) {
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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

          if (videos.isEmpty && (state.failed || hasMore)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.failed) ...[
                    Text(context.l10n.feedFailedToLoadVideos),
                    const SizedBox(height: 16),
                  ],
                  DivineButton(
                    label: context.l10n.commonRetry,
                    onPressed: () {
                      runDetached(
                        hasMore
                            ? _feed.loadMore()
                            : _loadHashtagVideos(refresh: true),
                        'load hashtag videos',
                        logName: 'HashtagFeedScreen',
                        category: LogCategory.video,
                      );
                    },
                  ),
                ],
              ),
            );
          }

          if (videos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      // Older events can carry thousands of characters in one
                      // tag; the app bar already ellipsizes, so this does too.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
              ),
            );
          }

          return NotificationListener<OverscrollNotification>(
            onNotification: (notification) {
              // A short grid can have no scroll extent on clamping physics.
              if (hasMore &&
                  !state.isLoading &&
                  notification.depth == 0 &&
                  notification.metrics.axis == Axis.vertical &&
                  notification.dragDetails != null &&
                  notification.overscroll > 0) {
                runDetached(
                  _feed.loadMore(),
                  'load more hashtag videos',
                  logName: 'HashtagFeedScreen',
                  category: LogCategory.video,
                );
              }
              return false;
            },
            child: ComposableVideoGrid(
              videos: videos,
              useMasonryLayout: true,
              onVideoTap: (videoList, index, captureOrigin) {
                final onVideoTap = widget.onVideoTap;
                if (onVideoTap != null) {
                  onVideoTap(videoList, index);
                } else {
                  _navigateToFullscreenFeed(
                    context,
                    videoList,
                    index,
                    captureOrigin(),
                  );
                }
              },
              onRefresh: () => _loadHashtagVideos(refresh: true),
              hasMoreContent: hasMore,
              isLoadingMore: hasMore && state.isLoading,
              onLoadMore: _feed.loadMore,
            ),
          );
        },
      ),
    );

    // If embedded, return body only; otherwise wrap with Scaffold
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: '#${widget.hashtag}',
        customActions: [HashtagFollowButton(hashtag: widget.hashtag)],
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: body,
    );
  }
}
