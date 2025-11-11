// ABOUTME: Explore screen with proper Vine theme and video grid functionality
// ABOUTME: Pure Riverpod architecture for video discovery with grid/feed modes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/error_analytics_tracker.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';

/// Pure ExploreScreen using revolutionary Riverpod architecture
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Feed mode and videos are now derived from URL + providers - no internal state needed
  String? _hashtagMode;  // When non-null, showing hashtag feed
  String? _customTitle;  // Custom title to override default "Explore"

  // Analytics services
  final _screenAnalytics = ScreenAnalyticsService();
  final _feedTracker = FeedPerformanceTracker();
  final _errorTracker = ErrorAnalyticsTracker();
  DateTime? _feedLoadStartTime;

  // Trending tab sort cache - avoid re-sorting 500 videos on every rebuild
  List<VideoEvent>? _cachedTrendingVideos;
  List<VideoEvent>? _lastRawVideos;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1); // Start on Popular Videos
    _tabController.addListener(_onTabChanged);

    // Track screen load
    _screenAnalytics.startScreenLoad('explore_screen');
    _screenAnalytics.trackScreenView('explore_screen');

    // Load top hashtags for trending navigation
    _loadHashtags();

    Log.info('🎯 ExploreScreenPure: Initialized with revolutionary architecture',
        category: LogCategory.video);

    // Listen for tab changes - no need to clear active video (router-driven now)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      ref.listenManual(
        tabVisibilityProvider,
        (prev, next) {
          if (next != 2) {
            // This tab (Explore = tab 2) is no longer visible
            Log.info('🔄 Tab 2 (Explore) hidden',
                name: 'ExploreScreen', category: LogCategory.ui);
          }
        },
      );
    });
  }

  Future<void> _loadHashtags() async {
    Log.info('🏷️ ExploreScreen: Starting hashtag load',
        category: LogCategory.video);
    await TopHashtagsService.instance.loadTopHashtags();
    final count = TopHashtagsService.instance.topHashtags.length;
    Log.info('🏷️ ExploreScreen: Hashtags loaded: $count total, isLoaded=${TopHashtagsService.instance.isLoaded}',
        category: LogCategory.video);

    // Trigger UI update to show loaded hashtags immediately
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();

    Log.info('🎯 ExploreScreenPure: Disposed cleanly',
        category: LogCategory.video);
  }

  void _onTabChanged() {
    if (!mounted) return;

    final tabNames = ['new_videos', 'popular_videos', 'editors_pick'];
    final tabName = tabNames[_tabController.index];

    Log.debug('🎯 ExploreScreenPure: Switched to tab ${_tabController.index}',
        category: LogCategory.video);

    // Track tab change
    _screenAnalytics.trackTabChange(
      screenName: 'explore_screen',
      tabName: tabName,
    );

    // Refresh editor's picks when that tab becomes active
    // This ensures the provider checks for newly fetched videos
    if (_tabController.index == 2) { // Editor's Pick tab
      Log.debug('🔄 Refreshing editor\'s picks provider on tab change',
          category: LogCategory.video);
      ref.read(curationProvider.notifier).refreshAll();
    }

    // Exit feed or hashtag mode when user switches tabs
    _resetToDefaultState();
  }

  void _resetToDefaultState() {
    if (!mounted) return;

    // Check current page context to see if we need to reset
    final pageContext = ref.read(pageContextProvider);
    final shouldReset = pageContext.whenOrNull(
      data: (ctx) => ctx.videoIndex != null || _hashtagMode != null,
    ) ?? false;

    if (shouldReset) {
      // Clear hashtag mode
      _hashtagMode = null;
      setCustomTitle(null);  // Clear custom title

      // Navigate back to grid mode (no videoIndex) - URL will drive UI state
      // Note: This navigation resets to the grid view, preserving the current tab
      // because TabController's index persists across route changes
      context.go('/explore');

      Log.info('🎯 ExploreScreenPure: Reset to default state',
          category: LogCategory.video);
    }
  }

  // Public method that can be called when same tab is tapped
  void onTabTapped() {
    _resetToDefaultState();
  }


  void _enterFeedMode(List<VideoEvent> videos, int startIndex) {
    if (!mounted) return;

    // Store video list in provider so it survives widget recreation
    ref.read(exploreTabVideosProvider.notifier).state = videos;

    // Navigate to update URL - URL will drive the UI state (no internal state needed!)
    // videoIndex maps directly to list index (0=first video, 1=second video)
    context.goExplore(startIndex);

    Log.info('🎯 ExploreScreenPure: Entered feed mode at index $startIndex with ${videos.length} videos',
        category: LogCategory.video);
  }

  void _exitFeedMode() {
    if (!mounted) return;

    // Clear the tab video list provider
    ref.read(exploreTabVideosProvider.notifier).state = null;

    // Navigate back to grid mode (no videoIndex) - URL will drive UI state
    context.go('/explore');

    Log.info('🎯 ExploreScreenPure: Exited feed mode via URL navigation',
        category: LogCategory.video);
  }

  void _enterHashtagMode(String hashtag) {
    if (!mounted) return;

    setState(() {
      _hashtagMode = hashtag;
    });

    setCustomTitle('#$hashtag');

    Log.info('🎯 ExploreScreenPure: Entered hashtag mode for #$hashtag',
        category: LogCategory.video);
  }


  @override
  Widget build(BuildContext context) {
    // Always show Column with TabBar + content
    return Column(
      children: [
        // Tabs always visible
        Container(
          color: VineTheme.cardBackground,
          child: TabBar(
            controller: _tabController,
            indicatorColor: VineTheme.whiteText,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: VineTheme.whiteText,
            unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            onTap: (index) {
              // If tapping the currently active tab, reset to default state (exit feed/hashtag mode)
              // But only if we're actually in feed or hashtag mode - otherwise do nothing
              if (index == _tabController.index) {
                final pageContext = ref.read(pageContextProvider);
                final isInFeedMode = pageContext.whenOrNull(
                  data: (ctx) => ctx.videoIndex != null,
                ) ?? false;
                final isInHashtagMode = _hashtagMode != null;

                if (isInFeedMode || isInHashtagMode) {
                  _resetToDefaultState();
                } else {
                  Log.debug('🎯 ExploreScreen: Already in grid mode for tab $index, ignoring tap',
                      category: LogCategory.video);
                }
              } else {
                // Switching to a different tab - reset to grid mode if needed
                _resetToDefaultState();
              }
            },
            tabs: const [
              Tab(text: 'New Videos'),
              Tab(text: 'Popular Videos'),
              Tab(text: "Editor's Pick"),
            ],
          ),
        ),
        // Content changes based on mode
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    // Derive mode from URL (single source of truth) instead of internal state
    final pageContext = ref.watch(pageContextProvider);

    return pageContext.when(
      data: (ctx) {
        // Check if we're in feed mode by looking at URL's videoIndex parameter
        final bool isInFeedMode = ctx.type == RouteType.explore && ctx.videoIndex != null;

        if (isInFeedMode) {
          return _buildFeedModeContent();
        }

        if (_hashtagMode != null) {
          return _buildHashtagModeContent(_hashtagMode!);
        }

        // Default: show tab view with banner
        return Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildNewVinesTab(),
                _buildTrendingTab(),
                _buildEditorsPickTab(),
              ],
            ),
            // New videos banner (only show on New Videos and Popular Videos tabs)
            if (_tabController.index < 2) _buildNewVideosBanner(),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (e, s) => Center(child: Text('Error: $e', style: TextStyle(color: VineTheme.likeRed))),
    );
  }

  Widget _buildFeedModeContent() {
    // Read videos from provider (survives widget recreation)
    final videos = ref.watch(exploreTabVideosProvider) ?? const <VideoEvent>[];

    // Derive starting index from URL
    final pageContext = ref.watch(pageContextProvider);
    final startIndex = pageContext.whenOrNull(
      data: (ctx) => ctx.videoIndex ?? 0,
    ) ?? 0;

    // Safety check: ensure we have videos and valid index
    if (videos.isEmpty || startIndex >= videos.length) {
      return Center(
        child: Text('No videos available', style: TextStyle(color: VineTheme.whiteText)),
      );
    }

    // Just return the video screen - tabs are shown above
    return ExploreVideoScreenPure(
      startingVideo: videos[startIndex],
      videoList: videos,
      contextTitle: '', // Don't show context title for general explore feed
      startingIndex: startIndex,
    );
  }

  Widget _buildHashtagModeContent(String hashtag) {
    // Return hashtag feed with callback to enter feed mode inline
    return HashtagFeedScreen(
      hashtag: hashtag,
      embedded: true,
      onVideoTap: (videos, index) => _enterFeedMode(videos, index),
    );
  }

  Widget _buildEditorsPickTab() {
    // Watch editor's picks from curation provider
    final editorsPicks = ref.watch(editorsPicksProvider);

    Log.debug(
      '🔍 EditorsPickTab: editorsPicks length: ${editorsPicks.length}',
      name: 'ExploreScreen',
      category: LogCategory.video,
    );

    if (editorsPicks.isEmpty) {
      return Container(
        key: const Key('editors-pick-content'),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 64, color: VineTheme.secondaryText),
              const SizedBox(height: 16),
              Text(
                "Editor's Pick",
                style: TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Curated content coming soon',
                style: TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildVideoGrid(editorsPicks, "Editor's Pick");
  }

  Widget _buildNewVinesTab() {
    // Watch popular now feed from dedicated provider
    final popularNowAsync = ref.watch(popularNowFeedProvider);

    Log.debug(
      '🔍 NewVinesTab: AsyncValue state - isLoading: ${popularNowAsync.isLoading}, '
      'hasValue: ${popularNowAsync.hasValue}, hasError: ${popularNowAsync.hasError}',
      name: 'ExploreScreen',
      category: LogCategory.video,
    );

    // Track feed loading start
    if (popularNowAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker.startFeedLoad('new_vines');
    }

    return popularNowAsync.when(
      data: (feedState) {
        final videos = feedState.videos;
        Log.info('✅ NewVinesTab: Data state - ${videos.length} videos',
            name: 'ExploreScreen', category: LogCategory.video);

        // Track feed loaded with videos
        if (_feedLoadStartTime != null) {
          _feedTracker.markFirstVideosReceived('new_vines', videos.length);
          _feedTracker.markFeedDisplayed('new_vines', videos.length);
          _screenAnalytics.markDataLoaded('explore_screen', dataMetrics: {
            'tab': 'new_vines',
            'video_count': videos.length,
          });
          _feedLoadStartTime = null;
        }

        // Track empty feed
        if (videos.isEmpty) {
          _feedTracker.trackEmptyFeed('new_vines');
        }

        // Videos are already sorted by PopularNowFeed provider (newest first)
        return _buildVideoGrid(videos, 'New Videos');
      },
      loading: () {
        Log.info('⏳ NewVinesTab: Showing loading indicator',
            name: 'ExploreScreen', category: LogCategory.video);

        // Track slow loading after 5 seconds
        if (_feedLoadStartTime != null) {
          final elapsed = DateTime.now().difference(_feedLoadStartTime!).inMilliseconds;
          if (elapsed > 5000) {
            _errorTracker.trackSlowOperation(
              operation: 'new_vines_feed_load',
              durationMs: elapsed,
              thresholdMs: 5000,
              location: 'explore_new_vines',
            );
          }
        }

        return Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        );
      },
      error: (error, stackTrace) {
        Log.error('❌ NewVinesTab: Error state - $error',
            name: 'ExploreScreen', category: LogCategory.video);

        // Track error
        final loadTime = _feedLoadStartTime != null
            ? DateTime.now().difference(_feedLoadStartTime!).inMilliseconds
            : null;
        _feedTracker.trackFeedError(
          'new_vines',
          errorType: 'load_failed',
          errorMessage: error.toString(),
        );
        _errorTracker.trackFeedLoadError(
          feedType: 'new_vines',
          errorType: 'provider_error',
          errorMessage: error.toString(),
          loadTimeMs: loadTime,
        );
        _feedLoadStartTime = null;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: VineTheme.likeRed),
              const SizedBox(height: 16),
              Text(
                'Failed to load videos',
                style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendingTab() {
    // Sort videos by loop count (most loops first) - "Popular Vines"
    final videoEventsAsync = ref.watch(videoEventsProvider);

    Log.debug(
      '🔍 PopularVinesTab: AsyncValue state - isLoading: ${videoEventsAsync.isLoading}, '
      'hasValue: ${videoEventsAsync.hasValue}, hasError: ${videoEventsAsync.hasError}, '
      'value length: ${videoEventsAsync.value?.length ?? 0}',
      name: 'ExploreScreen',
      category: LogCategory.video,
    );

    // Track feed loading start
    if (videoEventsAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker.startFeedLoad('trending');
    }

    // CRITICAL: Check hasValue FIRST before isLoading
    // StreamProviders can have both isLoading:true and hasValue:true during rebuilds
    if (videoEventsAsync.hasValue && videoEventsAsync.value != null) {
      final videos = videoEventsAsync.value!;
      Log.info('✅ TrendingTab: Data state - ${videos.length} videos',
          name: 'ExploreScreen', category: LogCategory.video);

      // Track feed loaded with videos
      if (_feedLoadStartTime != null) {
        _feedTracker.markFirstVideosReceived('trending', videos.length);
        _feedTracker.markFeedDisplayed('trending', videos.length);
        _screenAnalytics.markDataLoaded('explore_screen', dataMetrics: {
          'tab': 'trending',
          'video_count': videos.length,
        });
        _feedLoadStartTime = null;
      }

      // Track empty feed
      if (videos.isEmpty) {
        _feedTracker.trackEmptyFeed('trending');
      }

      // PERFORMANCE OPTIMIZATION: Only re-sort if video list changed
      // Check if we can use cached sorted list
      final List<VideoEvent> sortedVideos;
      if (identical(videos, _lastRawVideos) && _cachedTrendingVideos != null) {
        // Same video list object - use cached sort
        sortedVideos = _cachedTrendingVideos!;
        Log.debug(
          '✨ TRENDING CACHE HIT: Reusing sorted list (${sortedVideos.length} videos)',
          name: 'ExploreScreen',
          category: LogCategory.video,
        );
      } else {
        // New video list - sort and cache
        sortedVideos = List<VideoEvent>.from(videos);
        sortedVideos.sort((a, b) {
          final aLoops = a.originalLoops ?? 0;
          final bLoops = b.originalLoops ?? 0;
          return bLoops.compareTo(aLoops); // Descending order
        });

        // Update cache
        _lastRawVideos = videos;
        _cachedTrendingVideos = sortedVideos;

        // Debug: Log top 10 videos after sorting
        Log.debug(
          '🎯 TRENDING SORT: Sorted ${sortedVideos.length} videos by loop count',
          name: 'ExploreScreen',
          category: LogCategory.video,
        );
        if (sortedVideos.isNotEmpty) {
          final top10 = sortedVideos.take(10).toList();
          for (var i = 0; i < top10.length; i++) {
            final v = top10[i];
            Log.debug(
              '  #${i + 1}: ${v.originalLoops ?? 0} loops (id: ${v.id})',
              name: 'ExploreScreen',
              category: LogCategory.video,
            );
          }
        }
      }

      return _buildTrendingTabWithHashtags(sortedVideos);
    }

    if (videoEventsAsync.hasError) {
      Log.error('❌ TrendingTab: Error state - ${videoEventsAsync.error}',
          name: 'ExploreScreen', category: LogCategory.video);

      // Track error
      final loadTime = _feedLoadStartTime != null
          ? DateTime.now().difference(_feedLoadStartTime!).inMilliseconds
          : null;
      _feedTracker.trackFeedError(
        'trending',
        errorType: 'load_failed',
        errorMessage: videoEventsAsync.error.toString(),
      );
      _errorTracker.trackFeedLoadError(
        feedType: 'trending',
        errorType: 'provider_error',
        errorMessage: videoEventsAsync.error.toString(),
        loadTimeMs: loadTime,
      );
      _feedLoadStartTime = null;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load trending videos',
              style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Only show loading if we truly have no data yet
    Log.info('⏳ TrendingTab: Showing loading indicator',
        name: 'ExploreScreen', category: LogCategory.video);

    // Track slow loading after 5 seconds
    if (_feedLoadStartTime != null) {
      final elapsed = DateTime.now().difference(_feedLoadStartTime!).inMilliseconds;
      if (elapsed > 5000) {
        _errorTracker.trackSlowOperation(
          operation: 'trending_feed_load',
          durationMs: elapsed,
          thresholdMs: 5000,
          location: 'explore_trending',
        );
      }
    }

    return Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }

  Widget _buildTrendingTabWithHashtags(List<VideoEvent> videos) {
    return Column(
      children: [
        // Hashtag navigation section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Trending Hashtags',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 28,
                child: Builder(
                  builder: (context) {
                    final hashtags = TopHashtagsService.instance.getTopHashtags(limit: 20);

                    if (hashtags.isEmpty) {
                      // Show placeholder while loading
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Loading hashtags...',
                          style: TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: hashtags.length,
                      itemBuilder: (context, index) {
                        final hashtag = hashtags[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          context.goHashtag(hashtag);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.8),
                          decoration: BoxDecoration(
                            color: VineTheme.cardBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              '#$hashtag',
                              style: const TextStyle(
                                color: VineTheme.vineGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Videos grid
        Expanded(
          child: _buildVideoGrid(videos, 'Popular Videos'),
        ),
      ],
    );
  }

  Widget _buildVideoGrid(List<VideoEvent> videos, String tabName) {
    return ComposableVideoGrid(
      videos: videos,
      onVideoTap: (videos, index) {
        Log.info('🎯 ExploreScreen: Tapped video tile at index $index',
            category: LogCategory.video);
        _enterFeedMode(videos, index);
      },
      onRefresh: () async {
        Log.info('🔄 ExploreScreen: Refreshing $tabName tab',
            category: LogCategory.video);

        // Refresh the appropriate provider based on tab
        if (tabName == "Editor's Pick") {
          await ref.read(curationProvider.notifier).refreshAll();
        } else if (tabName == "New Videos") {
          // Refresh popular now feed
          ref.invalidate(popularNowFeedProvider);
          await ref.read(popularNowFeedProvider.future);
        } else {
          // For Trending tab, refresh video events
          ref.invalidate(videoEventsProvider);
          await ref.read(videoEventsProvider.future);
        }
      },
      emptyBuilder: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No videos in $tabName',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new content',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Public methods expected by main.dart
  void onScreenVisible() {
    // Handle screen becoming visible
    Log.debug('🎯 ExploreScreen became visible', category: LogCategory.video);

    // Enable buffering to prevent jarring auto-updates while browsing
    ref.read(videoEventsProvider.notifier).enableBuffering();
  }

  void onScreenHidden() {
    // Handle screen becoming hidden
    Log.debug('🎯 ExploreScreen became hidden', category: LogCategory.video);

    // Disable buffering when hidden (so videos load normally when returning)
    ref.read(videoEventsProvider.notifier).disableBuffering();
  }

  bool get isInFeedMode {
    // Derive from URL instead of internal state
    final pageContext = ref.read(pageContextProvider);
    return pageContext.whenOrNull(
      data: (ctx) => ctx.type == RouteType.explore && ctx.videoIndex != null,
    ) ?? false;
  }
  String? get currentHashtag => _hashtagMode;
  String? get customTitle => _customTitle;

  void setCustomTitle(String? title) {
    if (_customTitle != title) {
      setState(() {
        _customTitle = title;
      });
      // Note: Title updates are now handled by router-driven app bar
    }
  }

  void exitFeedMode() => _exitFeedMode();

  void showHashtagVideos(String hashtag) {
    Log.debug('🎯 ExploreScreen showing hashtag videos: $hashtag', category: LogCategory.video);
    _enterHashtagMode(hashtag);
  }

  void playSpecificVideo(VideoEvent video, List<VideoEvent> videos, int index) {
    Log.debug('🎯 ExploreScreen playing specific video: ${video.id}', category: LogCategory.video);
    _enterFeedMode(videos, index);
  }

  /// Build banner that shows when new videos are buffered
  Widget _buildNewVideosBanner() {
    final bufferedCount = ref.watch(bufferedVideoCountProvider);

    if (bufferedCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            // Load buffered videos
            ref.read(videoEventsProvider.notifier).loadBufferedVideos();
            Log.info('🔄 ExploreScreen: Loaded $bufferedCount buffered videos',
                category: LogCategory.video);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: VineTheme.vineGreen,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_upward, color: VineTheme.backgroundColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$bufferedCount new ${bufferedCount == 1 ? 'video' : 'videos'}',
                  style: TextStyle(
                    color: VineTheme.backgroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
