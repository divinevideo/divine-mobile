// ABOUTME: Router-driven Instagram-style profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling, URL is source of truth

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/vine_drafts_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_encoding.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:openvine/screens/followers_screen.dart';
import 'package:openvine/screens/following_screen.dart';

/// Router-driven ProfileScreen - Instagram-style scrollable profile
class ProfileScreenRouter extends ConsumerStatefulWidget {
  const ProfileScreenRouter({super.key});

  @override
  ConsumerState<ProfileScreenRouter> createState() =>
      _ProfileScreenRouterState();
}

class _ProfileScreenRouterState extends ConsumerState<ProfileScreenRouter>
    with TickerProviderStateMixin, VideoPrefetchMixin, PageControllerSyncMixin, AsyncValueUIHelpersMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  PageController? _videoController;  // For fullscreen video mode
  int? _lastVideoUrlIndex;  // Track URL changes for video mode

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // NOTE: Router-driven architecture - active video automatically updates based on URL
    // No manual state management needed - tab changes trigger route changes which update activeVideoIdProvider
  }

  void _fetchProfileIfNeeded(String userIdHex, bool isOwnProfile) {
    if (isOwnProfile) return; // Own profile loads automatically

    final userProfileService = ref.read(userProfileServiceProvider);

    // Fetch profile (shows cached immediately, refreshes in background)
    if (!userProfileService.hasProfile(userIdHex)) {
      Log.debug(
        '📥 Fetching uncached profile: ${userIdHex}',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );
      userProfileService.fetchProfile(userIdHex);
    } else {
      Log.debug('📋 Using cached profile: ${userIdHex}',
          name: 'ProfileScreenRouter', category: LogCategory.ui);
      // Still call fetchProfile to trigger background refresh if needed
      userProfileService.fetchProfile(userIdHex);
    }
  }

  void _navigateToFollowers(BuildContext context, String pubkey, String displayName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowersScreen(pubkey: pubkey, displayName: displayName),
      ),
    );
  }

  void _navigateToFollowing(BuildContext context, String pubkey, String displayName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowingScreen(pubkey: pubkey, displayName: displayName),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.info('🧭 ProfileScreenRouter.build', name: 'ProfileScreenRouter');

    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    return buildAsyncUI(
      pageContext,
      onData: (ctx) {
        // Only handle profile routes
        if (ctx.type != RouteType.profile) {
          return const Center(child: Text('Not a profile route'));
        }

        // Convert npub to hex for profile feed provider
        final npub = ctx.npub ?? '';

        // Handle "me" special case - redirect to actual user profile
        if (npub == 'me') {
          final authService = ref.watch(authServiceProvider);
          if (!authService.isAuthenticated || authService.currentPublicKeyHex == null) {
            // Not authenticated - redirect to home
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                GoRouter.of(context).go('/home/0');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          // Get current user's npub and redirect (preserve grid/feed mode from context)
          final currentUserNpub = NostrEncoding.encodePublicKey(authService.currentPublicKeyHex!);
          final videoIndex = ctx.videoIndex; // Don't default to 0 - preserve null for grid mode

          // Redirect to actual user profile using GoRouter explicitly
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Use context extension to properly handle null videoIndex (grid mode)
              if (videoIndex != null) {
                context.goProfile(currentUserNpub, videoIndex);
              } else {
                context.goProfileGrid(currentUserNpub);
              }
            }
          });

          // Show loading while redirecting
          return const Center(child: CircularProgressIndicator());
        }

        final userIdHex = npubToHexOrNull(npub);

        if (userIdHex == null) {
          return const Center(child: Text('Invalid profile ID'));
        }

        // Get current user for comparison
        final authService = ref.watch(authServiceProvider);
        final currentUserHex = authService.currentPublicKeyHex;
        final isOwnProfile = userIdHex == currentUserHex;

        // Check if this user has muted us (mutual mute blocking)
        final blocklistService = ref.watch(contentBlocklistServiceProvider);
        if (blocklistService.shouldFilterFromFeeds(userIdHex)) {
          return Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const Center(
              child: Text(
                'This account is not available',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        // Get video data from profile feed
        final videosAsync = ref.watch(profileFeedProvider(userIdHex));

        // Get profile stats
        final profileStatsAsync = ref.watch(fetchProfileStatsProvider(userIdHex));

        // Fetch profile data if needed (post-frame to avoid build mutations)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _fetchProfileIfNeeded(userIdHex, isOwnProfile);
          }
        });

        // Check if we should show fullscreen video mode (videoIndex > 0)
        final videoIndex = ctx.videoIndex;

        // Show main profile UI
        return buildAsyncUI(
          videosAsync,
          onData: (state) {
            final videos = state.videos;
            final socialService = ref.watch(socialServiceProvider);

            // If videoIndex is set, show fullscreen video mode
            // Note: videoIndex maps directly to list index (0 = first video, 1 = second video, etc.)
            // When videoIndex is null, show grid mode
            if (videoIndex != null && videos.isNotEmpty) {
              // videoIndex IS the list index - no conversion needed
              final listIndex = videoIndex;
              final safeIndex = listIndex.clamp(0, videos.length - 1);

              Log.debug(
                '🎬 ProfileScreenRouter video mode: videoIndex=$videoIndex, listIndex=$listIndex, safeIndex=$safeIndex, '
                'videos.length=${videos.length}, controllerExists=${_videoController != null}, '
                'lastUrlIndex=$_lastVideoUrlIndex',
                name: 'ProfileScreenRouter',
                category: LogCategory.video,
              );

              // Initialize controller once with URL index
              if (_videoController == null) {
                Log.info(
                  '🆕 Creating PageController with initialPage=$safeIndex for videoIndex=$videoIndex',
                  name: 'ProfileScreenRouter',
                  category: LogCategory.video,
                );
                _videoController = PageController(initialPage: safeIndex);
                _lastVideoUrlIndex = listIndex; // Track URL index, not safe index
              } else {
                // Sync controller when URL changes externally (back/forward/deeplink)
                // OR when videos list changes (e.g., provider reloads)
                // Only sync if controller already exists - initialPage handles first navigation
                final targetIndex = listIndex.clamp(0, videos.length - 1);
                final currentPage = _videoController!.hasClients ? _videoController!.page?.round() : null;

                Log.debug(
                  '🔄 Checking sync: urlIndex=$listIndex, lastUrlIndex=$_lastVideoUrlIndex, '
                  'hasClients=${_videoController!.hasClients}, currentPage=$currentPage, targetIndex=$targetIndex',
                  name: 'ProfileScreenRouter',
                  category: LogCategory.video,
                );

                if (shouldSync(
                  urlIndex: listIndex,
                  lastUrlIndex: _lastVideoUrlIndex,
                  controller: _videoController,
                  targetIndex: targetIndex,
                )) {
                  Log.info(
                    '📍 Syncing PageController: $currentPage → $targetIndex',
                    name: 'ProfileScreenRouter',
                    category: LogCategory.video,
                  );
                  _lastVideoUrlIndex = listIndex;
                  syncPageController(
                    controller: _videoController!,
                    targetIndex: listIndex,
                    itemCount: videos.length,
                  );
                }
              }

              // Build fullscreen video PageView
              return PageView.builder(
                key: const Key('profile-video-page-view'),
                controller: _videoController,
                scrollDirection: Axis.vertical,
                itemCount: videos.length,
                onPageChanged: (newIndex) {
                  // Update URL when swiping to stay in profile context
                  // videoIndex maps directly to list index (no conversion needed)
                  if (newIndex != videoIndex) {
                    context.goProfile(npub, newIndex);
                  }

                  // Trigger pagination near end
                  if (newIndex >= videos.length - 2) {
                    ref.read(profileFeedProvider(userIdHex).notifier).loadMore();
                  }

                  // Prefetch videos around current index
                  checkForPrefetch(currentIndex: newIndex, videos: videos);
                },
                itemBuilder: (context, index) {
                  if (index >= videos.length) return const SizedBox.shrink();

                  // VideoFeedItem uses list index for active video detection
                  // (URL manages 1-based indexing separately)
                  return VideoFeedItem(
                    key: ValueKey('video-${videos[index].id}'),
                    video: videos[index],
                    index: index,  // Use list index for active video detection
                    hasBottomNavigation: false, // Fullscreen mode, no bottom nav
                    forceShowOverlay: isOwnProfile, // Show overlay controls on own profile
                    contextTitle: ref.read(fetchUserProfileProvider(userIdHex)).value?.bestDisplayName ?? 'Profile',
                  );
                },
              );
            }

            // Otherwise show Instagram-style grid view
            return Stack(
              children: [
                DefaultTabController(
                  length: 3,
                  child: NestedScrollView(
                    controller: _scrollController,
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      // Profile Header
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _buildProfileHeader(
                              authService,
                              userIdHex,
                              isOwnProfile,
                              profileStatsAsync,
                            ),
                          ),
                        ),
                      ),

                      // Stats Row
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _buildStatsRow(profileStatsAsync),
                          ),
                        ),
                      ),

                      // Action Buttons
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _buildActionButtons(
                              socialService,
                              userIdHex,
                              isOwnProfile,
                            ),
                          ),
                        ),
                      ),

                      // Sticky Tab Bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: Colors.white,
                            indicatorWeight: 2,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
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
                        _buildVideosGrid(videos, userIdHex),
                        _buildLikedGrid(socialService),
                        _buildRepostsGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          onLoading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: VineTheme.vineGreen),
                SizedBox(height: 24),
                Text(
                  'Loading profile...',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a few moments',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          onError: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
        );
      },
      onLoading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: VineTheme.vineGreen),
            SizedBox(height: 24),
            Text(
              'Loading profile...',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      onError: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildProfileHeader(
    AuthService authService,
    String userIdHex,
    bool isOwnProfile,
    AsyncValue<ProfileStats> profileStatsAsync,
  ) {
    // Watch profile from embedded relay (reactive)
    final profileAsync = ref.watch(fetchUserProfileProvider(userIdHex));
    final profile = profileAsync.value;

    final profilePictureUrl = profile?.picture;
    final displayName = profile?.bestDisplayName ?? 'Loading user information';
    final hasCustomName = profile?.name?.isNotEmpty == true ||
        profile?.displayName?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Setup profile banner for new users with default names (only on own profile)
          if (isOwnProfile && !hasCustomName)
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
                    _buildStatColumn(
                      profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.videoCount
                          : null,
                      'Vines',
                      profileStatsAsync.isLoading,
                      onTap: null, // Videos aren't tappable
                    ),
                    _buildStatColumn(
                      profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.followers
                          : null,
                      'Followers',
                      profileStatsAsync.isLoading,
                      onTap: () => _navigateToFollowers(context, userIdHex, displayName),
                    ),
                    _buildStatColumn(
                      profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.following
                          : null,
                      'Following',
                      profileStatsAsync.isLoading,
                      onTap: () => _navigateToFollowing(context, userIdHex, displayName),
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
                      displayName,
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
                GestureDetector(
                  onTap: () => _copyNpubToClipboard(userIdHex),
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
                        Flexible(
                          child: SelectableText(
                            NostrEncoding.encodePublicKey(userIdHex),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
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

  Widget _buildStatColumn(int? count, String label, bool isLoading, {VoidCallback? onTap}) {
    final column = Column(
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

    // Wrap in InkWell if tappable
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: column,
        ),
      );
    }

    return column;
  }

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
            _buildStatValue(
              profileStatsAsync.value?.totalViews ?? 0,
              'Known Loops',
              profileStatsAsync.isLoading,
            ),
            _buildStatValue(
              profileStatsAsync.value?.totalLikes ?? 0,
              'Known Likes',
              profileStatsAsync.isLoading,
            ),
          ],
        ),
      );

  /// Helper to build a stat value column with animated loading state
  Widget _buildStatValue(int count, String label, bool isLoading) => Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLoading
                ? const Text(
                    '—',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : Text(
                    _formatCount(count),
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

  Widget _buildActionButtons(
    SocialService socialService,
    String userIdHex,
    bool isOwnProfile,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            if (isOwnProfile) ...[
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
                  onPressed: () => _shareProfile(userIdHex),
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
                child: Consumer(
                  builder: (context, ref, _) {
                    final isFollowing = ref.watch(isFollowingProvider(userIdHex));
                    return isFollowing
                        ? OutlinedButton(
                            onPressed: () => _unfollowUser(userIdHex),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VineTheme.vineGreen,
                              side: const BorderSide(
                                color: VineTheme.vineGreen,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Following'),
                          )
                        : ElevatedButton(
                            onPressed: () => _followUser(userIdHex),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VineTheme.vineGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Follow'),
                          );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Consumer(
                builder: (context, ref, _) {
                  final blocklistService = ref.watch(contentBlocklistServiceProvider);
                  final isBlocked = blocklistService.isBlocked(userIdHex);
                  return OutlinedButton(
                    onPressed: () => _blockUser(userIdHex, isBlocked),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isBlocked ? Colors.grey : Colors.red,
                      side: BorderSide(
                        color: isBlocked ? Colors.grey : Colors.red,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(isBlocked ? 'Unblock' : 'Block User'),
                  );
                },
              ),
            ],
          ],
        ),
      );

  Widget _buildVideosGrid(List<VideoEvent> videos, String userIdHex) {
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
                if (index >= videos.length) {
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

                final videoEvent = videos[index];
                return GestureDetector(
                  onTap: () {
                    final npub = NostrEncoding.encodePublicKey(userIdHex);
                    Log.info(
                      '🎯 ProfileScreenRouter GRID TAP: gridIndex=$index, '
                      'npub=$npub, videoId=${videoEvent.id}',
                      category: LogCategory.video,
                    );
                    // Navigate to fullscreen video mode using GoRouter
                    // videoIndex maps directly to list index (no offset)
                    context.goProfile(npub, index);
                    Log.info(
                      '✅ ProfileScreenRouter: Called goProfile($npub, $index)',
                      category: LogCategory.video,
                    );
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
              childCount: videos.length,
            ),
          ),
        ),
      ],
    );
  }

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

  // Action methods

  Future<void> _setupProfile() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: true),
      ),
    );
  }

  Future<void> _editProfile() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: false),
      ),
    );
  }

  Future<void> _shareProfile(String userIdHex) async {
    try {
      // Get profile info for better share text
      final profile = await ref.read(userProfileServiceProvider).fetchProfile(userIdHex);
      final displayName = profile?.bestDisplayName ?? 'User';

      // Convert hex pubkey to npub format for sharing
      final npub = NostrEncoding.encodePublicKey(userIdHex);

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
            name: 'ProfileScreenRouter',
            category: LogCategory.ui);
      }
    } catch (e) {
      Log.error('Error sharing profile: $e',
          name: 'ProfileScreenRouter',
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

  Future<void> _followUser(String pubkey) async {
    await FollowActionsHelper.followUser(
      ref: ref,
      context: context,
      pubkey: pubkey,
      contextName: 'ProfileScreenRouter',
    );
  }

  Future<void> _unfollowUser(String pubkey) async {
    await FollowActionsHelper.unfollowUser(
      ref: ref,
      context: context,
      pubkey: pubkey,
      contextName: 'ProfileScreenRouter',
    );
  }

  Future<void> _blockUser(String pubkey, bool currentlyBlocked) async {
    if (currentlyBlocked) {
      // Unblock without confirmation
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      blocklistService.unblockUser(pubkey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked')),
        );
      }
      return;
    }

    // Show confirmation dialog for blocking
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Block @',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You won\'t see their content in feeds. They won\'t be notified. You can still visit their profile.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      blocklistService.blockUser(pubkey);

      if (mounted) {
        // Show success confirmation using root navigator
        showDialog(
          context: context,
          useRootNavigator: true,
          builder: (context) => const _BlockConfirmationDialog(),
        );
      }
    }
  }

  void _sendMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening messages...')),
    );
  }

  Future<void> _copyNpubToClipboard(String userIdHex) async {
    try {
      final npub = NostrEncoding.encodePublicKey(userIdHex);
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

/// Confirmation dialog shown after successfully blocking a user
class _BlockConfirmationDialog extends StatelessWidget {
  const _BlockConfirmationDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 28),
            const SizedBox(width: 12),
            const Text(
              'User Blocked',
              style: TextStyle(color: VineTheme.whiteText),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You won\'t see content from this user in your feeds.',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can unblock them anytime from their profile or in Settings > Safety.',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                final uri = Uri.parse('https://divine.video/safety');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VineTheme.vineGreen),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: VineTheme.vineGreen, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Learn More',
                            style: TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'divine.video/safety',
                            style: TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new, color: VineTheme.vineGreen, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      );
}
