// ABOUTME: Unified settings hub providing access to all app configuration
// ABOUTME: Central entry point for profile, relay, media server, and notification settings

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
// import 'package:openvine/screens/p2p_sync_screen.dart'; // Hidden for release
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/camera_fab.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final isAuthenticated = authService.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      backgroundColor: Colors.black,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
          // Profile Section
          if (isAuthenticated) ...[
            _buildSectionHeader('Profile'),
            _buildSettingsTile(
              context,
              icon: Icons.person,
              title: 'Edit Profile',
              subtitle: 'Update your display name, bio, and avatar',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ProfileSetupScreen(isNewUser: false),
                ),
              ),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.key,
              title: 'Key Management',
              subtitle: 'Export, backup, and restore your Nostr keys',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KeyManagementScreen(),
                ),
              ),
            ),
          ],

          // Network Configuration
          _buildSectionHeader('Network'),
          _buildSettingsTile(
            context,
            icon: Icons.hub,
            title: 'Relays',
            subtitle: 'Manage Nostr relay connections',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RelaySettingsScreen(),
              ),
            ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.troubleshoot,
            title: 'Relay Diagnostics',
            subtitle: 'Debug relay connectivity and network issues',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RelayDiagnosticScreen(),
              ),
            ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.cloud_upload,
            title: 'Media Servers',
            subtitle: 'Configure Blossom upload servers',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BlossomSettingsScreen(),
              ),
            ),
          ),
          // P2P Sync hidden for release - not ready for production
          // _buildSettingsTile(
          //   context,
          //   icon: Icons.sync,
          //   title: 'P2P Sync',
          //   subtitle: 'Peer-to-peer synchronization settings',
          //   onTap: () => Navigator.push(
          //     context,
          //     MaterialPageRoute(
          //       builder: (context) => const P2PSyncScreen(),
          //     ),
          //   ),
          // ),

          // Preferences
          _buildSectionHeader('Preferences'),
          _buildSettingsTile(
            context,
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationSettingsScreen(),
              ),
            ),
          ),

          // Support
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            context,
            icon: Icons.bug_report,
            title: 'Report a Bug',
            subtitle: 'Send diagnostic info to help improve the app',
            onTap: () {
              final bugReportService = ref.read(bugReportServiceProvider);
              final userPubkey = authService.currentPublicKeyHex;

              showDialog(
                context: context,
                builder: (context) => BugReportDialog(
                  bugReportService: bugReportService,
                  currentScreen: 'SettingsScreen',
                  userPubkey: userPubkey,
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.save,
            title: 'Save Logs',
            subtitle: 'Export logs to file for manual sending',
            onTap: () async {
              final bugReportService = ref.read(bugReportServiceProvider);
              final userPubkey = authService.currentPublicKeyHex;

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exporting logs...'),
                  duration: Duration(seconds: 2),
                ),
              );

              final success = await bugReportService.exportLogsToFile(
                currentScreen: 'SettingsScreen',
                userPubkey: userPubkey,
              );

              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to export logs'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: VineTheme.vineGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: VineTheme.vineGreen),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      );
}