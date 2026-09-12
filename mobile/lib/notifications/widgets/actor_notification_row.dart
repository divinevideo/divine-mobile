// ABOUTME: One-row layout for ActorNotification — leading 32x32 type icon,
// ABOUTME: avatar + bold actor name + verb + inline timestamp, optional
// ABOUTME: comment quote, optional Follow back button.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/widgets/notification_actor_spans.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';
import 'package:openvine/notifications/widgets/notification_leading_type_icon.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Displays a single actor-anchored notification row (follow / mention /
/// like / likeComment / reply / system).
class ActorNotificationRow extends StatelessWidget {
  /// Creates an [ActorNotificationRow].
  const ActorNotificationRow({
    required this.notification,
    required this.onTap,
    required this.onProfileTap,
    this.onFollowBack,
    super.key,
  });

  /// The actor-anchored notification to render.
  final ActorNotification notification;

  /// Called when the row body is tapped.
  final VoidCallback onTap;

  /// Called when the avatar is tapped.
  final VoidCallback onProfileTap;

  /// Called when the Follow back button is tapped (follow kind only).
  final VoidCallback? onFollowBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.vineColors.surfaceContainerHigh,
      child: Semantics(
        button: true,
        container: true,
        label: notification.isRead ? null : l10n.notificationsUnreadPrefix,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.vineColors.outlineDisabled),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NotificationLeadingTypeIcon(
                    type: notification.type,
                    isRead: notification.isRead,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _NotificationContent(
                      notification: notification,
                      onProfileTap: onProfileTap,
                      onFollowBack: onFollowBack,
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

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({
    required this.notification,
    required this.onProfileTap,
    this.onFollowBack,
  });

  final ActorNotification notification;
  final VoidCallback onProfileTap;
  final VoidCallback? onFollowBack;

  bool get _showFollowBack =>
      notification.type == NotificationKind.follow &&
      !notification.isFollowingBack;

  bool get _hasComment =>
      notification.commentText != null && notification.commentText!.isNotEmpty;

  bool _shouldStackFollowBackButton(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1) >
        NotificationConstants.actorRowLargeTextStackThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The trailing relative timestamp anchors to the visual end of the
    // row. When a comment quote is rendered, the quote owns the
    // timestamp suffix; without a quote, the timestamp sits at the end
    // of the message text.
    final relativeTime = LocalizedTimeFormatter.formatRelative(
      l10n,
      notification.timestamp.millisecondsSinceEpoch ~/ 1000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar + (optional) Follow back share a single row so the avatar
        // stays anchored to the top-left and the button hugs the right
        // edge. Keeping the button on this row — instead of as a sibling
        // of the entire content column — means the message text's width
        // below doesn't change when the button appears or disappears, so
        // tapping Follow back never re-wraps the message line.
        Row(
          children: [
            UserAvatar(
              imageUrl: notification.actor.pictureUrl,
              name: notification.actor.displayName,
              placeholderSeed: notification.actor.pubkey,
              size: NotificationConstants.avatarSize,
              cornerRadius: NotificationConstants.avatarCornerRadius,
              onTap: onProfileTap,
              semanticLabel: l10n.notificationsViewProfileSemanticLabel(
                notification.actor.displayName,
              ),
            ),
            if (_showFollowBack && !_shouldStackFollowBackButton(context)) ...[
              const Spacer(),
              // Tiny variant (32px visible) so the row's trailing
              // affordance aligns with the leading 32px type icon and
              // the actor's 32px avatar — keeping the row's intrinsic
              // height stable when the button shows / hides.
              DivineButton(
                label: l10n.notificationFollowBack,
                onPressed: onFollowBack,
                size: DivineButtonSize.tiny,
              ),
            ],
          ],
        ),
        if (_showFollowBack && _shouldStackFollowBackButton(context)) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DivineButton(
              label: l10n.notificationFollowBack,
              onPressed: onFollowBack,
              size: DivineButtonSize.tiny,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _MessageText(
          notification: notification,
          timestamp: _hasComment ? null : relativeTime,
        ),
        if (_hasComment) ...[
          const SizedBox(height: 4),
          NotificationCommentQuote(
            text: notification.commentText!,
            timestamp: relativeTime,
          ),
        ],
      ],
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.notification, this.timestamp});

  final ActorNotification notification;

  /// When non-empty, appended in muted style at the end of the message.
  /// Pass `null` (the default) when a [NotificationCommentQuote] sits
  /// below this widget — the quote renders the timestamp instead, so
  /// the trailing relative time stays anchored to the visual end of
  /// the row.
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = notification.type;
    final spans = type == NotificationKind.system
        ? <InlineSpan>[
            TextSpan(
              text: l10n.notificationSystemUpdate,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ]
        : localizedActorSentenceSpans(
            fullText: _messageFor(l10n, type, notification.actor.displayName),
            actorName: notification.actor.displayName,
            colors: context.vineColors,
          );

    final ts = timestamp;
    if (ts != null && ts.isNotEmpty) {
      spans.add(
        TextSpan(
          text: ' $ts',
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}

String _messageFor(
  AppLocalizations l10n,
  NotificationKind type,
  String actorName,
) {
  return switch (type) {
    NotificationKind.follow => l10n.notificationStartedFollowing(actorName),
    NotificationKind.like => l10n.notificationLikedYourVideo(actorName),
    NotificationKind.mention => l10n.notificationMentionedYou(actorName),
    NotificationKind.likeComment => l10n.notificationLikedYourComment(
      actorName,
    ),
    NotificationKind.reply => l10n.notificationRepliedToYourComment(actorName),
    // newPost is video-anchored and never renders through the actor row;
    // listed here for switch exhaustivity only.
    NotificationKind.system ||
    NotificationKind.comment ||
    NotificationKind.repost ||
    NotificationKind.newPost ||
    NotificationKind.listAdd => '',
  };
}
