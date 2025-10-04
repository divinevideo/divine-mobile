// ABOUTME: Pure search screen using revolutionary Riverpod architecture
// ABOUTME: Searches for videos, users, and hashtags using composition architecture

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/screens/profile_screen_scrollable.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/pure/video_grid_widget.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pure search screen using revolutionary single-controller Riverpod architecture
class SearchScreenPure extends ConsumerStatefulWidget {
  const SearchScreenPure({super.key, this.embedded = false});

  final bool embedded; // When true, renders without Scaffold/AppBar (for embedding in ExploreScreen)

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
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);

    // Request focus after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
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

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _videoResults = [];
        _userResults = [];
        _hashtagResults = [];
        _isSearching = false;
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    Log.info('🔍 SearchScreenPure: Hybrid search for: $query', category: LogCategory.video);

    try {
      // PHASE 1: Search local cache immediately for instant results
      final videoEventsAsync = ref.read(videoEventsProvider);

      await videoEventsAsync.when(
        loading: () async {
          Log.debug('🔍 SearchScreenPure: Waiting for video cache to load', category: LogCategory.video);
        },
        error: (error, stack) async {
          Log.error('🔍 SearchScreenPure: Error loading local videos: $error', category: LogCategory.video);
        },
        data: (videos) async {
          // Filter local videos based on search query
          final filteredVideos = videos.where((video) {
            final titleMatch = video.title?.toLowerCase().contains(query.toLowerCase()) ?? false;
            final contentMatch = video.content.toLowerCase().contains(query.toLowerCase());
            final hashtagMatch = video.hashtags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
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

          // Show local results immediately
          if (mounted) {
            setState(() {
              _videoResults = filteredVideos;
              _hashtagResults = hashtags.take(20).toList();
              _userResults = users.take(20).toList();
              // Keep isSearching=true to show we're still searching remote
            });
          }

          Log.info('🔍 SearchScreenPure: Local results: ${filteredVideos.length} videos', category: LogCategory.video);
        },
      );

      // PHASE 2: Search remote relay via VideoEventService (NIP-50)
      final videoEventService = ref.read(videoEventServiceProvider);

      Log.info('🔍 SearchScreenPure: Starting remote relay search', category: LogCategory.video);

      // Start remote search (non-blocking)
      await videoEventService.searchVideos(query, limit: 50);

      // Wait briefly for remote results to arrive
      await Future.delayed(const Duration(milliseconds: 800));

      // Combine local + remote results
      final remoteResults = videoEventService.searchResults;
      final allVideos = [..._videoResults, ...remoteResults];

      // Deduplicate by video ID
      final seenIds = <String>{};
      final uniqueVideos = allVideos.where((video) {
        if (seenIds.contains(video.id)) return false;
        seenIds.add(video.id);
        return true;
      }).toList();

      // Extract all unique hashtags and users from combined results
      final allHashtags = <String>{};
      final allUsers = <String>{};

      for (final video in uniqueVideos) {
        for (final tag in video.hashtags) {
          if (tag.toLowerCase().contains(query.toLowerCase())) {
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
          _isSearching = false;
        });
      }

      Log.info('🔍 SearchScreenPure: Final results: ${uniqueVideos.length} videos (${remoteResults.length} from remote)',
          category: LogCategory.video);
    } catch (e) {
      Log.error('🔍 SearchScreenPure: Search failed: $e', category: LogCategory.video);

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchBar = TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      style: const TextStyle(color: VineTheme.whiteText),
      decoration: InputDecoration(
        hintText: 'Search videos, users, hashtags...',
        hintStyle: TextStyle(color: VineTheme.whiteText.withValues(alpha: 0.6)),
        border: InputBorder.none,
        prefixIcon: const Icon(Icons.search, color: VineTheme.whiteText),
        suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: VineTheme.whiteText),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            )
          : _isSearching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: VineTheme.whiteText,
                  strokeWidth: 2,
                ),
              )
            : null,
      ),
    );

    final tabBar = TabBar(
      controller: _tabController,
      indicatorColor: VineTheme.whiteText,
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
      children: [
        _buildVideosTab(),
        _buildUsersTab(),
        _buildHashtagsTab(),
      ],
    );

    // Embedded mode: return content without scaffold
    if (widget.embedded) {
      return Column(
        children: [
          Container(
            color: VineTheme.vineGreen,
            padding: const EdgeInsets.all(8),
            child: searchBar,
          ),
          Container(
            color: VineTheme.vineGreen,
            child: tabBar,
          ),
          Expanded(child: tabContent),
        ],
      );
    }

    // Standalone mode: return full scaffold with app bar
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
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

    return VideoGridWidget(
      key: const Key('search-videos-grid'),
      videos: _videoResults,
      crossAxisCount: 2,
      emptyMessage: 'No videos found for "$_currentQuery"',
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final userPubkey = _userResults[index];
        final profileService = ref.watch(userProfileServiceProvider);
        final profile = profileService.getCachedProfile(userPubkey);
        final displayName = profile?.displayName ??
                           profile?.name ??
                           '@${userPubkey.substring(0, 8)}...';

        return Card(
          color: VineTheme.cardBackground,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: VineTheme.vineGreen,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: VineTheme.whiteText, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              displayName,
              style: TextStyle(color: VineTheme.primaryText),
            ),
            subtitle: Text(
              'Content creator',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
            onTap: () {
              Log.info('🔍 SearchScreenPure: Tapped user: $userPubkey', category: LogCategory.video);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileScreenScrollable(profilePubkey: userPubkey),
                ),
              );
            },
          ),
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
              style: TextStyle(color: VineTheme.primaryText, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Tap to view videos with this hashtag',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
            onTap: () {
              Log.info('🔍 SearchScreenPure: Tapped hashtag: $hashtag', category: LogCategory.video);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HashtagFeedScreen(hashtag: hashtag),
                ),
              );
            },
          ),
        );
      },
    );
  }
}