// ABOUTME: Widget for displaying individual notification items in the notifications list
// ABOUTME: Shows actor avatar, notification message, timestamp, and action buttons

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/theme/app_theme.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    super.key,
  });
  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: notification.isRead
          ? (isDarkMode ? Colors.black : Colors.white)
          : (isDarkMode ? Colors.grey[900] : Colors.grey[50]),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or icon
              _buildLeadingWidget(isDarkMode),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main message
                    _buildMessage(context, isDarkMode),
                    const SizedBox(height: 4),

                    // Additional content (comment text, etc.)
                    if (_hasAdditionalContent()) ...[
                      const SizedBox(height: 4),
                      _buildAdditionalContent(isDarkMode),
                    ],

                    // Timestamp
                    const SizedBox(height: 4),
                    Text(
                      notification.formattedTimestamp,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              // Thumbnail or action button
              if (notification.targetVideoThumbnail != null)
                _buildVideoThumbnail(isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingWidget(bool isDarkMode) {
    if (notification.type == NotificationType.system) {
      // System notification icon
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            notification.typeIcon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      );
    }

    // User avatar with overlay icon
    return Stack(
      children: [
        // Avatar
        ClipOval(
          child: notification.actorPictureUrl != null
              ? CachedNetworkImage(
                  imageUrl: notification.actorPictureUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  cacheManager: openVineImageCache,
                  placeholder: (context, url) => Container(
                    width: 48,
                    height: 48,
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  ),
                  errorWidget: (context, url, error) {
                    // Log the failed URL for debugging
                    if (error.toString().contains('Invalid image data') ||
                        error.toString().contains('Image codec failed')) {
                      Log.warning(
                        'Invalid image data for actor avatar URL: $url - Error: $error',
                        name: 'NotificationListItem',
                        category: LogCategory.ui,
                      );
                    } else {
                      Log.debug(
                        'Actor avatar load failed, URL: $url - Error: $error',
                        name: 'NotificationListItem',
                        category: LogCategory.ui,
                      );
                    }
                    return _buildDefaultAvatar(isDarkMode);
                  },
                )
              : _buildDefaultAvatar(isDarkMode),
        ),

        // Type icon overlay
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _getIconBackgroundColor(),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode ? Colors.black : Colors.white,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                notification.typeIcon,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(bool isDarkMode) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: DivineTheme.primaryPurple.withValues(alpha: 0.2),
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: Icon(Icons.person, color: DivineTheme.primaryPurple, size: 24),
    ),
  );

  Widget _buildMessage(BuildContext context, bool isDarkMode) {
    final textStyle = TextStyle(
      fontSize: 14,
      color: isDarkMode ? Colors.white : Colors.black,
    );

    if (notification.actorName != null) {
      // Build rich text with bold actor name
      return RichText(
        text: TextSpan(
          style: textStyle,
          children: [
            TextSpan(
              text: notification.actorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: notification.message.substring(
                notification.message.indexOf(' '),
              ),
            ),
          ],
        ),
      );
    }

    return Text(notification.message, style: textStyle);
  }

  bool _hasAdditionalContent() {
    if (notification.type == NotificationType.comment) {
      return notification.metadata?['comment'] != null;
    } else if (notification.type == NotificationType.mention) {
      return notification.metadata?['text'] != null;
    }
    return false;
  }

  Widget _buildAdditionalContent(bool isDarkMode) {
    String? content;

    if (notification.type == NotificationType.comment) {
      content = notification.metadata?['comment'] as String?;
    } else if (notification.type == NotificationType.mention) {
      content = notification.metadata?['text'] as String?;
    }

    if (content == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildVideoThumbnail(bool isDarkMode) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: notification.targetVideoThumbnail!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        cacheManager: openVineImageCache,
        placeholder: (context, url) => Container(
          width: 64,
          height: 64,
          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) {
          // Log the failed URL for debugging
          if (error.toString().contains('Invalid image data') ||
              error.toString().contains('Image codec failed')) {
            Log.warning(
              'Invalid image data for video thumbnail URL: $url - Error: $error',
              name: 'NotificationListItem',
              category: LogCategory.ui,
            );
          } else {
            Log.debug(
              'Video thumbnail load failed, URL: $url - Error: $error',
              name: 'NotificationListItem',
              category: LogCategory.ui,
            );
          }
          return Container(
            width: 64,
            height: 64,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
            child: Icon(
              Icons.video_library,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
          );
        },
      ),
    ),
  );

  Color _getIconBackgroundColor() {
    switch (notification.type) {
      case NotificationType.like:
        return Colors.red;
      case NotificationType.comment:
        return Colors.blue;
      case NotificationType.follow:
        return DivineTheme.primaryPurple;
      case NotificationType.mention:
        return Colors.orange;
      case NotificationType.repost:
        return VineTheme.vineGreen;
      case NotificationType.system:
        return Colors.grey;
    }
  }
}
