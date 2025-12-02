// ABOUTME: Notifications screen displaying user's social interactions and system updates
// ABOUTME: Shows likes, comments, follows, mentions, reposts with filtering and read state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';
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
    // AppShell provides the Scaffold and AppBar, so this is just the body content
    return Column(
      children: [
        // Tab bar for filtering notifications
        Container(
          color: VineTheme.cardBackground,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: VineTheme.whiteText,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: VineTheme.whiteText,
            unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
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
        // Notification list
        Expanded(
          child: Builder(
            builder: (context) {
              final service = ref.watch(notificationServiceEnhancedProvider);
              // Filter notifications based on selected tab
              final notifications = _selectedFilter == null
                  ? service.notifications
                  : service.getNotificationsByType(_selectedFilter!);

              if (notifications.isEmpty) {
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == null
                              ? 'No notifications yet'
                              : 'No ${_getFilterName(_selectedFilter!)} notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "When people interact with your content,\nyou'll see it here",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                color: Colors.black,
                child: RefreshIndicator(
                  semanticsLabel: 'checking for new notifications',
                  onRefresh: () async {
                    await service.refreshNotifications();
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
                                  color: Colors.grey[400],
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
                              color: Colors.grey[800],
                              indent: 72,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
    Log.info(
      'Navigating to video: $videoEventId',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

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
          useLocalActiveState:
              true, // Use local state since not using URL routing
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userPubkey) {
    Log.info(
      'Navigating to profile: $userPubkey',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

    // Navigate to profile screen
    context.goProfile(userPubkey, 0);
  }
}
