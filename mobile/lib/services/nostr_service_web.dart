// ABOUTME: Web-specific NostrService implementation using direct relay connections
// ABOUTME: Bypasses embedded relay for simpler Web functionality

import 'dart:async';
import 'dart:convert';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/constants/app_constants.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Web implementation of NostrService that connects directly to external relays
/// Uses browser's WebSocket API instead of trying to run a local relay
abstract class NostrServiceWeb implements INostrService {
  final List<String> _configuredRelays = [];
  final Map<String, WebSocketChannel> _relayConnections = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, String> _activeSubscriptions =
      {}; // subscriptionId -> relayUrl
  final StreamController<sdk.Event> _eventController =
      StreamController<sdk.Event>.broadcast();
  bool _isInitialized = false;
  bool _isDisposed = false;
  int _subscriptionCounter = 0;

  // Event batching for compact logging
  final Map<String, Map<int, int>> _eventBatchCounts =
      {}; // relayUrl -> {kind: count}
  Timer? _batchLogTimer;
  static const _batchLogInterval = Duration(seconds: 5);

  NostrServiceWeb() {
    _startBatchLogging();
  }

  void _startBatchLogging() {
    _batchLogTimer = Timer.periodic(
      _batchLogInterval,
      (_) => _flushBatchedLogs(),
    );
  }

  void _flushBatchedLogs() {
    if (_eventBatchCounts.isEmpty) return;

    for (final entry in _eventBatchCounts.entries) {
      final relayUrl = entry.key;
      final kindCounts = entry.value;
      final totalCount = kindCounts.values.fold(0, (sum, count) => sum + count);

      if (totalCount > 0) {
        final kindSummary = kindCounts.entries
            .map((e) => 'kind ${e.key}: ${e.value}')
            .join(', ');
        Log.debug(
          'Received $totalCount events ($kindSummary) from $relayUrl',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      }
    }

    _eventBatchCounts.clear();
  }

  void _recordEventForBatching(String relayUrl, int kind) {
    _eventBatchCounts.putIfAbsent(relayUrl, () => {});
    _eventBatchCounts[relayUrl]![kind] =
        (_eventBatchCounts[relayUrl]![kind] ?? 0) + 1;
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  List<String> get connectedRelays => _relayConnections.keys.toList();

  @override
  Future<void> initialize({
    List<String>? customRelays,
    bool enableP2P = false,
  }) async {
    if (_isInitialized) {
      Log.warning(
        'NostrServiceWeb already initialized',
        name: 'NostrServiceWeb',
        category: LogCategory.relay,
      );
      return;
    }

    // Default relay
    final defaultRelay = AppConstants.defaultRelayUrl;
    final relaysToAdd = customRelays ?? [defaultRelay];
    if (!relaysToAdd.contains(defaultRelay)) {
      relaysToAdd.add(defaultRelay);
    }

    // Connect to relays directly using WebSocket
    for (final relayUrl in relaysToAdd) {
      try {
        final wsUrl = Uri.parse(relayUrl);
        final channel = WebSocketChannel.connect(wsUrl);

        // Listen for messages from this relay
        channel.stream.listen(
          (message) => _handleRelayMessage(relayUrl, message),
          onError: (error) => _handleRelayError(relayUrl, error),
          onDone: () => _handleRelayDisconnect(relayUrl),
        );

        _relayConnections[relayUrl] = channel;
        _configuredRelays.add(relayUrl);

        Log.info(
          'Connected to relay: $relayUrl',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      } catch (e) {
        Log.error(
          'Failed to connect to relay $relayUrl: $e',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      }
    }

    _isInitialized = true;
    _isDisposed = false;
  }

  void _handleRelayMessage(String relayUrl, dynamic message) {
    try {
      final decoded = jsonDecode(message as String) as List;
      final messageType = decoded[0] as String;

      if (messageType == 'EVENT' && decoded.length >= 3) {
        final eventJson = decoded[2] as Map<String, dynamic>;

        // Convert to SDK Event
        final event = sdk.Event.fromJson(eventJson);
        _eventController.add(event);

        // Record event for batched logging instead of logging individually
        _recordEventForBatching(relayUrl, event.kind);
      } else if (messageType == 'EOSE' && decoded.length >= 2) {
        // End of stored events
        final subscriptionId = decoded[1] as String;
        Log.debug(
          'EOSE received from $relayUrl for subscription $subscriptionId',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );

        // Trigger any EOSE callbacks
        // Note: We store callbacks separately if needed
      } else if (messageType == 'NOTICE') {
        Log.info(
          'Notice from $relayUrl: ${decoded[1]}',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      }
    } catch (e) {
      Log.error(
        'Error handling relay message from $relayUrl: $e',
        name: 'NostrServiceWeb',
        category: LogCategory.relay,
      );
    }
  }

  void _handleRelayError(String relayUrl, dynamic error) {
    Log.error(
      'Relay error from $relayUrl: $error',
      name: 'NostrServiceWeb',
      category: LogCategory.relay,
    );
  }

  void _handleRelayDisconnect(String relayUrl) {
    Log.warning(
      'Relay disconnected: $relayUrl',
      name: 'NostrServiceWeb',
      category: LogCategory.relay,
    );
    _relayConnections.remove(relayUrl);
  }

  @override
  Stream<sdk.Event> subscribeToEvents({
    required List<sdk.Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    if (!_isInitialized) {
      throw StateError('Relay not initialized. Call initialize() first.');
    }

    if (_relayConnections.isEmpty) {
      throw Exception('No connected relays');
    }

    // Generate subscription ID
    final subscriptionId = 'sub_${++_subscriptionCounter}';

    // Send REQ message to each relay
    for (final entry in _relayConnections.entries) {
      try {
        final relayUrl = entry.key;
        final channel = entry.value;

        // Convert filters to JSON
        final filtersJson = filters.map((f) => f.toJson()).toList();

        // Send REQ message: ["REQ", subscription_id, filter...]
        final reqMessage = jsonEncode(['REQ', subscriptionId, ...filtersJson]);
        channel.sink.add(reqMessage);

        _activeSubscriptions[subscriptionId] = relayUrl;

        Log.debug(
          'Sent REQ to $relayUrl: $subscriptionId',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      } catch (e) {
        Log.error(
          'Failed to subscribe to relay ${entry.key}: $e',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      }
    }

    // Return the event stream
    return _eventController.stream;
  }

  Future<List<sdk.Event>> queryEvents(List<sdk.Filter> filters) async {
    if (!_isInitialized) {
      throw StateError('Relay not initialized. Call initialize() first.');
    }

    if (_relayConnections.isEmpty) {
      throw Exception('No connected relays');
    }

    final events = <sdk.Event>{};
    final subscriptionId = 'query_${++_subscriptionCounter}';

    // Query each relay with a temporary subscription
    for (final entry in _relayConnections.entries) {
      try {
        final channel = entry.value;

        // Convert filters to JSON
        final filtersJson = filters.map((f) => f.toJson()).toList();

        // Send REQ message
        final reqMessage = jsonEncode(['REQ', subscriptionId, ...filtersJson]);
        channel.sink.add(reqMessage);

        // Wait briefly for events, then close subscription
        await Future.delayed(const Duration(seconds: 2));

        // Send CLOSE message
        final closeMessage = jsonEncode(['CLOSE', subscriptionId]);
        channel.sink.add(closeMessage);
      } catch (e) {
        Log.error(
          'Failed to query relay ${entry.key}: $e',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      }
    }

    return events.toList();
  }

  @override
  Future<NostrBroadcastResult> broadcastEvent(sdk.Event event) async {
    if (!_isInitialized) {
      _isInitialized = true; // Try to recover
      await initialize();
    }

    if (_relayConnections.isEmpty) {
      return NostrBroadcastResult(
        event: event,
        successCount: 0,
        totalRelays: 0,
        results: {},
        errors: {'all': 'No connected relays'},
      );
    }

    final results = <String, bool>{};
    final errors = <String, String>{};
    int successCount = 0;

    // Broadcast to each relay
    for (final entry in _relayConnections.entries) {
      try {
        final relayUrl = entry.key;
        final channel = entry.value;

        // Send EVENT message: ["EVENT", event_json]
        final eventMessage = jsonEncode(['EVENT', event.toJson()]);
        channel.sink.add(eventMessage);

        results[relayUrl] = true;
        successCount++;

        Log.debug(
          'Published event to $relayUrl: ${event.id}',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      } catch (e) {
        results[entry.key] = false;
        errors[entry.key] = e.toString();
        Log.error(
          'Failed to broadcast to ${entry.key}: $e',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      }
    }

    return NostrBroadcastResult(
      event: event,
      successCount: successCount,
      totalRelays: _relayConnections.length,
      results: results,
      errors: errors,
    );
  }

  void unsubscribe(String id) {
    // Cancel all subscriptions with this ID
    final keysToRemove = <String>[];
    for (final key in _subscriptions.keys) {
      if (key.startsWith('$id-')) {
        _subscriptions[key]?.cancel();
        keysToRemove.add(key);
      }
    }
    keysToRemove.forEach(_subscriptions.remove);

    // Send CLOSE message to relays
    for (final channel in _relayConnections.values) {
      try {
        final closeMessage = jsonEncode(['CLOSE', id]);
        channel.sink.add(closeMessage);
      } catch (e) {
        // Ignore unsubscribe errors
      }
    }

    _activeSubscriptions.remove(id);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    // Cancel batch logging timer
    _batchLogTimer?.cancel();
    _batchLogTimer = null;

    // Flush any remaining batched logs
    _flushBatchedLogs();

    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Close all WebSocket connections
    for (final entry in _relayConnections.entries) {
      try {
        await entry.value.sink.close(status.normalClosure);
        Log.debug(
          'Closed connection to ${entry.key}',
          name: 'NostrServiceWeb',
          category: LogCategory.relay,
        );
      } catch (e) {
        // Ignore disconnect errors
      }
    }
    _relayConnections.clear();
    _activeSubscriptions.clear();

    _isDisposed = true;
    _isInitialized = false;
  }

  Future<Map<String, dynamic>> getRelayInfo(String relayUrl) async {
    return {'url': relayUrl, 'status': 'connected'};
  }

  Future<void> authenticateToRelay(String relayUrl, sdk.Event authEvent) async {
    // Web doesn't need NIP-42 auth typically
  }

  @override
  bool isRelayAuthenticated(String relayUrl) => true;

  @override
  String get primaryRelay => _configuredRelays.isNotEmpty
      ? _configuredRelays.first
      : AppConstants.defaultRelayUrl;

  @override
  Future<Map<String, dynamic>?> getRelayStats() async {
    if (!_isInitialized) return null;

    return {
      'connected_relays': _relayConnections.length,
      'configured_relays': _configuredRelays.length,
      'active_subscriptions': _activeSubscriptions.length,
      'web_implementation': true,
    };
  }

  Map<String, dynamic> getRelayStatistics() {
    return {
      'connectedRelays': connectedRelays.length,
      'totalEvents': 0,
      'subscriptions': _subscriptions.length,
    };
  }

  Future<void> handleNip05Update(String nip05Identifier) async {
    // Not implemented for Web
  }

  Stream<sdk.Event> discoverRelaysFromEvents(List<sdk.Event> events) {
    return Stream.empty();
  }

  Future<void> connectToRelay(String relayUrl) async {
    if (_relayConnections.containsKey(relayUrl)) {
      return; // Already connected
    }

    try {
      final wsUrl = Uri.parse(relayUrl);
      final channel = WebSocketChannel.connect(wsUrl);

      // Listen for messages from this relay
      channel.stream.listen(
        (message) => _handleRelayMessage(relayUrl, message),
        onError: (error) => _handleRelayError(relayUrl, error),
        onDone: () => _handleRelayDisconnect(relayUrl),
      );

      _relayConnections[relayUrl] = channel;
      _configuredRelays.add(relayUrl);

      Log.info(
        'Connected to relay: $relayUrl',
        name: 'NostrServiceWeb',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.error(
        'Failed to connect to relay $relayUrl: $e',
        name: 'NostrServiceWeb',
        category: LogCategory.relay,
      );
      rethrow;
    }
  }

  Future<void> disconnectFromRelay(String relayUrl) async {
    final channel = _relayConnections[relayUrl];
    if (channel != null) {
      try {
        await channel.sink.close(status.normalClosure);
      } catch (e) {
        // Ignore close errors
      }
      _relayConnections.remove(relayUrl);
      _configuredRelays.remove(relayUrl);
    }
  }

  Future<void> reconnectToRelays() async {
    for (final relayUrl in _configuredRelays.toList()) {
      await disconnectFromRelay(relayUrl);
      await connectToRelay(relayUrl);
    }
  }

  Future<sdk.Event?> getEvent(String eventId) async {
    final filters = [
      sdk.Filter(ids: [eventId]),
    ];
    final events = await queryEvents(filters);
    return events.isNotEmpty ? events.first : null;
  }

  @override
  Future<sdk.Event?> fetchEventById(String eventId, {String? relayUrl}) async {
    // Use existing getEvent method
    return getEvent(eventId);
  }

  // Additional INostrService methods for web implementation
  @override
  Future<bool> addRelay(String relayUrl) async {
    try {
      await connectToRelay(relayUrl);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<Map<String, bool>> get authStateStream => Stream.value({});

  @override
  Future<void> closeAllSubscriptions() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _activeSubscriptions.clear();
  }

  @override
  int get connectedRelayCount => _relayConnections.length;

  @override
  Future<List<sdk.Event>> getEvents({
    required List<sdk.Filter> filters,
    int? limit,
  }) async {
    // Add limit to filters if specified
    if (limit != null) {
      for (final f in filters) {
        f.limit = limit;
      }
    }
    return queryEvents(filters);
  }

  @override
  Map<String, bool> getRelayStatus() {
    final status = <String, bool>{};
    for (final relay in _configuredRelays) {
      status[relay] = _relayConnections.containsKey(relay);
    }
    return status;
  }

  @override
  bool get hasKeys => true; // Web always has keys from keyManager

  @override
  NostrKeyManager get keyManager =>
      throw UnimplementedError('Override in subclass');

  @override
  bool get isDisposed => _isDisposed;

  @override
  bool get isVineRelayAuthenticated => true; // Web doesn't need special auth

  @override
  String? get publicKey => null; // Managed by keyManager

  @override
  Future<NostrBroadcastResult> publishFileMetadata({
    required dynamic metadata, // NIP94Metadata
    required String content,
    List<String> hashtags = const [],
  }) async {
    // For now, create a simple event
    // TODO: Properly handle NIP94Metadata when available
    final tags = <List<String>>[];

    // Add hashtags as tags
    for (final tag in hashtags) {
      tags.add(['t', tag]);
    }

    final event = sdk.Event(
      publicKey ?? '',
      1063, // File metadata event kind
      tags,
      content,
    );

    return broadcastEvent(event);
  }

  @override
  Future<void> reconnectAll() async {
    await reconnectToRelays();
  }

  @override
  Map<String, bool> get relayAuthStates =>
      Map.fromEntries(_configuredRelays.map((r) => MapEntry(r, true)));

  @override
  int get relayCount => _configuredRelays.length;

  @override
  Map<String, dynamic> get relayStatuses => getRelayStatistics();

  @override
  List<String> get relays => _configuredRelays.toList();

  @override
  Future<void> removeRelay(String relayUrl) async {
    await disconnectFromRelay(relayUrl);
  }

  @override
  Future<void> retryInitialization() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  @override
  Stream<sdk.Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    final filters = [
      sdk.Filter(
        kinds: [34236], // Video event kind
        authors: authors,
        search: query,
        limit: limit,
        since: since != null ? since.millisecondsSinceEpoch ~/ 1000 : null,
        until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      ),
    ];

    return subscribeToEvents(filters: filters);
  }

  @override
  Stream<sdk.Event> searchUsers(String query, {int? limit}) {
    final filters = [
      sdk.Filter(
        kinds: [sdk.EventKind.METADATA], // User profile event kind
        search: query,
        limit: limit,
      ),
    ];

    return subscribeToEvents(filters: filters);
  }

  @override
  void setAuthTimeout(Duration timeout) {
    // Not needed for web
  }
}
