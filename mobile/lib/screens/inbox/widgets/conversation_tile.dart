// ABOUTME: Individual conversation list item for the inbox screen.
// ABOUTME: Shows avatar, display name, last message preview, and relative time.
// ABOUTME: Unread conversations show a red dot indicator next to the timestamp.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

/// A single conversation row in the DM conversation list.
///
/// Layout matches the Figma "preview" component:
/// 40px avatar | 20px gap | content (name + timestamp row, message preview)
/// with a bottom border divider.
class ConversationTile extends ConsumerWidget {
  const ConversationTile({
    required this.conversation,
    required this.currentUserPubkey,
    required this.onTap,
    this.onLongPress,
    this.highlighted = false,
    this.displayNameOverride,
    this.subtitleOverride,
    super.key,
  });

  final DmConversation conversation;
  final String currentUserPubkey;

  /// Opens the thread, or null for a row with no thread to open — a blocked
  /// account the viewer never exchanged messages with. A null handler also
  /// drops the row's `button` semantics, so assistive tech stops promising an
  /// action that is not there.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// When true, applies the semantic `containerLow` background tint to
  /// indicate this row is the target of an open long-press action sheet.
  final bool highlighted;

  /// Fixed display name, bypassing the kind-0 profile lookup.
  ///
  /// Needed for rows whose identity is known ahead of the network: the profile
  /// provider yields `null` until the relay client is ready, and the tile's
  /// fallback is a generated "Adjective Animal N" name, so a known account
  /// would otherwise render as a random user for the whole cold-start window.
  final String? displayNameOverride;

  /// Fixed preview line, bypassing [DmConversation.lastMessageContent].
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherPubkey = dmConversationFirstPeer(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: currentUserPubkey,
    );

    final profileAsync = ref.watch(fetchUserProfileProvider(otherPubkey));
    final isResolving = ref.watch(
      profileIdentityResolvingProvider(otherPubkey),
    );

    // The thread and its history stay — the messages are the viewer's own copy
    // and a NIP-62 vanish cannot retract them. Only the counterparty's identity
    // is replaced.
    final isDeleted = ref.watch(profileVanishedProvider(otherPubkey));

    final peerName = dmPeerDisplayName(
      context,
      pubkeyHex: otherPubkey,
      isVanished: isDeleted,
      displayNameOverride: displayNameOverride,
      profile: profileAsync.asData?.value,
      isResolving: isResolving,
    );
    // A group is named for the room, not for whichever peer happens to sort
    // first: `otherPubkey` above is an arbitrary member, and naming the row
    // after them hides that anyone else is in it.
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
    final accessibilityName = isIdentityResolving
        ? context.l10n.commonLoading
        : displayName;
    final visualDisplayName = displayName.isEmpty
        ? UserProfile.defaultDisplayNameFor(otherPubkey)
        : displayName;

    final imageUrl = isDeleted
        ? null
        : profileAsync.maybeWhen(
            data: (profile) => profile?.picture,
            orElse: () => null,
          );

    final relativeTime = conversation.lastMessageTimestamp != null
        ? LocalizedTimeFormatter.formatConversationTimestamp(
            context.l10n,
            conversation.lastMessageTimestamp!,
            locale: Localizations.localeOf(context).toLanguageTag(),
          )
        : '';
    final openThread = onTap;

    return Semantics(
      button: openThread != null,
      // Unread state is conveyed to sighted users by the red dot + emphasized
      // preview; mirror it for assistive tech by prefixing the unread status
      // to the row label (same pattern as the notification rows).
      label: conversation.isRead
          ? context.l10n.inboxConversationTileLabel(accessibilityName)
          : context.l10n.inboxConversationTileLabelUnread(accessibilityName),
      // Only advertise the long-press affordance when there is one: the hint
      // is a promise to assistive tech, and rows built without a handler
      // (the pinned support row) have no action sheet to open.
      onLongPressHint: onLongPress == null
          ? null
          : context.l10n.inboxConversationTileLongPressHint,
      child: GestureDetector(
        onTap: openThread == null
            ? null
            : () {
                Log.debug(
                  '🎯 ConversationTile tapped: ${conversation.id}',
                  name: 'ConversationTile',
                  category: LogCategory.ui,
                );
                openThread();
              },
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? context.vineColors.containerLow : null,
            border: Border(
              bottom: BorderSide(color: context.vineColors.outlineDisabled),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              // Top-anchored so the avatar lines up with the name on the
              // first line whether the preview wraps to a second line or
              // not, instead of drifting down with a centered column.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IdentitySkeletonizer(
                  isLoading: isIdentityResolving,
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: UserAvatar(
                      // A group has no single member's photo to show; the room
                      // icon matches the room title beside it.
                      imageUrl: conversation.isGroup ? null : imageUrl,
                      name: visualDisplayName,
                      placeholderSeed: otherPubkey,
                      size: 40,
                      // Bundled artwork for the moderation account, whose
                      // kind-0 picture does not survive the SVG parser.
                      contentOverride: conversation.isGroup
                          ? DivineIcon(
                              icon: DivineIconName.users,
                              color: context.vineColors.primaryText,
                            )
                          : isModerationAccount(otherPubkey)
                          ? const ModerationAvatar()
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + timestamp row
                      Row(
                        children: [
                          Expanded(
                            child: IdentitySkeletonizer(
                              isLoading: isIdentityResolving,
                              excludeSemantics: true,
                              child: DivineHeartText(
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
                      // The closed marker ranks under an explicit override,
                      // unchanged from #6416: the one caller that can pass
                      // both is the Blocked slice's synthesised row, where
                      // "you blocked this account" is the more urgent claim.
                      if (subtitleOverride case final subtitle?) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (isRetiredModerationAccount(otherPubkey)) ...[
                        const SizedBox(height: 4),
                        const ClosedThreadSubtitle(maxLines: 2),
                      ] else if (conversation.lastMessageContent != null) ...[
                        const SizedBox(height: 4),
                        _ConversationPreviewText(
                          payload: _previewPayload(
                            context,
                            conversation.lastMessageContent!,
                          ),
                          emphasized: !conversation.isRead,
                        ),
                      ],
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

class _PreviewPayload {
  const _PreviewPayload({required this.text, required this.isDivineVideoShare});

  final String text;
  final bool isDivineVideoShare;
}

_PreviewPayload _previewPayload(BuildContext context, String rawContent) {
  // This is an endsWith check against fixed short suffixes, so it can safely
  // inspect the original string without doing work proportional to its length.
  // Run it before slicing so a long legacy invite still gets the localized
  // preview instead of exposing its plaintext fallback.
  if (CollaboratorInviteService.hasInvitePlaintextSuffix(rawContent)) {
    return _PreviewPayload(
      text: context.l10n.inboxConversationCollabInvitePreview,
      isDivineVideoShare: false,
    );
  }

  // Sender-controlled text straight from a rumor body, so it can carry
  // unpaired UTF-16 surrogates that crash the paragraph builder during
  // layout. This preview renders through plain `Text`/`Text.rich` rather than
  // `LinkifiedText`, so it does not inherit the span builder's guard and
  // sanitizes once here, ahead of every split and both output paths.
  final boundedContent = sliceDmDisplayText(
    rawContent,
    dmPreviewDisplayCodeUnits,
  ).text;
  final content = StringUtils.sanitizeUtf16(boundedContent);

  // Drop blank lines and trim each remaining line. Shared-video DMs and
  // similar payloads arrive with a blank line between title and URL —
  // without this, `Text(maxLines: 2)` reserves height for the empty line
  // and the tile renders taller than a true one-line preview.
  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final isDivineVideoShare = lines.any(divineVideoUrlLineRegex.hasMatch);
  if (isDivineVideoShare) {
    final nonUrlLines = lines
        .where((line) => !divineVideoUrlLineRegex.hasMatch(line))
        .toList();
    return _PreviewPayload(
      text: nonUrlLines.join('\n'),
      isDivineVideoShare: true,
    );
  }
  return _PreviewPayload(text: lines.join('\n'), isDivineVideoShare: false);
}

/// Two-line preview text with an optional inline camera icon prefix when
/// the last message in the conversation is a divine-video share.
class _ConversationPreviewText extends StatelessWidget {
  const _ConversationPreviewText({
    required this.payload,
    required this.emphasized,
  });

  final _PreviewPayload payload;

  /// True for unread conversations: the preview renders white and semibold
  /// so unread rows stand out beyond the small dot alone.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? VineTheme.labelLargeFont(color: context.vineColors.primaryText)
        : VineTheme.bodyMediumFont(color: context.vineColors.onSurfaceVariant);
    if (!payload.isDivineVideoShare) {
      return DivineHeartText(
        payload.text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    // Icon sized to the preview text's line height so it occupies exactly
    // one line of vertical space; rendered white per design.
    final iconSize = style.fontSize! * (style.height ?? 1);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: DivineIcon(
                icon: DivineIconName.cameraRetro,
                color: context.vineColors.primaryText,
                size: iconSize,
              ),
            ),
          ),
          if (payload.text.isNotEmpty) TextSpan(text: payload.text),
        ],
      ),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
