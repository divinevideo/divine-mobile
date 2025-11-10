// ABOUTME: Navigation drawer providing access to settings, relays, bug reports and other app options
// ABOUTME: Reusable sidebar menu that appears from the top right on all main screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
// import 'package:openvine/screens/p2p_sync_screen.dart'; // Hidden for release
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Navigation drawer with app settings and configuration options
class VineDrawer extends ConsumerStatefulWidget {
  const VineDrawer({super.key});

  @override
  ConsumerState<VineDrawer> createState() => _VineDrawerState();
}

class _VineDrawerState extends ConsumerState<VineDrawer> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final isAuthenticated = authService.isAuthenticated;

    return Drawer(
      backgroundColor: VineTheme.backgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 20 + MediaQuery.of(context).padding.top, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [VineTheme.vineGreen, Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Divine logo
                      Image.asset(
                        'assets/icon/White cropped.png',
                        width: constraints.maxWidth * 0.5,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Version $_appVersion',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Profile section
                  if (isAuthenticated) ...[
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: 'Edit Profile',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        context.push('/edit-profile');
                      },
                    ),
                    const Divider(color: Colors.grey, height: 1),
                  ],

                  // Settings section
                  _buildSectionHeader('Configuration'),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      context.push('/settings');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.hub,
                    title: 'Relays',
                    subtitle: 'Manage Nostr relay connections',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RelaySettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.cloud_upload,
                    title: 'Media Servers',
                    subtitle: 'Configure Blossom upload servers',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BlossomSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  // P2P Sync hidden for release - not ready for production
                  // _buildDrawerItem(
                  //   icon: Icons.sync,
                  //   title: 'P2P Sync',
                  //   subtitle: 'Peer-to-peer synchronization',
                  //   onTap: () {
                  //     Navigator.pop(context); // Close drawer
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => const P2PSyncScreen(),
                  //       ),
                  //     );
                  //   },
                  // ),
                  _buildDrawerItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),

                  const Divider(color: Colors.grey, height: 1),

                  // Support section
                  _buildSectionHeader('Support'),
                  _buildDrawerItem(
                    icon: Icons.bug_report,
                    title: 'Report a Bug',
                    subtitle: 'Send diagnostic info to developers',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      final bugReportService =
                          ref.read(bugReportServiceProvider);
                      final userPubkey = authService.currentPublicKeyHex;

                      showDialog(
                        context: context,
                        builder: (context) => BugReportDialog(
                          bugReportService: bugReportService,
                          currentScreen: 'VineDrawer',
                          userPubkey: userPubkey,
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.save,
                    title: 'Save Logs',
                    subtitle: 'Export logs to file for manual sending',
                    onTap: () async {
                      Navigator.pop(context); // Close drawer
                      final bugReportService =
                          ref.read(bugReportServiceProvider);
                      final userPubkey = authService.currentPublicKeyHex;

                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exporting logs...'),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      final success = await bugReportService.exportLogsToFile(
                        currentScreen: 'VineDrawer',
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

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Decentralized video sharing\npowered by Nostr',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: VineTheme.vineGreen, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              )
            : null,
        onTap: onTap,
      );
}
