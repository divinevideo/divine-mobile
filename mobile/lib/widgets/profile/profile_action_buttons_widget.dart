// ABOUTME: Action buttons widget for profile page (library, share, follow)
// ABOUTME: Shows different buttons for own profile vs other user profiles

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/notify_bell/notify_bell_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';
import 'package:openvine/widgets/profile/profile_notify_bell_button.dart';

/// Action buttons shown on profile page.
///
/// Different buttons shown for own profile vs other user profiles.
/// For other profiles, button order changes based on follow state:
/// - Not following: [Follow] [Message] [Share]
/// - Following:     [Message] [Bell] [Following] [Share]
///
/// Creates [MyFollowingBloc] for other profiles so both the follow button
/// and the row ordering react to the same optimistic state change instantly,
/// and [NotifyBellCubit] so the follow-gated bell has a host that outlives
/// its own mount.
class ProfileActionButtons extends ConsumerWidget {
  const ProfileActionButtons({
    required this.userIdHex,
    required this.isOwnProfile,
    this.displayName,
    this.onEditProfile,
    this.onOpenClips,
    this.onMessageUser,
    this.isMessageRestricted = false,
    this.onShareProfile,
    this.onBlockedTap,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;

  /// Display name for unfollow confirmation (required when not own profile).
  final String? displayName;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenClips;
  final VoidCallback? onMessageUser;
  final bool isMessageRestricted;
  final void Function(BuildContext context)? onShareProfile;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOwnProfile) {
      return _ActionButtonsRow(children: _buildOwnProfileButtons(context));
    }

    final followRepository = ref.watch(followRepositoryProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    final notifySubscriptions = ref.watch(
      notifySubscriptionsRepositoryProvider,
    );
    final nostrClient = ref.watch(nostrServiceProvider);
    // Empty rather than null when no signer is attached (the placeholder
    // LocalKeySigner), so signed-out is an emptiness check.
    final viewerPubkey = nostrClient.publicKey;
    // Off until divine-push-service delivers kind 34236 to d=notify
    // subscribers; until then the bell would publish a subscription that
    // never produces a notification.
    final canShowBell =
        viewerPubkey.isNotEmpty &&
        ref.watch(isFeatureEnabledProvider(FeatureFlag.newPostNotifications));

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    final isBlocked = contentBlocklistRepository.canUnblock(userIdHex);
    final canTargetUser = ref.watch(canTargetUserProvider(userIdHex));

    // Create MyFollowingBloc at this level so both the follow button
    // and the row ordering share the same optimistic state.
    //
    // NotifyBellCubit is provided here too, above the follow-gated bell, so
    // it survives the bell unmounting on unfollow and can still publish the
    // teardown. Both are keyed on their repositories' identity so an auth
    // flip rebuilds them instead of leaving a stale capture.
    return MultiBlocProvider(
      key: ValueKey((
        followRepository,
        contentBlocklistRepository,
        notifySubscriptions,
        viewerPubkey,
        canShowBell,
      )),
      providers: [
        BlocProvider(
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistRepository: contentBlocklistRepository,
          )..add(const MyFollowingListLoadRequested()),
        ),
        if (canShowBell)
          BlocProvider(
            create: (_) => NotifyBellCubit(
              repository: notifySubscriptions,
              viewerPubkey: viewerPubkey,
              creatorPubkey: userIdHex,
            )..load(),
          ),
      ],
      child: _OtherProfileButtons(
        userIdHex: userIdHex,
        displayName: displayName,
        currentUserPubkey: viewerPubkey,
        isBlocked: isBlocked,
        canTargetUser: canTargetUser,
        isMessageRestricted: isMessageRestricted,
        onMessageUser: onMessageUser,
        onShareProfile: onShareProfile,
        onBlockedTap: onBlockedTap,
        canShowBell: canShowBell,
      ),
    );
  }

  List<Widget> _buildOwnProfileButtons(BuildContext context) {
    return [
      Expanded(
        child: DivineButton(
          key: const Key('library-button'),
          expanded: true,
          leadingIcon: .filmSlate,
          type: .secondary,
          size: .small,
          label: context.l10n.profileMyLibraryLabel,
          onPressed: onOpenClips,
        ),
      ),
      DivineIconButton(
        icon: .pencilSimpleLine,
        type: .secondary,
        size: .small,
        semanticLabel: context.l10n.profileSetupEditProfileTitle,
        semanticIdentifier: SemanticIds.profileEditButton,
        onPressed: onEditProfile,
      ),
      DivineIconButton(
        icon: .shareFat,
        type: .secondary,
        size: .small,
        semanticLabel: context.l10n.profileShareLabel,
        onPressed: onShareProfile == null
            ? null
            : () => onShareProfile!(context),
      ),
    ];
  }
}

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: Row(spacing: 6, children: children),
    );
  }
}

/// Other-profile buttons that reorder based on [MyFollowingBloc] state.
///
/// Uses [BlocSelector] on the bloc provided by [ProfileActionButtons]
/// so the reorder happens in the same frame as the follow button's
/// visual state change.
class _OtherProfileButtons extends StatelessWidget {
  const _OtherProfileButtons({
    required this.userIdHex,
    required this.displayName,
    required this.currentUserPubkey,
    required this.isBlocked,
    required this.canTargetUser,
    required this.isMessageRestricted,
    required this.onMessageUser,
    required this.onShareProfile,
    required this.onBlockedTap,
    required this.canShowBell,
  });

  final String userIdHex;
  final String? displayName;
  final String? currentUserPubkey;
  final bool isBlocked;

  /// Whether a [NotifyBellCubit] was provided (requires a signed-in viewer).
  final bool canShowBell;

  /// Whether the UI may offer interactions targeting this user. False
  /// hides the follow and message affordances entirely — absence, never
  /// an explanation (disclosure invariant).
  final bool canTargetUser;

  /// Whether the protected-minor DM policy hides only the message affordance.
  final bool isMessageRestricted;

  final VoidCallback? onMessageUser;
  final void Function(BuildContext context)? onShareProfile;
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<MyFollowingBloc, MyFollowingState>(
      // The bell is follow-gated, so an abandoned subscription would keep
      // pushing videos from someone the viewer no longer follows with no UI
      // left to switch it off. Bridged here rather than inside the bell,
      // which has already unmounted by the time this fires.
      listenWhen: (previous, current) =>
          canShowBell &&
          previous.isFollowing(userIdHex) &&
          !current.isFollowing(userIdHex),
      listener: (context, state) {
        context.read<NotifyBellCubit>().clearForUnfollow();
      },
      buildWhen: (previous, current) =>
          previous.isFollowing(userIdHex) != current.isFollowing(userIdHex),
      builder: (context, state) {
        final isFollowing = state.isFollowing(userIdHex);
        final canShowMessage = canTargetUser && !isMessageRestricted;
        final followButton = FollowFromProfileButtonView(
          pubkey: userIdHex,
          displayName: displayName ?? l10n.profileUserFallback,
          currentUserPubkey: currentUserPubkey,
          isBlocked: isBlocked,
          canTargetAuthor: canTargetUser,
          onBlockedTap: onBlockedTap,
        );

        final shareButton = DivineIconButton(
          icon: .shareFat,
          type: .secondary,
          size: .small,
          semanticLabel: l10n.profileShareLabel,
          onPressed: onShareProfile == null
              ? null
              : () => onShareProfile!(context),
        );
        final List<Widget> children;

        if (isFollowing) {
          // Following: [Message (expanded)] [Bell] [Following] [Share]
          children = [
            if (canTargetUser) ...[
              if (canShowMessage)
                Expanded(
                  child: DivineButton(
                    expanded: true,
                    leadingIcon: .envelopeSimple,
                    type: .secondary,
                    size: .small,
                    label: l10n.profileMessageLabel,
                    onPressed: onMessageUser,
                  ),
                ),
              if (!canShowMessage) const Spacer(),
              if (canShowBell) const ProfileNotifyBellButton(),
              followButton,
            ] else
              const Spacer(),
            shareButton,
          ];
        } else {
          // Not following: [Follow (expanded)] [Message (icon)] [Share]
          children = [
            if (canTargetUser) ...[
              Expanded(child: followButton),
              if (canShowMessage)
                DivineButton(
                  leadingIcon: .envelopeSimple,
                  type: .secondary,
                  size: .small,
                  label: '',
                  semanticLabel: l10n.profileMessageLabel,
                  onPressed: onMessageUser,
                ),
            ] else
              const Spacer(),
            shareButton,
          ];
        }

        return _ActionButtonsRow(children: children);
      },
    );
  }
}
