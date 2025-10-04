// ABOUTME: Notifications screen displaying user's social interactions and system updates
// ABOUTME: Shows likes, comments, follows, mentions, reposts with filtering and read state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/screens/profile_screen_scrollable.dart';
import 'package:openvine/theme/app_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/notification_list_item.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NotificationType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Builder(
            builder: (context) {
              final service = ref.watch(notificationServiceEnhancedProvider);
              if (service.notifications.isEmpty) return const SizedBox.shrink();

              return PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onSelected: (value) async {
                  if (value == 'mark_all_read') {
                    await service.markAllAsRead();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications marked as read'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (value == 'clear_all') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear All Notifications?'),
                        content: const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await service.clearAll();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All notifications cleared'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Text('Clear all'),
                  ),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: DivineTheme.primaryPurple,
          labelColor: DivineTheme.primaryPurple,
          unselectedLabelColor: isDarkMode ? Colors.grey : Colors.grey[600],
          onTap: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _selectedFilter = null;
                case 1:
                  _selectedFilter = NotificationType.like;
                case 2:
                  _selectedFilter = NotificationType.comment;
                case 3:
                  _selectedFilter = NotificationType.follow;
                case 4:
                  _selectedFilter = NotificationType.repost;
              }
            });
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Likes'),
            Tab(text: 'Comments'),
            Tab(text: 'Follows'),
            Tab(text: 'Reposts'),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          final service = ref.watch(notificationServiceEnhancedProvider);
          // Filter notifications based on selected tab
          final notifications = _selectedFilter == null
              ? service.notifications
              : service.getNotificationsByType(_selectedFilter!);

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == null
                        ? 'No notifications yet'
                        : 'No ${_getFilterName(_selectedFilter!)} notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "When people interact with your content,\nyou'll see it here",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // TODO: Implement refresh logic
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final showDateHeader = _shouldShowDateHeader(
                  index,
                  notifications,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          _getDateHeader(notification.timestamp),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    NotificationListItem(
                      notification: notification,
                      onTap: () async {
                        // Mark as read
                        await service.markAsRead(notification.id);

                        // Navigate to appropriate screen based on type
                        if (context.mounted) {
                          _navigateToTarget(context, notification);
                        }
                      },
                    ),
                    if (index < notifications.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        indent: 72,
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _getFilterName(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return 'like';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.mention:
        return 'mention';
      case NotificationType.repost:
        return 'repost';
      case NotificationType.system:
        return 'system';
    }
  }

  bool _shouldShowDateHeader(int index, List<NotificationModel> notifications) {
    if (index == 0) return true;

    final current = notifications[index];
    final previous = notifications[index - 1];

    final currentDate = DateTime(
      current.timestamp.year,
      current.timestamp.month,
      current.timestamp.day,
    );

    final previousDate = DateTime(
      previous.timestamp.year,
      previous.timestamp.month,
      previous.timestamp.day,
    );

    return currentDate != previousDate;
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToTarget(BuildContext context, NotificationModel notification) {
    Log.info(
      '🔔 Notification clicked: ${notification.navigationAction} -> ${notification.navigationTarget}',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

    switch (notification.navigationAction) {
      case 'open_video':
        if (notification.navigationTarget != null) {
          _navigateToVideo(context, notification.navigationTarget!);
        }
        break;
      case 'open_profile':
        if (notification.navigationTarget != null) {
          _navigateToProfile(context, notification.navigationTarget!);
        }
        break;
      case 'none':
        // System notifications don't need navigation
        break;
      default:
        Log.warning(
          'Unknown navigation action: ${notification.navigationAction}',
          name: 'NotificationsScreen',
          category: LogCategory.ui,
        );
    }
  }

  void _navigateToVideo(BuildContext context, String videoEventId) {
    Log.info('Navigating to video: $videoEventId',
        name: 'NotificationsScreen', category: LogCategory.ui);

    // Get video from video event service (search all feed types)
    final videoEventService = ref.read(videoEventServiceProvider);

    // Try to find video in discovery videos first, then other feeds
    final allVideos = [
      ...videoEventService.discoveryVideos,
      ...videoEventService.homeFeedVideos,
      ...videoEventService.profileVideos,
    ];

    final video = allVideos.cast().firstWhere(
          (v) => v != null && v.id == videoEventId,
          orElse: () => null,
        );

    if (video == null) {
      // Video not found, show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video not found'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to video player with this specific video
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExploreVideoScreenPure(
          startingVideo: video,
          videoList: [video],
          contextTitle: 'From Notification',
          startingIndex: 0,
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userPubkey) {
    Log.info('Navigating to profile: $userPubkey',
        name: 'NotificationsScreen', category: LogCategory.ui);

    // Navigate to profile screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileScreenScrollable(profilePubkey: userPubkey),
      ),
    );
  }
}
