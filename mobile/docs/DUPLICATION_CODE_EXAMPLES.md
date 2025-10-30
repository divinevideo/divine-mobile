# OpenVine Duplication Analysis - Code Examples & Snippets

This document provides detailed code examples for each duplication pattern identified in DUPLICATION_ANALYSIS.md.

---

## 1. PageController Sync Duplication (HIGH PRIORITY)

### Pattern 1A: home_screen_router.dart (Lines 143-164)

**Current Implementation:**
```dart
// Sync controller when URL changes externally (back/forward/deeplink)
// Use post-frame to avoid calling jumpToPage during build
// Skip if URL update is already pending from reorder detection
if (_controller!.hasClients && !urlUpdatePending) {
  final safeIndex = urlIndex.clamp(0, itemCount - 1);
  final currentPage = _controller!.page?.round() ?? 0;

  // Sync if URL changed OR if controller position doesn't match URL
  if (urlIndex != _lastUrlIndex || currentPage != safeIndex) {
    _lastUrlIndex = urlIndex;
    _currentVideoId = videos[safeIndex].id; // Update tracked video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller!.hasClients) return;
      final currentPageNow = _controller!.page?.round() ?? 0;
      if (currentPageNow != safeIndex) {
        Log.debug('🔄 Syncing PageController: current=$currentPageNow -> target=$safeIndex',
            name: 'HomeScreenRouter', category: LogCategory.video);
        _controller!.jumpToPage(safeIndex);
      }
    });
  }
}
```

**Refactored with PageControllerSyncMixin:**
```dart
if (_controller!.hasClients && !urlUpdatePending) {
  final safeIndex = urlIndex.clamp(0, itemCount - 1);
  if (shouldSync(
    urlIndex: urlIndex,
    lastUrlIndex: _lastUrlIndex,
    controller: _controller,
    targetIndex: safeIndex,
  )) {
    _lastUrlIndex = urlIndex;
    _currentVideoId = videos[safeIndex].id;
    syncPageController(
      controller: _controller!,
      targetIndex: safeIndex,
      itemCount: itemCount,
    );
  }
}
```

**Lines Saved**: ~13

---

### Pattern 1B: explore_screen_router.dart (Lines 73-91)

**Current Implementation:**
```dart
// Sync controller when URL changes externally (back/forward/deeplink)
// OR when videos list changes (e.g., provider reloads)
// Use post-frame to avoid calling jumpToPage during build
if (_controller!.hasClients) {
  final safeIndex = urlIndex.clamp(0, itemCount - 1);
  final currentPage = _controller!.page?.round() ?? 0;

  // Sync if URL changed OR if controller position doesn't match URL
  if (urlIndex != _lastUrlIndex || currentPage != safeIndex) {
    _lastUrlIndex = urlIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller!.hasClients) return;
      final currentPageNow = _controller!.page?.round() ?? 0;
      if (currentPageNow != safeIndex) {
        _controller!.jumpToPage(safeIndex);
      }
    });
  }
}
```

**Refactored with PageControllerSyncMixin:**
```dart
if (_controller!.hasClients) {
  final safeIndex = urlIndex.clamp(0, itemCount - 1);
  if (shouldSync(
    urlIndex: urlIndex,
    lastUrlIndex: _lastUrlIndex,
    controller: _controller,
    targetIndex: safeIndex,
  )) {
    _lastUrlIndex = urlIndex;
    syncPageController(
      controller: _controller!,
      targetIndex: safeIndex,
      itemCount: itemCount,
    );
  }
}
```

**Lines Saved**: ~12

---

### Pattern 1C: profile_screen_router.dart (Lines 179-196)

**Current Implementation:**
```dart
// Sync controller when URL changes externally (back/forward/deeplink)
// OR when videos list changes (e.g., provider reloads)
if (_videoController!.hasClients) {
  final targetIndex = listIndex.clamp(0, videos.length - 1);
  final currentPage = _videoController!.page?.round() ?? 0;

  // Sync if URL changed OR if controller position doesn't match URL
  if (listIndex != _lastVideoUrlIndex || currentPage != targetIndex) {
    _lastVideoUrlIndex = listIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_videoController!.hasClients) return;
      final currentPageNow = _videoController!.page?.round() ?? 0;
      if (currentPageNow != targetIndex) {
        _videoController!.jumpToPage(targetIndex);
      }
    });
  }
}
```

**Refactored with PageControllerSyncMixin:**
```dart
if (_videoController!.hasClients) {
  final targetIndex = listIndex.clamp(0, videos.length - 1);
  if (shouldSync(
    urlIndex: listIndex,
    lastUrlIndex: _lastVideoUrlIndex,
    controller: _videoController,
    targetIndex: targetIndex,
  )) {
    _lastVideoUrlIndex = listIndex;
    syncPageController(
      controller: _videoController!,
      targetIndex: targetIndex,
      itemCount: videos.length,
    );
  }
}
```

**Lines Saved**: ~11

---

## 2. AsyncValue Loading/Error State Duplication (MEDIUM PRIORITY)

### Pattern 2A: Repeated loading/error states in routers

**Current Implementation (repeated 6+ times):**
```dart
return pageContext.when(
  data: (ctx) {
    // ... complex routing logic ...
    
    return videosAsync.when(
      data: (videos) {
        // Main widget tree (30+ lines)
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
```

**Proposed Mixin:**
```dart
mixin AsyncValueUIHelpersMixin {
  /// Build a widget that handles AsyncValue states uniformly
  Widget buildAsyncUI<T>(
    AsyncValue<T> asyncValue, {
    required Widget Function(T data) onData,
    Widget Function()? onLoading,
    Widget Function(Object error, StackTrace stack)? onError,
  }) {
    return asyncValue.when(
      data: onData,
      loading: onLoading ?? _buildDefaultLoading,
      error: onError ?? _buildDefaultError,
    );
  }

  Widget _buildDefaultLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: VineTheme.vineGreen,
      ),
    );
  }

  Widget _buildDefaultError(Object error, StackTrace stack) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

**Refactored Usage:**
```dart
class _MyScreenState extends ConsumerState<MyScreen> with AsyncValueUIHelpersMixin {
  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(videoProvider);
    
    return buildAsyncUI(
      videosAsync,
      onData: (videos) => buildVideoList(videos),
    );
  }
}
```

**Lines Saved**: ~15-20 per usage × 6 files = 90-120 lines

---

## 3. Follow/Unfollow List Pattern Duplication (MEDIUM PRIORITY)

### Pattern 3A & 3B: followers_screen.dart and following_screen.dart

**Current followers_screen.dart (Lines 26-105):**
```dart
class _FollowersScreenState extends ConsumerStatefulWidget {
  final List<String> _followers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      await _fetchFollowersFromNostr(widget.pubkey);
    } catch (e) {
      Log.error('Failed to load followers: $e',
          name: 'FollowersScreen', category: LogCategory.ui);
      if (mounted) {
        setState(() {
          _error = 'Failed to load followers';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchFollowersFromNostr(String pubkey) async {
    final nostrService = ref.read(nostrServiceProvider);
    final subscription = nostrService.subscribeToEvents(
      filters: [
        nostr_sdk.Filter(
          kinds: [3],
          p: [pubkey],
        ),
      ],
    );

    subscription.listen(
      (event) {
        if (!_followers.contains(event.pubkey)) {
          if (mounted) {
            setState(() {
              _followers.add(event.pubkey);
              _isLoading = false;
            });
          }
        }
      },
      onError: (error) {
        Log.error('Error in followers subscription: $error',
            name: 'FollowersScreen', category: LogCategory.relay);
        if (mounted) {
          setState(() {
            _error = 'Failed to load followers';
            _isLoading = false;
          });
        }
      },
    );

    Timer(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }
}
```

**Current following_screen.dart (Lines 26-120):**
```dart
// Nearly identical to followers_screen, just different Nostr query:
// - Uses authors: [pubkey], kinds: [3], limit: 1
// - Extracts p tags from event.tags
// Same error handling, loading pattern, timer logic
```

**Proposed Base Mixin:**
```dart
mixin NostrListFetchMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final List<String> items = [];
  bool isLoading = true;
  String? error;

  /// Load items with common error handling and loading pattern
  Future<void> loadItems({
    required Future<void> Function() fetchFn,
    required String logName,
  }) async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      await fetchFn();
    } catch (e) {
      Log.error('Failed to load items: $e',
          name: logName, category: LogCategory.ui);
      if (mounted) {
        setState(() {
          error = 'Failed to load items';
          isLoading = false;
        });
      }
    }
  }

  /// Common error handler for subscriptions
  void handleSubscriptionError(Object error) {
    Log.error('Error in subscription: $error',
        name: 'NostrListFetchMixin', category: LogCategory.relay);
    if (mounted) {
      setState(() {
        this.error = 'Failed to load items';
        isLoading = false;
      });
    }
  }

  /// Set loading complete after timeout
  void completeLoadingAfterTimeout(Duration timeout) {
    Timer(timeout, () {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }
}
```

**Refactored followers_screen.dart:**
```dart
class _FollowersScreenState extends ConsumerState<FollowersScreen>
    with NostrListFetchMixin {
  @override
  void initState() {
    super.initState();
    loadItems(
      fetchFn: () => _fetchFollowersFromNostr(widget.pubkey),
      logName: 'FollowersScreen',
    );
  }

  Future<void> _fetchFollowersFromNostr(String pubkey) async {
    final nostrService = ref.read(nostrServiceProvider);
    final subscription = nostrService.subscribeToEvents(
      filters: [nostr_sdk.Filter(kinds: [3], p: [pubkey])],
    );

    subscription.listen(
      (event) {
        if (!items.contains(event.pubkey) && mounted) {
          setState(() {
            items.add(event.pubkey);
            isLoading = false;
          });
        }
      },
      onError: handleSubscriptionError,
    );

    completeLoadingAfterTimeout(const Duration(seconds: 3));
  }
}
```

**Lines Saved**: ~40-50 per file × 2 files = 80-100 lines

---

## 4. Profile Stats Display Duplication (MEDIUM PRIORITY)

### Pattern 4A: Duplicate stat columns in profile_screen_router.dart

**Current Implementation (Lines 612-674):**
```dart
// First stat column - Total Views
Column(
  children: [
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: profileStatsAsync.isLoading
          ? const Text(
              '—',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : Text(
              _formatCount(
                  profileStatsAsync.value?.totalViews ?? 0),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    ),
    Text(
      'Total Views',
      style: TextStyle(
        color: Colors.grey.shade300,
        fontSize: 12,
      ),
    ),
  ],
),

// Second stat column - Total Likes (IDENTICAL STRUCTURE)
Column(
  children: [
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: profileStatsAsync.isLoading
          ? const Text(
              '—',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : Text(
              _formatCount(
                  profileStatsAsync.value?.totalLikes ?? 0),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    ),
    Text(
      'Total Likes',
      style: TextStyle(
        color: Colors.grey.shade300,
        fontSize: 12,
      ),
    ),
  ],
),
```

**Refactored Helper Method:**
```dart
Widget _buildStatValue(
  AsyncValue<ProfileStats> statsAsync,
  int? Function(ProfileStats?) getValue,
  String label,
) {
  return Column(
    children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: statsAsync.isLoading
            ? const Text(
                '—',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : Text(
                _formatCount(getValue(statsAsync.value) ?? 0),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade300,
          fontSize: 12,
        ),
      ),
    ],
  );
}
```

**Refactored Usage:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildStatValue(
      profileStatsAsync,
      (stats) => stats?.totalViews,
      'Total Views',
    ),
    _buildStatValue(
      profileStatsAsync,
      (stats) => stats?.totalLikes,
      'Total Likes',
    ),
  ],
);
```

**Lines Saved**: ~30

---

## 5. Empty Video List States Duplication (MEDIUM PRIORITY)

### Pattern 5A: home_screen_router.dart empty state (Lines 85-105)

**Current Implementation:**
```dart
if (videos.isEmpty) {
  return const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'No videos available',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        SizedBox(height: 8),
        Text(
          'Follow some creators to see their videos here',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
```

### Pattern 5B: profile_screen_router.dart empty state (Lines 777-814)

**Current Implementation:**
```dart
if (videos.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam_outlined, color: Colors.grey, size: 64),
        const SizedBox(height: 16),
        const Text(
          'No Videos Yet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ref.read(authServiceProvider).currentPublicKeyHex == userIdHex
              ? 'Share your first video to see it here'
              : "This user hasn't shared any videos yet",
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        IconButton(
          onPressed: () {
            ref.read(profileFeedProvider(userIdHex).notifier).loadMore();
          },
          icon: const Icon(Icons.refresh,
              color: VineTheme.vineGreen, size: 28),
          tooltip: 'Refresh',
        ),
      ],
    ),
  );
}
```

**Proposed Reusable Widget:**
```dart
class EmptyVideoListWidget extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onRefresh;
  final bool showRefreshButton;

  const EmptyVideoListWidget({
    Key? key,
    required this.title,
    required this.description,
    this.icon = Icons.video_library_outlined,
    this.onRefresh,
    this.showRefreshButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showRefreshButton) ...[
            const SizedBox(height: 32),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh,
                  color: VineTheme.vineGreen, size: 28),
              tooltip: 'Refresh',
            ),
          ],
        ],
      ),
    );
  }
}
```

**Refactored home_screen_router.dart:**
```dart
if (videos.isEmpty) {
  return const EmptyVideoListWidget(
    title: 'No videos available',
    description: 'Follow some creators to see their videos here',
  );
}
```

**Refactored profile_screen_router.dart:**
```dart
if (videos.isEmpty) {
  return EmptyVideoListWidget(
    title: 'No Videos Yet',
    description: ref.read(authServiceProvider).currentPublicKeyHex == userIdHex
        ? 'Share your first video to see it here'
        : "This user hasn't shared any videos yet",
    icon: Icons.videocam_outlined,
    showRefreshButton: true,
    onRefresh: () => ref.read(profileFeedProvider(userIdHex).notifier).loadMore(),
  );
}
```

**Lines Saved**: ~40-50 total

---

## 6. Empty Profile Tab States Duplication (LOW PRIORITY)

### Pattern 6A & 6B: profile_screen_router.dart (Lines 967-1033)

**Current Implementation - _buildLikedGrid:**
```dart
Widget _buildLikedGrid(SocialService socialService) {
  return CustomScrollView(
    slivers: [
      SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.favorite_border, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Liked Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Videos you like will appear here',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
```

**Current Implementation - _buildRepostsGrid:**
```dart
Widget _buildRepostsGrid() {
  return CustomScrollView(
    slivers: [
      SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.repeat, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Reposts Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Videos you repost will appear here',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
```

**Proposed Reusable Widget:**
```dart
class EmptyTabWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const EmptyTabWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

**Refactored Usage:**
```dart
TabBarView(
  controller: _tabController,
  children: [
    _buildVideosGrid(videos, userIdHex),
    const EmptyTabWidget(
      icon: Icons.favorite_border,
      title: 'No Liked Videos Yet',
      description: 'Videos you like will appear here',
    ),
    const EmptyTabWidget(
      icon: Icons.repeat,
      title: 'No Reposts Yet',
      description: 'Videos you repost will appear here',
    ),
  ],
);
```

**Lines Saved**: ~30

---

## Implementation Guide for Rabble

### High Priority (Do First)
1. **PageControllerSyncMixin Usage**: Add mixin to three router screens - straightforward substitution
2. **EmptyVideoListWidget**: Extract to `lib/widgets/empty_video_list_widget.dart`

### Medium Priority (Do Next)
3. **AsyncValueUIHelpersMixin**: Add to router screens - good for consistency
4. **Profile Stats Extraction**: Refactor `_buildStatValue()` in profile_screen_router.dart

### Lower Priority (Polish)
5. **NostrListFetchMixin**: Extract shared list-fetching logic
6. **EmptyTabWidget**: Consolidate profile tab empty states

---

