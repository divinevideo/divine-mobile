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
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

              // Account Section (only show when authenticated)
              if (isAuthenticated) ...[
                _buildSectionHeader('Account'),
                _buildSettingsTile(
                  context,
                  icon: Icons.logout,
                  title: 'Log Out',
                  subtitle: 'Sign out of your account (keeps your keys)',
                  onTap: () => _handleLogout(context, ref),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.key_off,
                  title: 'Remove Keys from Device',
                  subtitle:
                      'Delete your nsec from this device (content stays on relays)',
                  onTap: () => _handleRemoveKeys(context, ref),
                  iconColor: Colors.orange,
                  titleColor: Colors.orange,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.delete_forever,
                  title: 'Delete Account and Data',
                  subtitle:
                      'PERMANENTLY delete your account and all content from Nostr relays',
                  onTap: () => _handleDeleteAllContent(context, ref),
                  iconColor: Colors.red,
                  titleColor: Colors.red,
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
              _buildSettingsTile(
                context,
                icon: Icons.shield,
                title: 'Safety & Privacy',
                subtitle: 'Blocked users, muted content, and report history',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SafetySettingsScreen(),
                  ),
                ),
              ),

              // Support
              _buildSectionHeader('Support'),
              _buildSettingsTile(
                context,
                icon: Icons.verified_user,
                title: 'ProofMode Info',
                subtitle: 'Learn about ProofMode verification and authenticity',
                onTap: () => _openProofModeInfo(context),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.support_agent,
                title: 'Contact Support',
                subtitle: 'Get help or report an issue',
                onTap: () async {
                  // Try Zendesk first, fallback to email if not available
                  if (ZendeskSupportService.isAvailable) {
                    final success =
                        await ZendeskSupportService.showNewTicketScreen(
                          subject: 'Support Request',
                          tags: ['mobile', 'support'],
                        );

                    if (!success && context.mounted) {
                      // Zendesk failed, show fallback options
                      _showSupportFallback(context, ref, authService);
                    }
                  } else {
                    // Zendesk not available, show fallback options
                    if (context.mounted) {
                      _showSupportFallback(context, ref, authService);
                    }
                  }
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
    Color? iconColor,
    Color? titleColor,
  }) => ListTile(
    leading: Icon(icon, color: iconColor ?? VineTheme.vineGreen),
    title: Text(
      title,
      style: TextStyle(
        color: titleColor ?? Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: Colors.grey, fontSize: 14),
    ),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    onTap: onTap,
  );

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Log Out?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: const Text(
          'Are you sure you want to log out? Your keys will be saved and you can log back in later.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Sign out (keeps keys for re-login)
    // Router will automatically redirect to /welcome when auth state becomes unauthenticated
    await authService.signOut(deleteKeys: false);
  }

  /// Handle removing keys from device only (no relay broadcast)
  Future<void> _handleRemoveKeys(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

    // Show warning dialog
    await showRemoveKeysWarningDialog(
      context: context,
      onConfirm: () async {
        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        );

        try {
          // Sign out and delete keys (no relay broadcast)
          await authService.signOut(deleteKeys: true);

          // Close loading indicator
          if (!context.mounted) return;
          Navigator.of(context).pop();

          // Show success message
          // Router will automatically redirect to /welcome when auth state becomes unauthenticated
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Keys removed from device. Your content remains on Nostr relays.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
        } catch (e) {
          // Close loading indicator
          if (!context.mounted) return;
          Navigator.of(context).pop();

          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to remove keys: $e',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  /// Handle deleting ALL content from Nostr relays (nuclear option)
  Future<void> _handleDeleteAllContent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);

    // Show double-confirmation warning dialogs
    await showDeleteAllContentWarningDialog(
      context: context,
      onConfirm: () async {
        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        );

        // Execute NIP-62 deletion request
        final result = await deletionService.deleteAccount();

        // Close loading indicator
        if (!context.mounted) return;
        Navigator.of(context).pop();

        if (result.success) {
          // Sign out and delete keys
          // Router will automatically redirect to /welcome when auth state becomes unauthenticated
          await authService.signOut(deleteKeys: true);

          // Show completion dialog
          if (!context.mounted) return;
          await showDeleteAccountCompletionDialog(
            context: context,
            onCreateNewAccount: () => Navigator.of(context).pop(),
          );
        } else {
          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error ?? 'Failed to delete content from relays',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  /// Open ProofMode info page at divine.video/proofmode
  Future<void> _openProofModeInfo(BuildContext context) async {
    final url = Uri.parse('https://divine.video/proofmode');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open ProofMode info page'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show fallback support options when Zendesk is not available
  void _showSupportFallback(
    BuildContext context,
    WidgetRef ref,
    dynamic authService, // Type inferred from authServiceProvider
  ) {
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
  }
}
