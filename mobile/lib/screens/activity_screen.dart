// ABOUTME: Activity screen showing user interactions like likes, follows, and comments
// ABOUTME: Displays notifications feed similar to original Vine's activity tab

import 'package:flutter/material.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/models/user_profile.dart' as models;
import 'package:openvine/models/video_event.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/comments_screen.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);

    if (!authService.isAuthenticated) {
      return _buildUnauthenticatedState();
    }

    return Column(
      children: [
        Container(
          color: VineTheme.vineGreen,
          child: TabBar(
            controller: _tabController,
            indicatorColor: VineTheme.whiteText,
            indicatorWeight: 2,
            labelColor: VineTheme.whiteText,
            unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'ALL'),
              Tab(text: 'FOLLOWING'),
              Tab(text: 'YOU'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllActivity(),
              _buildFollowingActivity(),
              _buildPersonalActivity(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnauthenticatedState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outlined, size: 64, color: VineTheme.secondaryText),
        SizedBox(height: 16),
        Text(
          'Sign in to see activity',
          style: TextStyle(
            color: VineTheme.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Connect your Nostr keys to see\nlikes, follows, and comments.',
          style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildAllActivity() {
    final notificationService = ref.watch(notificationServiceEnhancedProvider);
    final notifications = notificationService.notifications;

    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 64,
              color: VineTheme.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'When people interact with your content\nor you follow others, it will show up here.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) => _NotificationItem(
        notification: notifications[index],
        onTap: () => _handleNotificationTap(notifications[index]),
      ),
    );
  }

  Widget _buildFollowingActivity() {
    final socialService = ref.watch(socialServiceProvider);
    final followingPubkeys = socialService.followingPubkeys;

    if (followingPubkeys.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: VineTheme.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              "You're not following anyone",
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Follow some creators to see\ntheir activity here.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final userProfileService = ref.watch(userProfileServiceProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: followingPubkeys.length,
      itemBuilder: (context, index) {
        final pubkey = followingPubkeys[index];
        final profile = userProfileService.getCachedProfile(pubkey);
        return _FollowingItem(
          pubkey: pubkey,
          profile: profile,
          onTap: () => _openUserProfile(pubkey),
        );
      },
    );
  }

  Widget _buildPersonalActivity() {
    final authService = ref.watch(authServiceProvider);
    final videoEventService = ref.watch(videoEventServiceProvider);

    // Get current user's videos
    final userVideos = videoEventService.discoveryVideos
        .where((video) => video.pubkey == authService.currentPublicKeyHex)
        .toList();

    if (userVideos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: VineTheme.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'No videos yet',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first vine to start\nreceiving activity notifications.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userVideos.length,
      itemBuilder: (context, index) {
        final video = userVideos[index];
        return _PersonalVideoItem(
          video: video,
          onTap: () => _openVideo(video, videoEventService),
        );
      },
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (notification.targetEventId != null) {
      // Find the video and navigate to it
      final videoEventService = ref.read(videoEventServiceProvider);
      final video = videoEventService.getVideoEventById(
        notification.targetEventId!,
      );
      if (video != null) {
        // For comment notifications, open comments screen
        // For other notifications (like, repost), open video feed
        if (notification.type == NotificationType.comment) {
          _openComments(video);
        } else {
          _openVideo(video, videoEventService);
        }
      }
    } else {
      // Navigate to user profile
      _openUserProfile(notification.actorPubkey);
    }
  }

  void _openUserProfile(String pubkey) {
    // Navigate to profile tab using GoRouter
    context.goProfile(pubkey, 0);
  }

  void _openComments(VideoEvent video) {
    Log.debug(
      'Opening comments from Activity: ${video.id}...',
      name: 'ActivityScreen',
      category: LogCategory.ui,
    );

    // Navigate to comments screen with the video
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommentsScreen(videoEvent: video),
      ),
    );
  }

  void _openVideo(VideoEvent video, VideoEventService videoEventService) {
    Log.debug(
      'Opening video from Activity: ${video.id}...',
      name: 'ActivityScreen',
      category: LogCategory.ui,
    );
    Log.debug(
      '📱 Video URL: ${video.videoUrl}',
      name: 'ActivityScreen',
      category: LogCategory.ui,
    );
    Log.verbose(
      'Thumbnail URL: ${video.thumbnailUrl}',
      name: 'ActivityScreen',
      category: LogCategory.ui,
    );
    Log.verbose(
      'Title: ${video.title}',
      name: 'ActivityScreen',
      category: LogCategory.ui,
    );

    // Check if video has a valid URL
    if (video.videoUrl?.isEmpty != false) {
      Log.error(
        'Cannot open video - empty or null video URL',
        name: 'ActivityScreen',
        category: LogCategory.ui,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video URL is not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final allVideos = videoEventService.discoveryVideos;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExploreVideoScreenPure(
          startingVideo: video,
          videoList: allVideos,
          contextTitle: 'Activity Video',
          useLocalActiveState:
              true, // Use local state since not using URL routing
        ),
      ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  const _NotificationItem({required this.notification, required this.onTap});
  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(
      notification.actorPubkey,
    );
    final userName = profile?.bestDisplayName ?? 'Unknown User';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatar(imageUrl: profile?.picture, name: userName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile?.nip05 != null &&
                            profile!.nip05!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(notification.timestamp),
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.targetEventId != null)
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(
                    Icons.play_arrow,
                    color: VineTheme.vineGreen,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Removed unused _getNotificationIcon method

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class _FollowingItem extends StatelessWidget {
  const _FollowingItem({
    required this.pubkey,
    required this.onTap,
    this.profile,
  });
  final String pubkey;
  final models.UserProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.grey[900],
    child: ListTile(
      onTap: onTap,
      leading: UserAvatar(
        imageUrl: profile?.picture,
        name: profile?.bestDisplayName,
        size: 40,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile?.bestDisplayName ?? 'Unknown User',
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (profile?.nip05 != null && profile!.nip05!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 10),
            ),
          ],
        ],
      ),
      subtitle: profile?.about != null && profile!.about!.isNotEmpty
          ? Text(
              profile!.about!,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: VineTheme.secondaryText,
        size: 16,
      ),
    ),
  );
}

class _PersonalVideoItem extends StatelessWidget {
  const _PersonalVideoItem({required this.video, required this.onTap});
  final VideoEvent video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.grey[900],
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Video thumbnail placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: VineTheme.vineGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),

            // Video details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (video.title?.isNotEmpty == true)
                        ? video.title!
                        : 'Untitled Video',
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(
                      DateTime.fromMillisecondsSinceEpoch(
                        video.createdAt * 1000,
                      ),
                    ),
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow indicator
            const Icon(
              Icons.arrow_forward_ios,
              color: VineTheme.secondaryText,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
