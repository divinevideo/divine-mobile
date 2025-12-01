// ABOUTME: P2P Sync Screen for managing peer-to-peer video sharing
// ABOUTME: User interface for discovering, connecting to, and syncing with nearby divine devices

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/providers/p2p_sync_provider.dart';
import 'package:openvine/services/p2p_discovery_service.dart';
import 'package:openvine/widgets/camera_fab.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

class P2PSyncScreen extends ConsumerStatefulWidget {
  const P2PSyncScreen({super.key});

  @override
  ConsumerState<P2PSyncScreen> createState() => _P2PSyncScreenState();
}

class _P2PSyncScreenState extends ConsumerState<P2PSyncScreen>
    with AsyncValueUIHelpersMixin {
  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(p2pSyncStatusProvider);
    final peers = ref.watch(p2pPeersProvider);
    final actions = ref.read(p2pActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Video Sync'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
      ),
      backgroundColor: Colors.black,
      body: buildAsyncUI(
        syncStatus,
        onData: (status) => _buildSyncContent(context, status, peers, actions),
        onError: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'P2P Sync Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: const CameraFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const VineBottomNav(),
    );
  }

  Widget _buildSyncContent(
    BuildContext context,
    P2PSyncStatus status,
    AsyncValue<List<P2PPeer>> peers,
    P2PActions actions,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(context, status),
          const SizedBox(height: 16),
          _buildControlButtons(context, status, actions),
          const SizedBox(height: 24),
          _buildPeersSection(context, peers, actions),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, P2PSyncStatus status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isEnabled ? Icons.wifi : Icons.wifi_off,
                  color: status.isEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'P2P Video Sync',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.isEnabled
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.isEnabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      color: status.isEnabled
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (status.isEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatusItem(
                    context,
                    'Peers Found',
                    status.peersCount.toString(),
                    Icons.people_outline,
                  ),
                  const SizedBox(width: 24),
                  _buildStatusItem(
                    context,
                    'Connected',
                    status.connectionsCount.toString(),
                    Icons.link,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (status.isAdvertising)
                    Chip(
                      label: const Text('Broadcasting'),
                      avatar: const Icon(Icons.broadcast_on_personal, size: 18),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                    ),
                  if (status.isDiscovering) ...[
                    if (status.isAdvertising) const SizedBox(width: 8),
                    Chip(
                      label: const Text('Discovering'),
                      avatar: const Icon(Icons.search, size: 18),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButtons(
    BuildContext context,
    P2PSyncStatus status,
    P2PActions actions,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: status.isDiscovering
                ? () => actions.stopDiscovery()
                : () => actions.startDiscovery(),
            icon: Icon(status.isDiscovering ? Icons.stop : Icons.search),
            label: Text(
              status.isDiscovering ? 'Stop Discovery' : 'Start Discovery',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => actions.syncWithPeers(),
            icon: const Icon(Icons.sync),
            label: const Text('Sync Now'),
          ),
        ),
      ],
    );
  }

  Widget _buildPeersSection(
    BuildContext context,
    AsyncValue<List<P2PPeer>> peers,
    P2PActions actions,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nearby divine Users',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: buildAsyncUI(
              peers,
              onData: (peersList) => peersList.isEmpty
                  ? _buildEmptyPeersState(context)
                  : _buildPeersList(context, peersList, actions),
              onError: (error, stack) =>
                  Center(child: Text('Error loading peers: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPeersState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No divine users nearby',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start discovery to find other divine users\nwho are sharing videos nearby.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeersList(
    BuildContext context,
    List<P2PPeer> peers,
    P2PActions actions,
  ) {
    return ListView.builder(
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        return _buildPeerTile(context, peer, actions);
      },
    );
  }

  Widget _buildPeerTile(
    BuildContext context,
    P2PPeer peer,
    P2PActions actions,
  ) {
    final transportIcon = peer.transportType == P2PTransportType.ble
        ? Icons.bluetooth
        : Icons.wifi;

    final transportColor = peer.transportType == P2PTransportType.ble
        ? Colors.blue
        : VineTheme.vineGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transportColor.withValues(alpha: 0.1),
          child: Icon(transportIcon, color: transportColor),
        ),
        title: Text(peer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              peer.transportType == P2PTransportType.ble
                  ? 'Bluetooth LE'
                  : 'WiFi Direct',
              style: TextStyle(color: transportColor),
            ),
            Text(
              'Discovered ${_formatTimeAgo(peer.discoveredAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _connectToPeer(peer, actions),
          child: const Text('Connect'),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _connectToPeer(P2PPeer peer, P2PActions actions) async {
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      final success = await actions.connectToPeer(peer);

      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Connected to ${peer.name}'),
            backgroundColor: primaryColor,
          ),
        );

        // Automatically start syncing after connection
        await actions.syncWithPeers();

        messenger.showSnackBar(
          const SnackBar(content: Text('Video sync started')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${peer.name}'),
            backgroundColor: errorColor,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }
}
