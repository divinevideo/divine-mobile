// ABOUTME: P2P Sync Provider for managing peer-to-peer video sharing
// ABOUTME: Riverpod provider for P2P discovery, connections, and sync state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/p2p_discovery_service.dart';

/// Provider for P2P discovery service
final p2pDiscoveryServiceProvider = Provider<P2PDiscoveryService?>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);

  // Check if the Nostr service is NostrService with P2P capabilities
  if (nostrService is NostrService) {
    // The P2P service is managed internally by NostrService
    // We'll access it through the relay service methods
    return null; // Handled internally
  }

  return null;
});

/// Provider for P2P peers discovery state
final p2pPeersProvider = StreamProvider<List<P2PPeer>>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);

  if (nostrService is NostrService) {
    // Create a stream that emits peer updates
    return Stream.periodic(const Duration(seconds: 2), (_) {
      return nostrService.getP2PPeers();
    }).distinct((a, b) => a.length == b.length);
  }

  return Stream.value([]);
});

/// Provider for P2P sync status
final p2pSyncStatusProvider = FutureProvider<P2PSyncStatus>((ref) async {
  final nostrService = ref.watch(nostrServiceProvider);

  if (nostrService is NostrService) {
    final stats = await nostrService.getRelayStats();

    return P2PSyncStatus(
      isEnabled: stats?['p2p_enabled'] as bool? ?? false,
      peersCount: stats?['p2p_peers'] as int? ?? 0,
      connectionsCount: stats?['p2p_connections'] as int? ?? 0,
      isAdvertising: stats?['p2p_advertising'] as bool? ?? false,
      isDiscovering: stats?['p2p_discovering'] as bool? ?? false,
    );
  }

  return const P2PSyncStatus(
    isEnabled: false,
    peersCount: 0,
    connectionsCount: 0,
    isAdvertising: false,
    isDiscovering: false,
  );
});

/// Provider for P2P actions
final p2pActionsProvider = Provider<P2PActions>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);

  return P2PActions(
    startDiscovery: () async {
      if (nostrService is NostrService) {
        return nostrService.startP2PDiscovery();
      }
      return false;
    },
    stopDiscovery: () async {
      if (nostrService is NostrService) {
        await nostrService.stopP2PDiscovery();
      }
    },
    startAdvertising: () async {
      if (nostrService is NostrService) {
        return nostrService.startP2PAdvertising();
      }
      return false;
    },
    stopAdvertising: () async {
      if (nostrService is NostrService) {
        await nostrService.stopP2PAdvertising();
      }
    },
    connectToPeer: (peer) async {
      if (nostrService is NostrService) {
        return nostrService.connectToP2PPeer(peer);
      }
      return false;
    },
    syncWithPeers: () async {
      if (nostrService is NostrService) {
        await nostrService.syncWithP2PPeers();
      }
    },
  );
});

/// P2P sync status data class
class P2PSyncStatus {
  final bool isEnabled;
  final int peersCount;
  final int connectionsCount;
  final bool isAdvertising;
  final bool isDiscovering;

  const P2PSyncStatus({
    required this.isEnabled,
    required this.peersCount,
    required this.connectionsCount,
    required this.isAdvertising,
    required this.isDiscovering,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is P2PSyncStatus &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          peersCount == other.peersCount &&
          connectionsCount == other.connectionsCount &&
          isAdvertising == other.isAdvertising &&
          isDiscovering == other.isDiscovering;

  @override
  int get hashCode =>
      isEnabled.hashCode ^
      peersCount.hashCode ^
      connectionsCount.hashCode ^
      isAdvertising.hashCode ^
      isDiscovering.hashCode;
}

/// P2P actions interface for UI components
class P2PActions {
  final Future<bool> Function() startDiscovery;
  final Future<void> Function() stopDiscovery;
  final Future<bool> Function() startAdvertising;
  final Future<void> Function() stopAdvertising;
  final Future<bool> Function(P2PPeer peer) connectToPeer;
  final Future<void> Function() syncWithPeers;

  const P2PActions({
    required this.startDiscovery,
    required this.stopDiscovery,
    required this.startAdvertising,
    required this.stopAdvertising,
    required this.connectToPeer,
    required this.syncWithPeers,
  });
}
