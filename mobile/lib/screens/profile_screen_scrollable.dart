// ABOUTME: Instagram-style scrollable profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling experience

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/profile_videos_provider.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/vine_drafts_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_encoding.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreenScrollable extends ConsumerStatefulWidget {
  const ProfileScreenScrollable({super.key, this.profilePubkey});
  final String? profilePubkey;

  @override
  ConsumerState<ProfileScreenScrollable> createState() =>
      _ProfileScreenScrollableState();
}

class _ProfileScreenScrollableState
    extends ConsumerState<ProfileScreenScrollable>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isOwnProfile = true;
  String? _targetPubkey;
  bool _isInitializing = true;
  final ScrollController _scrollController = ScrollController();

  // Feed mode state (like ExploreScreen)
  bool _isInFeedMode = false;
  List<VideoEvent>? _feedVideos;
  int _feedStartIndex = 0;

  // Custom title for AppBar (like ExploreScreen pattern)
  String? get customTitle {
    if (_isInitializing || _targetPubkey == null) return null;

    final authService = ref.read(authServiceProvider);
    final userProfileService = ref.read(userProfileServiceProvider);

    final authProfile = _isOwnProfile ? authService.currentProfile : null;
    final cachedProfile = !_isOwnProfile ? userProfileService.getCachedProfile(_targetPubkey!) : null;

    return authProfile?.displayName ?? cachedProfile?.displayName;
  }

  @override
  void initState() {
    super.initState();
    Log.info('🎬 ProfileScreenScrollable.initState: widget.profilePubkey=${widget.profilePubkey?.substring(0, 8) ?? 'null (own profile)'}, hashCode=${hashCode}',
        name: 'ProfileScreenScrollable', category: LogCategory.ui);
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Log.info('🎯 ProfileScreenScrollable: postFrameCallback - calling _initializeProfile for ${widget.profilePubkey?.substring(0, 8) ?? 'own'}',
          name: 'ProfileScreenScrollable', category: LogCategory.ui);
      _initializeProfile();
    });
  }

  Future<void> _initializeProfile() async {
    final authService = ref.read(authServiceProvider);

    // Wait for AuthService to be properly initialized
    if (!authService.isAuthenticated) {
      Log.warning('AuthService not ready, waiting for authentication',
          name: 'ProfileScreen', category: LogCategory.ui);

      // Use proper async pattern instead of Future.delayed
      final completer = Completer<void>();

      void checkAuth() {
        if (authService.isAuthenticated &&
            authService.currentPublicKeyHex != null) {
          completer.complete();
        } else {
          // Check again on next frame
          WidgetsBinding.instance.addPostFrameCallback((_) => checkAuth());
        }
      }

      checkAuth();
      await completer.future;
    }

    final currentUserPubkey = authService.currentPublicKeyHex;

    setState(() {
      _targetPubkey = widget.profilePubkey ?? currentUserPubkey;
      _isOwnProfile = _targetPubkey == currentUserPubkey;
      _isInitializing = false;
    });

    Log.debug(
        '🔍 initState complete | _targetPubkey=${_targetPubkey?.substring(0, 8) ?? 'null'} | widget.profilePubkey=${widget.profilePubkey?.substring(0, 8) ?? 'null'} | currentUserPubkey=${currentUserPubkey?.substring(0, 8) ?? 'null'}',
        name: 'ProfileScreen',
        category: LogCategory.ui);

    if (_targetPubkey != null) {
      Log.debug('✅ _targetPubkey is not null, calling _loadProfileVideos()',
          name: 'ProfileScreen', category: LogCategory.ui);
      _loadProfileVideos();

      if (!_isOwnProfile) {
        _loadUserProfile();
      }
    } else {
      Log.error('❌ _targetPubkey is null, skipping video load',
          name: 'ProfileScreen', category: LogCategory.ui);
    }
  }

  void _loadProfileVideos() {
    if (_targetPubkey == null) {
      Log.error('Cannot load profile videos: _targetPubkey is null',
          name: 'ProfileScreen', category: LogCategory.ui);
      return;
    }

    Log.debug(
        'Loading profile videos for: ${_targetPubkey!.substring(0, 8)}... (isOwnProfile: $_isOwnProfile)',
        name: 'ProfileScreen',
        category: LogCategory.ui);
    try {
      ref
          .read(profileVideosProvider.notifier)
          .loadVideosForUser(_targetPubkey!)
          .then((_) {
        Log.info(
            'Profile videos load completed for ${_targetPubkey!.substring(0, 8)}',
            name: 'ProfileScreen',
            category: LogCategory.ui);
      }).catchError((error) {
        Log.error(
            'Profile videos load failed for ${_targetPubkey!.substring(0, 8)}: $error',
            name: 'ProfileScreen',
            category: LogCategory.ui);
      });
    } catch (e) {
      Log.error('Error initiating profile videos load: $e',
          name: 'ProfileScreen', category: LogCategory.ui);
    }
  }

  void _loadUserProfile() {
    if (_targetPubkey == null) return;
    final userProfileService = ref.read(userProfileServiceProvider);

    // Only fetch if not already cached - show cached data immediately
    if (!userProfileService.hasProfile(_targetPubkey!)) {
      Log.debug(
          '📥 Fetching uncached profile: ${_targetPubkey!.substring(0, 8)}',
          name: 'ProfileScreenScrollable',
          category: LogCategory.ui);
      userProfileService.fetchProfile(_targetPubkey!);
    } else {
      Log.debug('📋 Using cached profile: ${_targetPubkey!.substring(0, 8)}',
          name: 'ProfileScreenScrollable', category: LogCategory.ui);
      // Still call fetchProfile to trigger background refresh if needed
      userProfileService.fetchProfile(_targetPubkey!);
    }
  }

  @override
  void didUpdateWidget(ProfileScreenScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);

    Log.info('🔄 ProfileScreenScrollable.didUpdateWidget: old=${oldWidget.profilePubkey?.substring(0, 8) ?? 'null'} → new=${widget.profilePubkey?.substring(0, 8) ?? 'null'}, hashCode=${hashCode}',
        name: 'ProfileScreenScrollable', category: LogCategory.ui);

    // Check if the profilePubkey parameter has changed
    if (widget.profilePubkey != oldWidget.profilePubkey) {
      Log.info(
          '✅ Profile parameter CHANGED from ${oldWidget.profilePubkey?.substring(0, 8) ?? 'own'} to ${widget.profilePubkey?.substring(0, 8) ?? 'own'} - reinitializing',
          name: 'ProfileScreenScrollable',
          category: LogCategory.ui);

      // Set initializing state and reinitialize profile with new pubkey
      _isInitializing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeProfile();
      });
    } else {
      Log.debug('⏭️ Profile parameter unchanged - no action needed',
          name: 'ProfileScreenScrollable', category: LogCategory.ui);
    }
  }

  @override
  void dispose() {
    Log.info('🗑️ ProfileScreenScrollable.dispose: profilePubkey=${widget.profilePubkey?.substring(0, 8) ?? 'null'}, hashCode=${hashCode}',
        name: 'ProfileScreenScrollable', category: LogCategory.ui);
    _tabController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _enterFeedMode(List<VideoEvent> videos, int startIndex) {
    if (!mounted) return;

    setState(() {
      _isInFeedMode = true;
      _feedVideos = videos;
      _feedStartIndex = startIndex;
    });

    // Set active video
    if (startIndex >= 0 && startIndex < videos.length) {
      ref.read(activeVideoProvider.notifier).setActiveVideo(videos[startIndex].id);
    }

    Log.info('🎯 ProfileScreen: Entered feed mode at index $startIndex',
        category: LogCategory.video);
  }

  void _exitFeedMode() {
    if (!mounted) return;

    setState(() {
      _isInFeedMode = false;
      _feedVideos = null;
    });

    // Clear active video on exit
    ref.read(activeVideoProvider.notifier).clearActiveVideo();

    Log.info('🎯 ProfileScreen: Exited feed mode',
        category: LogCategory.video);
  }

  @override
  Widget build(BuildContext context) {
    Log.debug('🎯 ProfileScreen: build() called - _isInitializing=$_isInitializing, _targetPubkey=$_targetPubkey',
        name: 'ProfileScreen', category: LogCategory.ui);

    // Show loading screen during initialization
    if (_isInitializing || _targetPubkey == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: VineTheme.vineGreen),
            SizedBox(height: 16),
            Text(
              'Loading Profile...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // If in feed mode, show full-screen video player (covers parent AppBar)
    if (_isInFeedMode && _feedVideos != null) {
      final authSvc = ref.watch(authServiceProvider);
      final targetPubkey = _targetPubkey ?? authSvc.currentPublicKeyHex ?? '';

      // Watch profile from embedded relay
      final profileAsync = ref.watch(fetchUserProfileProvider(targetPubkey));
      final displayName = profileAsync.value?.displayName ?? 'User';

      // Get current video for edit/delete actions
      final currentVideo = _feedVideos![_feedStartIndex];
      final isOwnVideo = currentVideo.pubkey == authSvc.currentPublicKeyHex;

      // Return full Scaffold to cover parent AppBar with gesture support
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Support swipe-down to exit (like TikTok/Instagram)
          onVerticalDragEnd: (details) {
            // Swipe down with sufficient velocity = exit
            if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
              _exitFeedMode();
            }
          },
          child: Stack(
            children: [
              // Video player (full screen)
              ExploreVideoScreenPure(
                startingVideo: currentVideo,
                videoList: _feedVideos!,
                contextTitle: displayName,
                startingIndex: _feedStartIndex,
              ),
              // Clean header: [Profile Name] [Edit/Delete] - tappable to exit
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: GestureDetector(
                    // Tap header to exit (Option 1)
                    onTap: _exitFeedMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          // Profile name (tap to exit)
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Edit/Delete buttons for own videos
                          if (isOwnVideo) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 22),
                              onPressed: () {
                                // TODO: Implement edit video
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Edit video - coming soon')),
                                );
                              },
                              tooltip: 'Edit video',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white, size: 22),
                              onPressed: () {
                                // TODO: Implement delete video with confirmation
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Delete video - coming soon')),
                                );
                              },
                              tooltip: 'Delete video',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final authService = ref.watch(authServiceProvider);
    final socialService = ref.watch(socialServiceProvider);

    // Get the current user's pubkey for stats/videos
    final targetPubkey = _targetPubkey ?? authService.currentPublicKeyHex ?? '';
    final profileStatsAsync = ref.watch(fetchProfileStatsProvider(targetPubkey));

    // DEBUG: Check AsyncValue state
    Log.debug(
        '📊 ProfileStats AsyncValue: isLoading=${profileStatsAsync.isLoading}, '
        'hasValue=${profileStatsAsync.hasValue}, '
        'hasError=${profileStatsAsync.hasError}, '
        'value=${profileStatsAsync.value}',
        name: 'ProfileScreen',
        category: LogCategory.ui);

    // Watch the profile videos notifier state for reactive updates
    final profileVideosState = ref.watch(profileVideosProvider);

    // Convert notifier state to AsyncValue for compatibility with existing UI code
    final profileVideosAsync = profileVideosState.isLoading && profileVideosState.videos.isEmpty
        ? const AsyncValue<List<VideoEvent>>.loading()
        : profileVideosState.hasError
            ? AsyncValue<List<VideoEvent>>.error(profileVideosState.error!, StackTrace.current)
            : AsyncValue.data(profileVideosState.videos);

    return Stack(
      children: [
        DefaultTabController(
          length: 3,
          child: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // Profile Header
                SliverToBoxAdapter(
                  child: _buildScrollableProfileHeader(
                      authService, profileStatsAsync),
                ),

                // Stats Row
                SliverToBoxAdapter(
                  child: _buildStatsRow(profileStatsAsync),
                ),

                // Action Buttons
                SliverToBoxAdapter(
                  child: _buildActionButtons(socialService),
                ),

                // Sticky Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      indicatorWeight: 2,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on, size: 20)),
                        Tab(icon: Icon(Icons.favorite_border, size: 20)),
                        Tab(icon: Icon(Icons.repeat, size: 20)),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildSliverVinesGrid(profileVideosAsync),
                  _buildSliverLikedGrid(socialService),
                  _buildSliverRepostsGrid(),
                ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableProfileHeader(
    AuthService authService,
    AsyncValue<ProfileStats> profileStatsAsync,
  ) {
    // Watch profile from embedded relay (reactive)
    final targetPubkey = _targetPubkey ?? authService.currentPublicKeyHex ?? '';
    final profileAsync = ref.watch(fetchUserProfileProvider(targetPubkey));
    final profile = profileAsync.value;

    final profilePictureUrl = profile?.picture;
    final displayName = profile?.displayName;
    final hasCustomName = displayName != null &&
        !displayName.startsWith('npub1') &&
        displayName != 'Loading user information';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Setup profile banner for new users with default names (only on own profile)
          if (_isOwnProfile && !hasCustomName)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add your name, bio, and picture to get started',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _setupProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Set Up',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Profile picture and stats row
          Row(
            children: [
              // Profile picture
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.pink, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: UserAvatar(
                      imageUrl: profilePictureUrl,
                      name: null,
                      size: 80,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDynamicStatColumn(
                      profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.videoCount
                          : null,
                      'Vines',
                      profileStatsAsync.isLoading,
                    ),
                    _buildDynamicStatColumn(
                      profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.followers
                          : null,
                      'Followers',
                      profileStatsAsync.isLoading,
                    ),
                    _buildDynamicStatColumn(
                      profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.following
                          : null,
                      'Following',
                      profileStatsAsync.isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name and bio
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SelectableText(
                      displayName ?? 'Loading user information',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // Add NIP-05 verification badge if verified
                    if (profile?.nip05 != null && profile!.nip05!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Show NIP-05 identifier if present
                if (profile?.nip05 != null && profile!.nip05!.isNotEmpty)
                  Text(
                    profile.nip05!,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                if (profile?.about != null && profile!.about!.isNotEmpty)
                  SelectableText(
                    profile.about!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                // Public key display with copy functionality
                if (_targetPubkey != null)
                  GestureDetector(
                    onTap: _copyNpubToClipboard,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[600]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            NostrEncoding.encodePublicKey(_targetPubkey!),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.copy,
                            color: Colors.grey,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverVinesGrid(
      AsyncValue<List<VideoEvent>> profileVideosAsync) {
    if (profileVideosAsync.isLoading &&
        (profileVideosAsync.value?.isEmpty ?? true)) {
      return const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (profileVideosAsync.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Error loading videos',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              profileVideosAsync.error?.toString() ?? 'Unknown error',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _targetPubkey != null
                  ? () => ref
                      .read(profileVideosProvider.notifier)
                      .refreshVideos(_targetPubkey!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.whiteText,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (profileVideosAsync.value?.isEmpty ?? true) {
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
              _isOwnProfile
                  ? 'Share your first video to see it here'
                  : "This user hasn't shared any videos yet",
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            IconButton(
              onPressed: () async {
                Log.debug(
                    'Manual refresh videos requested for ${_targetPubkey?.substring(0, 8)}',
                    name: 'ProfileScreen',
                    category: LogCategory.ui);
                if (_targetPubkey != null) {
                  try {
                    await ref
                        .read(profileVideosProvider.notifier)
                        .refreshVideos(_targetPubkey!);
                    Log.info('Manual refresh completed',
                        name: 'ProfileScreen', category: LogCategory.ui);
                  } catch (e) {
                    Log.error('Manual refresh failed: $e',
                        name: 'ProfileScreen', category: LogCategory.ui);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Refresh failed: $e')),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.refresh,
                  color: VineTheme.vineGreen, size: 28),
              tooltip: 'Refresh',
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= (profileVideosAsync.value?.length ?? 0)) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: VineTheme.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final videoEvent = profileVideosAsync.value?[index];
                if (videoEvent == null) {
                  // Show loading placeholder instead of empty Container
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: VineTheme.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () {
                    final videos = profileVideosAsync.value ?? const <VideoEvent>[];
                    Log.info('🎯 ProfileScreen: Tapped video tile at index $index',
                        category: LogCategory.video);
                    _enterFeedMode(videos, index);
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: VineTheme.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: videoEvent.thumbnailUrl != null &&
                                    videoEvent.thumbnailUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: videoEvent.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: LinearGradient(
                                          colors: [
                                            VineTheme.vineGreen.withValues(alpha: 0.3),
                                            Colors.blue.withValues(alpha: 0.3),
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: VineTheme.whiteText,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: LinearGradient(
                                          colors: [
                                            VineTheme.vineGreen.withValues(alpha: 0.3),
                                            Colors.blue.withValues(alpha: 0.3),
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          color: VineTheme.whiteText,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: LinearGradient(
                                        colors: [
                                          VineTheme.vineGreen.withValues(alpha: 0.3),
                                          Colors.blue.withValues(alpha: 0.3),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: VineTheme.whiteText,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white70,
                            size: 32,
                          ),
                        ),
                        if (videoEvent.duration != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                videoEvent.formattedDuration,
                                style: const TextStyle(
                                  color: VineTheme.whiteText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                
              },
              childCount: profileVideosAsync.value?.length ?? 0,
            ),
          ),
        ),
        // Load more trigger
        // TODO: Implement load more with new AsyncValue pattern
      ],
    );
  }

  Widget _buildSliverLikedGrid(SocialService socialService) {
    // Placeholder for liked grid - implement similar to vines grid
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

  Widget _buildSliverRepostsGrid() {
    // Placeholder for reposts grid - implement similar to vines grid
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

  // Helper methods (copied from original)
  Widget _buildDynamicStatColumn(int? count, String label, bool isLoading) =>
      Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLoading
                ? const Text(
                    '—',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : Text(
                    count != null ? _formatCount(count) : '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );

  String _formatCount(int count) {
    return StringUtils.formatCompactNumber(count);
  }

  Widget _buildStatsRow(AsyncValue<ProfileStats> profileStatsAsync) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
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
          ],
        ),
      );

  Widget _buildActionButtons(SocialService socialService) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            if (_isOwnProfile) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _editProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  key: const Key('drafts-button'),
                  onPressed: _openDrafts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Drafts'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _shareProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Share Profile'),
                ),
              ),
            ] else ...[
              Expanded(
                child: Builder(
                  builder: (context) {
                    final isFollowing =
                        socialService.isFollowing(_targetPubkey!);
                    return ElevatedButton(
                      onPressed: isFollowing ? _unfollowUser : _followUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isFollowing ? Colors.grey[700] : Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.mail_outline),
              ),
            ],
          ],
        ),
      );

  // All the action methods

  Future<void> _setupProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: true),
      ),
    );

    // Refresh profile after setup
    if (mounted) {
      _initializeProfile();
    }
  }

  Future<void> _editProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: false),
      ),
    );

    // Refresh profile after editing
    if (mounted) {
      _initializeProfile();
    }
  }

  Future<void> _shareProfile() async {
    try {
      final pubkey = _targetPubkey;
      if (pubkey == null) {
        Log.warning('Cannot share profile: pubkey is null',
            name: 'ProfileScreen', category: LogCategory.ui);
        return;
      }

      // Get profile info for better share text
      final profile = await ref.read(userProfileServiceProvider).fetchProfile(pubkey);
      final displayName = profile?.displayName ?? 'User';

      // Convert hex pubkey to npub format for sharing
      final npub = NostrEncoding.encodePublicKey(pubkey);

      // Create share text with divine.video URL format
      final shareText = 'Check out $displayName on divine!\n\n'
          'https://divine.video/profile/$npub';

      // Use share_plus to show native share sheet
      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: '$displayName on divine',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        Log.info('Profile shared successfully',
            name: 'ProfileScreen',
            category: LogCategory.ui);
      }
    } catch (e) {
      Log.error('Error sharing profile: $e',
          name: 'ProfileScreen',
          category: LogCategory.ui);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share profile: $e')),
        );
      }
    }
  }

  void _openDrafts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VineDraftsScreen(),
      ),
    );
  }

  Future<void> _followUser() async {
    if (_targetPubkey == null) return;

    await FollowActionsHelper.followUser(
      ref: ref,
      context: context,
      pubkey: _targetPubkey!,
      contextName: 'ProfileScreen',
    );
  }

  Future<void> _unfollowUser() async {
    if (_targetPubkey == null) return;

    await FollowActionsHelper.unfollowUser(
      ref: ref,
      context: context,
      pubkey: _targetPubkey!,
      contextName: 'ProfileScreen',
    );
  }

  void _sendMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening messages...')),
    );
  }

  Future<void> _copyNpubToClipboard() async {
    if (_targetPubkey == null) return;

    try {
      final npub = NostrEncoding.encodePublicKey(_targetPubkey!);
      await Clipboard.setData(ClipboardData(text: npub));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 8),
                Text('Public key copied to clipboard'),
              ],
            ),
            backgroundColor: VineTheme.vineGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: VineTheme.backgroundColor,
        child: _tabBar,
      );

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
