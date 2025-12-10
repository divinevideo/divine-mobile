// ABOUTME: NostrService implementation using direct function calls to embedded relay
// ABOUTME: Replaces WebSocket connection with high-performance function channel

import 'dart:async';
import 'dart:convert';

import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;
import 'package:logging/logging.dart' as logging;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:models/models.dart' show NIP94Metadata;
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/p2p_discovery_service.dart';
import 'package:openvine/services/p2p_video_sync_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// High-performance NostrService using direct function calls.
///
/// This implementation replaces WebSocket connections with direct function
/// calls to the embedded relay, providing:
/// - No network overhead
/// - No local network permissions required on iOS
/// - Instant message delivery
/// - No connection management
/// - Better performance and reliability
class NostrServiceFunction implements INostrService {
  NostrServiceFunction(
    this._keyManager, {
    embedded.EmbeddedNostrRelay? embeddedRelay,
  }) {
    // Allow injecting an embedded relay for testing
    if (embeddedRelay != null) {
      _embeddedRelay = embeddedRelay;
    }
  }

  final NostrKeyManager _keyManager;
  final Map<String, StreamController<Event>> _subscriptions = {};
  final Map<String, bool> _relayAuthStates = {};
  final _authStateController = StreamController<Map<String, bool>>.broadcast();

  // Embedded relay with function channel
  embedded.EmbeddedNostrRelay? _embeddedRelay;
  embedded.FunctionChannelSession? _functionSession;

  // Map subscription IDs to their stream controllers
  final Map<String, StreamController<Event>> _subscriptionStreams = {};

  // P2P sync components
  P2PDiscoveryService? _p2pService;
  P2PVideoSyncService? _videoSyncService;
  bool _p2pEnabled = false;

  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _configuredRelays = [];

  @override
  Future<void> initialize({
    List<String>? customRelays,
    bool enableP2P = true,
  }) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (_isInitialized) return;

    Log.info(
      'Starting initialization with function channel relay',
      name: 'NostrServiceFunction',
      category: LogCategory.relay,
    );

    // Ensure default relay is always included (for external relay connections)
    final defaultRelay = AppConstants.defaultRelayUrl;
    final relaysToAdd = customRelays ?? [defaultRelay];
    if (!relaysToAdd.contains(defaultRelay)) {
      relaysToAdd.add(defaultRelay);
    }

    try {
      // Initialize embedded relay with function channel
      _embeddedRelay ??= embedded.EmbeddedNostrRelay();

      Log.info(
        'Initializing embedded relay with function channel...',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      CrashReportingService.instance.logInitializationStep(
        'Creating embedded relay with function channel',
      );

      await _embeddedRelay!.initialize(
        logLevel: logging
            .Level
            .INFO, // Temporary: restore INFO to debug startup issue
        enableGarbageCollection: true,
        useFunctionChannel:
            true, // Enable function channel instead of WebSocket
      );

      Log.info(
        'Embedded relay initialized with function channel',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );

      // Create function channel session
      _functionSession = _embeddedRelay!.createFunctionSession();

      // Set up event listener
      _functionSession!.responseStream.listen(_handleRelayResponse);

      Log.info(
        'Function channel session created and connected',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );

      // MIGRATION: Remove old relay3.openvine.co if present
      const oldRelay = 'wss://relay3.openvine.co';
      final currentRelays = _embeddedRelay!.connectedRelays;

      if (currentRelays.contains(oldRelay)) {
        Log.info(
          '🔄 MIGRATION: Removing old relay $oldRelay',
          name: 'NostrServiceFunction',
          category: LogCategory.relay,
        );
        try {
          await _embeddedRelay!.removeExternalRelay(oldRelay);
          Log.info(
            '✅ MIGRATION: Successfully removed old relay',
            name: 'NostrServiceFunction',
            category: LogCategory.relay,
          );
        } catch (e) {
          Log.error(
            '❌ MIGRATION: Failed to remove old relay: $e',
            name: 'NostrServiceFunction',
            category: LogCategory.relay,
          );
        }
      }

      // Add external relays for proxying
      for (final relayUrl in relaysToAdd) {
        try {
          await _embeddedRelay!.addExternalRelay(relayUrl);
          _configuredRelays.add(relayUrl);
          Log.info(
            'Added external relay: $relayUrl',
            name: 'NostrServiceFunction',
            category: LogCategory.relay,
          );
        } catch (e) {
          Log.error(
            'Failed to add relay $relayUrl: $e',
            name: 'NostrServiceFunction',
            category: LogCategory.relay,
          );
        }
      }

      // Initialize P2P sync if enabled
      if (enableP2P) {
        _p2pEnabled = true;
        // P2P initialization moved to lazy loading when needed
      }

      _isInitialized = true;
      Log.info(
        'Initialization complete with function channel and ${_configuredRelays.length} external relays',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.error(
        'Initialization failed: $e',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );

      // Add default relay to configured list for retry capability
      if (!_configuredRelays.contains(defaultRelay)) {
        _configuredRelays.add(defaultRelay);
      }

      _isInitialized = true; // Allow app to continue
      Log.warning(
        'NostrService initialized with limited functionality',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
    }
  }

  void _handleRelayResponse(embedded.RelayResponse response) {
    if (response is embedded.EventResponse) {
      final subId = response.subscriptionId;
      final event = response.event;

      // No global dedupe - the same event should be delivered to multiple subscriptions
      // that match it (discovery, homeFeed, profile, etc.). Each subscription layer
      // (VideoEventService) handles per-feed deduplication via seenEventIds.

      // Convert to SDK Event and emit
      final controller = _subscriptionStreams[subId];
      if (controller != null && !controller.isClosed) {
        try {
          final sdkEvent = Event.fromJson(event.toJson());
          controller.add(sdkEvent);
        } catch (e) {
          Log.error(
            'Error converting event: $e',
            name: 'NostrServiceFunction',
            category: LogCategory.relay,
          );
        }
      }
    } else if (response is embedded.EoseResponse) {
      // End of stored events - could be used for UI feedback
      Log.debug(
        'EOSE for subscription: ${response.subscriptionId}',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
    } else if (response is embedded.OkResponse) {
      Log.debug(
        'OK response: ${response.eventId} - ${response.success}',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
    } else if (response is embedded.NoticeResponse) {
      Log.warning(
        'Notice from relay: ${response.message}',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
    }
  }

  @override
  Stream<Event> subscribeToEvents({
    required List<nostr.Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    return subscribeToEventsWithId(
      subscriptionId: subscriptionId,
      filters: filters,
      onEvent: null,
      onEose: onEose,
    );
  }

  Stream<Event> subscribeToEventsWithId({
    required List<nostr.Filter> filters,
    required String subscriptionId,
    void Function(Event)? onEvent,
    void Function()? onEose,
  }) {
    if (!_isInitialized) {
      throw StateError('NostrService not initialized');
    }

    Log.info(
      'Creating subscription: $subscriptionId',
      name: 'NostrServiceFunction',
      category: LogCategory.relay,
    );

    // Close existing subscription if any
    _closeSubscription(subscriptionId);

    // Create new stream controller
    final controller = StreamController<Event>.broadcast();
    _subscriptionStreams[subscriptionId] = controller;

    // Send REQ message via function channel
    _functionSession?.sendMessage(
      embedded.ReqMessage(
        subscriptionId: subscriptionId,
        filters: filters
            .map(
              (f) => embedded.Filter(
                authors: f.authors,
                kinds: f.kinds,
                ids: f.ids,
                tags: f.t != null
                    ? {'t': f.t!}
                    : null, // Fixed: Include hashtag tags property (f.t maps to embedded.Filter.tags)
                since: f.since,
                until: f.until,
                limit: f.limit,
              ),
            )
            .toList(),
      ),
    );

    // Set up event listener if provided
    if (onEvent != null) {
      controller.stream.listen(onEvent);
    }

    return controller.stream;
  }

  Future<void> closeSubscription(String subscriptionId) async {
    _closeSubscription(subscriptionId);
  }

  void _closeSubscription(String subscriptionId) {
    Log.debug(
      'Closing subscription: $subscriptionId',
      name: 'NostrServiceFunction',
      category: LogCategory.relay,
    );

    // Send CLOSE message via function channel
    _functionSession?.sendMessage(
      embedded.CloseMessage(subscriptionId: subscriptionId),
    );

    // Clean up stream controller
    final controller = _subscriptionStreams.remove(subscriptionId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }

    _subscriptions.remove(subscriptionId);
  }

  Future<void> publishEvent(Event event) async {
    if (!_isInitialized) {
      throw StateError('NostrService not initialized');
    }

    Log.info(
      'Publishing event: ${event.id}',
      name: 'NostrServiceFunction',
      category: LogCategory.relay,
    );

    try {
      // Convert SDK event to embedded event
      final embeddedEvent = embedded.NostrEvent.fromJson(event.toJson());

      // Send EVENT message via function channel (client-to-relay format)
      await _functionSession?.sendMessage(
        embedded.ClientEventMessage(event: embeddedEvent),
      );

      Log.info(
        'Event published successfully: ${event.id}',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.error(
        'Failed to publish event: $e',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      rethrow;
    }
  }

  Future<List<Event>> queryEvents({
    required List<nostr.Filter> filters,
    String? relayUrl,
  }) async {
    if (!_isInitialized) {
      throw StateError('NostrService not initialized');
    }

    // Use embedded relay's direct query method
    final embeddedFilters = filters
        .map(
          (f) => embedded.Filter(
            authors: f.authors,
            kinds: f.kinds,
            ids: f.ids,
            tags: f.t != null ? {'t': f.t!} : null,
            since: f.since, // f.since is already int? (seconds since epoch)
            until: f.until, // f.until is already int? (seconds since epoch)
            limit: f.limit,
          ),
        )
        .toList();

    final embeddedEvents = await _embeddedRelay!.queryEvents(embeddedFilters);

    // Convert to SDK events
    return embeddedEvents
        .map((e) {
          try {
            return Event.fromJson(e.toJson());
          } catch (err) {
            Log.error(
              'Error converting event: $err',
              name: 'NostrServiceFunction',
              category: LogCategory.relay,
            );
            return null;
          }
        })
        .whereType<Event>()
        .toList();
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isDisposed => _isDisposed;

  @override
  List<String> get connectedRelays => _embeddedRelay?.connectedRelays ?? [];

  @override
  String? get publicKey => _keyManager.publicKey;

  @override
  bool get hasKeys => _keyManager.hasKeys;

  @override
  NostrKeyManager get keyManager => _keyManager;

  @override
  int get relayCount => _configuredRelays.length;

  @override
  int get connectedRelayCount => _embeddedRelay?.connectedRelays.length ?? 0;

  @override
  List<String> get relays => List.from(_configuredRelays);

  @override
  Map<String, dynamic> get relayStatuses {
    final statuses = <String, dynamic>{};
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];

    for (final relayUrl in _configuredRelays) {
      statuses[relayUrl] = {
        'connected': connectedRelays.contains(relayUrl),
        'url': relayUrl,
      };
    }

    return statuses;
  }

  @override
  Stream<Map<String, bool>> get authStateStream => _authStateController.stream;

  @override
  Map<String, bool> get relayAuthStates => Map.from(_relayAuthStates);

  Future<void> sendAuth(String relayUrl, Event authEvent) async {
    // Not needed with function channel
    Log.debug(
      'Auth not required for function channel',
      name: 'NostrServiceFunction',
      category: LogCategory.relay,
    );
  }

  @override
  Future<bool> addRelay(String url) async {
    if (!_isInitialized) {
      throw StateError('NostrService not initialized');
    }

    if (_configuredRelays.contains(url)) {
      Log.info(
        'Relay already configured: $url',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      return true;
    }

    try {
      await _embeddedRelay!.addExternalRelay(url);
      _configuredRelays.add(url);
      Log.info(
        'Added relay: $url',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      return true;
    } catch (e) {
      Log.error(
        'Failed to add relay $url: $e',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      rethrow;
    }
  }

  @override
  Future<void> removeRelay(String url) async {
    if (!_isInitialized) {
      throw StateError('NostrService not initialized');
    }

    if (!_configuredRelays.contains(url)) {
      Log.info(
        'Relay not configured: $url',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      return;
    }

    try {
      await _embeddedRelay!.removeExternalRelay(url);
      _configuredRelays.remove(url);
      Log.info(
        'Removed relay: $url',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.error(
        'Failed to remove relay $url: $e',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      rethrow;
    }
  }

  Future<bool> connectRelay(String url) async {
    // With function channel, this is handled by addRelay
    return addRelay(url).then((_) => true).catchError((_) => false);
  }

  Future<void> disconnectRelay(String url) async {
    // With function channel, this is handled by removeRelay
    await removeRelay(url);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    Log.info(
      'Disposing NostrService',
      name: 'NostrServiceFunction',
      category: LogCategory.relay,
    );

    // Close all subscriptions
    for (final subId in _subscriptions.keys.toList()) {
      _closeSubscription(subId);
    }

    // Close function session
    await _functionSession?.close();
    _functionSession = null;

    // Clean up P2P
    _p2pService?.dispose();
    _videoSyncService?.dispose();

    // Clear state
    _subscriptions.clear();
    _subscriptionStreams.clear();
    _relayAuthStates.clear();
    await _authStateController.close();

    _isDisposed = true;
    _isInitialized = false;

    Log.info(
      'NostrService disposed',
      name: 'NostrServiceFunction',
      category: LogCategory.relay,
    );
  }

  Future<Event?> fetchEventById(String eventId, {String? relayUrl}) async {
    final filters = [
      nostr.Filter(ids: [eventId]),
    ];
    final events = await queryEvents(filters: filters, relayUrl: relayUrl);
    return events.isEmpty ? null : events.first;
  }

  Future<Map<String, dynamic>?> fetchUserProfile(
    String pubkey, {
    String? relayUrl,
  }) async {
    final filters = [
      nostr.Filter(
        authors: [pubkey],
        kinds: [0], // Kind 0 is user metadata
        limit: 1,
      ),
    ];

    final events = await queryEvents(filters: filters, relayUrl: relayUrl);
    if (events.isEmpty) return null;

    try {
      return jsonDecode(events.first.content);
    } catch (e) {
      Log.error(
        'Error parsing user profile: $e',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  Future<List<String>> fetchUserRelays(
    String pubkey, {
    String? relayUrl,
  }) async {
    final filters = [
      nostr.Filter(
        authors: [pubkey],
        kinds: [10002], // NIP-65 relay list
        limit: 1,
      ),
    ];

    final events = await queryEvents(filters: filters, relayUrl: relayUrl);
    if (events.isEmpty) return [];

    final relayUrls = <String>[];
    for (final tag in events.first.tags) {
      if (tag.isNotEmpty && tag[0] == 'r' && tag.length > 1) {
        relayUrls.add(tag[1]);
      }
    }

    return relayUrls;
  }

  // P2P methods
  Future<void> startP2PDiscovery() async {
    if (!_p2pEnabled) {
      Log.warning(
        'P2P not enabled',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      return;
    }

    _p2pService ??= P2PDiscoveryService();
    await _p2pService!.startDiscovery();
  }

  Future<void> stopP2PDiscovery() async {
    await _p2pService?.stopDiscovery();
  }

  Stream<P2PPeer> get p2pPeerStream =>
      _p2pService?.discoveredPeers ?? const Stream.empty();

  Future<void> startVideoSync(String peerId) async {
    if (!_p2pEnabled) {
      Log.warning(
        'P2P not enabled',
        name: 'NostrServiceFunction',
        category: LogCategory.relay,
      );
      return;
    }

    _videoSyncService ??= P2PVideoSyncService(_embeddedRelay!, _p2pService!);
    await _videoSyncService!
        .syncWithAllPeers(); // P2P sync with all connected peers
  }

  Future<void> stopVideoSync() async {
    _videoSyncService?.stopAutoSync();
  }

  // Required methods from INostrService interface (implemented above)

  @override
  bool isRelayAuthenticated(String relayUrl) =>
      _relayAuthStates[relayUrl] ?? false;

  @override
  bool get isVineRelayAuthenticated =>
      isRelayAuthenticated(AppConstants.defaultRelayUrl);

  @override
  void setAuthTimeout(Duration timeout) {
    // TODO: Implement auth timeout if needed
  }

  @override
  Future<NostrBroadcastResult> broadcastEvent(Event event) async {
    await publishEvent(event);
    // For function channel, we assume success since it's direct call
    return NostrBroadcastResult(
      event: event,
      successCount: _configuredRelays.length,
      totalRelays: _configuredRelays.length,
      results: Map.fromEntries(_configuredRelays.map((r) => MapEntry(r, true))),
      errors: {},
    );
  }

  @override
  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  }) async {
    // Create NIP-94 event for file metadata
    final event = Event.fromJson({
      'kind': 1063,
      'content': content,
      'tags': [
        ['url', metadata.url],
        ['m', metadata.mimeType],
        ['x', metadata.sha256Hash],
        ['size', metadata.sizeBytes.toString()],
        if (metadata.altText != null) ['alt', metadata.altText!],
        ...hashtags.map((tag) => ['t', tag]),
      ],
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'pubkey': publicKey ?? '',
    });

    return broadcastEvent(event);
  }

  @override
  Map<String, bool> getRelayStatus() => Map.from(_relayAuthStates);

  @override
  Future<void> reconnectAll() async {
    // For function channel, reconnection is not needed
  }

  @override
  Future<void> retryInitialization() async {
    await initialize();
  }

  @override
  Future<void> closeAllSubscriptions() async {
    final subscriptionIds = List<String>.from(_subscriptions.keys);
    for (final id in subscriptionIds) {
      await closeSubscription(id);
    }
  }

  @override
  Future<List<Event>> getEvents({
    required List<nostr.Filter> filters,
    int? limit,
  }) async {
    return queryEvents(filters: filters);
  }

  @override
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    // Create search filter for NIP-50
    final filter = nostr.Filter()
      ..kinds =
          [NIP71VideoKinds.addressableShortVideo] // Kind 34236 only
      ..search = query;

    if (authors != null) {
      filter.authors = authors;
    }
    if (since != null) {
      filter.since = since.millisecondsSinceEpoch ~/ 1000;
    }
    if (until != null) {
      filter.until = until.millisecondsSinceEpoch ~/ 1000;
    }
    if (limit != null) {
      filter.limit = limit;
    }

    return subscribeToEvents(filters: [filter]);
  }

  @override
  Stream<Event> searchUsers(String query, {int? limit}) {
    // Create search filter for NIP-50
    final filter = nostr.Filter()
      ..kinds =
          [EventKind.METADATA] // Kind 0 only
      ..search = query;

    if (limit != null) {
      filter.limit = limit;
    }

    return subscribeToEvents(filters: [filter]);
  }

  @override
  String get primaryRelay => _configuredRelays.isNotEmpty
      ? _configuredRelays.first
      : AppConstants.defaultRelayUrl;

  @override
  Future<Map<String, dynamic>?> getRelayStats() async {
    if (!_isInitialized || _embeddedRelay == null) return null;

    try {
      final stats = await _embeddedRelay!.getStats();
      final subscriptionStats = _embeddedRelay!.getSubscriptionStats();

      return {
        'database': stats,
        'subscriptions': subscriptionStats,
        'external_relays': _configuredRelays.length,
        'p2p_enabled': _p2pEnabled,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
