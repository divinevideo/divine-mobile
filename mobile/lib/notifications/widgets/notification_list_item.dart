// ABOUTME: Thin dispatcher: routes a NotificationItem to the matching row
// ABOUTME: widget (VideoNotificationRow / ActorNotificationRow) via an
// ABOUTME: exhaustive sealed switch.

import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/actor_notification_row.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';

/// Displays a single notification row, dispatching on the sealed
/// [NotificationItem] subtype.
///
/// Adding a new [NotificationItem] subtype is a compile error here, by
/// design — the switch must stay exhaustive.
class NotificationListItem extends StatelessWidget {
  /// Creates a [NotificationListItem].
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    this.onProfileTap,
    this.onFollowBack,
    this.onThumbnailTap,
    super.key,
  });

  /// The notification data to display.
  final NotificationItem notification;

  /// Called when the row body is tapped.
  final VoidCallback onTap;

  /// Called when the avatar / avatar stack is tapped.
  final VoidCallback? onProfileTap;

  /// Called when the Follow back button is tapped (follow rows only).
  final VoidCallback? onFollowBack;

  /// Called when the video thumbnail is tapped (video rows only).
  ///
  /// Defaults to [onTap] when not provided.
  final VoidCallback? onThumbnailTap;

  @override
  Widget build(BuildContext context) {
    return switch (notification) {
      final VideoNotification video => VideoNotificationRow(
        notification: video,
        onTap: onTap,
        onProfileTap: onProfileTap ?? onTap,
        onThumbnailTap: onThumbnailTap ?? onTap,
      ),
      final ActorNotification actor => ActorNotificationRow(
        notification: actor,
        onTap: onTap,
        onProfileTap: onProfileTap ?? onTap,
        onFollowBack: onFollowBack,
      ),
    };
  }
}
