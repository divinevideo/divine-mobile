// ABOUTME: Official catalog announcement row with accessible unread state.
// ABOUTME: Only trusted AnnouncementNotification items receive Divine branding.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/widgets/notification_leading_type_icon.dart';

/// An official announcement in the All notifications feed.
class AnnouncementNotificationRow extends StatelessWidget {
  const AnnouncementNotificationRow({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final AnnouncementNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final l10n = context.l10n;
    return Material(
      color: colors.surfaceContainerHigh,
      child: Semantics(
        button: true,
        container: true,
        label: notification.isRead ? null : l10n.notificationsUnreadPrefix,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineDisabled)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NotificationLeadingTypeIcon(
                    type: NotificationKind.announcement,
                    isRead: notification.isRead,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.notificationFromDivine,
                          style: VineTheme.bodySmallFont(
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.title,
                          style: VineTheme.bodyMediumFont(
                            color: colors.onSurface,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: VineTheme.bodyMediumFont(
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LocalizedTimeFormatter.formatRelative(
                            l10n,
                            notification.timestamp.millisecondsSinceEpoch ~/
                                1000,
                          ),
                          style: VineTheme.bodySmallFont(
                            color: colors.mutedText,
                          ),
                        ),
                      ],
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
