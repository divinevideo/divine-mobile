// ABOUTME: Screen for managing Nostr relay connections and settings
// ABOUTME: Allows users to add, remove, and configure external relay preferences

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/camera_fab.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for managing Nostr relay settings
class RelaySettingsScreen extends ConsumerStatefulWidget {
  const RelaySettingsScreen({super.key});

  @override
  ConsumerState<RelaySettingsScreen> createState() =>
      _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends ConsumerState<RelaySettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final externalRelays = nostrService.relays;

    Log.info('Displaying ${externalRelays.length} external relays',
        name: 'RelaySettingsScreen');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relay Settings'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Info banner with instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Divine is an open system - you control your connections',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These external relays sync with your embedded relay to distribute your content across the decentralized Nostr network. You can add or remove relays as you wish.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _launchNostrDocs(),
                  child: Text(
                    'Learn more about Nostr →',
                    style: TextStyle(
                      color: VineTheme.vineGreen,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Relay list
          Expanded(
            child: externalRelays.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off,
                            color: Colors.grey[600], size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No external relays configured',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add relays to sync your content',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddRelayDialog(),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Add Relay',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VineTheme.vineGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Action buttons at the top
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddRelayDialog(),
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text('Add Relay',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VineTheme.vineGreen,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _retryConnection(),
                                icon:
                                    const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Retry',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: externalRelays.length,
                          itemBuilder: (context, index) {
                            final relay = externalRelays[index];

                            return ListTile(
                              leading: Icon(
                                Icons.cloud,
                                color: Colors.green[400],
                                size: 20,
                              ),
                              title: Text(
                                relay,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'External relay',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeRelay(relay),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: const CameraFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: VineBottomNav(),
    );
  }

  Future<void> _removeRelay(String relayUrl) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Remove Relay?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove this relay?\n\n$relayUrl',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.removeRelay(relayUrl);

      // Force UI refresh by invalidating the provider
      ref.invalidate(nostrServiceProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed relay: $relayUrl'),
            backgroundColor: Colors.orange[700],
          ),
        );
      }

      Log.info('Successfully removed relay: $relayUrl',
          name: 'RelaySettingsScreen');
    } catch (e) {
      Log.error('Failed to remove relay: $e', name: 'RelaySettingsScreen');
      _showError('Failed to remove relay: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  Future<void> _retryConnection() async {
    try {
      final nostrService = ref.read(nostrServiceProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retrying relay connections...'),
          backgroundColor: Colors.orange,
        ),
      );

      await nostrService.retryInitialization();

      // Check if any relays are now connected
      final connectedCount = nostrService.connectedRelayCount;

      if (connectedCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to $connectedCount relay(s)!'),
              backgroundColor: Colors.green[700],
            ),
          );
        }

        // Trigger a refresh of video feeds
        final videoService = ref.read(videoEventServiceProvider);
        await videoService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          replace: true,
        );
      } else {
        _showError(
            'Failed to connect to relays. Please check your network connection.');
      }
    } catch (e) {
      Log.error('Failed to retry connection: $e', name: 'RelaySettingsScreen');
      _showError('Connection retry failed: ${e.toString()}');
    }
  }

  Future<void> _showAddRelayDialog() async {
    final controller = TextEditingController();

    final relayUrl = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Add Relay',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the WebSocket URL of the relay you want to add:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'wss://relay.example.com',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: VineTheme.vineGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.of(dialogContext).pop(url);
              }
            },
            child: const Text(
              'Add',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );

    controller.dispose();

    if (relayUrl == null || relayUrl.isEmpty) return;

    // Validate URL format
    if (!relayUrl.startsWith('wss://') && !relayUrl.startsWith('ws://')) {
      _showError('Relay URL must start with wss:// or ws://');
      return;
    }

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final success = await nostrService.addRelay(relayUrl);

      if (success) {
        // Force UI refresh by invalidating the provider
        ref.invalidate(nostrServiceProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added relay: $relayUrl'),
              backgroundColor: Colors.green[700],
            ),
          );
        }

        Log.info('Successfully added relay: $relayUrl',
            name: 'RelaySettingsScreen');
      } else {
        _showError('Failed to add relay. Please check the URL and try again.');
      }
    } catch (e) {
      Log.error('Failed to add relay: $e', name: 'RelaySettingsScreen');
      _showError('Failed to add relay: ${e.toString()}');
    }
  }

  Future<void> _launchNostrDocs() async {
    final url = Uri.parse('https://nostr.com');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open browser');
      }
    } catch (e) {
      Log.error('Failed to launch URL: $e', name: 'RelaySettingsScreen');
      _showError('Failed to open link');
    }
  }
}
