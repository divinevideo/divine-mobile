// ABOUTME: Horizontal scrollable bar of following users for the inbox screen.
// ABOUTME: Shows avatars with display names of users the current user follows.
// ABOUTME: Tapping an avatar navigates to start a conversation with that user.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Horizontal scrollable bar showing following users.
///
/// Displays a row of avatars with display names from [MyFollowingBloc].
/// Tapping a user triggers [onUserTapped] with their pubkey.
class FollowingBar extends StatelessWidget {
  const FollowingBar({
    required this.onUserTapped,
    required this.currentUserPubkey,
    super.key,
  });

  final ValueChanged<String> onUserTapped;

  /// The signed-in user, never offered as a conversation partner — Divine
  /// does not support a self-addressed conversation (#8351).
  final String currentUserPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<MyFollowingBloc, MyFollowingState, List<String>>(
      // Selects the list unchanged so its identity is stable across
      // emissions — BlocSelector compares with `==`, and List does not
      // override it, so filtering here would rebuild the bar on every
      // MyFollowingState emission.
      selector: (state) => state.followingPubkeys,
      builder: (context, allFollowingPubkeys) {
        // Drop the viewer here rather than in [MyFollowingBloc], which nine
        // other screens share and where following yourself is a legitimate
        // thing to render. A contact list written by another Nostr client
        // can self-follow, and only the merge path strips that — every other
        // path assigns the list as received. Case-insensitive: a pubkey
        // arriving from another client may be upper-case hex. See #8351.
        final followingPubkeys = [
          for (final pubkey in allFollowingPubkeys)
            if (!pubkeysEqual(pubkey, currentUserPubkey)) pubkey,
        ];
        if (followingPubkeys.isEmpty) return const SizedBox.shrink();

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.vineColors.outlineDisabled),
            ),
          ),
          child: SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 0),
              itemCount: followingPubkeys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _FollowingUserButton(
                pubkey: followingPubkeys[index],
                onTap: () => onUserTapped(followingPubkeys[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FollowingUserButton extends ConsumerWidget {
  const _FollowingUserButton({required this.pubkey, required this.onTap});

  final String pubkey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));
    final isResolving = ref.watch(profileIdentityResolvingProvider(pubkey));

    // A vanish cannot rewrite the viewer's own contact list, so the account
    // stays in this bar. Show it as deleted rather than under a stale name.
    final isDeleted = ref.watch(profileVanishedProvider(pubkey));

    final displayName = dmPeerDisplayName(
      context,
      pubkeyHex: pubkey,
      isVanished: isDeleted,
      profile: profileAsync.asData?.value,
      isResolving: isResolving,
    );
    final isIdentityResolving = isResolving && displayName.isEmpty;
    final visualDisplayName = displayName.isEmpty
        ? UserProfile.defaultDisplayNameFor(pubkey)
        : displayName;

    final imageUrl = isDeleted
        ? null
        : profileAsync.maybeWhen(
            data: (profile) => profile?.picture,
            orElse: () => null,
          );

    return Semantics(
      button: true,
      label: isIdentityResolving ? context.l10n.commonLoading : displayName,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              IdentitySkeletonizer(
                isLoading: isIdentityResolving,
                excludeSemantics: true,
                child: UserAvatar(
                  imageUrl: imageUrl,
                  name: visualDisplayName,
                  placeholderSeed: pubkey,
                  size: 48,
                ),
              ),
              IdentitySkeletonizer(
                isLoading: isIdentityResolving,
                excludeSemantics: true,
                child: Text(
                  visualDisplayName,
                  textScaler: TextScaler.noScaling,
                  style:
                      VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ).copyWith(
                        fontSize: MediaQuery.textScalerOf(context)
                            .scale(
                              VineTheme.bodySmallFont(
                                color: context.vineColors.primaryText,
                              ).fontSize!,
                            )
                            .clamp(0, 18),
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
