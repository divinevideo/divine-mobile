// ABOUTME: Router-driven Instagram-style profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling, URL is source of truth

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_scope.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:unified_logger/unified_logger.dart';

/// Router-driven ProfileScreen - Instagram-style scrollable profile
class ProfileScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'profile';

  /// Base path for profile routes.
  static const String path = RoutePaths.profile;

  /// Path for this route (grid mode).
  static const pathWithNpub = '/profile/:npub';

  /// Path for this route (feed mode).
  static const pathWithIndex = '/profile/:npub/:index';

  /// Build path for grid mode or specific npub.
  static String pathForNpub(String npub) => RoutePaths.profileForNpub(npub);

  /// Build path for feed mode with specific npub and index.
  static String pathForIndex(String npub, int index) =>
      RoutePaths.profileForIndex(npub, index);

  const ProfileScreenRouter({super.key});

  @override
  ConsumerState<ProfileScreenRouter> createState() =>
      _ProfileScreenRouterState();
}

class _ProfileScreenRouterState extends ConsumerState<ProfileScreenRouter>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  /// Notifier to trigger refresh of profile BLoCs (likes, reposts).
  final _refreshNotifier = ValueNotifier<int>(0);

  void _fetchProfileIfNeeded(String userIdHex, bool isOwnProfile) {
    if (isOwnProfile) return; // Own profile loads automatically

    // Trigger a background fetch via the read-only handle.
    ref
        .read(profileReadRepositoryProvider)
        ?.fetchFreshProfile(
          pubkey: userIdHex,
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.info('🧭 ProfileScreenRouter.build', name: 'ProfileScreenRouter');

    // Resolve this branch's route context. Until the scoped provider's
    // Stream.value emits (the very first sub-frame), fall back to parsing the
    // branch's own location synchronously so the first frame already renders
    // the real profile layout — settings button included — instead of a blank
    // placeholder. GoRouterState.of(context) is a direct widget read, so it
    // observes this branch's route (matching the scoped override in
    // app_router.dart), not the globally-active tab's.
    final routeContext =
        ref.watch(pageContextProvider).asData?.value ??
        parseRoute(GoRouterState.of(context).uri.path);

    // Check if this is own profile grid view (needs own scaffold)
    final currentUserHex = ref.read(authServiceProvider).currentPublicKeyHex;
    final isOwnProfileGrid = isOwnProfileGridRoute(
      routeContext,
      currentUserHex,
    );

    final content = _ProfileContentView(
      routeContext: routeContext,
      scrollController: _scrollController,
      onFetchProfile: _fetchProfileIfNeeded,
      onEditProfile: _editProfile,
      onOpenClips: _openClips,
      onMore: _more,
      onShareProfile: _shareProfile,
      refreshNotifier: _refreshNotifier,
    );

    if (isOwnProfileGrid) {
      final userIdHex = ref.read(authServiceProvider).currentPublicKeyHex;
      // Read-only handle: available at identity-known, so the own-profile
      // header renders the user's real cached name and avatar instead of a
      // generated placeholder while relays connect (#6423). MyProfileBloc
      // only reads.
      final profileRepository = ref.watch(profileReadRepositoryProvider);
      final identityClaimsRepository = ref.watch(
        identityClaimsRepositoryProvider,
      );

      if (userIdHex == null || profileRepository == null) {
        // No identity at all yet. Render the real profile layout — its header,
        // stats, and video grid degrade to skeletons while MyProfileBloc is
        // absent — instead of a separate loading view. Once the identity
        // resolves, the BlocProvider below mounts and the layout fills in.
        return ProfileScaffold(body: content);
      }

      return BlocProvider<MyProfileBloc>(
        key: ValueKey((profileRepository, identityClaimsRepository)),
        create: (context) =>
            MyProfileBloc(
                profileRepository: profileRepository,
                pubkey: userIdHex,
                identityClaimsRepository: identityClaimsRepository,
              )
              ..add(const MyProfileSubscriptionRequested())
              ..add(const MyProfileFetchRequested()),
        child: ProfileScaffold(body: content),
      );
    }

    return content;
  }

  // Action methods

  Future<void> _editProfile() async {
    // Navigate directly to edit-profile route (defined outside ShellRoute)
    await context.push(ProfileSetupScreen.editPath);
  }

  Future<void> _shareProfile(
    BuildContext shareButtonContext,
    String userIdHex,
  ) async {
    // Capture l10n callable functions before any awaits to avoid
    // use_build_context_synchronously warnings.
    final l10n = context.l10n;
    final shareTextFn = l10n.profileShareText;
    final shareSubjectFn = l10n.profileShareSubject;
    final sharePositionOrigin = shareAnchorForContext(shareButtonContext);

    try {
      // Get profile info for better share text
      final profile = await ref
          .read(profileReadRepositoryProvider)
          ?.getCachedProfile(pubkey: userIdHex);
      final displayName = profile?.bestDisplayName ?? 'User';

      // Convert hex pubkey to npub format for sharing
      final npub = NostrKeyUtils.encodePubKey(userIdHex);

      // Create share text with divine.video URL format
      final shareText = shareTextFn(displayName, npub);

      final result = await showShareSheetAtOrigin(
        ShareParams(text: shareText, subject: shareSubjectFn(displayName)),
        sharePositionOrigin: sharePositionOrigin,
      );

      if (result.status == ShareResultStatus.success) {
        Log.info(
          'Profile shared successfully',
          name: 'ProfileScreenRouter',
          category: LogCategory.ui,
        );
      }
    } catch (e) {
      Log.error(
        'Error sharing profile: $e',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.profileShareFailed,
            error: true,
          ),
        );
      }
    }
  }

  void _openClips() {
    // Navigate to clips route (defined outside ShellRoute)
    context.push(LibraryScreen.draftsPath);
  }

  Future<void> _more(String userIdHex) async {
    await VineBottomSheetActionMenu.show(
      context: context,
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.copy.assetPath,
          label: context.l10n.profileCopyPublicKey,
          onTap: () => _copyNpub(userIdHex),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.bracketsAngle.assetPath,
          label: context.l10n.profileGetEmbedCode,
          onTap: () => _copyEmbedCode(userIdHex),
        ),
      ],
    );
  }

  Future<void> _copyNpub(String userIdHex) async {
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    await Clipboard.setData(ClipboardData(text: npub));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(context.l10n.profilePublicKeyCopied),
      );
    }
  }

  Future<void> _copyEmbedCode(String userIdHex) async {
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    final embedSnippet =
        '<iframe\n'
        '  src="https://divine.video/embed?npub=$npub"\n'
        '  width="350"\n'
        '  height="380"\n'
        '  style="border-radius: 12px; border: none;"\n'
        '  title="Divine Video Widget"\n'
        '></iframe>';
    await Clipboard.setData(ClipboardData(text: embedSnippet));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(context.l10n.profileEmbedCodeCopied),
      );
    }
  }
}

/// The scaffold the own-profile grid renders inside, and nothing else does.
///
/// Public only so a test can assert the screen took the own-profile branch by
/// finding the real widget, rather than re-implementing the predicate and
/// proving nothing about the screen.
@visibleForTesting
class ProfileScaffold extends StatelessWidget {
  /// Creates the own-profile grid's scaffold around [body].
  const ProfileScaffold({required this.body, super.key});

  /// The profile content this scaffold wraps.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    // No bottom nav here — the enclosing AppShell provides the shared
    // VineBottomNav for every tab (own-profile no longer bypasses the shell).
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      body: body,
    );
  }
}

/// Private widget that handles profile content based on route context.
class _ProfileContentView extends ConsumerWidget {
  const _ProfileContentView({
    required this.routeContext,
    required this.scrollController,
    required this.onFetchProfile,
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onMore,
    required this.onShareProfile,
    required this.refreshNotifier,
  });

  final RouteContext routeContext;
  final ScrollController scrollController;
  final void Function(String userIdHex, bool isOwnProfile) onFetchProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final void Function(String userIdHex) onMore;
  final void Function(BuildContext context, String userIdHex) onShareProfile;
  final ValueNotifier<int> refreshNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routeContext.type != RouteType.profile) {
      // During navigation transitions, we may briefly see non-profile routes.
      // Just show nothing rather than an error message.
      return const SizedBox.shrink();
    }

    // Convert npub to hex for profile feed provider
    final npub = routeContext.npub ?? '';

    // Handle "me" special case - redirect to actual user profile
    if (npub == 'me') {
      return _MeProfileRedirect(videoIndex: routeContext.videoIndex);
    }

    final userIdHex = npubToHexOrNull(npub);

    if (userIdHex == null) {
      return Center(child: Text(context.l10n.profileInvalidId));
    }

    // Get current user for comparison
    final authService = ref.watch(authServiceProvider);
    final currentUserHex = authService.currentPublicKeyHex;
    final isOwnProfile = userIdHex == currentUserHex;

    // Check if this user has muted us (mutual mute blocking)
    // Note: We only block profile viewing for users who muted US, not users WE blocked.
    // Users can still view profiles of people they blocked (to unblock them).
    ref.watch(blocklistVersionProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    if (blocklistRepository.hasMutedUs(userIdHex) ||
        blocklistRepository.hasBlockedUs(userIdHex)) {
      // safePop: a deep link to a profile whose owner blocked or muted the
      // viewer lands here with a one-entry stack, where a raw pop throws.
      return BlockedUserScreen(onBack: context.safePop, userIdHex: userIdHex);
    }

    // Fetch profile data if needed (post-frame to avoid build mutations)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onFetchProfile(userIdHex, isOwnProfile);
    });

    // Get display name for unfollow confirmation (only needed for other profiles)
    final displayName = isOwnProfile
        ? null
        : ref
              .watch(userProfileReactiveProvider(userIdHex))
              .value
              ?.bestDisplayName;

    return ProfileFeedScope(
      userIdHex: userIdHex,
      child: _ProfileDataView(
        npub: npub,
        userIdHex: userIdHex,
        isOwnProfile: isOwnProfile,
        displayName: displayName,
        videoIndex: routeContext.videoIndex,
        scrollController: scrollController,
        onEditProfile: onEditProfile,
        onOpenClips: onOpenClips,
        onMore: onMore,
        onShareProfile: onShareProfile,
        refreshNotifier: refreshNotifier,
      ),
    );
  }
}

/// Handles redirect when npub is "me".
class _MeProfileRedirect extends ConsumerWidget {
  const _MeProfileRedirect({required this.videoIndex});

  final int? videoIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    if (!authService.isAuthenticated ||
        authService.currentPublicKeyHex == null) {
      // Not authenticated - redirect to home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(VideoFeedPage.pathForIndex(0));
      });
      return const Center(child: CircularProgressIndicator());
    }

    // Get current user's npub and redirect (preserve grid/feed mode from context)
    final currentUserNpub = NostrKeyUtils.encodePubKey(
      authService.currentPublicKeyHex!,
    );

    // Redirect to actual user profile using GoRouter explicitly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use direct GoRouter calls to properly handle null videoIndex (grid mode)
      if (videoIndex != null) {
        context.go(
          ProfileScreenRouter.pathForIndex(currentUserNpub, videoIndex!),
        );
      } else {
        context.go(ProfileScreenRouter.pathForNpub(currentUserNpub));
      }
    });

    // Show loading while redirecting
    return const Center(child: CircularProgressIndicator());
  }
}

/// Displays profile data after loading videos and stats.
class _ProfileDataView extends ConsumerWidget {
  const _ProfileDataView({
    required this.npub,
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videoIndex,
    required this.scrollController,
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onMore,
    required this.onShareProfile,
    required this.refreshNotifier,
    this.displayName,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final String? displayName;
  final int? videoIndex;
  final ScrollController scrollController;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final void Function(String userIdHex) onMore;
  final void Function(BuildContext context, String userIdHex) onShareProfile;
  final ValueNotifier<int> refreshNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get video data and stats from providers
    final feedState = context.watch<ProfileFeedCubit>().state;
    final profileStats = ref
        .watch(userProfileStatsReactiveProvider(userIdHex))
        .value;
    final profile = ref.watch(userProfileReactiveProvider(userIdHex)).value;

    if (feedState.status == ProfileFeedStatus.ready) {
      ref
          .read(screenAnalyticsServiceProvider)
          .markDataLoaded(
            'own_profile',
            dataMetrics: {'video_count': feedState.videos.length},
          );
    }

    return BlocListener<BackgroundPublishBloc, BackgroundPublishState>(
      listenWhen: (_, current) => current.recentlyPublished.isNotEmpty,
      listener: (context, state) {
        // Refresh the feed when a background publish succeeds.
        context.read<ProfileFeedCubit>().add(
          const ProfileFeedRefreshRequested(),
        );
      },
      child: switch (feedState.status) {
        ProfileFeedStatus.failure => Center(
          child: Text(context.l10n.profileFeedError),
        ),
        // During the cold load we render the real layout (header/stats
        // skeletonize themselves; the videos tab shows a skeleton grid)
        // instead of a separate placeholder, so the load→ready transition
        // does not pop.
        ProfileFeedStatus.initial ||
        ProfileFeedStatus.loading ||
        ProfileFeedStatus.ready => ProfileViewSwitcher(
          npub: npub,
          userIdHex: userIdHex,
          isOwnProfile: isOwnProfile,
          displayName: displayName,
          profile: profile,
          profileStats: profileStats,
          videos: feedState.videos,
          isLoadingVideos:
              feedState.status != ProfileFeedStatus.ready ||
              feedState.isInitialLoad,
          videoIndex: videoIndex,
          scrollController: scrollController,
          onEditProfile: onEditProfile,
          onOpenClips: onOpenClips,
          onMore: onMore,
          onShareProfile: onShareProfile,
          refreshNotifier: refreshNotifier,
        ),
      },
    );
  }
}

/// Switches between grid view and video feed view based on videoIndex.
class ProfileViewSwitcher extends StatelessWidget {
  /// Creates a ProfileViewSwitcher widget.
  @visibleForTesting
  const ProfileViewSwitcher({
    required this.npub,
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videos,
    required this.videoIndex,
    required this.scrollController,
    required this.onOpenClips,
    required this.onMore,
    required this.onShareProfile,
    this.onEditProfile,
    this.profileStats,
    this.profile,
    this.refreshNotifier,
    this.displayName,
    this.isLoadingVideos = false,
    super.key,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final String? displayName;
  final UserProfile? profile;
  final ProfileStats? profileStats;
  final List<VideoEvent> videos;
  final int? videoIndex;
  final ScrollController scrollController;
  final VoidCallback? onEditProfile;
  final VoidCallback onOpenClips;
  final void Function(String userIdHex) onMore;
  final void Function(BuildContext context, String userIdHex) onShareProfile;

  /// Whether the videos fetch (Nostr relay + Funnelcake REST) is still in
  /// flight. Drives the videos-tab loading-vs-empty branch in
  /// [ProfileGridView] / [ProfileVideosGrid] so we don't render "No
  /// videos" while the cold-start fetch is still running.
  final bool isLoadingVideos;

  /// Optional notifier to trigger BLoC refresh when its value changes.
  final ValueNotifier<int>? refreshNotifier;

  @override
  Widget build(BuildContext context) {
    // If videoIndex is set, show fullscreen video mode
    // Note: videoIndex maps directly to list index (0 = first video, etc.)
    // When videoIndex is null, show grid mode
    return (videoIndex != null && videos.isNotEmpty)
        ? ProfileVideoFeedView(
            npub: npub,
            userIdHex: userIdHex,
            videos: videos,
            videoIndex: videoIndex!,
            onPageChanged: (newIndex) {
              context.go(ProfileScreenRouter.pathForIndex(npub, newIndex));
            },
          )
        :
          // Otherwise show Instagram-style grid view
          ProfileGridView(
            userIdHex: userIdHex,
            isOwnProfile: isOwnProfile,
            displayName: displayName,
            profile: profile,
            profileStats: profileStats,
            videos: videos,
            isLoadingVideos: isLoadingVideos,
            scrollController: scrollController,
            onEditProfile: onEditProfile,
            onOpenClips: onOpenClips,
            onMore: () => onMore(userIdHex),
            onShareProfile: (context) => onShareProfile(context, userIdHex),
            refreshNotifier: refreshNotifier,
          );
  }
}
