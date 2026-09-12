// ABOUTME: One-row layout for VideoNotification — leading 32x32 type icon,
// ABOUTME: avatar stack + bold actor name(s) + verb + bold title +
// ABOUTME: inline timestamp, 56x56 video thumbnail on the right.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/widgets/notification_actor_spans.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';
import 'package:openvine/notifications/widgets/notification_leading_type_icon.dart';
import 'package:openvine/notifications/widgets/notification_video_thumbnail.dart';

/// Maximum stacked actor avatars before showing the overflow circle.
const int _maxStackActors = 3;

/// Displays a single video-anchored notification row.
///
/// Layout: leading 32x32 type icon (left) → avatar stack + message text
/// (center) → 56x56 rounded thumbnail (right). Tap targets are split: tap
/// on the row body fires [onTap] (open the video), tap on the thumbnail
/// fires [onThumbnailTap], tap on the avatar stack fires [onProfileTap].
class VideoNotificationRow extends StatelessWidget {
  /// Creates a [VideoNotificationRow].
  const VideoNotificationRow({
    required this.notification,
    required this.onTap,
    required this.onProfileTap,
    required this.onThumbnailTap,
    super.key,
  });

  /// The video-anchored notification to render.
  final VideoNotification notification;

  /// Called when the row body is tapped.
  final VoidCallback onTap;

  /// Called when the avatar stack is tapped.
  final VoidCallback onProfileTap;

  /// Called when the thumbnail on the right is tapped.
  final VoidCallback onThumbnailTap;

  bool _shouldStackThumbnail(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1) >
        NotificationConstants.largeTextStackThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shouldStackThumbnail = _shouldStackThumbnail(context);
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
                    isVideoSourcedMention:
                        notification.type == NotificationKind.mention,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _NotificationContent(
                      notification: notification,
                      onProfileTap: onProfileTap,
                      showStackedThumbnail: shouldStackThumbnail,
                      onThumbnailTap: onThumbnailTap,
                    ),
                  ),
                  if (!shouldStackThumbnail) ...[
                    const SizedBox(width: 12),
                    NotificationVideoThumbnail(
                      imageUrl: notification.videoThumbnailUrl,
                      title: notification.videoTitle,
                      onTap: onThumbnailTap,
                    ),
                  ],
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
    required this.showStackedThumbnail,
    required this.onThumbnailTap,
  });

  final VideoNotification notification;
  final VoidCallback onProfileTap;
  final bool showStackedThumbnail;
  final VoidCallback onThumbnailTap;

  bool get _hasComment =>
      notification.commentText != null && notification.commentText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overflowCount = notification.totalCount - notification.actors.length;
    // The trailing relative timestamp anchors to the visual end of the
    // row. When a comment quote is rendered, it goes after the quote
    // (NotificationCommentQuote handles that inline). Without a quote,
    // it sits at the end of the message text.
    final relativeTime = LocalizedTimeFormatter.formatRelative(
      l10n,
      notification.timestamp.millisecondsSinceEpoch ~/ 1000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: l10n.notificationsViewProfilesSemanticLabel,
          child: GestureDetector(
            onTap: onProfileTap,
            child: NotificationAvatarStack(
              actors: notification.actors.take(_maxStackActors).toList(),
              overflowCount: overflowCount > 0 ? overflowCount : null,
            ),
          ),
        ),
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
        if (showStackedThumbnail) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: NotificationVideoThumbnail(
              imageUrl: notification.videoThumbnailUrl,
              title: notification.videoTitle,
              onTap: onThumbnailTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.notification, this.timestamp});

  final VideoNotification notification;

  /// When non-empty, appended in muted style at the end of the message.
  /// Pass `null` (the default) when a [NotificationCommentQuote] sits
  /// below this widget — the quote renders the timestamp instead, so it
  /// stays anchored to the visual end of the row.
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spans = <InlineSpan>[];
    final actors = notification.actors;
    final type = notification.type;
    final videoTitle = notification.videoTitle;
    final othersCount = notification.totalCount - 1;

    if (type == NotificationKind.listAdd) {
      final listName = notification.listTitle?.isNotEmpty == true
          ? notification.listTitle!
          : l10n.routeDefaultListName;
      final fullText = l10n.notificationAddedYourVideosToList(
        actors.first.displayName,
        notification.addedVideoCount ?? notification.totalCount,
        listName,
      );
      spans.addAll(
        _localizedActorAndListSentenceSpans(
          fullText: fullText,
          actorName: actors.first.displayName,
          listName: listName,
          colors: context.vineColors,
        ),
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

    if (othersCount == 0) {
      spans.addAll(
        localizedActorSentenceSpans(
          fullText: _messageFor(l10n, type, actors.first.displayName),
          actorName: actors.first.displayName,
          colors: context.vineColors,
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: actors.first.displayName,
          style: VineTheme.labelLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: ' ${l10n.notificationAndConnector} ',
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: l10n.notificationOthersCount(othersCount),
          style: VineTheme.labelLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
      );
      spans.add(
        TextSpan(
          text: ' ${_verbFor(l10n, type)}',
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
      );
    }

    if (videoTitle != null && _typeShowsTitle(type)) {
      spans.add(
        TextSpan(
          text: ' $videoTitle',
          style: VineTheme.labelLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
      );
    }

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

/// Whether the row should append the bold video title after the verb.
///
/// `likeComment` is intentionally excluded: comment-likes are routed
/// through `ActorNotification` and have no associated video title here;
/// even if the dispatcher routes one to this row, suppressing the title
/// keeps the message accurate.
bool _typeShowsTitle(NotificationKind type) {
  return type == NotificationKind.like ||
      type == NotificationKind.comment ||
      type == NotificationKind.repost ||
      type == NotificationKind.newPost;
}

/// Returns just the verb portion (no actor name) for inline composition.
///
/// l10n verb keys carry the actor name as a leading `{actorName}`
/// placeholder. Calling them with an empty string and trimming the leading
/// separator yields just the verb that the caller can prepend a bold actor
/// span to.
String _verbFor(AppLocalizations l10n, NotificationKind type) {
  return switch (type) {
    NotificationKind.like => l10n.notificationLikedYourVideo('').trimLeft(),
    NotificationKind.likeComment =>
      l10n.notificationLikedYourComment('').trimLeft(),
    NotificationKind.comment =>
      l10n.notificationCommentedOnYourVideo('').trimLeft(),
    NotificationKind.repost =>
      l10n.notificationRepostedYourVideo('').trimLeft(),
    NotificationKind.mention => l10n.notificationMentionedYou('').trimLeft(),
    NotificationKind.newPost => l10n.notificationPostedNewVine('').trimLeft(),
    // VideoNotification asserts type ∈ {like, likeComment, comment, mention,
    // repost, newPost, listAdd}; the remaining cases satisfy switch
    // exhaustivity only.
    NotificationKind.reply ||
    NotificationKind.follow ||
    NotificationKind.listAdd ||
    NotificationKind.system => '',
  };
}

String _messageFor(
  AppLocalizations l10n,
  NotificationKind type,
  String actorName,
) {
  return switch (type) {
    NotificationKind.like => l10n.notificationLikedYourVideo(actorName),
    NotificationKind.likeComment => l10n.notificationLikedYourComment(
      actorName,
    ),
    NotificationKind.comment => l10n.notificationCommentedOnYourVideo(
      actorName,
    ),
    NotificationKind.repost => l10n.notificationRepostedYourVideo(actorName),
    NotificationKind.mention => l10n.notificationMentionedYou(actorName),
    NotificationKind.newPost => l10n.notificationPostedNewVine(actorName),
    NotificationKind.reply ||
    NotificationKind.follow ||
    NotificationKind.listAdd ||
    NotificationKind.system => '',
  };
}

List<InlineSpan> _localizedActorAndListSentenceSpans({
  required String fullText,
  required String actorName,
  required String listName,
  required VineThemeColors colors,
}) {
  final bodyStyle = VineTheme.bodyMediumFont(color: colors.primaryText);
  final boldStyle = VineTheme.labelLargeFont(color: colors.primaryText);
  final actorStart = fullText.indexOf(actorName);
  if (actorName.isEmpty || actorStart < 0) {
    return [TextSpan(text: fullText, style: bodyStyle)];
  }

  final actorEnd = actorStart + actorName.length;
  final listStart = fullText.indexOf(listName, actorEnd);
  if (listName.isEmpty || listStart < 0) {
    return localizedActorSentenceSpans(
      fullText: fullText,
      actorName: actorName,
      colors: colors,
    );
  }

  final listEnd = listStart + listName.length;
  return [
    if (actorStart > 0)
      TextSpan(text: fullText.substring(0, actorStart), style: bodyStyle),
    TextSpan(text: actorName, style: boldStyle),
    if (actorEnd < listStart)
      TextSpan(text: fullText.substring(actorEnd, listStart), style: bodyStyle),
    TextSpan(text: listName, style: boldStyle),
    if (listEnd < fullText.length)
      TextSpan(text: fullText.substring(listEnd), style: bodyStyle),
  ];
}
