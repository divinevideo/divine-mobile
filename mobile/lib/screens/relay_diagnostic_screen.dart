// ABOUTME: Diagnostic screen for debugging relay connectivity issues
// ABOUTME: Shows embedded relay status, external relay connections, and network health

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Comprehensive diagnostic screen for relay connectivity debugging
class RelayDiagnosticScreen extends ConsumerStatefulWidget {
  const RelayDiagnosticScreen({super.key});

  @override
  ConsumerState<RelayDiagnosticScreen> createState() =>
      _RelayDiagnosticScreenState();
}

class _RelayDiagnosticScreenState extends ConsumerState<RelayDiagnosticScreen> {
  Map<String, dynamic>? _relayStats;
  Map<String, String> _networkTests = {};
  bool _isTestingNetwork = false;
  bool _isRetrying = false;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _refreshDiagnostics();
  }

  Future<void> _refreshDiagnostics() async {
    setState(() {
      _lastRefresh = DateTime.now();
    });

    final nostrService = ref.read(nostrServiceProvider);

    // Get relay stats from embedded relay
    try {
      final stats = await nostrService.getRelayStats();
      setState(() {
        _relayStats = stats;
      });

      // Check if there are video events in the database
      if (stats != null && stats['database'] != null) {
        final totalEvents = stats['database']['total_events'] ?? 0;
        Log.info(
          'Embedded relay has $totalEvents total events in database',
          name: 'RelayDiagnostic',
        );

        // Query for video events specifically to see if any exist
        try {
          final videoEvents = await nostrService.getEvents(
            filters: [
              nostr.Filter(kinds: [34236]),
            ],
            limit: 10,
          );
          Log.info(
            'Found ${videoEvents.length} video events in embedded relay database',
            name: 'RelayDiagnostic',
          );
        } catch (e) {
          Log.error(
            'Failed to query video events: $e',
            name: 'RelayDiagnostic',
          );
        }
      }
    } catch (e) {
      Log.error('Failed to get relay stats: $e', name: 'RelayDiagnostic');
    }
  }

  Future<void> _testNetworkConnectivity() async {
    setState(() {
      _isTestingNetwork = true;
      _networkTests = {};
    });

    final nostrService = ref.read(nostrServiceProvider);
    final relays = nostrService.relays;

    for (final relayUrl in relays) {
      try {
        // Extract hostname from WebSocket URL
        final uri = Uri.parse(relayUrl);
        final host = uri.host;
        // Use default ports if not explicitly specified (uri.port returns 0 if not set)
        final port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);

        Log.info(
          'Testing connectivity to $host:$port (scheme=${uri.scheme})',
          name: 'RelayDiagnostic',
        );

        // Test TCP connection
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 5),
        );
        stopwatch.stop();
        await socket.close();

        setState(() {
          _networkTests[relayUrl] = 'OK (${stopwatch.elapsedMilliseconds}ms)';
        });

        Log.info(
          '✅ Relay $relayUrl reachable in ${stopwatch.elapsedMilliseconds}ms',
          name: 'RelayDiagnostic',
        );
      } catch (e) {
        setState(() {
          _networkTests[relayUrl] = 'FAILED: ${e.toString()}';
        });

        Log.error('❌ Relay $relayUrl unreachable: $e', name: 'RelayDiagnostic');
      }
    }

    setState(() {
      _isTestingNetwork = false;
    });
  }

  Future<void> _testDirectEventQuery() async {
    Log.info(
      '🔍 Testing direct event query (bypassing subscriptions)...',
      name: 'RelayDiagnostic',
    );

    final nostrService = ref.read(nostrServiceProvider);

    try {
      // Query for video events directly from embedded relay database
      final videoEvents = await nostrService.getEvents(
        filters: [
          nostr.Filter(kinds: [34236], limit: 100),
        ],
        limit: 100,
      );

      Log.info(
        '✅ Direct query returned ${videoEvents.length} video events',
        name: 'RelayDiagnostic',
      );

      if (videoEvents.isNotEmpty) {
        Log.info('📹 Sample events:', name: 'RelayDiagnostic');
        for (var i = 0; i < videoEvents.take(3).length; i++) {
          final event = videoEvents[i];
          Log.info(
            '  Event $i: kind=${event.kind}, author=${event.pubkey}, timestamp=${event.createdAt}',
            name: 'RelayDiagnostic',
          );
        }
      } else {
        Log.warning(
          '⚠️ No video events found in embedded relay database!',
          name: 'RelayDiagnostic',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${videoEvents.length} video events in database',
            ),
            backgroundColor: videoEvents.isNotEmpty
                ? Colors.green[700]
                : Colors.orange[700],
          ),
        );
      }
    } catch (e) {
      Log.error('❌ Direct query failed: $e', name: 'RelayDiagnostic');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Query failed: ${e.toString()}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _retryConnection() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);

      Log.info('Retrying relay connections...', name: 'RelayDiagnostic');

      await nostrService.retryInitialization();

      // Wait a bit for connections to establish
      await Future.delayed(const Duration(seconds: 2));

      // Refresh diagnostics
      await _refreshDiagnostics();

      // Check if any relays connected
      final connectedCount = nostrService.connectedRelayCount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              connectedCount > 0
                  ? 'Connected to $connectedCount relay(s)!'
                  : 'Failed to connect to any relays',
            ),
            backgroundColor: connectedCount > 0
                ? Colors.green[700]
                : Colors.red[700],
          ),
        );
      }

      // Trigger feed refresh if connected
      if (connectedCount > 0) {
        final videoService = ref.read(videoEventServiceProvider);
        await videoService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          replace: true,
        );
      }
    } catch (e) {
      Log.error('Failed to retry connection: $e', name: 'RelayDiagnostic');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection retry failed: ${e.toString()}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final videoService = ref.watch(videoEventServiceProvider);

    final configuredRelays = nostrService.relays;
    final connectedRelays = nostrService.connectedRelays;
    final relayStatuses = nostrService.relayStatuses;

    // Count events in different feeds
    final homeFeedCount = videoService.homeFeedVideos.length;
    final discoveryCount = videoService.discoveryVideos.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Relay Diagnostics'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDiagnostics,
            tooltip: 'Refresh diagnostics',
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
              // Last refresh time
              if (_lastRefresh != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Last refresh: ${_formatTime(_lastRefresh!)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Embedded relay status
              _buildSection(
                title: 'Embedded Relay',
                icon: Icons.storage,
                children: [
                  _buildStatusRow(
                    'Initialized',
                    nostrService.isInitialized,
                    nostrService.isInitialized ? 'Ready' : 'Not initialized',
                  ),
                  if (_relayStats != null) ...[
                    _buildInfoRow(
                      'Database Events',
                      _relayStats!['database']?['total_events']?.toString() ??
                          'N/A',
                    ),
                    _buildInfoRow(
                      'Active Subscriptions',
                      _relayStats!['subscriptions']?['active_count']
                              ?.toString() ??
                          'N/A',
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // External relays status
              _buildSection(
                title: 'External Relays',
                icon: Icons.cloud,
                children: [
                  _buildInfoRow(
                    'Configured',
                    '${configuredRelays.length} relay(s)',
                  ),
                  _buildInfoRow(
                    'Connected',
                    '${connectedRelays.length}/${configuredRelays.length}',
                  ),
                  const Divider(color: Colors.grey),
                  ...configuredRelays.map((relayUrl) {
                    final isConnected = connectedRelays.contains(relayUrl);
                    final status =
                        relayStatuses[relayUrl] as Map<String, dynamic>?;
                    return _buildRelayRow(
                      relayUrl,
                      isConnected,
                      status?['authenticated'] ?? false,
                    );
                  }).toList(),
                ],
              ),

              const SizedBox(height: 16),

              // Video events status
              _buildSection(
                title: 'Video Events',
                icon: Icons.video_library,
                children: [
                  _buildInfoRow('Home Feed', '$homeFeedCount videos'),
                  _buildInfoRow('Discovery', '$discoveryCount videos'),
                  _buildInfoRow(
                    'Loading',
                    videoService.isLoading ? 'Yes' : 'No',
                  ),
                  if (videoService.error != null)
                    _buildErrorRow('Error', videoService.error!),
                  const Divider(color: Colors.grey),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _testDirectEventQuery,
                      icon: const Icon(Icons.search, color: Colors.white),
                      label: const Text(
                        'Test Direct Query',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VineTheme.vineGreen,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Network connectivity test
              _buildSection(
                title: 'Network Connectivity',
                icon: Icons.network_check,
                children: [
                  if (_networkTests.isEmpty && !_isTestingNetwork)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _testNetworkConnectivity,
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text(
                          'Run Network Test',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                        ),
                      ),
                    ),
                  if (_isTestingNetwork)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            VineTheme.vineGreen,
                          ),
                        ),
                      ),
                    ),
                  if (_networkTests.isNotEmpty)
                    ..._networkTests.entries.map((entry) {
                      final isOk = entry.value.startsWith('OK');
                      return _buildInfoRow(
                        entry.key,
                        entry.value,
                        textColor: isOk ? Colors.green : Colors.red,
                      );
                    }).toList(),
                ],
              ),

              const SizedBox(height: 24),

              // Retry connection button
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _retryConnection,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  _isRetrying ? 'Retrying...' : 'Retry Connection',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Troubleshooting',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Green status = Connected and working\n'
                      '• Red status = Connection failed\n'
                      '• If network test fails, check internet connection\n'
                      '• If relays are configured but not connected, tap "Retry Connection"\n'
                      '• Screenshot this screen for debugging',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isOk, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value,
            style: TextStyle(
              color: isOk ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRow(String label, String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[900]?.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayRow(
    String relayUrl,
    bool isConnected,
    bool isAuthenticated,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.cloud_done : Icons.cloud_off,
                color: isConnected ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  relayUrl,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              isConnected
                  ? (isAuthenticated
                        ? 'Connected & Authenticated'
                        : 'Connected')
                  : 'Not connected',
              style: TextStyle(
                color: isConnected ? Colors.green[300] : Colors.red[300],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
