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
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:share_plus/share_plus.dart';

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

          // Get current user's npub and redirect
          final currentUserNpub = NostrEncoding.encodePublicKey(authService.currentPublicKeyHex!);
          final videoIndex = ctx.videoIndex ?? 0;

          // Redirect to actual user profile using GoRouter explicitly
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              GoRouter.of(context).go('/profile/$currentUserNpub/$videoIndex');
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

            // If videoIndex > 0, show fullscreen video mode
            // Note: videoIndex is 1-based (0 = grid, 1 = first video, etc.)
            if (videoIndex != null && videoIndex > 0 && videos.isNotEmpty) {
              // Convert URL index to list index (subtract 1)
              final listIndex = videoIndex - 1;
              final safeIndex = listIndex.clamp(0, videos.length - 1);

              // Initialize controller once with URL index
              if (_videoController == null) {
                _videoController = PageController(initialPage: safeIndex);
                _lastVideoUrlIndex = safeIndex;
              }

              // Sync controller when URL changes externally (back/forward/deeplink)
              // OR when videos list changes (e.g., provider reloads)
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
                  targetIndex: listIndex,
                  itemCount: videos.length,
                );
              }

              // Build fullscreen video PageView
              return PageView.builder(
                key: const Key('profile-video-page-view'),
                controller: _videoController,
                scrollDirection: Axis.vertical,
                itemCount: videos.length,
                onPageChanged: (newIndex) {
                  // Update URL when swiping to stay in profile context
                  // Convert list index to URL index (add 1)
                  final newUrlIndex = newIndex + 1;
                  if (newUrlIndex != videoIndex) {
                    context.goProfile(npub, newUrlIndex);
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
                    contextTitle: ref.read(fetchUserProfileProvider(userIdHex)).value?.displayName ?? 'Profile',
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
                        child: _buildProfileHeader(
                          authService,
                          userIdHex,
                          isOwnProfile,
                          profileStatsAsync,
                        ),
                      ),

                      // Stats Row
                      SliverToBoxAdapter(
                        child: _buildStatsRow(profileStatsAsync),
                      ),

                      // Action Buttons
                      SliverToBoxAdapter(
                        child: _buildActionButtons(
                          socialService,
                          userIdHex,
                          isOwnProfile,
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
          onLoading: () => const Center(child: CircularProgressIndicator()),
          onError: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
        );
      },
      onLoading: () => const Center(child: CircularProgressIndicator()),
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
    final displayName = profile?.displayName;
    final hasCustomName = displayName != null &&
        !displayName.startsWith('npub1') &&
        displayName != 'Loading user information';

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
                    ),
                    _buildStatColumn(
                      profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.followers
                          : null,
                      'Followers',
                      profileStatsAsync.isLoading,
                    ),
                    _buildStatColumn(
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

  Widget _buildStatColumn(int? count, String label, bool isLoading) => Column(
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
            _buildStatValue(
              profileStatsAsync.value?.totalViews ?? 0,
              'Total Views',
              profileStatsAsync.isLoading,
            ),
            _buildStatValue(
              profileStatsAsync.value?.totalLikes ?? 0,
              'Total Likes',
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
                    return ElevatedButton(
                      onPressed: isFollowing
                          ? () => _unfollowUser(userIdHex)
                          : () => _followUser(userIdHex),
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
                    Log.info('🎯 ProfileScreenRouter: Tapped video at index $index',
                        category: LogCategory.video);
                    // Navigate to fullscreen video mode using GoRouter
                    // This keeps user on /profile/:npub/:index routes
                    // Note: URL index is offset by 1 (0 = grid, 1 = first video, etc.)
                    final npub = NostrEncoding.encodePublicKey(userIdHex);
                    context.goProfile(npub, index + 1);
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: true),
      ),
    );
  }

  Future<void> _editProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: false),
      ),
    );
  }

  Future<void> _shareProfile(String userIdHex) async {
    try {
      // Get profile info for better share text
      final profile = await ref.read(userProfileServiceProvider).fetchProfile(userIdHex);
      final displayName = profile?.displayName ?? 'User';

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
