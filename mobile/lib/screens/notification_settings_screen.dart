// ABOUTME: Settings screen for notification preferences and controls
// ABOUTME: Allows users to customize notification types and behavior

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _followsEnabled = true;
  bool _mentionsEnabled = true;
  bool _repostsEnabled = true;
  bool _systemEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VineTheme.backgroundColor,
    appBar: AppBar(
      backgroundColor: VineTheme.vineGreen,
      foregroundColor: VineTheme.whiteText,
      elevation: 0,
      title: const Text(
        'Notification Settings',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() {
              _likesEnabled = true;
              _commentsEnabled = true;
              _followsEnabled = true;
              _mentionsEnabled = true;
              _repostsEnabled = true;
              _systemEnabled = true;
              _pushNotificationsEnabled = true;
              _soundEnabled = true;
              _vibrationEnabled = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings reset to defaults'),
                duration: Duration(seconds: 2),
                backgroundColor: VineTheme.vineGreen,
              ),
            );
          },
        ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Notification Types Section
            _buildSectionHeader('Notification Types'),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.favorite,
              iconColor: VineTheme.likeRed,
              title: 'Likes',
              subtitle: 'When someone likes your videos',
              value: _likesEnabled,
              onChanged: (value) => setState(() => _likesEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.chat_bubble,
              iconColor: VineTheme.commentBlue,
              title: 'Comments',
              subtitle: 'When someone comments on your videos',
              value: _commentsEnabled,
              onChanged: (value) => setState(() => _commentsEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.person_add,
              iconColor: VineTheme.vineGreen,
              title: 'Follows',
              subtitle: 'When someone follows you',
              value: _followsEnabled,
              onChanged: (value) => setState(() => _followsEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.alternate_email,
              iconColor: Colors.orange,
              title: 'Mentions',
              subtitle: 'When you are mentioned',
              value: _mentionsEnabled,
              onChanged: (value) => setState(() => _mentionsEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.repeat,
              iconColor: VineTheme.vineGreenLight,
              title: 'Reposts',
              subtitle: 'When someone reposts your videos',
              value: _repostsEnabled,
              onChanged: (value) => setState(() => _repostsEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.phone_android,
              iconColor: VineTheme.lightText,
              title: 'System',
              subtitle: 'App updates and system messages',
              value: _systemEnabled,
              onChanged: (value) => setState(() => _systemEnabled = value),
            ),

            const SizedBox(height: 24),

            // Push Notification Settings
            _buildSectionHeader('Push Notifications'),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.notifications,
              iconColor: VineTheme.vineGreen,
              title: 'Push Notifications',
              subtitle: 'Receive notifications when app is closed',
              value: _pushNotificationsEnabled,
              onChanged: (value) =>
                  setState(() => _pushNotificationsEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.volume_up,
              iconColor: VineTheme.commentBlue,
              title: 'Sound',
              subtitle: 'Play sound for notifications',
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.vibration,
              iconColor: VineTheme.vineGreen,
              title: 'Vibration',
              subtitle: 'Vibrate for notifications',
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
            ),

            const SizedBox(height: 24),

            // Actions
            _buildSectionHeader('Actions'),
            const SizedBox(height: 8),

            Builder(
              builder: (context) {
                final service = ref.watch(notificationServiceEnhancedProvider);
                return Column(
                  children: [
                    _buildActionCard(
                      icon: Icons.check_circle,
                      iconColor: VineTheme.vineGreenLight,
                      title: 'Mark All as Read',
                      subtitle: 'Mark all notifications as read',
                      onTap: () async {
                        await service.markAllAsRead();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All notifications marked as read'),
                              duration: Duration(seconds: 2),
                              backgroundColor: VineTheme.vineGreen,
                            ),
                          );
                        }
                      },
                    ),
                    _buildActionCard(
                      icon: Icons.delete_sweep,
                      iconColor: VineTheme.likeRed,
                      title: 'Clear Old Notifications',
                      subtitle: 'Remove notifications older than 30 days',
                      onTap: () async {
                        await service.clearOlderThan(const Duration(days: 30));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Old notifications cleared'),
                              duration: Duration(seconds: 2),
                              backgroundColor: VineTheme.vineGreen,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Info Section
            _buildInfoCard(),
          ],
        ),
      ),
    ),
  );

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: VineTheme.primaryText,
    ),
  );

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Card(
    color: VineTheme.cardBackground,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: VineTheme.primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: VineTheme.vineGreen,
      ),
    ),
  );

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Card(
    color: VineTheme.cardBackground,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: VineTheme.primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: VineTheme.lightText,
        size: 16,
      ),
      onTap: onTap,
    ),
  );

  Widget _buildInfoCard() => Card(
    color: VineTheme.cardBackground,
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: VineTheme.commentBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'About Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: VineTheme.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.',
            style: TextStyle(
              fontSize: 13,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}
