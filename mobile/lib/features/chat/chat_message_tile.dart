// ABOUTME: Compact room message with the same peer identity as Divine DMs.
// ABOUTME: Shows the message, timestamp, reactions, and recoverable send state.

import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_name_builder.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text.dart';
import 'package:openvine/widgets/user_avatar.dart';

class ChatMessageTile extends ConsumerWidget {
  const ChatMessageTile({
    required this.message,
    required this.reactions,
    required this.pending,
    required this.sending,
    required this.onRetry,
    super.key,
  });

  final ChatMessage message;
  final Map<String, int> reactions;
  final bool pending;
  final bool sending;
  final VoidCallback onRetry;

  void _openProfile(BuildContext context) {
    FocusScope.of(context).unfocus();
    unawaited(
      OtherProfileRouteData(
        npub: NostrKeyUtils.encodePubKey(message.author),
      ).push<void>(context),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = watchDmPeerName(context, ref, message.author);
    final profile = ref
        .watch(fetchUserProfileProvider(message.author))
        .asData
        ?.value;
    final avatar = dmPeerAvatar(
      isVanished: ref.watch(profileVanishedProvider(message.author)),
      moderation: ref.watch(moderationPresentationProvider(message.author)),
      pictureUrl: profile?.picture,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            size: 36,
            onTap: () => _openProfile(context),
            semanticLabel: context.l10n.profileChipTapHint(name.name),
            imageUrl: avatar.imageUrl,
            contentOverride: avatar.contentOverride,
            name: name.name,
            placeholderSeed: message.author,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (name.isResolving)
                      Container(
                        width: 96,
                        height: 16,
                        decoration: BoxDecoration(
                          color: context.vineColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    else
                      Semantics(
                        button: true,
                        label: context.l10n.profileChipTapHint(name.name),
                        onTap: () => _openProfile(context),
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => _openProfile(context),
                          child: Text(
                            name.name,
                            style: VineTheme.titleSmallFont(
                              color: context.vineColors.primaryText,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      LocalizedTimeFormatter.formatMessageTime(
                        context.l10n,
                        message.createdAt,
                        locale: Localizations.localeOf(context).toLanguageTag(),
                        use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
                      ),
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinkifiedText(
                  text: message.effectiveBody,
                  mentionProfilePubkeys: message.mentionedPubkeys,
                  style: VineTheme.bodyLargeFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                if (reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final reaction in reactions.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.vineColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${reaction.key} ${reaction.value}'),
                          ),
                      ],
                    ),
                  ),
                if (pending)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        sending
                            ? context.l10n.authSending
                            : context.l10n.dmStatusFailed,
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.onSurfaceMuted,
                        ),
                      ),
                      if (!sending)
                        DivineButton(
                          onPressed: onRetry,
                          label: context.l10n.dmSendFailedRetry,
                          type: DivineButtonType.link,
                          size: DivineButtonSize.small,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
