// ABOUTME: Follow button widget for profile page using BLoC pattern.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/unfollow_confirmation_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
class FollowFromProfileButton extends ConsumerWidget {
  const FollowFromProfileButton({
    required this.pubkey,
    required this.displayName,
    super.key,
    this.onBlockedTap,
  });

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  /// The display name of the user (for unfollow confirmation).
  final String displayName;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrClient.publicKey;

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    // Watch blocklist to reactively update button state
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final isBlocked = blocklistRepository.isBlocked(pubkey);
    final canTargetAuthor = ref.watch(canTargetUserProvider(pubkey));

    return BlocProvider(
      create: (_) => MyFollowingBloc(
        followRepository: followRepository,
        contentBlocklistRepository: blocklistRepository,
      )..add(const MyFollowingListLoadRequested()),
      child: FollowFromProfileButtonView(
        pubkey: pubkey,
        displayName: displayName,
        currentUserPubkey: currentUserPubkey,
        isBlocked: isBlocked,
        canTargetAuthor: canTargetAuthor,
        onBlockedTap: onBlockedTap,
      ),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow button.
///
/// Expects a [MyFollowingBloc] to be available in the widget tree.
/// Used by [FollowFromProfileButton] (which creates its own bloc)
/// and by [ProfileActionButtons] (which shares the bloc for row reordering).
class FollowFromProfileButtonView extends StatelessWidget {
  const FollowFromProfileButtonView({
    required this.pubkey,
    required this.displayName,
    required this.currentUserPubkey,
    super.key,
    this.isBlocked = false,
    this.canTargetAuthor = true,
    this.onBlockedTap,
  });

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  /// The display name of the user (for unfollow confirmation).
  final String displayName;

  /// The current user's public key (used for optimistic follower count update).
  final String? currentUserPubkey;

  /// Whether the user is blocked by us.
  final bool isBlocked;

  /// Whether the UI may offer interactions targeting this user.
  ///
  /// False when their published block or mute list names us. The button
  /// renders nothing in that case — absence, never an explanation
  /// (disclosure invariant).
  final bool canTargetAuthor;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) {
    // If the target doesn't accept interactions from us, render nothing.
    if (!canTargetAuthor) {
      return const SizedBox.shrink();
    }

    // Show Blocked state if user is blocked by us
    if (isBlocked) {
      return OutlinedButton(
        onPressed: onBlockedTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.vineColors.errorContainer,
          disabledBackgroundColor: context.vineColors.errorContainer,
          foregroundColor: VineTheme.error,
          disabledForegroundColor: VineTheme.error,
          side: BorderSide(color: context.vineColors.errorContainer, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              DivineIconName.prohibit.assetPath,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                VineTheme.error,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.profileBlockedLabel,
              style: VineTheme.titleMediumFont(color: VineTheme.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return BlocListener<MyFollowingBloc, MyFollowingState>(
      listenWhen: (previous, current) =>
          current.status == MyFollowingStatus.toggleFailure &&
          previous.status != MyFollowingStatus.toggleFailure,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.followersUpdateFollowFailed,
            error: true,
          ),
        );
      },
      child: BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
        selector: (state) => state.isFollowing(pubkey),
        builder: (context, isFollowing) {
          if (isFollowing) {
            return _FollowingButton(
              onPressed: () => _showUnfollowConfirmation(context),
            );
          }
          return _FollowButton(onPressed: () => _follow(context));
        },
      ),
    );
  }

  Future<void> _showUnfollowConfirmation(BuildContext context) async {
    final result = await showUnfollowConfirmation(
      context,
      displayName: displayName,
    );

    if (result == true && context.mounted) {
      _unfollow(context);
    }
  }

  void _follow(BuildContext context) {
    Log.info(
      'Profile follow button tapped for ${pubkeyForLogs(pubkey)}',
      name: 'FollowFromProfileButton',
      category: LogCategory.ui,
    );

    // Follow in MyFollowingBloc
    context.read<MyFollowingBloc>().add(MyFollowingToggleRequested(pubkey));

    // Optimistically update the followers count in OthersFollowersBloc
    final othersFollowersBloc = context.read<OthersFollowersBloc?>();
    if (othersFollowersBloc != null && currentUserPubkey != null) {
      othersFollowersBloc.add(
        OthersFollowersIncrementRequested(currentUserPubkey!),
      );
    }
  }

  void _unfollow(BuildContext context) {
    Log.info(
      'Profile unfollow confirmed for ${pubkeyForLogs(pubkey)}',
      name: 'FollowFromProfileButton',
      category: LogCategory.ui,
    );

    // Unfollow in MyFollowingBloc
    context.read<MyFollowingBloc>().add(MyFollowingToggleRequested(pubkey));

    // Optimistically update the followers count in OthersFollowersBloc
    final othersFollowersBloc = context.read<OthersFollowersBloc?>();
    if (othersFollowersBloc != null && currentUserPubkey != null) {
      othersFollowersBloc.add(
        OthersFollowersDecrementRequested(currentUserPubkey!),
      );
    }
  }
}

/// Button showing "Following" state — icon only; its accessible name describes
/// the unfollow action.
class _FollowingButton extends StatelessWidget {
  const _FollowingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      type: .secondary,
      size: .small,
      onPressed: onPressed,
      label: '',
      semanticLabel: context.l10n.unfollowUserSemanticLabel,
      leadingIcon: .userCheck,
    );
  }
}

/// Button showing "Follow" state with plus icon.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      onPressed: onPressed,
      size: .small,
      leadingIcon: DivineIconName.userPlus,
      label: context.l10n.profileFollowLabel,
      semanticIdentifier: SemanticIds.profileFollowAction,
    );
  }
}
