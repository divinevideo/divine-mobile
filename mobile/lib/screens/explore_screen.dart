// ABOUTME: Explore screen with proper Vine theme and video grid functionality
// ABOUTME: Pure Riverpod architecture for video discovery with grid/feed modes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
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
import 'package:openvine/widgets/popular_videos_tab.dart';
import 'package:openvine/widgets/list_card.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';

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

  @override
  void initState() {
    super.initState();

    // Restore tab index from provider to survive widget recreation
    final savedTabIndex = ref.read(exploreTabIndexProvider);
    _tabController = TabController(length: 3, vsync: this, initialIndex: savedTabIndex);
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

    final tabNames = ['new_videos', 'popular_videos', 'lists'];
    final tabName = tabNames[_tabController.index];

    Log.debug('🎯 ExploreScreenPure: Switched to tab ${_tabController.index}',
        category: LogCategory.video);

    // Persist tab index to survive widget recreation
    ref.read(exploreTabIndexProvider.notifier).state = _tabController.index;

    // Track tab change
    _screenAnalytics.trackTabChange(
      screenName: 'explore_screen',
      tabName: tabName,
    );

    // Lists tab - refresh lists when activated
    if (_tabController.index == 2) { // Lists tab
      Log.debug('🔄 Lists tab activated',
          category: LogCategory.video);
      // Invalidate providers to refresh list data
      ref.invalidate(userListsProvider);
      ref.invalidate(curatedListsProvider);
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
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle: const TextStyle(
              fontSize: 14,
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
              Tab(text: 'Lists'),
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

        // IMPORTANT: Clear hashtag mode when URL shows we're on main explore
        // This handles the case where user taps bottom nav "Explore" to go back
        if (ctx.type == RouteType.explore && ctx.hashtag == null && _hashtagMode != null) {
          Log.info('🔄 Clearing hashtag mode: URL is main explore but _hashtagMode=$_hashtagMode',
              name: 'ExploreScreen', category: LogCategory.ui);
          // Schedule the state clear for after this build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hashtagMode = null;
                _customTitle = null;
              });
            }
          });
          // Still show the grid content this frame (not hashtag content)
        } else if (_hashtagMode != null) {
          Log.debug('🏷️ Showing hashtag mode: $_hashtagMode',
              name: 'ExploreScreen', category: LogCategory.ui);
          return _buildHashtagModeContent(_hashtagMode!);
        }

        // Default: show tab view with banner
        return Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildNewVinesTab(),
                PopularVideosTab(
                  onVideoTap: _enterFeedMode,
                  screenAnalytics: _screenAnalytics,
                  feedTracker: _feedTracker,
                  errorTracker: _errorTracker,
                ),
                _buildListsTab(),
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

  Widget _buildListsTab() {
    // Load data but don't wait for everything - show UI progressively
    final allListsAsync = ref.watch(allListsProvider);

    // Always show the static UI elements immediately
    return RefreshIndicator(
      color: VineTheme.vineGreen,
      onRefresh: () async {
        // Invalidate both providers to refresh
        ref.invalidate(userListsProvider);
        ref.invalidate(curatedListsProvider);
      },
      child: ListView(
        key: const Key('lists-tab-content'),
        children: [
          // Discover Lists button - ALWAYS VISIBLE
          Container(
            margin: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                Log.info('Tapped Discover Lists button',
                    category: LogCategory.ui);
                // Stop any playing videos before navigating
                disposeAllVideoControllers(ref);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DiscoverListsScreen(),
                  ),
                );
              },
              icon: Icon(Icons.search, color: VineTheme.backgroundColor),
              label: Text(
                'Discover Lists',
                style: TextStyle(
                  color: VineTheme.backgroundColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Help text - ALWAYS VISIBLE
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VineTheme.vineGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: VineTheme.vineGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'About Lists',
                      style: TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Lists help you organize and curate Divine content in two ways:',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.group, color: VineTheme.vineGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'People Lists',
                            style: TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Follow groups of creators and see their latest videos',
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.video_library,
                        color: VineTheme.vineGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Video Lists',
                            style: TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create playlists of your favorite videos to watch later',
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // MY LISTS and PEOPLE LISTS - Show immediately when data available
          allListsAsync.when(
            data: (data) {
              final userLists = data.userLists;
              final myLists = data.curatedLists.where((list) {
                // Lists without nostrEventId are local-only user lists
                return list.nostrEventId == null;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Lists section
                  if (myLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.video_library,
                              color: VineTheme.vineGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'My Lists',
                            style: TextStyle(
                              color: VineTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...myLists.map((curatedList) => CuratedListCard(
                          curatedList: curatedList,
                          onTap: () {
                            Log.info(
                                'Tapped my curated list: ${curatedList.name}',
                                category: LogCategory.ui);
                            // Stop any playing videos before navigating
                            disposeAllVideoControllers(ref);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CuratedListFeedScreen(
                                  listId: curatedList.id,
                                  listName: curatedList.name,
                                ),
                              ),
                            );
                          },
                        )),
                    const SizedBox(height: 16),
                  ],

                  // People Lists section
                  if (userLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.group,
                              color: VineTheme.vineGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'People Lists',
                            style: TextStyle(
                              color: VineTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...userLists.map((userList) => UserListCard(
                          userList: userList,
                          onTap: () {
                            Log.info('Tapped user list: ${userList.name}',
                                category: LogCategory.ui);
                            // Stop any playing videos before navigating
                            disposeAllVideoControllers(ref);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserListPeopleScreen(userList: userList),
                              ),
                            );
                          },
                        )),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading lists: $error',
                style: TextStyle(color: VineTheme.likeRed),
              ),
            ),
          ),

          // SUBSCRIBED LISTS - Load separately with its own loading state
          _buildSubscribedListsSection(),
        ],
      ),
    );
  }

  /// Build subscribed lists section with independent loading state
  Widget _buildSubscribedListsSection() {
    final allListsAsync = ref.watch(allListsProvider);
    final serviceAsync = ref.watch(curatedListServiceProvider);

    // Wait for both to load subscribed lists
    if (!allListsAsync.hasValue || !serviceAsync.hasValue) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.playlist_add_check,
                    color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Subscribed Lists',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          ],
        ),
      );
    }

    final service = serviceAsync.value!;
    final allCuratedLists = allListsAsync.value!.curatedLists;

    // Filter subscribed lists
    final subscribedLists = allCuratedLists.where((list) {
      return service.isSubscribedToList(list.id);
    }).toList();

    if (subscribedLists.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no subscribed lists
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.playlist_add_check,
                  color: VineTheme.vineGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Subscribed Lists',
                style: TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...subscribedLists.map((curatedList) => CuratedListCard(
              curatedList: curatedList,
              onTap: () {
                Log.info('Tapped subscribed list: ${curatedList.name}',
                    category: LogCategory.ui);
                // Stop any playing videos before navigating
                disposeAllVideoControllers(ref);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CuratedListFeedScreen(
                      listId: curatedList.id,
                      listName: curatedList.name,
                    ),
                  ),
                );
              },
            )),
        const SizedBox(height: 16),
      ],
    );
  }


  // Keep Divine Team functionality for now - will migrate to a list
  // ignore: unused_element
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
                'Divine Team',
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

    return _buildVideoGrid(editorsPicks, 'Divine Team');
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
        // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
        final allVideos = feedState.videos;
        final videos = allVideos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .toList();
        Log.info('✅ NewVinesTab: Data state - ${videos.length} videos (filtered from ${allVideos.length} total)',
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
        // Use portrait aspect ratio (9:16) for New Videos to match vertical video format
        return _buildVideoGrid(
          videos,
          'New Videos',
          childAspectRatio: 0.50,  // Taller grid cells for portrait videos
          thumbnailAspectRatio: 9 / 16,  // Portrait thumbnail (0.5625)
        );
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

  Widget _buildVideoGrid(
    List<VideoEvent> videos,
    String tabName, {
    double? childAspectRatio,
    double? thumbnailAspectRatio,
  }) {
    // Default aspect ratios - square thumbnails with standard grid height
    final gridAspectRatio = childAspectRatio ?? 0.72;
    final thumbAspectRatio = thumbnailAspectRatio ?? 1.0;

    return ComposableVideoGrid(
      videos: videos,
      childAspectRatio: gridAspectRatio,
      thumbnailAspectRatio: thumbAspectRatio,
      onVideoTap: (videos, index) {
        Log.info('🎯 ExploreScreen: Tapped video tile at index $index',
            category: LogCategory.video);
        _enterFeedMode(videos, index);
      },
      onRefresh: () async {
        Log.info('🔄 ExploreScreen: Refreshing $tabName tab',
            category: LogCategory.video);

        // Refresh the appropriate provider based on tab
        if (tabName == 'Lists') {
          // Refresh list providers
          ref.invalidate(userListsProvider);
          ref.invalidate(curatedListsProvider);
        } else if (tabName == "New Videos") {
          // Refresh popular now feed - call refresh() to force new subscription
          await ref.read(popularNowFeedProvider.notifier).refresh();
        } else {
          // For Trending tab, refresh video events
          final _ = await ref.refresh(videoEventsProvider);
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
