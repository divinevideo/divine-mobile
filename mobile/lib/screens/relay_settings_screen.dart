// ABOUTME: Screen for managing Nostr relay connections and settings
// ABOUTME: Allows users to add, remove, and configure external relay preferences

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for managing Nostr relay settings
class RelaySettingsScreen extends ConsumerStatefulWidget {
  const RelaySettingsScreen({super.key});

  @override
  ConsumerState<RelaySettingsScreen> createState() =>
      _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends ConsumerState<RelaySettingsScreen> {
  late RelayGatewaySettings _gatewaySettings;
  bool _gatewayEnabled = true;
  final Map<String, RelayCapabilities?> _capabilitiesCache = {};
  final Map<String, bool> _capabilitiesLoading = {};

  @override
  void initState() {
    super.initState();
    _initGatewaySettings();
  }

  Future<void> _initGatewaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    _gatewaySettings = RelayGatewaySettings(prefs);
    setState(() {
      _gatewayEnabled = _gatewaySettings.isEnabled;
    });
  }

  Future<void> _fetchCapabilities(String relayUrl) async {
    if (_capabilitiesLoading[relayUrl] == true) return;
    if (_capabilitiesCache.containsKey(relayUrl)) return;

    setState(() {
      _capabilitiesLoading[relayUrl] = true;
    });

    try {
      final capabilityService = ref.read(relayCapabilityServiceProvider);
      final capabilities = await capabilityService.getRelayCapabilities(
        relayUrl,
      );
      if (mounted) {
        setState(() {
          _capabilitiesCache[relayUrl] = capabilities;
          _capabilitiesLoading[relayUrl] = false;
        });
      }
    } catch (e) {
      Log.debug(
        'Failed to fetch NIP-11 for $relayUrl: $e',
        name: 'RelaySettingsScreen',
      );
      if (mounted) {
        setState(() {
          _capabilitiesCache[relayUrl] = null;
          _capabilitiesLoading[relayUrl] = false;
        });
      }
    }
  }

  Future<void> _openRelayWebsite(String relayUrl) async {
    final httpUrl = relayUrl
        .replaceFirst('wss://', 'https://')
        .replaceFirst('ws://', 'http://');
    final url = Uri.parse(httpUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open browser');
      }
    } catch (e) {
      Log.error('Failed to launch relay URL: $e', name: 'RelaySettingsScreen');
      _showError('Failed to open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final externalRelays = nostrService.relays;

    Log.info(
      'Displaying ${externalRelays.length} external relays',
      name: 'RelaySettingsScreen',
    );

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
                          fontWeight: FontWeight.w500,
                        ),
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
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _launchNostrWatch(),
                  child: Text(
                    'Find public relays at nostr.watch →',
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

          // Gateway toggle section (only visible when divine relay configured)
          _buildGatewaySection(externalRelays),

          // Relay list
          Expanded(
            child: externalRelays.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.orange[700],
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'App Not Functional',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Divine requires at least one relay to load videos, post content, and sync data.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => _restoreDefaultRelay(),
                          icon: const Icon(Icons.restore, color: Colors.white),
                          label: const Text(
                            'Restore Default Relay',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VineTheme.vineGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAddRelayDialog(),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Add Custom Relay',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
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
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Add Relay',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VineTheme.vineGreen,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _retryConnection(),
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Retry',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
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

                            return _buildRelayTile(relay);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewaySection(List<String> relays) {
    // Only show when divine relay is configured
    if (!RelayGatewaySettings.isDivineRelayConfigured(relays)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: VineTheme.vineGreen, size: 20),
              const SizedBox(width: 8),
              const Text(
                'REST Gateway',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                key: const Key('gateway_toggle'),
                value: _gatewayEnabled,
                activeTrackColor: VineTheme.vineGreen,
                onChanged: (value) async {
                  await _gatewaySettings.setEnabled(value);
                  setState(() {
                    _gatewayEnabled = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Use caching gateway for faster loading of discovery feeds, hashtags, and profiles.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Only available when using relay.divine.video',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayTile(String relayUrl) {
    // Watch the stream provider to get reactive updates when statistics change
    final statsAsync = ref.watch(relayStatisticsStreamProvider);
    final stats = statsAsync.whenData((allStats) => allStats[relayUrl]).value;

    final isConnected = stats?.isConnected ?? false;
    final statusSummary = stats?.statusSummary ?? 'External relay';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(
          isConnected ? Icons.cloud_done : Icons.cloud_off,
          color: isConnected ? Colors.green[400] : Colors.orange[400],
          size: 20,
        ),
        title: Text(
          relayUrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          statusSummary,
          style: TextStyle(
            color: isConnected ? Colors.grey[500] : Colors.orange[300],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _removeRelay(relayUrl),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: Colors.grey, size: 20),
          ],
        ),
        iconColor: Colors.grey,
        collapsedIconColor: Colors.grey,
        onExpansionChanged: (expanded) {
          if (expanded) {
            _fetchCapabilities(relayUrl);
          }
        },
        children: [_buildRelayDetails(stats, relayUrl)],
      ),
    );
  }

  Widget _buildRelayDetails(RelayStatistics? stats, String relayUrl) {
    if (stats == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No statistics available yet',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }

    final capabilities = _capabilitiesCache[relayUrl];
    final isLoading = _capabilitiesLoading[relayUrl] ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(
            'Connection',
            stats.isConnected ? 'Connected' : 'Disconnected',
            stats.isConnected ? Colors.green[400]! : Colors.orange[400]!,
          ),
          if (stats.sessionDuration != null)
            _buildStatRow(
              'Session Duration',
              _formatDuration(stats.sessionDuration!),
              Colors.grey[400]!,
            ),
          if (stats.lastConnected != null)
            _buildStatRow(
              'Last Connected',
              _formatTime(stats.lastConnected!),
              Colors.grey[400]!,
            ),
          if (!stats.isConnected && stats.lastDisconnected != null)
            _buildStatRow(
              'Disconnected',
              _formatTime(stats.lastDisconnected!),
              Colors.orange[400]!,
            ),
          if (stats.lastDisconnectReason != null && !stats.isConnected)
            _buildStatRow(
              'Reason',
              stats.lastDisconnectReason!,
              Colors.orange[400]!,
            ),
          const Divider(color: Colors.grey, height: 16),
          _buildStatRow(
            'Active Subscriptions',
            '${stats.activeSubscriptions}',
            Colors.blue[400]!,
          ),
          _buildStatRow(
            'Total Subscriptions',
            '${stats.totalSubscriptions}',
            Colors.grey[400]!,
          ),
          _buildStatRow(
            'Events Received',
            _formatCount(stats.eventsReceived),
            Colors.green[400]!,
          ),
          _buildStatRow(
            'Events Sent',
            _formatCount(stats.eventsSent),
            Colors.blue[400]!,
          ),
          const Divider(color: Colors.grey, height: 16),
          _buildStatRow(
            'Requests This Session',
            '${stats.requestsThisSession}',
            Colors.grey[400]!,
          ),
          _buildStatRow(
            'Failed Requests',
            '${stats.failedRequests}',
            stats.failedRequests > 0 ? Colors.red[400]! : Colors.grey[400]!,
          ),
          if (stats.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last Error: ${stats.lastError}',
              style: TextStyle(color: Colors.red[300], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (stats.lastErrorTime != null)
              Text(
                _formatTime(stats.lastErrorTime!),
                style: TextStyle(color: Colors.red[200], fontSize: 11),
              ),
          ],
          // NIP-11 Relay Info Section
          _buildRelayInfoSection(relayUrl, capabilities, isLoading),
        ],
      ),
    );
  }

  Widget _buildRelayInfoSection(
    String relayUrl,
    RelayCapabilities? capabilities,
    bool isLoading,
  ) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.grey, height: 24),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.vineGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading relay info...',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ],
      );
    }

    if (capabilities == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.grey, height: 24),
        Text(
          'About Relay',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (capabilities.name != null && capabilities.name!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              capabilities.name!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (capabilities.description != null &&
            capabilities.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              capabilities.description!,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
        if (capabilities.supportedNips.isNotEmpty)
          _buildStatRow(
            'Supported NIPs',
            capabilities.supportedNips.join(', '),
            Colors.grey[400]!,
          ),
        if (capabilities.rawData['software'] != null)
          _buildStatRow(
            'Software',
            _formatSoftwareVersion(capabilities.rawData),
            Colors.grey[400]!,
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openRelayWebsite(relayUrl),
          icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
          label: const Text(
            'View Website',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

  String _formatSoftwareVersion(Map<String, dynamic> rawData) {
    final software = rawData['software'] as String?;
    final version = rawData['version'] as String?;
    if (software == null) return '';
    if (version != null) {
      return '$software v$version';
    }
    return software;
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
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
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.removeRelay(relayUrl);

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed relay: $relayUrl'),
            backgroundColor: Colors.orange[700],
          ),
        );
      }

      Log.info(
        'Successfully removed relay: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    } catch (e) {
      Log.error('Failed to remove relay: $e', name: 'RelaySettingsScreen');
      _showError('Failed to remove relay: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
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
          'Failed to connect to relays. Please check your network connection.',
        );
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
        title: const Text('Add Relay', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the WebSocket URL of the relay you want to add:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchNostrWatch(),
              child: Text(
                'Browse public relays at nostr.watch',
                style: TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
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
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
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

    // Dispose after frame to avoid hot reload issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

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
        if (mounted) {
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added relay: $relayUrl'),
              backgroundColor: Colors.green[700],
            ),
          );
        }

        Log.info(
          'Successfully added relay: $relayUrl',
          name: 'RelaySettingsScreen',
        );
      } else {
        _showError('Failed to add relay. Please check the URL and try again.');
      }
    } catch (e) {
      Log.error('Failed to add relay: $e', name: 'RelaySettingsScreen');
      _showError('Failed to add relay: ${e.toString()}');
    }
  }

  Future<void> _restoreDefaultRelay() async {
    try {
      final nostrService = ref.read(nostrServiceProvider);
      final defaultRelay = AppConstants.defaultRelayUrl;

      final success = await nostrService.addRelay(defaultRelay);

      if (success) {
        if (mounted) {
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restored default relay: $defaultRelay'),
              backgroundColor: Colors.green[700],
            ),
          );
        }

        Log.info('Restored default relay', name: 'RelaySettingsScreen');
      } else {
        _showError(
          'Failed to restore default relay. Please check your network connection.',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to restore default relay: $e',
        name: 'RelaySettingsScreen',
      );
      _showError('Failed to restore default relay: ${e.toString()}');
    }
  }

  Future<void> _launchNostrWatch() async {
    final url = Uri.parse('https://nostr.watch');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open browser');
      }
    } catch (e) {
      Log.error(
        'Failed to launch nostr.watch: $e',
        name: 'RelaySettingsScreen',
      );
      _showError('Failed to open link');
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
