// ABOUTME: Conversation tile variant for message requests.
// ABOUTME: Subtitle states the request, or that the thread is closed.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

/// A conversation row in the message requests list.
///
/// Layout matches [ConversationTile], but the subtitle never previews the
/// last message: it reads "Sent a message request", or — for a thread keyed
/// on a retired moderation account — the [ClosedThreadSubtitle] status line.
class RequestTile extends ConsumerWidget {
  const RequestTile({
    required this.conversation,
    required this.currentUserPubkey,
    required this.onTap,
    super.key,
  });

  final DmConversation conversation;
  final String currentUserPubkey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The member the row is named and pictured for: the peer of a one-to-one,
    // and a room's first member that is not a moderation key, without
    // Divine's branding (#10151).
    final named = dmConversationNamedPeer(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: currentUserPubkey,
      moderationPresentation: ref.watch(moderationPresentationResolverProvider),
    );
    final namedPubkey = named.pubkey;

    final profileAsync = ref.watch(userProfileReactiveProvider(namedPubkey));
    final isResolving = ref.watch(
      profileIdentityResolvingProvider(namedPubkey),
    );

    // Same treatment as [ConversationTile]: a request from an account that
    // later vanished is named for the state, not for the generated handle the
    // eviction leaves behind (#8185).
    final isDeleted = ref.watch(profileVanishedProvider(namedPubkey));
    final moderation = named.moderation;

    final peerName = dmPeerDisplayName(
      context,
      pubkeyHex: namedPubkey,
      isVanished: isDeleted,
      moderation: moderation,
      profile: profileAsync.asData?.value,
      isResolving: isResolving,
    );

    // A group reaches this list like any other unfollowed thread —
    // `classifyPotentialRequests` routes "1:1 or group alike" — so the row has
    // to name the room, not the one member `namedPubkey` names it for.
    final displayName = dmConversationDisplayTitle(
      context,
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: currentUserPubkey,
      isGroup: conversation.isGroup,
      peerName: peerName,
      subject: conversation.subject,
    );
    // Derived from the room title, not the peer name: a titled group resolves
    // without a profile and must not skeleton, while an untitled one is named
    // for its peer and must.
    final isIdentityResolving = isResolving && displayName.isEmpty;
    final visualDisplayName = displayName.isEmpty
        ? UserProfile.defaultDisplayNameFor(namedPubkey)
        : displayName;

    // The name above and the artwork here resolve through the same pair of
    // helpers so a row cannot name a peer one way and picture it another.
    final avatar = dmPeerAvatar(
      isVanished: isDeleted,
      moderation: moderation,
      pictureUrl: profileAsync.maybeWhen(
        data: (profile) => profile?.picture,
        orElse: () => null,
      ),
    );

    final relativeTime = conversation.lastMessageTimestamp != null
        ? LocalizedTimeFormatter.formatConversationTimestamp(
            context.l10n,
            conversation.lastMessageTimestamp!,
            locale: Localizations.localeOf(context).toLanguageTag(),
          )
        : '';
    // Any member, not the named one: a room is refused whole when any member
    // is, so a room that includes a retired key is closed wherever it sorts.
    final isClosedThread = dmConversationPeerPubkeys(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: currentUserPubkey,
    ).any(isRetiredModerationAccount);

    return Semantics(
      button: true,
      label: context.l10n.inboxRequestTileLabel(
        isIdentityResolving ? context.l10n.commonLoading : displayName,
      ),
      child: GestureDetector(
        onTap: () {
          Log.debug(
            'RequestTile tapped: ${conversation.id}',
            name: 'RequestTile',
            category: LogCategory.ui,
          );
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.vineColors.outlineDisabled),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              spacing: 20,
              children: [
                IdentitySkeletonizer(
                  isLoading: isIdentityResolving,
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: UserAvatar(
                      // A group has no single member's photo to show; the room
                      // icon matches the room title beside it.
                      imageUrl: conversation.isGroup ? null : avatar.imageUrl,
                      name: visualDisplayName,
                      placeholderSeed: namedPubkey,
                      size: 40,
                      contentOverride: conversation.isGroup
                          ? DivineIcon(
                              icon: DivineIconName.users,
                              color: context.vineColors.primaryText,
                            )
                          : avatar.contentOverride,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: IdentitySkeletonizer(
                              isLoading: isIdentityResolving,
                              excludeSemantics: true,
                              child: Text(
                                visualDisplayName,
                                style: VineTheme.titleMediumFont(
                                  color: context.vineColors.primaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (relativeTime.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            Text(
                              relativeTime,
                              style: VineTheme.bodyMediumFont(
                                color: context.vineColors.onSurfaceMuted,
                              ),
                            ),
                          ],
                          if (!conversation.isRead) ...[
                            const SizedBox(width: 8),
                            const _UnreadDot(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isClosedThread)
                        const ClosedThreadSubtitle()
                      else
                        Text(
                          context.l10n.inboxRequestTileSubtitle,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: VineTheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}
