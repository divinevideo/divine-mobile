// ABOUTME: TDD-driven video feed screen implementation with single source of truth
// ABOUTME: Memory-efficient PageView with intelligent preloading and error boundaries

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/pagination_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_feed_item.dart';

/// Feed context for filtering videos
enum FeedContext {
  general, // All videos (default feed)
  hashtag, // Videos from specific hashtag
  editorsPicks, // Curated videos
  trending, // Trending content
  userProfile, // User's videos
  search, // Search results videos
}

/// Main video feed screen implementing TDD specifications with Riverpod
///
/// Key features:
/// - Reactive Riverpod state management
/// - Single source of truth video management
/// - Memory-bounded operation (<500MB)
/// - Intelligent preloading around current position
/// - Error boundaries for individual videos
/// - Accessibility support
/// - Lifecycle management (pause on background, resume on foreground)
/// - Context-aware content filtering
class VideoFeedScreen extends ConsumerStatefulWidget {
  // hashtag name, user pubkey, etc.

  const VideoFeedScreen({
    super.key,
    this.startingVideo,
    this.context = FeedContext.general,
    this.contextValue,
    this.disableNavigation = false,
  });
  final VideoEvent? startingVideo;
  final FeedContext context;
  final String? contextValue;
  final bool
  disableNavigation; // Set to true to prevent context.go() calls (e.g., for deep links)

  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();

  /// Static method to pause videos - called from external components
  static void pauseVideos(GlobalKey<State<VideoFeedScreen>> key) {
    final state = key.currentState;
    if (state is _VideoFeedScreenState) {
      state.pauseVideos();
    }
  }

  /// Static method to resume videos - called from external components
  static void resumeVideos(GlobalKey<State<VideoFeedScreen>> key) {
    final state = key.currentState;
    if (state is _VideoFeedScreenState) {
      state.resumeVideos();
    }
  }

  /// Static method to get current video - called from external components
  static VideoEvent? getCurrentVideo(GlobalKey<State<VideoFeedScreen>> key) {
    final state = key.currentState;
    if (state is _VideoFeedScreenState) {
      return state.getCurrentVideo();
    }
    return null;
  }

  /// Static method to scroll to top and refresh - called from external components
  static void scrollToTopAndRefresh(GlobalKey<State<VideoFeedScreen>> key) {
    final state = key.currentState;
    if (state is _VideoFeedScreenState) {
      state.scrollToTopAndRefresh();
    }
  }
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen>
    with
        WidgetsBindingObserver,
        PaginationMixin,
        VideoPrefetchMixin,
        AsyncValueUIHelpersMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isRefreshing = false; // Track if feed is currently refreshing

  static int _instanceCounter = 0;
  static DateTime? _lastInitTime;
  late final int _instanceId;
  late final DateTime _initTime;

  @override
  void initState() {
    super.initState();

    _instanceCounter++;
    _instanceId = _instanceCounter;
    _initTime = DateTime.now();

    final timeSinceLastInit = _lastInitTime != null
        ? _initTime.difference(_lastInitTime!).inMilliseconds
        : null;

    Log.info(
      '🏗️  VideoFeedScreen: initState #$_instanceId at ${_initTime.millisecondsSinceEpoch}ms'
      '${timeSinceLastInit != null ? ' (${timeSinceLastInit}ms since last init)' : ''}',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    if (timeSinceLastInit != null && timeSinceLastInit < 2000) {
      Log.warning(
        '⚠️  VideoFeedScreen: RAPID RE-INIT DETECTED! Only ${timeSinceLastInit}ms since last init. '
        'This indicates the widget is being recreated!',
        name: 'VideoFeedScreen',
        category: LogCategory.ui,
      );
    }

    _lastInitTime = _initTime;

    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);

    // Feed mode removed - each screen manages its own content

    // Tab visibility handled by derived provider - when tab changes, pageContextProvider updates
    // which causes activeVideoIdProvider to recompute and return null for non-active tabs
  }

  @override
  void dispose() {
    final lifetime = DateTime.now().difference(_initTime).inMilliseconds;
    Log.info(
      '🗑️  VideoFeedScreen: dispose #$_instanceId after ${lifetime}ms lifetime',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();

    // Pause all videos when screen is disposed
    Log.debug(
      '📱 Callback firing: dispose._pauseAllVideos, widget mounted: $mounted',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );
    _pauseAllVideos();

    // NOTE: With Riverpod-native lifecycle, controllers autodispose via 30s timeout

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    Log.debug(
      '🌍 AppLifecycle: $state, timestamp: ${DateTime.now()}, mounted: $mounted',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    // On macOS/desktop, don't pause videos for brief focus changes (inactive)
    // This prevents excessive pausing that was preventing videos from playing
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    switch (state) {
      case AppLifecycleState.paused:
        Log.debug(
          '📱 App paused - pausing videos, state: $state',
          name: 'VideoFeedScreen',
          category: LogCategory.ui,
        );
        _pauseAllVideos();

      case AppLifecycleState.inactive:
        if (!isDesktop) {
          // Only pause for inactive on mobile platforms
          Log.debug(
            '📱 App inactive (mobile) - pausing videos, state: $state',
            name: 'VideoFeedScreen',
            category: LogCategory.ui,
          );
          _pauseAllVideos();
        } else {
          Log.debug(
            '🖥️ App inactive (desktop) - ignoring to prevent excessive pausing, state: $state',
            name: 'VideoFeedScreen',
            category: LogCategory.ui,
          );
        }

      case AppLifecycleState.resumed:
        Log.debug(
          '📱 App resumed - derived provider will handle video resumption, state: $state',
          name: 'VideoFeedScreen',
          category: LogCategory.ui,
        );
      // appForegroundProvider will update → activeVideoIdProvider recomputes → VideoFeedItem plays

      case AppLifecycleState.detached:
        Log.debug(
          '📱 App detached - pausing videos, state: $state',
          name: 'VideoFeedScreen',
          category: LogCategory.ui,
        );
        _pauseAllVideos();

      case AppLifecycleState.hidden:
        Log.debug(
          '📱 App hidden - pausing videos, state: $state',
          name: 'VideoFeedScreen',
          category: LogCategory.ui,
        );
        _pauseAllVideos();
    }
  }

  void _onPageChanged(int index) {
    // Store the previous index before updating
    final previousIndex = _currentIndex;

    Log.debug(
      '📱 Callback firing: _onPageChanged($index), widget mounted: $mounted, previousIndex: $previousIndex',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    setState(() {
      _currentIndex = index;
    });

    // Get current videos from home feed state
    Log.debug(
      '🔍 Attempting ref.read(homeFeedProvider) from VideoFeedScreen._onPageChanged, mounted: $mounted',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );
    final asyncState = ref.read(homeFeedProvider);
    final feedState = asyncState.hasValue ? asyncState.value : null;
    if (feedState == null) return;

    final videos = feedState.videos;
    if (videos.isEmpty) return;

    // Simple bounds check
    if (index < 0 || index >= videos.length) {
      return;
    }

    // Batch fetch profiles for videos around current position
    _batchFetchProfilesAroundIndex(index, videos);

    // Prefetch videos around current position for instant playback
    checkForPrefetch(currentIndex: index, videos: videos);

    // Update URL to trigger derived provider chain (unless navigation is disabled for deep links)
    // context.go() → routerLocationStream → pageContextProvider → activeVideoIdProvider → VideoFeedItem reacts
    if (!widget.disableNavigation) {
      context.go('/home/$index');
    }
  }

  // Legacy methods removed - active video is now derived from URL via activeVideoIdProvider

  void _pauseAllVideos() {
    Log.debug(
      '📱 _pauseAllVideos called - derived provider handles pause automatically',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );
    // When app backgrounds, appForegroundProvider updates → activeVideoIdProvider returns null → VideoFeedItem pauses
  }

  /// Public method to pause videos from external sources (like navigation)
  void pauseVideos() {
    _pauseAllVideos();
  }

  /// Public method to resume videos from external sources (like navigation)
  void resumeVideos() {
    // Resume is handled by the derived activeVideoIdProvider
    // When app foregrounds, appForegroundProvider updates → activeVideoIdProvider recomputes → VideoFeedItem plays
  }

  /// Get the currently displayed video
  VideoEvent? getCurrentVideo() {
    final asyncState = ref.read(homeFeedProvider);
    final feedState = asyncState.hasValue ? asyncState.value : null;
    if (feedState == null) return null;

    final videos = feedState.videos;
    if (_currentIndex < videos.length) {
      return videos[_currentIndex];
    }
    return null;
  }

  /// Scroll to top and refresh the feed
  void scrollToTopAndRefresh() {
    // Scroll to top
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );

      // Trigger refresh after scroll completes
      Future.delayed(const Duration(milliseconds: 600), _handleRefresh);
    } else {
      // If already at top or no clients, just refresh
      _handleRefresh();
    }
  }

  static int _buildCounter = 0;

  @override
  Widget build(BuildContext context) {
    _buildCounter++;
    Log.info(
      '🎨 VideoFeedScreen: build() #$_buildCounter (instance #$_instanceId)',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    // VideoFeedScreen is now a body widget - parent handles Scaffold
    return _buildBody();
  }

  Widget _buildBody() {
    Log.info(
      '🎬 VideoFeedScreen: _buildBody #$_buildCounter (instance #$_instanceId) - watching homeFeedProvider...',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    // Watch the home feed state
    final videoFeedAsync = ref.watch(homeFeedProvider);

    Log.info(
      '🎬 VideoFeedScreen: _buildBody #$_buildCounter received AsyncValue state: ${videoFeedAsync.runtimeType}, '
      'isLoading: ${videoFeedAsync.isLoading}, hasValue: ${videoFeedAsync.hasValue}, hasError: ${videoFeedAsync.hasError}',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    // The single video controller is instantiated via VideoFeedItem widgets

    return buildAsyncUI(
      videoFeedAsync,
      onLoading: () {
        Log.info(
          '🎬 VideoFeedScreen: Showing loading state',
          name: 'VideoFeedScreen',
          category: LogCategory.ui,
        );
        return _buildLoadingState();
      },
      onError: (error, stackTrace) {
        Log.error(
          '🎬 VideoFeedScreen: Error state - $error',
          name: 'VideoFeedScreen',
          category: LogCategory.ui,
        );
        return _buildErrorState(error.toString());
      },
      onData: (feedState) {
        final videos = feedState.videos;

        if (videos.isEmpty) {
          return _buildEmptyState();
        }

        // Initial active video is derived from pageContextProvider + feed state
        // No manual initialization needed - activeVideoIdProvider handles this automatically

        return _buildVideoFeed(videos, feedState);
      },
    );
  }

  Widget _buildLoadingState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 16),
        Text('Loading videos...', style: TextStyle(color: Colors.white)),
      ],
    ),
  );

  Widget _buildEmptyState() {
    // Check if user is following anyone to show appropriate message
    final socialData = ref.watch(social.socialProvider);
    final isFollowingAnyone = socialData.followingPubkeys.isNotEmpty;

    Log.info(
      '🔍 VideoFeedScreen: Empty state - '
      'isFollowingAnyone=$isFollowingAnyone, '
      'socialInitialized=${socialData.isInitialized}, '
      'followingCount=${socialData.followingPubkeys.length}',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    if (!isFollowingAnyone) {
      // Show educational message about divine's non-algorithmic approach
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline, size: 64, color: Colors.white54),
              const SizedBox(height: 24),
              const Text(
                'Your Feed, Your Choice',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'divine doesn\'t give you an algorithmic feed.\nYou choose who you follow.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Start following viners to see their posts here,\nor explore new content to discover creators.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Navigate to explore tab using GoRouter
                  context.goExplore();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Explore Vines'),
              ),
            ],
          ),
        ),
      );
    } else {
      // Show standard empty state for users who are following people
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No videos available',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildErrorState(String error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        const Text(
          'Error loading videos',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          error,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => ref.invalidate(homeFeedProvider),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildVideoFeed(List<VideoEvent> videos, VideoFeedState feedState) {
    Log.info(
      '🎬 VideoFeedScreen: Building home video feed with ${videos.length} videos from following',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    return PageView.builder(
      itemCount: videos.length,
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
        _onPageChanged(index);

        // Trigger pagination when near the end using PaginationMixin
        checkForPagination(
          currentIndex: index,
          totalItems: videos.length,
          onLoadMore: () => ref.read(homeFeedProvider.notifier).loadMore(),
        );

        Log.debug(
          '📄 Page changed to index $index (${videos[index].id}...)',
          name: 'VideoFeedScreen',
          category: LogCategory.video,
        );
      },
      itemBuilder: (context, index) {
        return VideoFeedItem(
          key: ValueKey('video-${videos[index].id}'),
          video: videos[index],
          index: index,
          hasBottomNavigation: true,
          contextTitle: '', // Home feed has no context title
        );
      },
    );
  }

  /// Handle pull-to-refresh functionality
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      Log.info(
        '🔄 Pull-to-refresh triggered - refreshing feed',
        name: 'VideoFeedScreen',
        category: LogCategory.ui,
      );

      // Refresh the home feed using Riverpod
      await ref.read(homeFeedProvider.notifier).refresh();

      // Clear pagination throttle after refresh
      resetPagination();

      Log.info(
        '✅ Feed refresh completed',
        name: 'VideoFeedScreen',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        '❌ Feed refresh failed: $e',
        name: 'VideoFeedScreen',
        category: LogCategory.ui,
      );

      // Show error feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to refresh feed'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Batch fetch profiles for videos around the current position
  void _batchFetchProfilesAroundIndex(
    int currentIndex,
    List<VideoEvent> videos,
  ) {
    if (videos.isEmpty) return;

    // Only fetch profile for the currently visible video
    // This prevents creating hundreds of relay subscriptions
    final currentVideo = videos[currentIndex];
    final pubkeysToFetch = <String>{};
    final userProfilesNotifier = ref.read(userProfileProvider.notifier);

    // Only add pubkey if we don't have the profile yet
    if (!userProfilesNotifier.hasProfile(currentVideo.pubkey)) {
      pubkeysToFetch.add(currentVideo.pubkey);
    }

    if (pubkeysToFetch.isEmpty) return;

    Log.debug(
      '⚡ Lazy loading profile for visible video at index $currentIndex',
      name: 'VideoFeedScreen',
      category: LogCategory.ui,
    );

    // Fetch profile only for the currently visible video
    userProfilesNotifier.prefetchProfilesImmediately(pubkeysToFetch.toList());
  }

  // Note: Keyboard navigation methods removed to avoid unused warnings
  // Would be implemented for accessibility support when needed
}

/// Error widget for video loading failures
class VideoErrorWidget extends StatelessWidget {
  const VideoErrorWidget({
    required this.message,
    super.key,
    this.onRetry,
    this.onGoBack,
  });
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onGoBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Network error',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (onGoBack != null || onRetry != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onGoBack != null) ...[
                  ElevatedButton(
                    onPressed: onGoBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Go Back'),
                  ),
                  if (onRetry != null) const SizedBox(width: 16),
                ],
                if (onRetry != null)
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
