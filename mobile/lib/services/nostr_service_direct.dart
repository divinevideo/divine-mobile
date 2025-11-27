// ABOUTME: Direct WebSocket implementation of NostrService without embedded relay
// ABOUTME: Connects directly to external Nostr relays for mobile and desktop platforms

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/nip94_metadata.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/log_batcher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Direct WebSocket implementation of NostrService
/// Connects directly to external Nostr relays without an embedded relay intermediary
class NostrServiceDirect implements INostrService {
  NostrServiceDirect(
    this._keyManager, {
    void Function()? onInitialized,
  }) : _onInitialized = onInitialized {
    UnifiedLogger.info(
      '🏗️  NostrServiceDirect CONSTRUCTOR called - creating NEW instance',
      name: 'NostrServiceDirect',
    );
    _startBatchLogging();
  }

  final NostrKeyManager _keyManager;
  final void Function()? _onInitialized;

  // Relay connections
  final List<String> _configuredRelays = [];
  final Map<String, WebSocketChannel> _relayConnections = {};
  final Map<String, StreamSubscription<dynamic>> _relayStreamSubscriptions = {};

  // Subscription management
  final Map<String, _SubscriptionState> _subscriptions = {};
  int _subscriptionCounter = 0;

  // AUTH state tracking
  final Map<String, bool> _relayAuthStates = {};
  final _authStateController = StreamController<Map<String, bool>>.broadcast();

  // State
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Event batching for compact logging
  final Map<String, Map<int, int>> _eventBatchCounts = {};
  Timer? _batchLogTimer;
  static const _batchLogInterval = Duration(seconds: 5);

  // SharedPreferences key for persisting relay configuration
  static const String _relayConfigKey = 'configured_relays';

  // Reconnection settings
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 5;
  final Map<String, int> _reconnectAttempts = {};
  final Map<String, Timer?> _reconnectTimers = {};

  void _startBatchLogging() {
    _batchLogTimer =
        Timer.periodic(_batchLogInterval, (_) => _flushBatchedLogs());
  }

  void _flushBatchedLogs() {
    if (_eventBatchCounts.isEmpty) return;

    for (final entry in _eventBatchCounts.entries) {
      final relayUrl = entry.key;
      final kindCounts = entry.value;
      final totalCount = kindCounts.values.fold(0, (sum, count) => sum + count);

      if (totalCount > 0) {
        final kindSummary =
            kindCounts.entries.map((e) => 'kind ${e.key}: ${e.value}').join(', ');
        Log.debug(
          'Received $totalCount events ($kindSummary) from $relayUrl',
          name: 'NostrServiceDirect',
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
  bool get isDisposed => _isDisposed;

  @override
  List<String> get connectedRelays => _relayConnections.keys.toList();

  @override
  String? get publicKey => _keyManager.publicKey;

  @override
  bool get hasKeys => _keyManager.hasKeys;

  @override
  NostrKeyManager get keyManager => _keyManager;

  @override
  int get relayCount => _configuredRelays.length;

  @override
  int get connectedRelayCount => _relayConnections.length;

  @override
  List<String> get relays => List.from(_configuredRelays);

  @override
  Map<String, dynamic> get relayStatuses {
    final statuses = <String, dynamic>{};
    for (final relayUrl in _configuredRelays) {
      final isConnected = _relayConnections.containsKey(relayUrl);
      statuses[relayUrl] = {
        'connected': isConnected,
        'authenticated': _relayAuthStates[relayUrl] ?? false,
      };
    }
    return statuses;
  }

  @override
  Map<String, bool> get relayAuthStates => Map.from(_relayAuthStates);

  @override
  Stream<Map<String, bool>> get authStateStream => _authStateController.stream;

  @override
  bool isRelayAuthenticated(String relayUrl) {
    return _relayAuthStates[relayUrl] ?? false;
  }

  @override
  bool get isVineRelayAuthenticated {
    return _configuredRelays.any(
      (relay) => _relayConnections.containsKey(relay),
    );
  }

  @override
  void setAuthTimeout(Duration timeout) {
    // Not applicable for direct connections
  }

  @override
  Future<void> initialize({List<String>? customRelays, bool enableP2P = true}) async {
    if (_isDisposed) throw StateError('NostrServiceDirect is disposed');
    if (_isInitialized) {
      UnifiedLogger.info(
        '🔄 initialize() called but service is already initialized',
        name: 'NostrServiceDirect',
      );
      return;
    }

    UnifiedLogger.info(
      '🚀 initialize() called - starting NostrServiceDirect initialization',
      name: 'NostrServiceDirect',
    );

    Log.info(
      'Starting initialization with direct relay connections',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    // Load relay configuration
    List<String> relaysToAdd;
    if (customRelays != null) {
      relaysToAdd = customRelays;
      Log.info(
        'Using provided customRelays: $customRelays',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedRelays = prefs.getStringList(_relayConfigKey);

      if (savedRelays != null && savedRelays.isNotEmpty) {
        relaysToAdd = savedRelays;
        Log.info(
          '✅ Loaded ${savedRelays.length} relay(s) from SharedPreferences',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );

        // Migration: Remove old relay if present
        const oldRelay = 'wss://relay3.openvine.co';
        if (relaysToAdd.contains(oldRelay)) {
          Log.info(
            '🔄 MIGRATION: Removing old relay from saved config: $oldRelay',
            name: 'NostrServiceDirect',
            category: LogCategory.relay,
          );
          relaysToAdd = relaysToAdd.where((r) => r != oldRelay).toList();
          await _saveRelayConfig(relaysToAdd);
        }
      } else {
        final defaultRelay = AppConstants.defaultRelayUrl;
        relaysToAdd = [defaultRelay];
        Log.info(
          '📋 No saved relay config found, using default: $defaultRelay',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
        await _saveRelayConfig(relaysToAdd);
      }
    }

    // Ensure default relay is always included
    final defaultRelay = AppConstants.defaultRelayUrl;
    if (!relaysToAdd.contains(defaultRelay)) {
      relaysToAdd.add(defaultRelay);
    }

    UnifiedLogger.info('📋 Relays to be loaded at startup:', name: 'NostrServiceDirect');
    for (var relay in relaysToAdd) {
      UnifiedLogger.info('   - $relay', name: 'NostrServiceDirect');
    }

    // Connect to relays
    for (final relayUrl in relaysToAdd) {
      try {
        await _connectToRelay(relayUrl);
        _configuredRelays.add(relayUrl);
      } catch (e, stackTrace) {
        Log.error(
          '❌ Failed to connect to relay $relayUrl: $e',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
        CrashReportingService.instance.recordError(
          Exception('Exception adding relay: $relayUrl - $e'),
          stackTrace,
          reason: 'Configured relays: ${_configuredRelays.length}',
        );
        // Still add to configured list for retry capability
        _configuredRelays.add(relayUrl);
      }
    }

    final connectedCount = _relayConnections.length;
    Log.info(
      '🎯 Relay connection complete: $connectedCount/${_configuredRelays.length} relays connected',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    if (connectedCount == 0 && _configuredRelays.isNotEmpty) {
      Log.error(
        '⚠️ WARNING: No relays connected! App will have limited functionality.',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
      CrashReportingService.instance.recordError(
        Exception('CRITICAL: No relays connected'),
        StackTrace.current,
        reason: 'All relay connections failed\n'
            'Configured relays: ${_configuredRelays.join(", ")}',
      );
    }

    _isInitialized = true;
    _onInitialized?.call();
    Log.info(
      'Initialization complete with ${_configuredRelays.length} configured relays',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );
  }

  Future<void> _connectToRelay(String relayUrl) async {
    if (_relayConnections.containsKey(relayUrl)) {
      Log.debug(
        'Already connected to $relayUrl',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
      return;
    }

    final connectStart = DateTime.now();
    Log.info(
      '🔌 Connecting to relay: $relayUrl',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    try {
      final wsUrl = Uri.parse(relayUrl);
      final channel = WebSocketChannel.connect(wsUrl);

      // Wait for the connection to be established
      await channel.ready;

      final subscription = channel.stream.listen(
        (message) => _handleRelayMessage(relayUrl, message),
        onError: (error) => _handleRelayError(relayUrl, error),
        onDone: () => _handleRelayDisconnect(relayUrl),
        cancelOnError: false,
      );

      _relayConnections[relayUrl] = channel;
      _relayStreamSubscriptions[relayUrl] = subscription;
      _relayAuthStates[relayUrl] = true; // Assume authenticated initially
      _reconnectAttempts[relayUrl] = 0;

      final connectDuration = DateTime.now().difference(connectStart);
      Log.info(
        '✅ Connected to relay: $relayUrl (${connectDuration.inMilliseconds}ms)',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );

      // Notify auth state listeners
      _authStateController.add(Map.from(_relayAuthStates));

      // Re-subscribe existing subscriptions to this relay
      for (final subState in _subscriptions.values) {
        _sendSubscriptionToRelay(relayUrl, subState);
      }
    } catch (e) {
      final connectDuration = DateTime.now().difference(connectStart);
      Log.error(
        '❌ Failed to connect to relay: $relayUrl (${connectDuration.inMilliseconds}ms): $e',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
      _relayAuthStates[relayUrl] = false;
      _scheduleReconnect(relayUrl);
      rethrow;
    }
  }

  void _scheduleReconnect(String relayUrl) {
    final attempts = _reconnectAttempts[relayUrl] ?? 0;
    if (attempts >= _maxReconnectAttempts) {
      Log.warning(
        'Max reconnect attempts reached for $relayUrl',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
      return;
    }

    _reconnectTimers[relayUrl]?.cancel();
    final delay = _reconnectDelay * (attempts + 1);
    Log.info(
      '🔄 Scheduling reconnect for $relayUrl in ${delay.inSeconds}s (attempt ${attempts + 1})',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    _reconnectTimers[relayUrl] = Timer(delay, () async {
      if (_isDisposed) return;
      _reconnectAttempts[relayUrl] = attempts + 1;
      try {
        await _connectToRelay(relayUrl);
      } catch (e) {
        // Error already logged in _connectToRelay
      }
    });
  }

  void _handleRelayMessage(String relayUrl, dynamic message) {
    try {
      final decoded = jsonDecode(message as String) as List;
      final messageType = decoded[0] as String;

      if (messageType == 'EVENT' && decoded.length >= 3) {
        final subscriptionId = decoded[1] as String;
        final eventJson = decoded[2] as Map<String, dynamic>;

        final event = Event.fromJson(eventJson);
        _recordEventForBatching(relayUrl, event.kind);

        // Deliver event to the appropriate subscription
        final subState = _subscriptions[subscriptionId];
        if (subState != null && !subState.controller.isClosed) {
          // Check for duplicates
          if (!subState.seenEventIds.contains(event.id)) {
            subState.seenEventIds.add(event.id);

            // Handle replaceable events
            if (_isReplaceableEvent(event)) {
              final replaceKey = _getReplaceableEventKey(event);
              final existing = subState.replaceableEvents[replaceKey];
              if (existing != null && existing.$2 >= event.createdAt) {
                // Existing event is newer or same, skip this one
                return;
              }
              subState.replaceableEvents[replaceKey] = (event.id, event.createdAt);
            }

            subState.controller.add(event);
          }
        }
      } else if (messageType == 'EOSE' && decoded.length >= 2) {
        final subscriptionId = decoded[1] as String;
        Log.debug(
          'EOSE received from $relayUrl for subscription $subscriptionId',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );

        final subState = _subscriptions[subscriptionId];
        if (subState != null) {
          subState.eoseReceivedFrom.add(relayUrl);
          // Call onEose callback when we receive EOSE from at least one relay
          if (subState.eoseReceivedFrom.length == 1) {
            subState.onEose?.call();
          }
        }
      } else if (messageType == 'OK' && decoded.length >= 3) {
        final eventId = decoded[1] as String;
        final success = decoded[2] as bool;
        final errorMessage = decoded.length > 3 ? decoded[3] as String : '';

        Log.debug(
          'OK received from $relayUrl for event $eventId: success=$success, msg=$errorMessage',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
      } else if (messageType == 'NOTICE') {
        final notice = decoded.length > 1 ? decoded[1] as String : '';
        Log.info(
          'Notice from $relayUrl: $notice',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
      } else if (messageType == 'AUTH') {
        // NIP-42 AUTH challenge
        Log.info(
          '🔐 AUTH challenge received from $relayUrl',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
        // For now, mark as needing auth - full NIP-42 implementation would sign the challenge
        _relayAuthStates[relayUrl] = false;
        _authStateController.add(Map.from(_relayAuthStates));
      } else if (messageType == 'CLOSED' && decoded.length >= 2) {
        final subscriptionId = decoded[1] as String;
        final reason = decoded.length > 2 ? decoded[2] as String : '';
        Log.debug(
          'Subscription $subscriptionId closed by $relayUrl: $reason',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
      }
    } catch (e) {
      Log.error(
        'Error handling relay message from $relayUrl: $e',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
    }
  }

  bool _isReplaceableEvent(Event event) {
    return event.kind == 0 ||
        event.kind == 3 ||
        (event.kind >= 10000 && event.kind < 20000) ||
        (event.kind >= 30000 && event.kind < 40000);
  }

  String _getReplaceableEventKey(Event event) {
    String key = '${event.kind}:${event.pubkey}';
    if (event.kind >= 30000 && event.kind < 40000) {
      final dTag = event.tags.firstWhere(
        (tag) => tag.isNotEmpty && tag[0] == 'd',
        orElse: () => <String>[],
      );
      if (dTag.isNotEmpty && dTag.length > 1) {
        key += ':${dTag[1]}';
      }
    }
    return key;
  }

  void _handleRelayError(String relayUrl, dynamic error) {
    Log.error(
      'Relay error from $relayUrl: $error',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );
    _cleanupRelayConnection(relayUrl);
    _scheduleReconnect(relayUrl);
  }

  void _handleRelayDisconnect(String relayUrl) {
    Log.warning(
      'Relay disconnected: $relayUrl',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );
    _cleanupRelayConnection(relayUrl);
    _scheduleReconnect(relayUrl);
  }

  void _cleanupRelayConnection(String relayUrl) {
    _relayStreamSubscriptions[relayUrl]?.cancel();
    _relayStreamSubscriptions.remove(relayUrl);
    _relayConnections.remove(relayUrl);
    _relayAuthStates[relayUrl] = false;
    _authStateController.add(Map.from(_relayAuthStates));
  }

  @override
  Stream<Event> subscribeToEvents({
    required List<nostr.Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    if (_isDisposed) throw StateError('NostrServiceDirect is disposed');
    if (!_isInitialized) throw StateError('NostrServiceDirect not initialized');

    final id = 'sub_${++_subscriptionCounter}';

    // Check for too many subscriptions
    if (_subscriptions.length >= 10 && !bypassLimits) {
      Log.warning(
        'Too many concurrent subscriptions (${_subscriptions.length}). Cleaning up old ones.',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
      _cleanupClosedSubscriptions();
    }

    final controller = StreamController<Event>.broadcast();
    final subState = _SubscriptionState(
      id: id,
      filters: filters,
      controller: controller,
      onEose: onEose,
    );

    _subscriptions[id] = subState;

    // Send subscription to all connected relays
    for (final relayUrl in _relayConnections.keys) {
      _sendSubscriptionToRelay(relayUrl, subState);
    }

    // Handle controller disposal
    controller.onCancel = () {
      Log.debug(
        'Stream cancelled for subscription $id',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );

      // Remove from tracking
      _subscriptions.remove(id);

      // Send CLOSE to all relays
      for (final channel in _relayConnections.values) {
        try {
          final closeMessage = jsonEncode(['CLOSE', id]);
          channel.sink.add(closeMessage);
        } catch (e) {
          // Ignore errors when closing
        }
      }
    };

    return controller.stream;
  }

  void _sendSubscriptionToRelay(String relayUrl, _SubscriptionState subState) {
    final channel = _relayConnections[relayUrl];
    if (channel == null) return;

    try {
      final filtersJson = subState.filters.map((f) => f.toJson()).toList();
      final reqMessage = jsonEncode(['REQ', subState.id, ...filtersJson]);
      channel.sink.add(reqMessage);

      Log.debug(
        'Sent REQ to $relayUrl: ${subState.id}',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.error(
        'Failed to send subscription to $relayUrl: $e',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
    }
  }

  void _cleanupClosedSubscriptions() {
    _subscriptions.removeWhere((key, state) => state.controller.isClosed);
  }

  @override
  Future<NostrBroadcastResult> broadcastEvent(Event event) async {
    if (_isDisposed) {
      Log.warning(
        'NostrServiceDirect was disposed, attempting to reinitialize',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
      _isDisposed = false;
      _isInitialized = false;
      await initialize();
    }

    if (!_isInitialized) throw StateError('NostrServiceDirect not initialized');

    if (_relayConnections.isEmpty) {
      return NostrBroadcastResult(
        event: event,
        successCount: 0,
        totalRelays: 0,
        results: {},
        errors: {'all': 'No connected relays'},
      );
    }

    Log.info(
      '🚀 Broadcasting event ${event.id} (kind ${event.kind})',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    final results = <String, bool>{};
    final errors = <String, String>{};
    var successCount = 0;

    for (final entry in _relayConnections.entries) {
      final relayUrl = entry.key;
      final channel = entry.value;

      try {
        final eventMessage = jsonEncode(['EVENT', event.toJson()]);
        channel.sink.add(eventMessage);
        results[relayUrl] = true;
        successCount++;
        Log.debug(
          '✅ Published event to $relayUrl: ${event.id}',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
      } catch (e) {
        results[relayUrl] = false;
        errors[relayUrl] = e.toString();
        Log.error(
          '❌ Failed to broadcast to $relayUrl: $e',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
      }
    }

    Log.info(
      '📊 Broadcast Summary: $successCount/${results.length} relays',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    return NostrBroadcastResult(
      event: event,
      successCount: successCount,
      totalRelays: results.length,
      results: results,
      errors: errors,
    );
  }

  @override
  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  }) async {
    // Build tags from metadata
    final tags = <List<String>>[];

    tags.add(['url', metadata.url]);
    tags.add(['m', metadata.mimeType]);
    tags.add(['x', metadata.sha256Hash]);
    tags.add(['size', metadata.sizeBytes.toString()]);
    tags.add(['dim', metadata.dimensions]);

    if (metadata.blurhash != null) {
      tags.add(['blurhash', metadata.blurhash!]);
    }
    if (metadata.altText != null) {
      tags.add(['alt', metadata.altText!]);
    }
    if (metadata.summary != null) {
      tags.add(['summary', metadata.summary!]);
    }
    if (metadata.thumbnailUrl != null) {
      tags.add(['thumb', metadata.thumbnailUrl!]);
    }

    for (final tag in hashtags) {
      tags.add(['t', tag]);
    }

    final event = Event(
      publicKey ?? '',
      1063, // File metadata event kind
      tags,
      content,
    );

    return broadcastEvent(event);
  }

  @override
  Future<bool> addRelay(String relayUrl) async {
    UnifiedLogger.info('🔌 addRelay() called for: $relayUrl', name: 'NostrServiceDirect');

    if (_configuredRelays.contains(relayUrl)) {
      UnifiedLogger.warning(
        '⚠️  Relay already in configuration: $relayUrl',
        name: 'NostrServiceDirect',
      );
      return false;
    }

    _configuredRelays.add(relayUrl);
    await _saveRelayConfig(_configuredRelays);

    try {
      await _connectToRelay(relayUrl);
      return true;
    } catch (e) {
      UnifiedLogger.error(
        '❌ Failed to connect relay (will retry): $e',
        name: 'NostrServiceDirect',
      );
      return true; // Added to config even if not connected yet
    }
  }

  @override
  Future<void> removeRelay(String relayUrl) async {
    UnifiedLogger.info('🔌 removeRelay() called for: $relayUrl', name: 'NostrServiceDirect');

    // Disconnect
    final channel = _relayConnections[relayUrl];
    if (channel != null) {
      try {
        await channel.sink.close(status.normalClosure);
      } catch (e) {
        // Ignore close errors
      }
    }
    _cleanupRelayConnection(relayUrl);

    // Remove from config
    _configuredRelays.remove(relayUrl);
    _reconnectAttempts.remove(relayUrl);
    _reconnectTimers[relayUrl]?.cancel();
    _reconnectTimers.remove(relayUrl);

    await _saveRelayConfig(_configuredRelays);
  }

  @override
  Map<String, bool> getRelayStatus() {
    final status = <String, bool>{};
    for (final relayUrl in _configuredRelays) {
      status[relayUrl] = _relayConnections.containsKey(relayUrl);
    }
    return status;
  }

  @override
  Future<void> reconnectAll() async {
    Log.info(
      '🔄 Reconnecting to all relays...',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    for (final relayUrl in _configuredRelays) {
      if (!_relayConnections.containsKey(relayUrl)) {
        try {
          await _connectToRelay(relayUrl);
        } catch (e) {
          // Error already logged
        }
      }
    }
  }

  @override
  Future<void> retryInitialization() async {
    Log.info(
      '🔄 Starting relay connection retry...',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    final beforeConnected = _relayConnections.length;

    for (final relayUrl in _configuredRelays) {
      _reconnectAttempts[relayUrl] = 0; // Reset attempts
      if (!_relayConnections.containsKey(relayUrl)) {
        try {
          await _connectToRelay(relayUrl);
        } catch (e) {
          // Error already logged
        }
      }
    }

    final afterConnected = _relayConnections.length;
    Log.info(
      '🎯 Retry complete: $afterConnected/${_configuredRelays.length} relays connected',
      name: 'NostrServiceDirect',
      category: LogCategory.relay,
    );

    if (afterConnected > beforeConnected) {
      Log.info(
        '✨ Successfully connected ${afterConnected - beforeConnected} additional relay(s)',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
    }
  }

  @override
  Future<void> closeAllSubscriptions() async {
    for (final subState in _subscriptions.values) {
      if (!subState.controller.isClosed) {
        await subState.controller.close();
      }
    }
    _subscriptions.clear();
  }

  @override
  Future<List<Event>> getEvents({
    required List<nostr.Filter> filters,
    int? limit,
  }) async {
    if (_isDisposed) throw StateError('NostrServiceDirect is disposed');
    if (!_isInitialized) throw StateError('NostrServiceDirect not initialized');

    final events = <String, Event>{};
    final completer = Completer<List<Event>>();

    final subscription = subscribeToEvents(
      filters: filters,
      onEose: () {
        if (!completer.isCompleted) {
          // Give a short delay for any remaining events
          Timer(const Duration(milliseconds: 100), () {
            if (!completer.isCompleted) {
              completer.complete(events.values.toList());
            }
          });
        }
      },
    );

    final streamSubscription = subscription.listen((event) {
      events[event.id] = event;
      if (limit != null && events.length >= limit) {
        if (!completer.isCompleted) {
          completer.complete(events.values.toList());
        }
      }
    });

    // Timeout after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(events.values.toList());
      }
    });

    final result = await completer.future;
    await streamSubscription.cancel();
    return result;
  }

  @override
  Future<Event?> fetchEventById(String eventId, {String? relayUrl}) async {
    final events = await getEvents(
      filters: [nostr.Filter(ids: [eventId])],
      limit: 1,
    );
    return events.isNotEmpty ? events.first : null;
  }

  @override
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    if (_isDisposed) throw StateError('NostrServiceDirect is disposed');
    if (!_isInitialized) throw StateError('NostrServiceDirect not initialized');

    final filter = nostr.Filter(
      kinds: [34236, 16], // Video events + generic reposts
      authors: authors,
      since: since != null ? (since.millisecondsSinceEpoch ~/ 1000) : null,
      until: until != null ? (until.millisecondsSinceEpoch ~/ 1000) : null,
      limit: limit ?? 100,
      search: query, // NIP-50 search parameter
    );

    return subscribeToEvents(filters: [filter]);
  }

  @override
  String get primaryRelay {
    return _configuredRelays.isNotEmpty
        ? _configuredRelays.first
        : AppConstants.defaultRelayUrl;
  }

  @override
  Future<Map<String, dynamic>?> getRelayStats() async {
    if (!_isInitialized) return null;

    return {
      'connected_relays': _relayConnections.length,
      'configured_relays': _configuredRelays.length,
      'active_subscriptions': _subscriptions.length,
      'relay_auth_states': Map.from(_relayAuthStates),
      'direct_implementation': true,
    };
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    // Flush batched logs
    LogBatcher.flush();
    _flushBatchedLogs();
    _batchLogTimer?.cancel();

    UnifiedLogger.info('Starting disposal...', name: 'NostrServiceDirect');

    // Close subscriptions
    await closeAllSubscriptions();
    await _authStateController.close();

    // Cancel reconnect timers
    for (final timer in _reconnectTimers.values) {
      timer?.cancel();
    }
    _reconnectTimers.clear();

    // Close all WebSocket connections
    for (final entry in _relayConnections.entries) {
      try {
        await _relayStreamSubscriptions[entry.key]?.cancel();
        await entry.value.sink.close(status.normalClosure);
        Log.debug(
          'Closed connection to ${entry.key}',
          name: 'NostrServiceDirect',
          category: LogCategory.relay,
        );
      } catch (e) {
        // Ignore disconnect errors
      }
    }
    _relayConnections.clear();
    _relayStreamSubscriptions.clear();
    _relayAuthStates.clear();

    _isDisposed = true;
    UnifiedLogger.info('Disposal complete', name: 'NostrServiceDirect');
  }

  Future<void> _saveRelayConfig(List<String> relays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_relayConfigKey, relays);
      Log.debug(
        '💾 Saved ${relays.length} relay(s) to SharedPreferences',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.error(
        'Failed to save relay config to SharedPreferences: $e',
        name: 'NostrServiceDirect',
        category: LogCategory.relay,
      );
    }
  }
}

/// Internal state for a subscription
class _SubscriptionState {
  _SubscriptionState({
    required this.id,
    required this.filters,
    required this.controller,
    this.onEose,
  });

  final String id;
  final List<nostr.Filter> filters;
  final StreamController<Event> controller;
  final void Function()? onEose;

  final Set<String> seenEventIds = {};
  final Set<String> eoseReceivedFrom = {};
  final Map<String, (String, int)> replaceableEvents = {};
}