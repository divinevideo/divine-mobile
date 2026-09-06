// ABOUTME: Profile header widget showing avatar, stats, name, and bio
// ABOUTME: Reusable between own profile and others' profile screens

import 'dart:async';
import 'dart:ui';

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:openvine/config/profile_metrics.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/monetization/monetization_analytics.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/features/people_lists/view/people_list_membership_indicator.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/widgets/followers_screen_router.dart';
import 'package:openvine/router/widgets/following_screen_router.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/deferred_login_options_navigator.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/secure_account_prompt_dismissal.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/og_viner_badge.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_actions_sheet.dart';
import 'package:openvine/widgets/profile/profile_followers_stat.dart';
import 'package:openvine/widgets/profile/profile_following_stat.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/profile/profile_support_sheet.dart';
import 'package:openvine/widgets/profile/profile_website_row.dart';
import 'package:openvine/widgets/profile/verified_accounts_row.dart';
import 'package:openvine/widgets/profile_badge_explanation_sheet.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:skeletonizer/skeletonizer.dart';

part 'profile_header_identity.dart';
part 'profile_header_media.dart';

/// Profile header widget displaying avatar, stats, name, and bio.
class ProfileHeaderWidget extends ConsumerStatefulWidget {
  const ProfileHeaderWidget({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videoCount,
    this.profile,
    this.profileStats,
    this.onEditProfile,
    this.onBack,
    this.onMore,
    this.displayNameHint,
    this.avatarUrlHint,
    this.displayName,
    this.onOpenClips,
    this.onMessageUser,
    this.isMessageRestricted = false,
    this.onShareProfile,
    this.onBlockedTap,
    super.key,
  });

  /// The hex public key of the profile being displayed.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// The number of videos loaded in the profile grid.
  final int videoCount;

  /// Optional profile owned by the parent widget.
  /// When provided, avoids a second profile fetch path.
  final UserProfile? profile;

  /// Optional cached stats owned by the parent widget.
  final ProfileStats? profileStats;

  /// Callback when edit profile is tapped (own profile only).
  final VoidCallback? onEditProfile;

  /// Callback for back navigation (other profiles only).
  final VoidCallback? onBack;

  /// Callback for more options menu (other profiles only).
  final VoidCallback? onMore;

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  /// Display name for unfollow confirmation (only used for other profiles).
  final String? displayName;

  /// Callback when "Clips" button is tapped (own profile only).
  final VoidCallback? onOpenClips;

  /// Callback when "Message" button is tapped (other profiles only).
  final VoidCallback? onMessageUser;

  /// Whether the Message affordance should be hidden for policy reasons.
  final bool isMessageRestricted;

  /// Callback when share button is tapped.
  final void Function(BuildContext context)? onShareProfile;

  /// Callback when the Blocked button is tapped (other profiles only).
  final VoidCallback? onBlockedTap;

  @override
  ConsumerState<ProfileHeaderWidget> createState() =>
      _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends ConsumerState<ProfileHeaderWidget> {
  /// Maximum window during which the username/avatar render as a skeleton.
  /// After this elapses, the existing generated-name / identicon fallback
  /// kicks in even if the parent says the profile is still loading. This
  /// keeps users who genuinely have no Kind 0 from seeing an infinite
  /// shimmer (#4163).
  static const _identitySkeletonTimeout = Duration(seconds: 7);

  Timer? _identitySkeletonTimer;
  bool _identityTimeoutExpired = false;
  bool? _wasLoadingIdentity;
  final _deferredLoginOptionsNavigator = DeferredLoginOptionsNavigator();

  @override
  void dispose() {
    _identitySkeletonTimer?.cancel();
    _deferredLoginOptionsNavigator.dispose();
    super.dispose();
  }

  void _syncIdentitySkeletonTimer({required bool isLoading}) {
    if (_wasLoadingIdentity == isLoading) return;
    _wasLoadingIdentity = isLoading;
    _identitySkeletonTimer?.cancel();
    _identitySkeletonTimer = null;
    _identityTimeoutExpired = false;
    if (!isLoading) return;
    _identitySkeletonTimer = Timer(_identitySkeletonTimeout, () {
      if (mounted) setState(() => _identityTimeoutExpired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // A deleted account must not render under its own identity. This widget
    // resolves identity from three independent sources — the profile bloc,
    // fetchUserProfileProvider, and the route hints — so evicting the cached
    // row is not enough on its own: the hints are supplied by whoever
    // navigated here and outlive the cache entirely.
    final isVanished = ref.watch(profileVanishedProvider(widget.userIdHex));

    final UserProfile? effectiveProfile;
    final bool isLoadingIdentity;
    if (isVanished) {
      effectiveProfile = null;
      isLoadingIdentity = false;
    } else if (widget.isOwnProfile) {
      // Project to (profile, isInitialOrLoading) so this widget rebuilds only
      // when the displayed profile or the genuine "still loading" signal
      // changes. Watching the whole state would also rebuild on isFresh /
      // extractedUsername / verifiedClaims transitions and on the
      // MyProfileError variant, none of which the header reads here.
      ({UserProfile? profile, bool isInitialOrLoading}) selection;
      try {
        selection = context
            .select<
              MyProfileBloc,
              ({UserProfile? profile, bool isInitialOrLoading})
            >((bloc) {
              final state = bloc.state;
              return (
                profile: switch (state) {
                  MyProfileUpdated(:final profile) => profile,
                  MyProfileLoaded(:final profile) => profile,
                  MyProfileLoading(:final profile) => profile,
                  _ => null,
                },
                isInitialOrLoading:
                    state is MyProfileInitial || state is MyProfileLoading,
              );
            });
      } on ProviderNotFoundException {
        // MyProfileBloc is not provided yet — cold start before
        // profileRepository is ready (the screen renders the real layout as a
        // skeleton during this window). Treat it as still loading so the
        // identity shimmers until the bloc is wired in.
        selection = (profile: null, isInitialOrLoading: true);
      }
      effectiveProfile = _bestProfileForHeader(
        selection.profile,
        widget.profile,
      );
      // Skeleton on the user's own profile is appropriate only while we
      // genuinely have nothing to show. As soon as a cached profile is
      // available, fall through to render the real identity. After
      // MyProfileError(notFound) the generated fallback is the truthful
      // steady state — don't skeleton it.
      isLoadingIdentity =
          effectiveProfile == null && selection.isInitialOrLoading;
    } else if (widget.profile != null) {
      effectiveProfile = widget.profile;
      isLoadingIdentity = false;
    } else {
      final asyncProfile = ref.watch(
        fetchUserProfileProvider(widget.userIdHex),
      );
      effectiveProfile = asyncProfile.value;
      isLoadingIdentity = asyncProfile.isLoading && asyncProfile.value == null;
    }

    final showIdentitySkeleton = isLoadingIdentity && !_identityTimeoutExpired;
    // Drive the skeleton timeout timer from a post-frame callback rather
    // than mutating timer state during build. The `_wasLoadingIdentity`
    // guard inside `_syncIdentitySkeletonTimer` keeps this idempotent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncIdentitySkeletonTimer(isLoading: isLoadingIdentity);
    });

    // Use hints as fallbacks for users without Kind 0 profiles (e.g., classic Viners)
    // Check for both null AND empty string - some profiles have empty picture field
    final displayNameHint = isVanished ? null : widget.displayNameHint;
    final profilePictureUrl = isVanished
        ? null
        : (effectiveProfile?.picture?.isNotEmpty == true)
        ? effectiveProfile!.picture
        : widget.avatarUrlHint;
    final hasCustomName =
        effectiveProfile?.name?.isNotEmpty == true ||
        effectiveProfile?.displayName?.isNotEmpty == true ||
        displayNameHint?.isNotEmpty == true;
    final hasAnyProfileInfo =
        hasCustomName ||
        effectiveProfile?.picture?.isNotEmpty == true ||
        effectiveProfile?.about?.isNotEmpty == true ||
        effectiveProfile?.nip05?.isNotEmpty == true;
    final nip05 = effectiveProfile?.shortDisplayNip05;
    final about = effectiveProfile?.about;
    final profileColor = effectiveProfile?.profileBackgroundColor;
    final authService = ref.watch(authServiceProvider);

    // Watch auth state to rebuild when auth state changes
    // (e.g., after email verification completes, or after background RPC
    // upgrade resolves — the auth stream emits a nudge in both cases)
    ref.watch(currentAuthStateProvider);
    final isAnonymous = authService.isAnonymous;
    final isAccountEnforced =
        widget.isOwnProfile && ref.watch(isAccountEnforcedProvider);
    final hasExpiredSession = authService.hasExpiredOAuthSession;
    final isRpcUpgradeInProgress = authService.isRpcUpgradeInProgress;
    final prefs = ref.watch(sharedPreferencesProvider);
    final isDivineLoginBannerHidden = DivineLoginBannerDismissalStore(
      prefs: prefs,
      userIdHex: widget.userIdHex,
    ).isDismissed();

    // This is the condition, not the trigger. It stays true while the session
    // is expired, so _SessionExpiredPromptTrigger owns the edge (#7308).
    final shouldPromptForExpiredSession =
        widget.isOwnProfile &&
        !isAnonymous &&
        hasExpiredSession &&
        !isRpcUpgradeInProgress &&
        !isDivineLoginBannerHidden;

    // Compute pending profile actions for the avatar badge
    final secureAccountPromptDismissal = SecureAccountPromptDismissalStore(
      prefs: prefs,
      userIdHex: widget.userIdHex,
    );
    final pendingActions =
        ProfileActionType.pending(
          isOwnProfile: widget.isOwnProfile,
          isAccountEnforced: isAccountEnforced,
          isAnonymous: isAnonymous,
          hasAnyProfileInfo: hasAnyProfileInfo,
        ).where((action) {
          return action != ProfileActionType.secureAccount ||
              !secureAccountPromptDismissal.isDismissed();
        }).toList();

    // Banner is rendered separately by ProfileBannerLayer in profile_grid.dart
    // so it can be placed behind the safe area. This widget only renders the
    // foreground content (nav buttons, avatar, name, bio, stats) on a
    // transparent background — the banner shows through underneath.
    //
    // The NestedScrollView extends edge-to-edge (no SafeArea wrapper), so we
    // add safeAreaTop as top padding here to push nav buttons below the
    // status bar at rest.
    final safeAreaTop = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.only(top: safeAreaTop),
      child: Column(
        mainAxisSize: .min,
        children: [
          // Zero-sized. Owns *when* the session-expired sheet is presented,
          // so the header's build stays free of route side effects.
          _SessionExpiredPromptTrigger(
            shouldPrompt: shouldPromptForExpiredSession,
            onPrompt: () =>
                _showSessionExpiredSheet(context, ref, widget.userIdHex),
          ),

          // Navigation buttons — always visible immediately.
          //
          // These are not reliably over media: a profile with no banner image
          // and no `profileColor` — the default — gets the palette gradient
          // `containerLow` -> `surface` from [ProfileBanner], and the banner's
          // own scrim is fully transparent at this height. A fixed light glyph
          // would sit at ~1.5:1 there on light, so they follow the palette.
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.isOwnProfile)
                  DivineIconButton(
                    icon: DivineIconName.gear,
                    type: DivineIconButtonType.ghostSecondary,
                    size: DivineIconButtonSize.small,
                    semanticLabel: context.l10n.settingsTitle,
                    semanticIdentifier: SemanticIds.profileSettingsButton,
                    onPressed: () => context.push(SettingsScreen.path),
                  )
                else if (widget.onBack != null)
                  DivineIconButton(
                    icon: DivineIconName.caretLeft,
                    type: DivineIconButtonType.ghostSecondary,
                    size: DivineIconButtonSize.small,
                    semanticLabel: context.l10n.commonBack,
                    semanticIdentifier: SemanticIds.profileBackButton,
                    onPressed: widget.onBack,
                  ),
                if (widget.onMore != null)
                  DivineIconButton(
                    icon: DivineIconName.dotsThree,
                    type: DivineIconButtonType.ghostSecondary,
                    size: DivineIconButtonSize.small,
                    semanticLabel: context.l10n.profileMoreTooltip,
                    semanticIdentifier: SemanticIds.profileMoreButton,
                    onPressed: widget.onMore,
                  ),
              ],
            ),
          ),

          // Identity content. A single Skeletonizer wraps just the avatar
          // and the name/NIP-05/bio block so its shimmer + pointer
          // absorption stays scoped to the widgets actually loading. The
          // people-list pill, stats row, and action buttons sit as
          // siblings outside the skeleton so they remain tappable
          // during the loading window (#4183 review).
          Skeletonizer(
            enabled: showIdentitySkeleton,
            enableSwitchAnimation: true,
            effect: vineSkeletonEffectOf(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered avatar with action label pill
                Center(
                  child: _ProfileAvatarWithColor(
                    imageUrl: profilePictureUrl,
                    userIdHex: widget.userIdHex,
                    showSkeleton: showIdentitySkeleton,
                    profileColor: profileColor,
                    pendingActions: pendingActions,
                    onActionTap: pendingActions.isEmpty
                        ? null
                        : pendingActions.first ==
                              ProfileActionType.accountRestricted
                        ? () => context.push(RoutePaths.accountStatus)
                        : () => _showActionsSheet(
                            context,
                            pendingActions,
                            secureAccountPromptDismissal,
                          ),
                  ),
                ),

                // Name, NIP-05, and bio. Horizontal inset lives on the
                // children so the badge row can scroll edge-to-edge.
                Padding(
                  padding: const EdgeInsets.only(top: 32, bottom: 16),
                  child: _ProfileNameAndBio(
                    profile: effectiveProfile,
                    userIdHex: widget.userIdHex,
                    nip05: nip05,
                    about: about,
                    displayNameHint: displayNameHint,
                    isVanished: isVanished,
                    accentColor: profileColor,
                    isOwnProfile: widget.isOwnProfile,
                    monetizationLinks: monetizationLinksForCurrentStorefront(
                      effectiveProfile?.enabledMonetizationLinks ?? const [],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.isOwnProfile) ...[
            PeopleListMembershipIndicator(pubkey: widget.userIdHex),
            const SizedBox(height: 16),
          ],

          // Stats row owns its own loading skeleton (driven by
          // profileStats == null) and lives outside the identity
          // skeletonizer so it remains interactive.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ProfileStatsRow(
              userIdHex: widget.userIdHex,
              displayName: widget.displayName,
              isOwnProfile: widget.isOwnProfile,
              profileStats: widget.profileStats,
            ),
          ),

          ProfileActionButtons(
            userIdHex: widget.userIdHex,
            isOwnProfile: widget.isOwnProfile,
            displayName: widget.displayName,
            onEditProfile: widget.onEditProfile,
            onOpenClips: widget.onOpenClips,
            onMessageUser: widget.onMessageUser,
            isMessageRestricted: widget.isMessageRestricted,
            onShareProfile: widget.onShareProfile,
            onBlockedTap: widget.onBlockedTap,
          ),
        ],
      ),
    );
  }

  UserProfile? _bestProfileForHeader(
    UserProfile? blocProfile,
    UserProfile? suppliedProfile,
  ) {
    if (blocProfile == null) return suppliedProfile;
    if (suppliedProfile == null) return blocProfile;

    final blocHasMonetization = blocProfile.rawData.containsKey(
      divineMonetizationLinksKey,
    );
    final suppliedHasMonetization = suppliedProfile.rawData.containsKey(
      divineMonetizationLinksKey,
    );

    // Funnelcake REST profiles do not include Divine's custom Kind 0 fields.
    // Prefer a relay/cache profile that has the monetization key over a REST
    // projection that cannot carry it, even when the REST timestamp is newer.
    if (suppliedHasMonetization &&
        !blocHasMonetization &&
        blocProfile.isRestProjection) {
      return suppliedProfile;
    }
    if (blocHasMonetization &&
        !suppliedHasMonetization &&
        suppliedProfile.isRestProjection) {
      return blocProfile;
    }

    if (suppliedProfile.createdAt.isAfter(blocProfile.createdAt)) {
      return suppliedProfile;
    }
    return blocProfile;
  }

  /// Completes when the sheet is closed, so the caller can tell whether one is
  /// still on screen.
  Future<void> _showSessionExpiredSheet(
    BuildContext context,
    WidgetRef ref,
    String userIdHex,
  ) {
    final l10n = context.l10n;
    // The sheet is a route of its own, so it outlives this widget: the
    // profile content unmounts as soon as the shell route's URL leaves the
    // profile, while the sheet stays on screen and stays tappable. Resolve
    // every dependency here, where the header is still mounted — reading
    // `ref` or looking up an ancestor from a button callback throws once the
    // header is gone (#7297).
    final authService = ref.read(authServiceProvider);
    final bannerDismissal = DivineLoginBannerDismissalStore(
      prefs: ref.read(sharedPreferencesProvider),
      userIdHex: userIdHex,
    );
    final publishBloc = context.read<BackgroundPublishBloc>();
    final navigator = Navigator.of(context);

    return VineBottomSheetPrompt.show<void>(
      context: context,
      sticker: DivineStickerName.skeletonKey,
      title: l10n.profileSessionExpired,
      subtitle: l10n.profileSignInToRestore,
      primaryButtonText: l10n.profileSignInButton,
      onPrimaryPressed: () async {
        navigator.pop();
        final refreshed = await authService.tryRefreshExpiredSession();
        if (!context.mounted) return;
        if (refreshed) return;

        _deferredLoginOptionsNavigator.goAfterUploadsComplete(
          context: context,
          publishBloc: publishBloc,
        );
      },
      secondaryButtonText: l10n.profileMaybeLaterLabel,
      onSecondaryPressed: () async {
        // Close first, persist after: the sheet stays tappable for as long as
        // the write is in flight, and this is a sheet users are known to tap
        // repeatedly (#7297), so a second tap would pop the screen underneath.
        // Awaiting first buys nothing — `setInt` updates the in-memory
        // SharedPreferences cache synchronously, so the dismissal is already
        // visible to `isDismissed` before the pop.
        navigator.pop();
        await bannerDismissal.dismiss();
      },
    );
  }

  void _showActionsSheet(
    BuildContext context,
    List<ProfileActionType> actions,
    SecureAccountPromptDismissalStore secureAccountPromptDismissal,
  ) {
    VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      showHeaderDivider: false,
      body: ProfileActionsSheetContent(
        actions: actions,
        onMaybeLater: (action) {
          if (action != ProfileActionType.secureAccount) return;
          // The write lands in the in-memory SharedPreferences cache before
          // the future completes, so an empty setState is enough to drop the
          // action from the next build.
          unawaited(secureAccountPromptDismissal.dismiss());
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

/// Presents the session-expired prompt on condition edges, without stacking.
///
/// The condition stays true while the session is expired, so this reduces it
/// to an edge: [initState] covers a header that mounts already expired,
/// [didUpdateWidget] ignores rebuilds that merely re-report true (#7308).
/// Edges alone are not enough — `isRpcUpgradeInProgress` flickers true then
/// false on every app resume while expired, from
/// `AuthService._refreshOAuthTokenOnResume`. That `false -> true` edge can
/// arrive while the first sheet is open, so `_isPresenting` also suppresses a
/// prompt whose predecessor has not closed.
class _SessionExpiredPromptTrigger extends StatefulWidget {
  const _SessionExpiredPromptTrigger({
    required this.shouldPrompt,
    required this.onPrompt,
  });

  /// Whether the expired-session prompt currently applies.
  final bool shouldPrompt;

  /// Presents the prompt. Called from a post-frame callback; the returned
  /// future completes when the sheet is closed.
  final Future<void> Function() onPrompt;

  @override
  State<_SessionExpiredPromptTrigger> createState() =>
      _SessionExpiredPromptTriggerState();
}

class _SessionExpiredPromptTriggerState
    extends State<_SessionExpiredPromptTrigger> {
  bool _isPresenting = false;

  @override
  void initState() {
    super.initState();
    if (widget.shouldPrompt) _schedulePrompt();
  }

  @override
  void didUpdateWidget(_SessionExpiredPromptTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPrompt && !oldWidget.shouldPrompt) _schedulePrompt();
  }

  /// Deferred to the next frame because pushing a route is not allowed while
  /// the tree that asked for it is still building.
  void _schedulePrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Re-checked at the end of the frame: the condition can resolve between
      // arming and firing — a silent refresh succeeding clears the expiry —
      // and there is no point prompting for a session that is live again.
      if (!mounted || _isPresenting || !widget.shouldPrompt) return;
      _isPresenting = true;
      try {
        await widget.onPrompt();
      } finally {
        if (mounted) _isPresenting = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Centered tip/support pill below the bio.
///
/// Renders nothing when the profile has no storefront-eligible links or the
/// monetization flag is off.
class _ProfileSupportButton extends ConsumerWidget {
  const _ProfileSupportButton({required this.links});

  final List<MonetizationLink> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.profileMonetizationLinks),
    );

    return _ProfileHeaderReveal(
      child: links.isEmpty || !enabled
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                child: DivineButton(
                  key: const Key('profile-support-button'),
                  type: .secondary,
                  size: .tiny,
                  label: _supportAffordanceLabel(context),
                  onPressed: () => _openSupportSheet(context, ref, links),
                ),
              ),
            ),
    );
  }
}

/// Visible label for the tip/support affordance — "Tip" on iOS storefronts,
/// "Support" elsewhere. Deliberately label-only: a bolt glyph reads as
/// Lightning-Network payment, which this is not.
String _supportAffordanceLabel(BuildContext context) =>
    usesAppleAppStoreTipPolicy
    ? context.l10n.profileTipButtonLabel
    : context.l10n.profileSupportButtonLabel;

void _openSupportSheet(
  BuildContext context,
  WidgetRef ref,
  List<MonetizationLink> links,
) {
  final analytics = ref.read(analyticsEventSinkProvider);
  trackMonetizationAffordanceTapped(analytics: analytics, links: links);
  showProfileSupportSheet(context: context, links: links, analytics: analytics);
}

/// Profile name, NIP-05, bio, and public key display.
///
/// The username shimmers when an enclosing [Skeletonizer] is enabled;
/// the NIP-05 / npub identifier and the bio body are wrapped in
/// [Skeleton.keep] so they stay interactive and unshimmered (#4163).
