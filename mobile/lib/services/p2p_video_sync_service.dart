// ABOUTME: P2P Video Sync Service for divine - handles video metadata synchronization
// ABOUTME: Simplified implementation using available embedded relay methods

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;
import 'package:openvine/services/p2p_discovery_service.dart';

/// Simple P2P video sync service for divine
/// Uses available embedded relay methods for video event synchronization
class P2PVideoSyncService extends ChangeNotifier {
  final embedded.EmbeddedNostrRelay _embeddedRelay;
  final P2PDiscoveryService _p2pService;

  final Map<String, DateTime> _lastSyncTimes = {};
  bool _isAutoSyncing = false;
  Timer? _autoSyncTimer;

  P2PVideoSyncService(this._embeddedRelay, this._p2pService);

  /// Start automatic syncing with connected peers
  Future<void> startAutoSync({
    Duration interval = const Duration(minutes: 5),
  }) async {
    if (_isAutoSyncing) return;

    _isAutoSyncing = true;
    _autoSyncTimer = Timer.periodic(interval, (_) => syncWithAllPeers());

    debugPrint(
      'P2P Video Sync: Auto-sync started (interval: ${interval.inMinutes}m)',
    );
  }

  /// Stop automatic syncing
  void stopAutoSync() {
    _isAutoSyncing = false;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;

    debugPrint('P2P Video Sync: Auto-sync stopped');
  }

  /// Sync video events with all connected peers
  Future<void> syncWithAllPeers() async {
    final connections = _p2pService.connections;
    if (connections.isEmpty) {
      debugPrint('P2P Video Sync: No peers connected');
      return;
    }

    debugPrint(
      'P2P Video Sync: Starting sync with ${connections.length} peers',
    );

    for (final connection in connections) {
      await _syncWithPeer(connection);
    }
  }

  /// Sync video events with a specific peer
  Future<void> _syncWithPeer(P2PConnection connection) async {
    try {
      final peerId = connection.peer.id;
      final lastSync = _lastSyncTimes[peerId];

      // Get recent video events (Kind 34236 addressable short videos)
      final since =
          lastSync ?? DateTime.now().subtract(const Duration(days: 7));
      final videoFilter = embedded.Filter(
        kinds: [34236], // Kind 34236 addressable short video events
        since: since.millisecondsSinceEpoch ~/ 1000,
        limit: 100,
      );

      final localVideos = await _embeddedRelay.queryEvents([videoFilter]);

      // Create a simple sync message with video metadata
      final syncMessage = {
        'type': 'video_sync_offer',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'video_count': localVideos.length,
        'video_summaries': localVideos
            .map(
              (event) => {
                'id': event.id,
                'created_at': event.createdAt,
                'pubkey': event.pubkey,
                // Extract video URL from content if available
                'has_content': event.content.isNotEmpty,
              },
            )
            .toList(),
      };

      await _sendSyncMessage(connection, syncMessage);
      _lastSyncTimes[peerId] = DateTime.now();

      debugPrint(
        'P2P Video Sync: Synced with ${connection.peer.name} (${localVideos.length} videos)',
      );
    } catch (e) {
      debugPrint(
        'P2P Video Sync: Failed to sync with ${connection.peer.name}: $e',
      );
    }
  }

  /// Send a sync message to a peer
  Future<void> _sendSyncMessage(
    P2PConnection connection,
    Map<String, dynamic> message,
  ) async {
    final jsonString = jsonEncode(message);
    final bytes = utf8.encode(jsonString);

    await connection.send(bytes);
  }

  /// Handle incoming sync messages from peers
  Future<void> handleIncomingSync(
    String peerId,
    Map<String, dynamic> message,
  ) async {
    final messageType = message['type'] as String?;

    switch (messageType) {
      case 'video_sync_offer':
        await _handleSyncOffer(peerId, message);
        break;
      case 'video_sync_request':
        await _handleSyncRequest(peerId, message);
        break;
      case 'video_data':
        await _handleVideoData(peerId, message);
        break;
      default:
        debugPrint('P2P Video Sync: Unknown message type: $messageType');
    }
  }

  /// Handle sync offer from a peer
  Future<void> _handleSyncOffer(
    String peerId,
    Map<String, dynamic> message,
  ) async {
    final videoSummaries = message['video_summaries'] as List?;
    if (videoSummaries == null) return;

    final missingVideos = <String>[];

    // Check which videos we don't have
    for (final summary in videoSummaries) {
      final eventId = summary['id'] as String?;
      if (eventId != null) {
        final existingEvent = await _embeddedRelay.getEvent(eventId);
        if (existingEvent == null) {
          missingVideos.add(eventId);
        }
      }
    }

    if (missingVideos.isNotEmpty) {
      // Request missing videos
      final requestMessage = {
        'type': 'video_sync_request',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'requested_videos': missingVideos,
      };

      final connection = _p2pService.connections.firstWhere(
        (conn) => conn.peer.id == peerId,
        orElse: () => throw StateError('Peer connection not found'),
      );

      await _sendSyncMessage(connection, requestMessage);

      debugPrint(
        'P2P Video Sync: Requested ${missingVideos.length} missing videos from $peerId',
      );
    }
  }

  /// Handle sync request from a peer
  Future<void> _handleSyncRequest(
    String peerId,
    Map<String, dynamic> message,
  ) async {
    final requestedVideos = message['requested_videos'] as List?;
    if (requestedVideos == null) return;

    P2PConnection? connection;
    try {
      connection = _p2pService.connections.firstWhere(
        (conn) => conn.peer.id == peerId,
      );
    } catch (e) {
      connection = null;
    }

    if (connection == null) return;

    // Send requested videos
    for (final videoId in requestedVideos) {
      final event = await _embeddedRelay.getEvent(videoId as String);
      if (event != null) {
        final videoMessage = {
          'type': 'video_data',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'event': {
            'id': event.id,
            'pubkey': event.pubkey,
            'created_at': event.createdAt,
            'kind': event.kind,
            'tags': event.tags,
            'content': event.content,
            'sig': event.sig,
          },
        };

        await _sendSyncMessage(connection, videoMessage);
      }
    }

    debugPrint(
      'P2P Video Sync: Sent ${requestedVideos.length} videos to $peerId',
    );
  }

  /// Handle video data from a peer
  Future<void> _handleVideoData(
    String peerId,
    Map<String, dynamic> message,
  ) async {
    final eventData = message['event'] as Map<String, dynamic>?;
    if (eventData == null) return;

    try {
      // Create NostrEvent from received data
      final event = embedded.NostrEvent.fromJson(eventData);

      // Store the event in local relay
      final stored = await _embeddedRelay.publish(event);

      if (stored) {
        debugPrint('P2P Video Sync: Stored video ${event.id} from $peerId');
        notifyListeners(); // Notify UI of new content
      }
    } catch (e) {
      debugPrint('P2P Video Sync: Failed to store video from $peerId: $e');
    }
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'is_auto_syncing': _isAutoSyncing,
      'connected_peers': _p2pService.connections.length,
      'last_sync_times': Map.from(_lastSyncTimes),
    };
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
