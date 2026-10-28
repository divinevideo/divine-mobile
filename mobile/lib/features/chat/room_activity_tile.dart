// ABOUTME: Public room preview with unread messages and recent participation.
// ABOUTME: Uses verified activity and shared peer identity, never online claims.

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_name_builder.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Uses the same full-row target as [DivineListTile], with a custom layout
/// because previews, unread state and contributor avatars need multiple rows.
class RoomActivityTile extends StatelessWidget {
  const RoomActivityTile({
    required this.title,
    required this.onTap,
    this.activity,
    this.onRetry,
    super.key,
  });

  final String title;
  final RoomActivitySummary? activity;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final summary = activity;
    final latest = summary?.latestMessage;
    final loading = summary?.loading ?? true;
    final loadFailed = summary?.loadFailed ?? false;
    final unreadCount = summary?.unreadCount ?? 0;
    final colors = context.vineColors;
    final mutedStyle = VineTheme.bodySmallFont(color: colors.onSurfaceMuted);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '#',
                    style: VineTheme.titleLargeFont(
                      color: colors.accentPositive,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: VineTheme.titleMediumFont(
                              color: colors.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ExcludeSemantics(
                          child: DivineIcon(
                            icon: DivineIconName.caretRight,
                            size: 20,
                            color: colors.accentPositive,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          context.l10n.listVisibilityPublic,
                          style: mutedStyle,
                        ),
                        if (unreadCount > 0)
                          _RoomUnreadBadge(
                            count: unreadCount,
                            historyLimited: summary!.historyLimited,
                          ),
                        if (latest != null)
                          Text(
                            LocalizedTimeFormatter.formatConversationTimestamp(
                              context.l10n,
                              latest.createdAt,
                              locale: Localizations.localeOf(context)
                                  .toLanguageTag(),
                            ),
                            style: mutedStyle,
                          ),
                      ],
                    ),
                    if (latest != null) ...[
                      const SizedBox(height: 8),
                      _LatestRoomMessage(message: latest),
                    ],
                    if (loading || loadFailed || latest == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              loadFailed
                                  ? context.l10n.messagesRoomLoadFailed
                                  : loading
                                  ? context.l10n.messagesRoomLoading
                                  : context.l10n.messagesRoomEmpty,
                              style: mutedStyle,
                            ),
                            if (loadFailed && onRetry != null)
                              DivineButton(
                                label: context.l10n.commonRetry,
                                onPressed: onRetry,
                                type: DivineButtonType.link,
                                size: DivineButtonSize.small,
                              ),
                          ],
                        ),
                      ),
                    if (summary != null && latest != null) ...[
                      const SizedBox(height: 10),
                      _RecentRoomActivity(activity: summary),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomUnreadBadge extends StatelessWidget {
  const _RoomUnreadBadge({required this.count, required this.historyLimited});

  final int count;
  final bool historyLimited;

  @override
  Widget build(BuildContext context) {
    final fullCount = historyLimited ? '$count+' : '$count';
    return Semantics(
      label: context.l10n.messagesRoomUnreadLabel(count, fullCount),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: context.vineColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          context.l10n.messagesRoomNewCount(
            count,
            count > 99 ? '99+' : fullCount,
          ),
          style: VineTheme.bodySmallFont(
            color: context.vineColors.accentPositive,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _LatestRoomMessage extends StatelessWidget {
  const _LatestRoomMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) => DmPeerNameBuilder(
    pubkey: message.author,
    builder: (context, name) => Text(
      name.isResolving
          ? message.effectiveBody
          : context.l10n.messagesRoomLatestMessage(
              name.name,
              message.effectiveBody,
            ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: VineTheme.bodyMediumFont(color: context.vineColors.primaryText),
    ),
  );
}

class _RecentRoomActivity extends StatelessWidget {
  const _RecentRoomActivity({required this.activity});

  final RoomActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final authors = activity.recentAuthors;
    final style = VineTheme.bodySmallFont(
      color: context.vineColors.onSurfaceMuted,
    );
    final suffix = activity.historyLimited ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (authors.isNotEmpty)
              ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final author in authors.take(3))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 4),
                        child: _RoomContributorAvatar(pubkey: author),
                      ),
                  ],
                ),
              ),
            Text(
              context.l10n.messagesRoomContributors(
                authors.length,
                '${authors.length}$suffix',
              ),
              style: style,
            ),
            const ExcludeSemantics(child: Text('·')),
            Text(
              context.l10n.messagesRoomRecentMessages(
                activity.recentMessageCount,
                '${activity.recentMessageCount}$suffix',
              ),
              style: style,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(context.l10n.messagesRoomActivityPeriod, style: style),
      ],
    );
  }
}

class _RoomContributorAvatar extends ConsumerWidget {
  const _RoomContributorAvatar({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = watchDmPeerName(context, ref, pubkey);
    final profile = ref.watch(fetchUserProfileProvider(pubkey)).asData?.value;
    final avatar = dmPeerAvatar(
      isVanished: name.isVanished,
      moderation: ref.watch(moderationPresentationProvider(pubkey)),
      pictureUrl: profile?.picture,
    );
    return UserAvatar(
      size: 24,
      imageUrl: avatar.imageUrl,
      contentOverride: avatar.contentOverride,
      name: name.name,
      placeholderSeed: pubkey,
    );
  }
}
