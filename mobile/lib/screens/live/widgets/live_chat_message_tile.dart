import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:time_formatter/time_formatter.dart';

class LiveChatMessageTile extends ConsumerWidget {
  const LiveChatMessageTile({
    required this.message,
    super.key,
  });

  final LiveChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(message.pubkey))
        .value;
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(message.pubkey);
    final imageUrl = profile?.picture;
    final relativeTime = TimeFormatter.formatConversationTimestamp(
      message.createdAt.millisecondsSinceEpoch ~/ 1000,
    );

    return Semantics(
      label: '$displayName live chat message',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              imageUrl: imageUrl,
              name: displayName,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: profile != null
                            ? UserName.fromUserProfile(
                                profile,
                                style: VineTheme.labelLargeFont(
                                  color: VineTheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : UserName.fromPubKey(
                                message.pubkey,
                                style: VineTheme.labelLargeFont(
                                  color: VineTheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (relativeTime.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          relativeTime,
                          style: VineTheme.bodySmallFont(
                            color: VineTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: VineTheme.bodyMediumFont(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
