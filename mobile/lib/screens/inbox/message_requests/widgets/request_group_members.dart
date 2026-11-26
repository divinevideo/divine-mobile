// ABOUTME: Who is in a group message request: one row per member, each
// ABOUTME: opening that member's profile (#10018).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// The members of a group message request, so the viewer can see who is in
/// the room before accepting it.
class RequestGroupMembers extends StatelessWidget {
  const RequestGroupMembers({required this.memberPubkeys, super.key});

  /// The request's counterparties, the viewer excluded.
  final List<String> memberPubkeys;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.l10n.messageRequestGroupMembersHeading,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final pubkey in memberPubkeys) _GroupMemberRow(pubkey: pubkey),
        ],
      ),
    );
  }
}

/// One member: avatar, name and identifier, opening their profile on tap.
///
/// A room's members are whoever its author listed, so a moderation key here
/// shows no wordmark and no handle (#10151). A blocked member stays listed,
/// marked and without a photo, so the viewer knows they are in the room
/// (#10150). The identifier is the NIP-05 claim only once it verifies for this
/// key, and the npub until then, as where someone picks a recipient.
class _GroupMemberRow extends ConsumerWidget {
  const _GroupMemberRow({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(pubkey))
        .asData
        ?.value;
    final isResolving = ref.watch(profileIdentityResolvingProvider(pubkey));
    final isVanished = ref.watch(profileVanishedProvider(pubkey));
    ref.watch(blocklistVersionProvider);
    final isBlocked = ref
        .read(contentBlocklistRepositoryProvider)
        .isBlocked(pubkey);
    final isModerationKey = isModerationAccount(pubkey);
    final moderation = switch (ref.watch(
      moderationPresentationProvider(pubkey),
    )) {
      ModerationPresentation.official => ModerationPresentation.ordinary,
      final presentation => presentation,
    };

    final name = dmPeerDisplayName(
      context,
      pubkeyHex: pubkey,
      isVanished: isVanished,
      moderation: moderation,
      profile: profile,
      isResolving: isResolving,
    );
    final visualName = name.isEmpty
        ? UserProfile.defaultDisplayNameFor(pubkey)
        : name;
    final avatar = dmPeerAvatar(
      isVanished: isVanished,
      moderation: moderation,
      pictureUrl: isBlocked || isModerationKey ? null : profile?.picture,
    );
    final claim = dmPeerHandle(
      isVanished: isVanished,
      moderation: moderation,
      handle: isModerationKey ? null : profile?.nip05,
    );
    final isVerified =
        claim != null &&
        claim.isNotEmpty &&
        ref
                .watch(
                  nip05ClaimVerificationProvider(
                    Nip05Claim(pubkey: pubkey, nip05: claim),
                  ),
                )
                .asData
                ?.value ==
            Nip05VerificationStatus.verified;
    final npub = NostrKeyUtils.encodePubKey(pubkey);
    final identifier = isVerified ? profile?.shortDisplayNip05 ?? npub : npub;

    return MergeSemantics(
      child: Semantics(
        button: true,
        onTapHint: context.l10n.messageRequestViewProfileButton,
        child: InkWell(
          onTap: () => OtherProfileRouteData(npub: npub).push<void>(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                spacing: 12,
                children: [
                  ExcludeSemantics(
                    child: UserAvatar(
                      imageUrl: avatar.imageUrl,
                      name: visualName,
                      placeholderSeed: pubkey,
                      size: 40,
                      contentOverride: avatar.contentOverride,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IdentitySkeletonizer(
                          isLoading: name.isEmpty,
                          excludeSemantics: true,
                          child: Text(
                            visualName,
                            style: VineTheme.titleMediumFont(
                              color: context.vineColors.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          identifier,
                          style: VineTheme.bodySmallFont(
                            color: context.vineColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isBlocked)
                    Text(
                      context.l10n.profileBlockedLabel,
                      style: VineTheme.labelMediumFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
