// ABOUTME: Pure search screen using revolutionary Riverpod architecture
// ABOUTME: Searches for videos, users, and hashtags using composition architecture

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pure search screen using revolutionary single-controller Riverpod architecture
class SearchScreenPure extends ConsumerStatefulWidget {
  const SearchScreenPure({super.key, this.embedded = false});

  final bool
  embedded; // When true, renders without Scaffold/AppBar (for embedding in ExploreScreen)

  @override
  ConsumerState<SearchScreenPure> createState() => _SearchScreenPureState();
}

class _SearchScreenPureState extends ConsumerState<SearchScreenPure>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _tabController;

  List<VideoEvent> _videoResults = [];
  List<String> _userResults = [];
  List<String> _hashtagResults = [];

  bool _isSearching = false;
  bool _isSearchingExternal = false;
  bool _hasSearchedExternal = false;
  int _localResultCount = 0;
  int _externalResultCount = 0;
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);

    // Initialize search term from URL if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final pageContext = ref.read(pageContextProvider);
        pageContext.whenData((ctx) {
          if (ctx.type == RouteType.search &&
              ctx.searchTerm != null &&
              ctx.searchTerm!.isNotEmpty) {
            // Set search controller text and trigger search
            // Pass updateUrl: false to avoid infinite loop during initialization
            _searchController.text = ctx.searchTerm!;
            _performSearch(ctx.searchTerm!, updateUrl: false);
            Log.info(
              '🔍 SearchScreenPure: Initialized with search term: ${ctx.searchTerm}',
              category: LogCategory.video,
            );
          } else {
            // Request focus for empty search
            _searchFocusNode.requestFocus();
          }
        });
      }
    });

    Log.info('🔍 SearchScreenPure: Initialized', category: LogCategory.video);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();

    Log.info('🔍 SearchScreenPure: Disposed', category: LogCategory.video);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query == _currentQuery) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query, {bool updateUrl = true}) async {
    if (query.isEmpty) {
      setState(() {
        _videoResults = [];
        _userResults = [];
        _hashtagResults = [];
        _isSearching = false;
        _hasSearchedExternal = false;
        _localResultCount = 0;
        _externalResultCount = 0;
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearchedExternal = false;
      _localResultCount = 0;
      _externalResultCount = 0;
      _currentQuery = query;
    });

    Log.info(
      '🔍 SearchScreenPure: Local search for: $query',
      category: LogCategory.video,
    );

    try {
      // Search local cache ONLY (embedded relay cache)
      final videoEventService = ref.read(videoEventServiceProvider);
      final videos = videoEventService.discoveryVideos;

      Log.debug(
        '🔍 SearchScreenPure: Filtering ${videos.length} cached videos',
        category: LogCategory.video,
      );

      // Filter local videos based on search query
      final filteredVideos = videos.where((video) {
        final titleMatch =
            video.title?.toLowerCase().contains(query.toLowerCase()) ?? false;
        final contentMatch = video.content.toLowerCase().contains(
          query.toLowerCase(),
        );
        final hashtagMatch = video.hashtags.any(
          (tag) => tag.toLowerCase().contains(query.toLowerCase()),
        );
        return titleMatch || contentMatch || hashtagMatch;
      }).toList();

      // Extract unique hashtags and users from local results
      final hashtags = <String>{};
      final users = <String>{};

      for (final video in filteredVideos) {
        for (final tag in video.hashtags) {
          if (tag.toLowerCase().contains(query.toLowerCase())) {
            hashtags.add(tag);
          }
        }
        users.add(video.pubkey);
      }

      // Sort local results before showing
      filteredVideos.sort(VideoEvent.compareByLoopsThenTime);

      // Show local results
      if (mounted) {
        setState(() {
          _videoResults = filteredVideos;
          _hashtagResults = hashtags.take(20).toList();
          _userResults = users.take(20).toList();
          _localResultCount = filteredVideos.length;
          _isSearching = false;
        });
        // Update provider so active video system can access search results
        ref.read(searchScreenVideosProvider.notifier).state = filteredVideos;
      }

      Log.info(
        '🔍 SearchScreenPure: Local results: ${filteredVideos.length} videos',
        category: LogCategory.video,
      );

      // Automatically search external relays (no button needed)
      _searchExternalRelays();
    } catch (e) {
      Log.error(
        '🔍 SearchScreenPure: Local search failed: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// Search external relays for more results (user-initiated)
  Future<void> _searchExternalRelays() async {
    if (_currentQuery.isEmpty || _isSearchingExternal) return;

    setState(() {
      _isSearchingExternal = true;
    });

    Log.info(
      '🔍 SearchScreenPure: Searching external relays for: $_currentQuery',
      category: LogCategory.video,
    );

    try {
      final videoEventService = ref.read(videoEventServiceProvider);

      // Search external relays via embedded relay NIP-50
      await videoEventService.searchVideos(_currentQuery, limit: 100);

      // Get remote results
      final remoteResults = videoEventService.searchResults;

      // Combine local + remote results
      final allVideos = [..._videoResults, ...remoteResults];

      // Deduplicate by video ID
      final seenIds = <String>{};
      final uniqueVideos = allVideos.where((video) {
        if (seenIds.contains(video.id)) return false;
        seenIds.add(video.id);
        return true;
      }).toList();

      // Sort: new vines (no loops) chronologically, then original vines by loop count
      uniqueVideos.sort(VideoEvent.compareByLoopsThenTime);

      // Extract all unique hashtags and users from combined results
      final allHashtags = <String>{};
      final allUsers = <String>{};

      for (final video in uniqueVideos) {
        for (final tag in video.hashtags) {
          if (tag.toLowerCase().contains(_currentQuery.toLowerCase())) {
            allHashtags.add(tag);
          }
        }
        allUsers.add(video.pubkey);
      }

      if (mounted) {
        setState(() {
          _videoResults = uniqueVideos;
          _hashtagResults = allHashtags.take(20).toList();
          _userResults = allUsers.take(20).toList();
          _externalResultCount = remoteResults.length;
          _hasSearchedExternal = true;
          _isSearchingExternal = false;
        });
        // Update provider so active video system can access merged search results
        ref.read(searchScreenVideosProvider.notifier).state = uniqueVideos;
      }

      Log.info(
        '🔍 SearchScreenPure: External search complete: ${remoteResults.length} new results (total: ${uniqueVideos.length})',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '🔍 SearchScreenPure: External search failed: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _isSearchingExternal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're in feed mode (videoIndex set in URL)
    final pageContext = ref.watch(pageContextProvider);
    final isInFeedMode = pageContext.maybeWhen(
      data: (ctx) => ctx.type == RouteType.search && ctx.videoIndex != null,
      orElse: () => false,
    );

    // If in feed mode, show video player instead of search UI
    if (isInFeedMode && _videoResults.isNotEmpty) {
      final videoIndex = pageContext.asData?.value.videoIndex ?? 0;
      final safeIndex = videoIndex.clamp(0, _videoResults.length - 1);

      return ExploreVideoScreenPure(
        startingVideo: _videoResults[safeIndex],
        videoList: _videoResults,
        contextTitle: 'Search: $_currentQuery',
        startingIndex: safeIndex,
        // No onBackToGrid needed - AppShell's AppBar back button handles this
      );
    }

    // Otherwise show search grid UI
    final searchBar = TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      style: const TextStyle(color: VineTheme.whiteText),
      decoration: InputDecoration(
        hintText: 'Search videos, users, hashtags...',
        hintStyle: TextStyle(color: VineTheme.whiteText.withValues(alpha: 0.6)),
        border: InputBorder.none,
        prefixIcon: _isSearching
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: VineTheme.vineGreen,
                    strokeWidth: 2,
                  ),
                ),
              )
            : const Icon(Icons.search, color: VineTheme.whiteText),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: VineTheme.whiteText),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              )
            : null,
      ),
    );

    final tabBar = TabBar(
      controller: _tabController,
      indicatorColor: VineTheme.whiteText,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: VineTheme.whiteText,
      unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
      tabs: [
        Tab(text: 'Videos (${_videoResults.length})'),
        Tab(text: 'Users (${_userResults.length})'),
        Tab(text: 'Hashtags (${_hashtagResults.length})'),
      ],
    );

    final tabContent = TabBarView(
      controller: _tabController,
      children: [_buildVideosTab(), _buildUsersTab(), _buildHashtagsTab()],
    );

    // Embedded mode: return content without scaffold
    if (widget.embedded) {
      return Container(
        color: VineTheme.backgroundColor, // Ensure visible background
        child: Column(
          children: [
            Container(
              color: VineTheme.cardBackground,
              padding: const EdgeInsets.all(8),
              child: searchBar,
            ),
            Container(color: VineTheme.cardBackground, child: tabBar),
            Expanded(child: tabContent),
          ],
        ),
      );
    }

    // Standalone mode: return full scaffold with app bar
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.cardBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: searchBar,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: tabBar,
        ),
      ),
      body: tabContent,
    );
  }

  Widget _buildVideosTab() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'Search for videos',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
            Text(
              'Enter keywords, hashtags, or user names',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Show loading indicator when searching external relays
        if (_isSearchingExternal)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.vineGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Searching servers...',
                  style: TextStyle(color: VineTheme.whiteText),
                ),
              ],
            ),
          ),

        // Video grid
        Expanded(
          child: ComposableVideoGrid(
            key: const Key('search-videos-grid'),
            videos: _videoResults,
            onVideoTap: (videos, index) {
              Log.info(
                '🔍 SearchScreenPure: Tapped video at index $index',
                category: LogCategory.video,
              );
              // Navigate using GoRouter to enable router-driven video playback
              context.goSearch(
                _currentQuery.isNotEmpty ? _currentQuery : null,
                index,
              );
            },
            emptyBuilder: () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library,
                    size: 64,
                    color: VineTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearchingExternal
                        ? 'Searching servers for "$_currentQuery"...'
                        : 'No videos found for "$_currentQuery"',
                    style: TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'Search for users',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
            Text(
              'Find content creators and friends',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    if (_userResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_currentQuery"',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Sort users: those with display names first, unnamed users last
    final sortedUsers = List<String>.from(_userResults);
    final profileService = ref.watch(userProfileServiceProvider);

    sortedUsers.sort((a, b) {
      final profileA = profileService.getCachedProfile(a);
      final profileB = profileService.getCachedProfile(b);

      final hasNameA =
          profileA?.bestDisplayName != null &&
          !profileA!.bestDisplayName.startsWith('npub') &&
          !profileA.bestDisplayName.startsWith('@');
      final hasNameB =
          profileB?.bestDisplayName != null &&
          !profileB!.bestDisplayName.startsWith('npub') &&
          !profileB.bestDisplayName.startsWith('@');

      // Users with names come first
      if (hasNameA && !hasNameB) return -1;
      if (!hasNameA && hasNameB) return 1;
      return 0;
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedUsers.length,
      itemBuilder: (context, index) {
        final userPubkey = sortedUsers[index];

        return UserProfileTile(
          pubkey: userPubkey,
          showFollowButton: false, // Hide follow button in search results
          onTap: () {
            Log.info(
              '🔍 SearchScreenPure: Tapped user: $userPubkey',
              category: LogCategory.video,
            );
            context.goProfileGrid(userPubkey);
          },
        );
      },
    );
  }

  Widget _buildHashtagsTab() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'Search for hashtags',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
            Text(
              'Discover trending topics and content',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    if (_hashtagResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag_outlined, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No hashtags found for "$_currentQuery"',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final hashtag = _hashtagResults[index];
        return Card(
          color: VineTheme.cardBackground,
          child: ListTile(
            leading: Icon(Icons.tag, color: VineTheme.vineGreen),
            title: Text(
              '#$hashtag',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Tap to view videos with this hashtag',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
            onTap: () {
              Log.info(
                '🔍 SearchScreenPure: Tapped hashtag: $hashtag',
                category: LogCategory.video,
              );
              // Navigate using GoRouter
              context.goHashtag(hashtag);
            },
          ),
        );
      },
    );
  }
}
