// ABOUTME: Profile screen for viewing other users with bottom navigation
// ABOUTME: Pushed on stack from video feeds, profiles, search results, etc.

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_scope.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/add_to_people_lists_sheet.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/profile/new_people_list_sheet.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:unified_logger/unified_logger.dart';

/// Fullscreen profile screen for viewing other users' profiles.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen profile viewing
/// experience with back navigation.
class OtherProfileScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'profile-view';

  /// Base path for profile view routes.
  static const String path = RoutePaths.otherProfile;

  /// Path pattern for this route.
  static const pathWithNpub = '/profile-view/:npub';

  /// Build path for a specific npub.
  static String pathForNpub(String npub) =>
      RoutePaths.otherProfileForNpub(npub);

  const OtherProfileScreen({
    required this.npub,
    this.displayNameHint,
    this.avatarUrlHint,
    super.key,
  });

  /// The npub of the user whose profile is being viewed.
  final String npub;

  /// Optional display name hint for users without Kind 0 profiles.
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);

    if (profileRepository == null) return const BrandedLoadingScaffold();

    final pubkey = npubToHexOrNull(npub);

    if (pubkey == null) {
      return _ProfileErrorScreen(
        message: context.l10n.profileInvalidId,
        onBack: context.safePop,
      );
    }

    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final identityClaimsRepository = ref.watch(
      identityClaimsRepositoryProvider,
    );
    final requireRawKind0 = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.profileMonetizationLinks),
    );

    return BlocProvider(
      // Re-create the bloc when captured dependencies change. A keyless
      // create: would keep stale repositories/current-user state after auth or
      // account changes, and would also miss requireRawKind0 flag flips.
      key: ValueKey((
        requireRawKind0,
        profileRepository,
        blocklistRepository,
        nostrClient.publicKey,
        followRepository,
        identityClaimsRepository,
      )),
      create: (context) => OtherProfileBloc(
        pubkey: pubkey,
        profileRepository: profileRepository,
        contentBlocklistRepository: blocklistRepository,
        currentUserPubkey: nostrClient.publicKey,
        followRepository: followRepository,
        identityClaimsRepository: identityClaimsRepository,
        requireRawKind0: requireRawKind0,
      )..add(const OtherProfileLoadRequested()),
      child: OtherProfileView(
        pubkey: pubkey,
        displayNameHint: displayNameHint,
        avatarUrlHint: avatarUrlHint,
      ),
    );
  }
}

/// Internal view widget for OtherProfileScreen.
///
/// Contains the actual UI implementation. The parent [OtherProfileScreen]
/// handles BLoC creation and npub validation.
class OtherProfileView extends ConsumerStatefulWidget {
  const OtherProfileView({
    required this.pubkey,
    this.displayNameHint,
    this.avatarUrlHint,
    super.key,
  });

  /// The hex pubkey of the profile being viewed.
  final String pubkey;

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  @override
  ConsumerState<OtherProfileView> createState() => _OtherProfileViewState();
}

class _OtherProfileViewState extends ConsumerState<OtherProfileView> {
  final ScrollController _scrollController = ScrollController();

  /// Notifier to trigger refresh of profile BLoCs (likes, reposts).
  final _refreshNotifier = ValueNotifier<int>(0);

  /// Whether the profile feed load has been tracked.
  bool _hasTrackedFeedLoad = false;
  late final FeedPerformanceTracker _feedTracker;
  late final FeedLoadHandle _feedLoad;

  @override
  void initState() {
    super.initState();
    _feedTracker = ref.read(feedPerformanceTrackerProvider);
    _feedLoad = _feedTracker.startFeedLoad('profile');
    // The feed cubit cold-loads on mount (via ProfileFeedScope below); reading
    // it here would be a cross-route ProviderNotFoundException because the
    // cubit lives under build.
  }

  @override
  void dispose() {
    _feedTracker.abandonFeedLoad(_feedLoad);
    _scrollController.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  /// Whether the current user may not DM this profile (#176) — DM-restricted
  /// (protected minor, or an unresolved status that fails closed) and this
  /// pubkey is not an approved official recipient. Drives hiding the Message
  /// affordance and guards the tap itself.
  bool _messagingBlockedForProtectedMinor({bool? isDmRestricted}) {
    if (!(isDmRestricted ?? ref.read(isDmRestrictedProvider))) return false;
    return !ref
        .read(officialAccountsServiceProvider)
        .isApprovedMinorDmRecipientSync(widget.pubkey);
  }

  void _messageUser() {
    // Defense-in-depth: the button is hidden when blocked, but a stale tap or
    // programmatic call must not open a conversation the minor can't use.
    if (_messagingBlockedForProtectedMinor()) return;
    final currentPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    if (currentPubkey == null || currentPubkey.isEmpty) return;
    // The route id must be the canonical sha256 of the sorted participants —
    // the same id `sendMessage` persists under. Passing the raw peer pubkey
    // here opened a thread whose id matched no stored row, so history never
    // rendered and messages sent from this screen never appeared in it.
    context.push(
      ConversationPage.pathForId(
        DmRepository.computeConversationId([currentPubkey, widget.pubkey]),
      ),
      extra: [widget.pubkey],
    );
  }

  Future<void> _shareProfile(BuildContext shareButtonContext) async {
    final l10n = context.l10n;
    final shareTextFn = l10n.profileShareText;
    final shareSubjectFn = l10n.profileShareSubject;
    final fallbackName = l10n.profileUserFallback;
    final sharePositionOrigin = shareAnchorForContext(shareButtonContext);

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          ?.getCachedProfile(pubkey: widget.pubkey);
      final displayName = profile?.bestDisplayName ?? fallbackName;
      final npub = NostrKeyUtils.encodePubKey(widget.pubkey);
      final shareText = shareTextFn(displayName, npub);

      await showShareSheetAtOrigin(
        ShareParams(text: shareText, subject: shareSubjectFn(displayName)),
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      Log.error(
        'Error sharing profile: $e',
        name: 'OtherProfileView',
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

  Future<void> _more() async {
    final l10n = context.l10n;
    final fallbackName = l10n.profileUserFallback;
    final otherProfileBloc = context.read<OtherProfileBloc>();
    final isBlocked = otherProfileBloc.isBlocked;
    final isFollowing = otherProfileBloc.isFollowing;

    // Get display name for actions (match pattern from build())
    final profile = ref.read(userProfileReactiveProvider(widget.pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? widget.displayNameHint ?? fallbackName;

    final profileListFeaturesEnabled = ref.read(
      isFeatureEnabledProvider(FeatureFlag.profileListFeatures),
    );
    // curatedLists is the master switch for people lists; profileListFeatures
    // only adds this surface on top of it. Without both, tapping would
    // construct the lazily-registered PeopleListsBloc for a disabled feature.
    final curatedListsEnabled = ref.read(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    final isOwnProfile =
        widget.pubkey == ref.read(authServiceProvider).currentPublicKeyHex;
    final showAddToList =
        profileListFeaturesEnabled && curatedListsEnabled && !isOwnProfile;

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      scrollable: false,
      body: StatefulBuilder(
        builder: (context, setState) {
          return MoreSheetContent(
            userIdHex: widget.pubkey,
            displayName: displayName,
            isFollowing: isFollowing,
            isBlocked: isBlocked,
            showAddToList: showAddToList,
            showReport: !isOwnProfile,
          );
        },
      ),
      children: const [], // Required but unused when body is provided
    );

    if (!mounted || result == null) return;

    switch (result) {
      case MoreSheetResult.copy:
        final npub = NostrKeyUtils.encodePubKey(widget.pubkey);
        await ClipboardUtils.copyPubkey(context, npub);
      case MoreSheetResult.addToList:
        if (!ref.read(isFeatureEnabledProvider(FeatureFlag.curatedLists))) {
          return;
        }

        final profile = ref
            .read(userProfileReactiveProvider(widget.pubkey))
            .value;
        final hasEditableLists = context
            .read<PeopleListsBloc>()
            .state
            .lists
            .any((list) => list.isEditable);
        if (hasEditableLists) {
          await AddToPeopleListsSheet.show(
            context,
            pubkey: widget.pubkey,
            entryPoint: PeopleListEntryPoint.profile,
            displayName: profile?.bestDisplayName,
            initialCollaborator: profile,
          );
        } else {
          await showNewPeopleListSheet(context, initialCollaborator: profile);
        }
      case MoreSheetResult.unfollow:
        await _unfollowUser();
      case MoreSheetResult.report:
        await ReportContentDialog.showForUser(
          context,
          userPubkey: widget.pubkey,
        );
      case MoreSheetResult.blockConfirmed:
        context.read<OtherProfileBloc>().add(
          const OtherProfileBlockRequested(),
        );
        if (mounted) {
          final profile = ref
              .read(userProfileReactiveProvider(widget.pubkey))
              .value;
          final name =
              profile?.bestDisplayName ??
              widget.displayNameHint ??
              fallbackName;
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(l10n.profileBlockedUser(name)),
          );
          context.safePop();
        }
      case MoreSheetResult.unblockConfirmed:
        context.read<OtherProfileBloc>().add(
          const OtherProfileUnblockRequested(),
        );
        if (mounted) {
          final profile = ref
              .read(userProfileReactiveProvider(widget.pubkey))
              .value;
          final name =
              profile?.bestDisplayName ??
              widget.displayNameHint ??
              fallbackName;
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(l10n.profileUnblockedUser(name)),
          );
        }
      case MoreSheetResult.embedCode:
        // Not surfaced here: MoreSheetContent above never sets
        // showEmbedCode, so this branch is unreachable on another user's
        // profile.
        break;
    }
  }

  Future<void> _unfollowUser() async {
    final fallbackName = context.l10n.profileUserFallback;
    final profile = ref.read(userProfileReactiveProvider(widget.pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? widget.displayNameHint ?? fallbackName;

    final followRepository = ref.read(followRepositoryProvider);
    await followRepository.toggleFollow(widget.pubkey);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.profileUnfollowedUser(displayName),
        ),
      );
    }
  }

  Future<void> _showUnblockConfirmation() async {
    final fallbackName = context.l10n.profileUserFallback;
    final profile = ref.read(userProfileReactiveProvider(widget.pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? widget.displayNameHint ?? fallbackName;

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      scrollable: false,
      body: MoreSheetContent(
        userIdHex: widget.pubkey,
        displayName: displayName,
        isFollowing: false,
        isBlocked: true,
        initialMode: MoreSheetMode.unblockConfirmation,
      ),
      children: const [],
    );

    if (!mounted) return;

    if (result == MoreSheetResult.unblockConfirmed) {
      if (!mounted) return;
      context.read<OtherProfileBloc>().add(
        const OtherProfileUnblockRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.info(
      '🧭 OtherProfileView.build for ${pubkeyForLogs(widget.pubkey)}',
      name: 'OtherProfileView',
    );

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    return ProfileFeedScope(
      userIdHex: widget.pubkey,
      child: Builder(
        builder: (context) {
          final feedState = context.watch<ProfileFeedCubit>().state;
          // Track analytics when data is loaded
          if (feedState.status == ProfileFeedStatus.ready) {
            ref
                .read(screenAnalyticsServiceProvider)
                .markDataLoaded(
                  'other_profile',
                  dataMetrics: {'video_count': feedState.videos.length},
                );

            if (!_hasTrackedFeedLoad) {
              _hasTrackedFeedLoad = true;
              final count = feedState.videos.length;
              _feedTracker.markFirstVideosReceived(_feedLoad, count);
              _feedTracker.markFeedDisplayed(_feedLoad, count);
            }
          }

          return BlocBuilder<OtherProfileBloc, OtherProfileState>(
            builder: (context, state) {
              // Name the state rather than pass a deleted account's identity
              // downstream. ProfileHeaderWidget applies the same rule to the
              // avatar and the route hints, which it resolves itself.
              final isVanished = ref.watch(
                profileVanishedProvider(widget.pubkey),
              );
              final headerProfile = isVanished
                  ? null
                  : switch (state) {
                      OtherProfileInitial() => null,
                      OtherProfileLoading(:final profile) => profile,
                      OtherProfileLoaded(:final profile) => profile,
                      OtherProfileError(:final profile) => profile,
                    };
              final statsAsync = ref.watch(
                userProfileStatsReactiveProvider(widget.pubkey),
              );
              final headerStats = statsAsync.value;

              final displayName = isVanished
                  ? context.l10n.profileDeletedAccountName
                  : headerProfile?.bestDisplayName ??
                        widget.displayNameHint ??
                        context.l10n.profileTitle;
              final isDmRestricted = ref.watch(isDmRestrictedProvider);
              final isMessageRestricted = _messagingBlockedForProtectedMinor(
                isDmRestricted: isDmRestricted,
              );

              return Scaffold(
                backgroundColor: context.vineColors.surface,
                body: switch (feedState.status) {
                  ProfileFeedStatus.failure => Center(
                    child: Text(
                      context.l10n.profileFeedError,
                      style: TextStyle(color: context.vineColors.primaryText),
                    ),
                  ),
                  // During the cold load we render the real layout (header
                  // skeletonizes itself; the videos tab shows a skeleton grid)
                  // instead of a separate placeholder, so the load→ready
                  // transition does not pop.
                  ProfileFeedStatus.initial ||
                  ProfileFeedStatus.loading ||
                  ProfileFeedStatus.ready => ProfileGridView(
                    userIdHex: widget.pubkey,
                    isOwnProfile: false,
                    profile: headerProfile,
                    profileStats: headerStats,
                    displayName: displayName,
                    videos: feedState.videos,
                    isLoadingVideos:
                        feedState.status != ProfileFeedStatus.ready ||
                        feedState.isInitialLoad,
                    scrollController: _scrollController,
                    onBack: context.safePop,
                    onMore: _more,
                    onMessageUser: _messageUser,
                    isMessageRestricted: isMessageRestricted,
                    onShareProfile: _shareProfile,
                    onBlockedTap: _showUnblockConfirmation,
                    displayNameHint: widget.displayNameHint,
                    avatarUrlHint: widget.avatarUrlHint,
                    refreshNotifier: _refreshNotifier,
                  ),
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.profileTitle,
        showBackButton: true,
        onBackPressed: onBack,
      ),
      body: Center(
        child: Text(
          message,
          style: TextStyle(color: context.vineColors.primaryText),
        ),
      ),
    );
  }
}
