// ABOUTME: Navigation drawer providing access to settings, relays, bug reports and other app options
// ABOUTME: Reusable sidebar menu that appears from the top right on all main screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
// import 'package:openvine/screens/p2p_sync_screen.dart'; // Hidden for release
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Launch a URL in the external browser
  Future<void> _launchWebPage(
    BuildContext context,
    String urlString,
    String pageName,
  ) async {
    final url = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open $pageName'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening $pageName: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              padding: EdgeInsets.fromLTRB(
                20,
                20 + MediaQuery.of(context).padding.top,
                20,
                20,
              ),
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
                        print(
                          '🔍 NAV DEBUG: VineDrawer.Edit Profile - about to push /edit-profile',
                        );
                        print(
                          '🔍 NAV DEBUG: Current location: ${GoRouterState.of(context).uri}',
                        );
                        context
                          ..pop()
                          ..push('/edit-profile');
                        print('🔍 NAV DEBUG: Returned from push /edit-profile');
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
                      context
                        ..pop()
                        ..push('/settings');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.hub,
                    title: 'Relays',
                    subtitle: 'Manage Nostr relay connections',
                    onTap: () {
                      disposeAllVideoControllers(ref);
                      context
                        ..pop()
                        ..push('/relay-settings');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.cloud_upload,
                    title: 'Media Servers',
                    subtitle: 'Configure Blossom upload servers',
                    onTap: () {
                      disposeAllVideoControllers(ref);
                      context
                        ..pop()
                        ..push('/blossom-settings');
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
                      disposeAllVideoControllers(ref);
                      context
                        ..pop()
                        ..push('/notification-settings');
                    },
                  ),

                  const Divider(color: Colors.grey, height: 1),

                  // Support section
                  _buildSectionHeader('Support'),
                  _buildDrawerItem(
                    icon: Icons.support_agent,
                    title: 'Contact Support',
                    subtitle: 'Get help or report an issue',
                    onTap: () async {
                      print('🎫 Contact Support tapped');

                      // Check Zendesk availability BEFORE closing drawer
                      final isZendeskAvailable =
                          ZendeskSupportService.isAvailable;
                      print('🔍 Zendesk available: $isZendeskAvailable');

                      // CRITICAL: Capture provider values BEFORE closing drawer
                      // to avoid "ref unmounted" error when dialog buttons are tapped
                      final bugReportService = ref.read(
                        bugReportServiceProvider,
                      );
                      final userPubkey = authService.currentPublicKeyHex;

                      // Get root context before closing drawer
                      final rootContext = context;

                      context.pop(); // Close drawer

                      // Wait for drawer close animation
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (!rootContext.mounted) {
                        print('⚠️ Context not mounted after drawer close');
                        return;
                      }

                      // Show support options dialog using root context
                      // Pass captured services instead of ref
                      _showSupportOptionsDialog(
                        rootContext,
                        bugReportService,
                        userPubkey,
                        isZendeskAvailable,
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.save,
                    title: 'Save Logs',
                    subtitle: 'Export logs to file for manual sending',
                    onTap: () async {
                      context.pop(); // Close drawer

                      // Wait for drawer close animation to complete
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (!context.mounted) return;

                      final bugReportService = ref.read(
                        bugReportServiceProvider,
                      );
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

                  const Divider(color: Colors.grey, height: 1),

                  // Legal & Safety section
                  _buildSectionHeader('Legal & Safety'),
                  _buildDrawerItem(
                    icon: Icons.privacy_tip,
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    onTap: () {
                      context.pop(); // Close drawer
                      _launchWebPage(
                        context,
                        'https://divine.video/privacy',
                        'Privacy Policy',
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shield,
                    title: 'Safety Center',
                    subtitle: 'Community safety guidelines',
                    onTap: () {
                      context.pop(); // Close drawer
                      _launchWebPage(
                        context,
                        'https://divine.video/safety',
                        'Safety Center',
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'FAQ',
                    subtitle: 'Frequently asked questions',
                    onTap: () {
                      context.pop(); // Close drawer
                      _launchWebPage(
                        context,
                        'https://divine.video/faq',
                        'FAQ',
                      );
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
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
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
  }) => ListTile(
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
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          )
        : null,
    onTap: onTap,
  );

  /// Show support options dialog
  /// NOTE: bugReportService and userPubkey must be captured BEFORE the drawer
  /// is closed, because ref becomes invalid after widget unmounts.
  void _showSupportOptionsDialog(
    BuildContext context,
    dynamic bugReportService,
    String? userPubkey,
    bool isZendeskAvailable,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'How can we help?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSupportOption(
              context: dialogContext,
              icon: Icons.bug_report,
              title: 'Report a Bug',
              subtitle: 'Technical issues with the app',
              onTap: () {
                dialogContext.pop();
                _handleBugReportWithServices(
                  context,
                  bugReportService,
                  userPubkey,
                  isZendeskAvailable,
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              context: dialogContext,
              icon: Icons.flag,
              title: 'Report Content',
              subtitle: 'Inappropriate videos or users',
              onTap: () {
                dialogContext.pop();
                _handleContentReportWithServices(
                  context,
                  bugReportService,
                  userPubkey,
                  isZendeskAvailable,
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              context: dialogContext,
              icon: Icons.chat,
              title: 'View Past Messages',
              subtitle: 'Check responses from support',
              onTap: () async {
                dialogContext.pop();
                if (isZendeskAvailable) {
                  print('💬 Opening Zendesk ticket list');
                  await ZendeskSupportService.showTicketList();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support chat not available'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              context: dialogContext,
              icon: Icons.help,
              title: 'View FAQ',
              subtitle: 'Common questions & answers',
              onTap: () {
                dialogContext.pop();
                _launchWebPage(context, 'https://divine.video/faq', 'FAQ');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a support option button
  Widget _buildSupportOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VineTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Icon(icon, color: VineTheme.vineGreen, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  /// Handle bug report submission
  Future<void> _handleBugReportWithServices(
    BuildContext context,
    dynamic bugReportService,
    String? userPubkey,
    bool isZendeskAvailable,
  ) async {
    if (isZendeskAvailable) {
      // Get device and app info
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final description =
          '''
Please describe the bug you encountered:

---
App Version: $appVersion
Platform: ${Theme.of(context).platform.name}
''';

      print('🐛 Opening Zendesk for bug report');
      final success = await ZendeskSupportService.showNewTicketScreen(
        subject: 'Bug Report',
        description: description,
        tags: ['mobile', 'bug', 'ios'],
      );

      if (!success && context.mounted) {
        _showSupportFallbackWithServices(context, bugReportService, userPubkey);
      }
    } else {
      _showSupportFallbackWithServices(context, bugReportService, userPubkey);
    }
  }

  /// Handle content report submission
  Future<void> _handleContentReportWithServices(
    BuildContext context,
    dynamic bugReportService,
    String? userPubkey,
    bool isZendeskAvailable,
  ) async {
    if (isZendeskAvailable) {
      final description = '''
Please describe the inappropriate content:

Content Type (video/user/comment):
Link or ID (if available):
Reason for report:

''';

      print('🚩 Opening Zendesk for content report');
      final success = await ZendeskSupportService.showNewTicketScreen(
        subject: 'Content Report',
        description: description,
        tags: ['mobile', 'content-report', 'moderation'],
      );

      if (!success && context.mounted) {
        _showSupportFallbackWithServices(context, bugReportService, userPubkey);
      }
    } else {
      _showSupportFallbackWithServices(context, bugReportService, userPubkey);
    }
  }

  /// Show fallback support options when Zendesk is not available
  void _showSupportFallbackWithServices(
    BuildContext context,
    dynamic bugReportService,
    String? userPubkey,
  ) {
    showDialog(
      context: context,
      builder: (context) => BugReportDialog(
        bugReportService: bugReportService,
        currentScreen: 'VineDrawer',
        userPubkey: userPubkey,
      ),
    );
  }
}
