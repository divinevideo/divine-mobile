// ABOUTME: NostrService - production implementation using nostr_sdk RelayPool directly
// ABOUTME: Manages direct WebSocket connections to Nostr relays without embedded relay layer

import 'dart:async';

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:nostr_sdk/nostr.dart' as nostr_lib;
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/nip94_metadata.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/log_batcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production implementation of NostrService using nostr_sdk RelayPool directly
/// Manages direct WebSocket connections to Nostr relays without embedded relay layer
class NostrService implements INostrService, BackgroundAwareService {
  NostrService(this._keyManager, {
    void Function()? onInitialized,
  }) : _onInitialized = onInitialized {
    UnifiedLogger.info('🏗️  NostrService CONSTRUCTOR called - creating NEW instance', name: 'NostrService');
    UnifiedLogger.info('   Using direct relay connections via nostr_sdk RelayPool', name: 'NostrService');
  }

  final NostrKeyManager _keyManager;
  final void Function()? _onInitialized;
  final Map<String, StreamController<Event>> _subscriptions = {};
  final Map<String, bool> _relayAuthStates = {};
  final _authStateController = StreamController<Map<String, bool>>.broadcast();

  // Direct relay management via nostr_sdk
  nostr_lib.Nostr? _nostr;
  RelayPool? _relayPool;
  final Map<String, Relay> _relays = {};

  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _configuredRelays = [];

  // SharedPreferences key for persisting relay configuration
  static const String _relayConfigKey = 'configured_relays';

  @override
  Future<void> initialize(
      {List<String>? customRelays, bool enableP2P = true}) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (_isInitialized) {
      UnifiedLogger.info('🔄 initialize() called but service is already initialized', name: 'NostrService');
      return;
    }

    UnifiedLogger.info('🚀 initialize() called - starting NostrService initialization', name: 'NostrService');
    UnifiedLogger.info('   customRelays parameter: ${customRelays ?? "null (will use default)"}', name: 'NostrService');

    // Load relay configuration from SharedPreferences
    List<String> relaysToAdd;
    if (customRelays != null) {
      relaysToAdd = customRelays;
      UnifiedLogger.info('Using provided customRelays: $customRelays', name: 'NostrService');
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedRelays = prefs.getStringList(_relayConfigKey);

      if (savedRelays != null && savedRelays.isNotEmpty) {
        relaysToAdd = savedRelays;
        UnifiedLogger.info('✅ Loaded ${savedRelays.length} relay(s) from SharedPreferences', name: 'NostrService');
      } else {
        final defaultRelay = AppConstants.defaultRelayUrl;
        relaysToAdd = [defaultRelay];
        UnifiedLogger.info('📋 No saved relay config found, using default: $defaultRelay', name: 'NostrService');
        await _saveRelayConfig(relaysToAdd);
      }
    }

    // Ensure default relay is always included
    final defaultRelay = AppConstants.defaultRelayUrl;
    if (!relaysToAdd.contains(defaultRelay)) {
      relaysToAdd.add(defaultRelay);
    }

    UnifiedLogger.info('📋 Relays to be loaded at startup:', name: 'NostrService');
    for (var relay in relaysToAdd) {
      UnifiedLogger.info('   - $relay', name: 'NostrService');
    }

    try {
      // Initialize nostr_sdk - handle both authenticated and anonymous modes
      final privateKey = _keyManager.privateKey;
      final publicKey = _keyManager.publicKey;

      // If we have keys, create authenticated Nostr instance
      if (publicKey != null && privateKey != null) {
        UnifiedLogger.info('🔑 Creating authenticated Nostr instance with publicKey: $publicKey', name: 'NostrService');

        // Create signer from private key
        final signer = LocalNostrSigner(privateKey);

        // Create Nostr instance with RelayPool
        _nostr = nostr_lib.Nostr(
          signer,
          publicKey,
          [], // eventFilters - empty for now
          (url) => RelayBase(url, RelayStatus(url)), // tempRelayGener
        );

        _relayPool = _nostr!.relayPool;
      } else {
        // No keys available yet - this can happen on first app launch or logout
        // Initialize anyway for read-only functionality (viewing public feeds)
        UnifiedLogger.warning('🔓 No keys available - initializing in anonymous mode', name: 'NostrService');
        UnifiedLogger.warning('   Users can view public content but cannot publish until logged in', name: 'NostrService');

        // Create anonymous Nostr instance with temp keys for read-only access
        // These temp keys won't be used for publishing - only for relay connections
        final tempPrivateKey = generatePrivateKey();
        final tempPublicKey = getPublicKey(tempPrivateKey);
        final signer = LocalNostrSigner(tempPrivateKey);

        _nostr = nostr_lib.Nostr(
          signer,
          tempPublicKey,
          [], // eventFilters - empty for now
          (url) => RelayBase(url, RelayStatus(url)), // tempRelayGener
        );

        _relayPool = _nostr!.relayPool;
      }

      UnifiedLogger.info('✅ Nostr instance created successfully', name: 'NostrService');

      // Connect to relays
      UnifiedLogger.info('🔗 Connecting to ${relaysToAdd.length} relay(s)...', name: 'NostrService');

      for (final relayUrl in relaysToAdd) {
        try {
          final connectStart = DateTime.now();
          UnifiedLogger.info('🔌 Connecting to relay: $relayUrl', name: 'NostrService');

          // Create relay instance
          final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
          _relays[relayUrl] = relay;

          // Configure vine.hol.is to always require auth
          if (relayUrl.contains('vine.hol.is')) {
            relay.relayStatus.alwaysAuth = true;
            UnifiedLogger.info('🔐 Configured $relayUrl to always require auth', name: 'NostrService');
          }

          // Add to relay pool
          final success = await _relayPool!.add(relay);

          final connectDuration = DateTime.now().difference(connectStart);
          _configuredRelays.add(relayUrl);

          if (success && relay.relayStatus.connected == ClientConneccted.CONNECTED) {
            _relayAuthStates[relayUrl] = true;
            UnifiedLogger.info('✅ Relay connected: $relayUrl (${connectDuration.inMilliseconds}ms)', name: 'NostrService');
          } else {
            UnifiedLogger.error('❌ Relay FAILED to connect: $relayUrl (${connectDuration.inMilliseconds}ms)', name: 'NostrService');
            _relayAuthStates[relayUrl] = false;
          }
        } catch (e, stackTrace) {
          UnifiedLogger.error('❌ Failed to add relay $relayUrl: $e', name: 'NostrService');
          CrashReportingService.instance.recordError(
            Exception('Exception adding relay: $relayUrl - $e'),
            stackTrace,
            reason: 'Configured relays: ${_configuredRelays.length}',
          );
        }
      }

      // Final connection summary
      final connectedCount = _relays.values.where((r) => r.relayStatus.connected == ClientConneccted.CONNECTED).length;
      UnifiedLogger.info('🎯 Relay connection complete: $connectedCount/${_configuredRelays.length} relays connected', name: 'NostrService');

      if (connectedCount == 0 && _configuredRelays.isNotEmpty) {
        UnifiedLogger.error('⚠️ WARNING: No relays connected! App will have limited functionality.', name: 'NostrService');
        CrashReportingService.instance.recordError(
          Exception('CRITICAL: No relays connected'),
          StackTrace.current,
          reason: 'All relay connections failed\nConfigured relays: ${_configuredRelays.join(", ")}\nAttempted: ${_configuredRelays.length} relays\nConnected: 0 relays',
        );
      }

      _isInitialized = true;
      _onInitialized?.call();
      UnifiedLogger.info('✅ NostrService initialization complete with $connectedCount/${_configuredRelays.length} relays', name: 'NostrService');

    } catch (e, stackTrace) {
      UnifiedLogger.error('❌ NostrService initialization failed: $e', name: 'NostrService');
      CrashReportingService.instance.recordError(e, stackTrace, reason: 'NostrService initialization failed');

      // Mark as partially initialized to allow app to continue
      _isInitialized = true;
      _onInitialized?.call();

      UnifiedLogger.warning('NostrService initialized with limited functionality - relay connections may need manual retry', name: 'NostrService');
    }
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isDisposed => _isDisposed;

  @override
  List<String> get connectedRelays {
    final relays = <String>[];
    for (final entry in _relays.entries) {
      if (entry.value.relayStatus.connected == ClientConneccted.CONNECTED) {
        relays.add(entry.key);
      }
    }
    return relays;
  }

  @override
  String? get publicKey => _keyManager.publicKey;

  @override
  bool get hasKeys => _keyManager.hasKeys;

  @override
  NostrKeyManager get keyManager => _keyManager;

  @override
  int get relayCount => _configuredRelays.length;

  @override
  int get connectedRelayCount {
    return _relays.values.where((r) => r.relayStatus.connected == ClientConneccted.CONNECTED).length;
  }

  @override
  List<String> get relays => List.from(_configuredRelays);

  @override
  Map<String, dynamic> get relayStatuses {
    final statuses = <String, dynamic>{};
    for (final relayUrl in _configuredRelays) {
      final relay = _relays[relayUrl];
      final isConnected = relay?.relayStatus.connected == ClientConneccted.CONNECTED;
      statuses[relayUrl] = {
        'connected': isConnected,
        'authenticated': relay?.relayStatus.authed ?? false,
      };
      _relayAuthStates[relayUrl] = isConnected;
    }
    return statuses;
  }

  @override
  Map<String, bool> get relayAuthStates {
    for (final relayUrl in _configuredRelays) {
      final relay = _relays[relayUrl];
      _relayAuthStates[relayUrl] = relay?.relayStatus.connected == ClientConneccted.CONNECTED;
    }
    return Map.from(_relayAuthStates);
  }

  @override
  Stream<Map<String, bool>> get authStateStream => _authStateController.stream;

  @override
  bool isRelayAuthenticated(String relayUrl) {
    final relay = _relays[relayUrl];
    return relay?.relayStatus.authed ?? false;
  }

  @override
  bool get isVineRelayAuthenticated {
    return _configuredRelays.any((url) {
      final relay = _relays[url];
      return relay?.relayStatus.authed ?? false;
    });
  }

  @override
  void setAuthTimeout(Duration timeout) {
    // Not applicable for direct relay connections
  }

  @override
  Stream<Event> subscribeToEvents(
      {required List<nostr.Filter> filters,
      bool bypassLimits = false,
      void Function()? onEose}) {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_relayPool == null) {
      throw StateError('RelayPool not initialized');
    }

    final filterHash = _generateFilterHash(filters);
    final id = 'sub_$filterHash';

    if (_subscriptions.containsKey(id) && !_subscriptions[id]!.isClosed) {
      UnifiedLogger.info('🔄 Reusing existing subscription $id with identical filters', name: 'NostrService');
      return _subscriptions[id]!.stream;
    }

    if (_subscriptions.length >= 10 && !bypassLimits) {
      UnifiedLogger.warning('Too many concurrent subscriptions (${_subscriptions.length}). Cleaning up old ones.', name: 'NostrService');
      _subscriptions.removeWhere((key, controller) => controller.isClosed);
      UnifiedLogger.info('After cleanup of closed controllers: ${_subscriptions.length}', name: 'NostrService');
    }

    final controller = StreamController<Event>.broadcast();
    final seenEventIds = <String>{};
    final replaceableEvents = <String, (String, int)>{};

    _subscriptions[id] = controller;
    UnifiedLogger.debug('Total active subscriptions: ${_subscriptions.length}', name: 'NostrService');

    // Convert filters to JSON for relay pool
    final filterJsonList = filters.map((f) => f.toJson()).toList();

    UnifiedLogger.debug('Creating subscription $id with ${filterJsonList.length} filters', name: 'NostrService');
    UnifiedLogger.debug('📋 Filter JSON: ${filterJsonList.map((f) => f.toString()).join(", ")}', name: 'NostrService');

    // Subscribe via relay pool
    final subscriptionId = _relayPool!.subscribe(
      filterJsonList,
      (event) {
        // Deduplication logic
        if (seenEventIds.contains(event.id)) {
          RelayEventLogBatcher.batchDuplicateEvent(
            eventId: event.id,
            subscriptionId: id,
          );
          return;
        }

        // Handle replaceable events
        final isReplaceable = event.kind == 0 ||
            event.kind == 3 ||
            (event.kind >= 10000 && event.kind < 20000) ||
            (event.kind >= 30000 && event.kind < 40000);

        if (isReplaceable) {
          String replaceKey = '${event.kind}:${event.pubkey}';

          if (event.kind >= 30000 && event.kind < 40000) {
            final dTag = event.tags.firstWhere(
              (tag) => tag.isNotEmpty && tag[0] == 'd',
              orElse: () => <String>[],
            );
            if (dTag.isNotEmpty && dTag.length > 1) {
              replaceKey += ':${dTag[1]}';
            }
          }

          if (replaceableEvents.containsKey(replaceKey)) {
            final (oldEventId, oldTimestamp) = replaceableEvents[replaceKey]!;

            if (event.createdAt > oldTimestamp) {
              UnifiedLogger.debug('Replacing old ${event.kind} event (ts:$oldTimestamp) with newer (ts:${event.createdAt})', name: 'NostrService');
              replaceableEvents[replaceKey] = (event.id, event.createdAt);
              seenEventIds.remove(oldEventId);
              seenEventIds.add(event.id);
            } else {
              return;
            }
          } else {
            replaceableEvents[replaceKey] = (event.id, event.createdAt);
            seenEventIds.add(event.id);
          }
        } else {
          seenEventIds.add(event.id);
        }

        if (!controller.isClosed) {
          controller.add(event);
        }
      },
      id: id,
      sendAfterAuth: true, // Send after auth for relays that require it
    );

    // Handle controller disposal
    controller.onCancel = () {
      UnifiedLogger.debug('Stream cancelled for subscription $id', name: 'NostrService');
      _subscriptions.remove(id);

      Future.delayed(const Duration(seconds: 2), () async {
        try {
          _relayPool!.unsubscribe(subscriptionId);
          if (!controller.isClosed) {
            await controller.close();
          }
        } catch (e) {
          UnifiedLogger.error('Error during subscription cleanup: $e', name: 'NostrService');
        }
      });
    };

    // Call onEose if provided (note: relay pool doesn't have EOSE callback in subscribe)
    // We'll need to handle this differently or via query method
    if (onEose != null) {
      Timer(const Duration(seconds: 2), () {
        try {
          onEose();
        } catch (e) {
          UnifiedLogger.error('Error in onEose callback: $e', name: 'NostrService');
        }
      });
    }

    return controller.stream;
  }

  /// Subscribe to events using custom filter JSON (bypasses Filter class)
  /// This allows querying with custom tags like #a for addressable events
  Stream<Event> subscribeToEventsWithCustomJson({
    required List<Map<String, dynamic>> filtersJson,
    String? subscriptionId,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_relayPool == null) {
      throw StateError('RelayPool not initialized');
    }

    // Generate subscription ID from filter JSON
    final filterHash = filtersJson.map((f) => f.toString()).join('|').hashCode.toRadixString(16);
    final id = subscriptionId ?? 'sub_custom_$filterHash';

    if (_subscriptions.containsKey(id) && !_subscriptions[id]!.isClosed) {
      UnifiedLogger.info('🔄 Reusing existing subscription $id with identical filters', name: 'NostrService');
      return _subscriptions[id]!.stream;
    }

    final controller = StreamController<Event>.broadcast();
    final seenEventIds = <String>{};
    final replaceableEvents = <String, (String, int)>{};

    _subscriptions[id] = controller;
    UnifiedLogger.debug('Total active subscriptions: ${_subscriptions.length}', name: 'NostrService');

    UnifiedLogger.info('Creating custom subscription $id with ${filtersJson.length} filters', name: 'NostrService');
    UnifiedLogger.info('📋 Custom Filter JSON: ${filtersJson.map((f) => f.toString()).join(", ")}', name: 'NostrService');

    // Subscribe via relay pool with raw JSON
    UnifiedLogger.info('🔌 Calling _relayPool.subscribe() with custom filter...', name: 'NostrService');
    final subId = _relayPool!.subscribe(
      filtersJson,
      (event) {
        UnifiedLogger.info('📨 Custom subscription $id received event ${event.id} (kind ${event.kind})', name: 'NostrService');

        // Deduplication logic
        if (seenEventIds.contains(event.id)) {
          RelayEventLogBatcher.batchDuplicateEvent(
            eventId: event.id,
            subscriptionId: id,
          );
          return;
        }

        // Handle replaceable events
        final isReplaceable = event.kind == 0 ||
            event.kind == 3 ||
            (event.kind >= 10000 && event.kind < 20000) ||
            (event.kind >= 30000 && event.kind < 40000);

        if (isReplaceable) {
          String replaceKey = '${event.kind}:${event.pubkey}';

          if (event.kind >= 30000 && event.kind < 40000) {
            final dTag = event.tags.firstWhere(
              (tag) => tag.isNotEmpty && tag[0] == 'd',
              orElse: () => <String>[],
            );
            if (dTag.isNotEmpty && dTag.length > 1) {
              replaceKey += ':${dTag[1]}';
            }
          }

          if (replaceableEvents.containsKey(replaceKey)) {
            final (oldEventId, oldTimestamp) = replaceableEvents[replaceKey]!;

            if (event.createdAt > oldTimestamp) {
              UnifiedLogger.debug('Replacing old ${event.kind} event (ts:$oldTimestamp) with newer (ts:${event.createdAt})', name: 'NostrService');
              replaceableEvents[replaceKey] = (event.id, event.createdAt);
              seenEventIds.remove(oldEventId);
            } else {
              UnifiedLogger.debug('Ignoring older ${event.kind} event (ts:${event.createdAt}) vs current (ts:$oldTimestamp)', name: 'NostrService');
              return;
            }
          } else {
            replaceableEvents[replaceKey] = (event.id, event.createdAt);
          }
        }

        seenEventIds.add(event.id);

        if (!controller.isClosed) {
          controller.add(event);
        }
      },
      id: id,
      sendAfterAuth: true,
    );

    UnifiedLogger.info('✅ Subscription created with subId: $subId', name: 'NostrService');

    // Handle controller disposal
    controller.onCancel = () {
      UnifiedLogger.debug('Stream cancelled for subscription $id', name: 'NostrService');
      _subscriptions.remove(id);

      Future.delayed(const Duration(seconds: 2), () async {
        try {
          _relayPool!.unsubscribe(subId);
          if (!controller.isClosed) {
            await controller.close();
          }
        } catch (e) {
          UnifiedLogger.error('Error during subscription cleanup: $e', name: 'NostrService');
        }
      });
    };

    // Call onEose if provided
    if (onEose != null) {
      Timer(const Duration(seconds: 2), () {
        try {
          onEose();
        } catch (e) {
          UnifiedLogger.error('Error in onEose callback: $e', name: 'NostrService');
        }
      });
    }

    return controller.stream;
  }

  @override
  Future<NostrBroadcastResult> broadcastEvent(Event event) async {
    if (_isDisposed) {
      UnifiedLogger.warning('NostrService was disposed, attempting to reinitialize', name: 'NostrService');
      _isDisposed = false;
      _isInitialized = false;
      await initialize();
    }

    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_nostr == null || _relayPool == null) {
      throw StateError('Nostr or RelayPool not initialized');
    }

    // Ensure we have connected relays before broadcasting
    await ensureConnected();

    UnifiedLogger.info('🚀 Broadcasting event ${event.id} (kind ${event.kind})', name: 'NostrService');
    UnifiedLogger.info('📊 Relay Status:', name: 'NostrService');
    UnifiedLogger.info('   - Configured relays: ${_configuredRelays.join(", ")}', name: 'NostrService');
    UnifiedLogger.info('   - Connected relays: ${connectedRelays.join(", ")}', name: 'NostrService');

    final results = <String, bool>{};
    final errors = <String, String>{};

    try {
      // Send via relay pool
      final success = _relayPool!.send(["EVENT", event.toJson()]);

      if (success) {
        for (final relayUrl in _configuredRelays) {
          final relay = _relays[relayUrl];
          final isConnected = relay?.relayStatus.connected == ClientConneccted.CONNECTED;
          results[relayUrl] = isConnected;

          if (isConnected) {
            UnifiedLogger.info('✅ Relay $relayUrl: event sent', name: 'NostrService');
          } else {
            UnifiedLogger.warning('⚠️  Relay $relayUrl: NOT CONNECTED', name: 'NostrService');
            errors[relayUrl] = 'Relay not connected';
          }
        }
      } else {
        for (final relayUrl in _configuredRelays) {
          results[relayUrl] = false;
          errors[relayUrl] = 'Failed to send to relay pool';
          UnifiedLogger.error('❌ Relay $relayUrl: FAILED', name: 'NostrService');
        }
      }
    } catch (e) {
      for (final relayUrl in _configuredRelays) {
        results[relayUrl] = false;
        errors[relayUrl] = 'Exception: $e';
      }
    }

    final successCount = results.values.where((success) => success).length;

    UnifiedLogger.info('📊 Broadcast Summary:', name: 'NostrService');
    UnifiedLogger.info('   - Success: $successCount/${results.length} relays', name: 'NostrService');
    if (errors.isNotEmpty) {
      UnifiedLogger.info('   - Errors: $errors', name: 'NostrService');
    }

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
    throw UnimplementedError('File metadata publishing not yet implemented');
  }

  @override
  Future<bool> addRelay(String relayUrl) async {
    UnifiedLogger.info('🔌 addRelay() called for: $relayUrl', name: 'NostrService');

    if (_configuredRelays.contains(relayUrl)) {
      UnifiedLogger.warning('⚠️  Relay already in configuration: $relayUrl', name: 'NostrService');
      return false;
    }

    _configuredRelays.add(relayUrl);
    UnifiedLogger.info('✅ Added relay to configuration: $relayUrl', name: 'NostrService');

    await _saveRelayConfig(_configuredRelays);

    if (_relayPool != null) {
      try {
        final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
        _relays[relayUrl] = relay;

        if (relayUrl.contains('vine.hol.is')) {
          relay.relayStatus.alwaysAuth = true;
        }

        final success = await _relayPool!.add(relay);

        if (success) {
          _relayAuthStates[relayUrl] = true;
          _authStateController.add(Map.from(_relayAuthStates));
          UnifiedLogger.info('🔗 Connected to relay: $relayUrl', name: 'NostrService');
          return true;
        } else {
          UnifiedLogger.error('❌ Failed to connect relay: $relayUrl', name: 'NostrService');
        }
      } catch (e) {
        UnifiedLogger.error('❌ Exception connecting relay: $e', name: 'NostrService');
      }
    }

    return true;
  }

  @override
  Future<void> retryInitialization() async {
    UnifiedLogger.info('🔄 Starting relay connection retry...', name: 'NostrService');

    if (_relayPool == null) {
      UnifiedLogger.error('RelayPool not initialized, cannot retry', name: 'NostrService');
      return;
    }

    final beforeConnected = connectedRelays.length;
    UnifiedLogger.info('📊 Before retry: $beforeConnected/${_configuredRelays.length} relays connected', name: 'NostrService');

    // Use SDK's built-in reconnect() which calls relay.connect() on all relays
    _relayPool!.reconnect();

    // Poll for connection establishment with exponential backoff
    // Start with 100ms, double each time, up to 2 seconds max
    int pollDelay = 100;
    int totalWaited = 0;
    const maxWait = 5000; // 5 seconds total
    final connectStart = DateTime.now();

    while (connectedRelays.isEmpty && totalWaited < maxWait) {
      await Future.delayed(Duration(milliseconds: pollDelay));
      totalWaited += pollDelay;

      // Exponential backoff: 100ms -> 200ms -> 400ms -> 800ms -> 1600ms -> 2000ms (capped)
      pollDelay = (pollDelay * 2).clamp(100, 2000);
    }

    final connectDuration = DateTime.now().difference(connectStart);
    final afterConnected = connectedRelays.length;

    UnifiedLogger.info('🎯 Retry complete: $afterConnected/${_configuredRelays.length} relays connected (${connectDuration.inMilliseconds}ms)',
        name: 'NostrService');

    if (afterConnected > beforeConnected) {
      UnifiedLogger.info('✨ Successfully connected ${afterConnected - beforeConnected} additional relay(s)', name: 'NostrService');
    } else if (afterConnected == 0) {
      UnifiedLogger.error('⚠️ WARNING: Still no relays connected after retry!', name: 'NostrService');
    }

    _authStateController.add(Map.from(_relayAuthStates));
  }

  @override
  Future<void> removeRelay(String relayUrl) async {
    UnifiedLogger.info('🔌 removeRelay() called for: $relayUrl', name: 'NostrService');

    if (_relayPool != null && _relays.containsKey(relayUrl)) {
      try {
        _relayPool!.remove(relayUrl);
        _relays.remove(relayUrl);
        UnifiedLogger.info('🔗 Disconnected from relay: $relayUrl', name: 'NostrService');
      } catch (e) {
        UnifiedLogger.error('❌ Failed to remove relay: $e', name: 'NostrService');
      }
    }

    _configuredRelays.remove(relayUrl);
    _relayAuthStates.remove(relayUrl);
    UnifiedLogger.info('✅ Removed relay from configuration: $relayUrl', name: 'NostrService');

    await _saveRelayConfig(_configuredRelays);
  }

  @override
  Map<String, bool> getRelayStatus() {
    final status = <String, bool>{};
    for (final relayUrl in _configuredRelays) {
      final relay = _relays[relayUrl];
      status[relayUrl] = relay?.relayStatus.connected == ClientConneccted.CONNECTED;
    }
    return status;
  }

  @override
  Future<void> reconnectAll() async {
    if (!_isInitialized || _relayPool == null) return;

    UnifiedLogger.info('🔄 Reconnecting all relays...', name: 'NostrService');

    // Use retryInitialization() which actually waits for connections
    await retryInitialization();
  }

  /// Ensure we have at least one connected relay before performing operations
  /// Automatically attempts reconnection if no relays are connected
  Future<void> ensureConnected() async {
    if (!_isInitialized || _relayPool == null) {
      UnifiedLogger.warning('⚠️ ensureConnected: NostrService not initialized', name: 'NostrService');
      return;
    }

    if (connectedRelays.isEmpty) {
      UnifiedLogger.warning('⚠️ No relays connected, attempting reconnection...', name: 'NostrService');
      // reconnectAll() already handles polling and waiting for connections
      await reconnectAll();
    }
  }

  @override
  Future<void> closeAllSubscriptions() async {
    for (final controller in _subscriptions.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _subscriptions.clear();
  }

  @override
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_relayPool == null) {
      throw StateError('RelayPool not initialized');
    }

    final nostrFilter = nostr.Filter(
      kinds: [34236, 34235, 22, 21, 6],
      authors: authors,
      since: since != null ? (since.millisecondsSinceEpoch ~/ 1000) : null,
      until: until != null ? (until.millisecondsSinceEpoch ~/ 1000) : null,
      limit: limit ?? 100,
      search: query,
    );

    final controller = StreamController<Event>();
    final seenEventIds = <String>{};

    () async {
      try {
        final subscriptionId = _relayPool!.subscribe(
          [nostrFilter.toJson()],
          (event) {
            if (!seenEventIds.contains(event.id) && !controller.isClosed) {
              seenEventIds.add(event.id);
              controller.add(event);
            }
          },
        );

        // Close after timeout
        Timer(const Duration(seconds: 5), () async {
          try {
            _relayPool!.unsubscribe(subscriptionId);
            if (!controller.isClosed) {
              await controller.close();
            }
          } catch (e) {
            UnifiedLogger.error('Error closing search subscription: $e', name: 'NostrService');
          }
        });
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  @override
  String get primaryRelay {
    return _configuredRelays.isNotEmpty
        ? _configuredRelays.first
        : AppConstants.defaultRelayUrl;
  }

  @override
  Future<Map<String, dynamic>?> getRelayStats() async {
    if (!_isInitialized || _relayPool == null) return null;

    try {
      final stats = <String, dynamic>{};

      for (final entry in _relays.entries) {
        final relayUrl = entry.key;
        final relay = entry.value;

        stats[relayUrl] = {
          'connected': relay.relayStatus.connected == ClientConneccted.CONNECTED,
          'authenticated': relay.relayStatus.authed,
          'read_access': relay.relayStatus.readAccess,
          'write_access': relay.relayStatus.writeAccess,
        };
      }

      return {
        'relays': stats,
        'total_configured': _configuredRelays.length,
        'total_connected': connectedRelayCount,
        'subscriptions': _subscriptions.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    LogBatcher.flush();
    UnifiedLogger.info('Starting disposal...', name: 'NostrService');

    await closeAllSubscriptions();
    await _authStateController.close();

    if (_relayPool != null) {
      try {
        _relayPool!.removeAll();
        UnifiedLogger.info('Removed all relays from pool', name: 'NostrService');
      } catch (e) {
        UnifiedLogger.error('Error removing relays: $e', name: 'NostrService');
      }
    }

    _relays.clear();
    _configuredRelays.clear();
    _relayPool = null;
    _nostr = null;

    _isDisposed = true;
    UnifiedLogger.info('Disposal complete', name: 'NostrService');
  }

  @override
  Future<List<Event>> getEvents({
    required List<nostr.Filter> filters,
    int? limit,
  }) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_nostr == null) {
      throw StateError('Nostr not initialized');
    }

    final filterJsonList = filters.map((f) => f.toJson()).toList();

    // Apply limit to first filter if provided
    if (limit != null && filterJsonList.isNotEmpty) {
      filterJsonList[0]['limit'] = limit;
    }

    try {
      final events = await _nostr!.queryEvents(filterJsonList);
      return events;
    } catch (e) {
      UnifiedLogger.error('Error querying events: $e', name: 'NostrService');
      return [];
    }
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
  Future<List<Event>> queryEventsWithCustomJson({
    required List<Map<String, dynamic>> filtersJson,
  }) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_nostr == null) {
      throw StateError('Nostr not initialized');
    }

    UnifiedLogger.info('Querying events with custom JSON: ${filtersJson.map((f) => f.toString()).join(", ")}', name: 'NostrService');

    try {
      final events = await _nostr!.queryEvents(filtersJson);
      UnifiedLogger.info('✅ Query returned ${events.length} events', name: 'NostrService');
      return events;
    } catch (e) {
      UnifiedLogger.error('❌ Error querying events with custom JSON: $e', name: 'NostrService');
      return [];
    }
  }

  // Private helper methods

  String _generateFilterHash(List<nostr.Filter> filters) {
    final parts = <String>[];

    for (final filter in filters) {
      final filterParts = <String>[];

      if (filter.kinds != null && filter.kinds!.isNotEmpty) {
        final sortedKinds = List<int>.from(filter.kinds!)..sort();
        filterParts.add('k:${sortedKinds.join(",")}');
      }

      if (filter.authors != null && filter.authors!.isNotEmpty) {
        final sortedAuthors = List<String>.from(filter.authors!)..sort();
        filterParts.add('a:${sortedAuthors.join(",")}');
      }

      if (filter.ids != null && filter.ids!.isNotEmpty) {
        final sortedIds = List<String>.from(filter.ids!)..sort();
        filterParts.add('i:${sortedIds.join(",")}');
      }

      if (filter.since != null) filterParts.add('s:${filter.since}');
      if (filter.until != null) filterParts.add('u:${filter.until}');
      if (filter.limit != null) filterParts.add('l:${filter.limit}');

      if (filter.t != null && filter.t!.isNotEmpty) {
        final sortedTags = List<String>.from(filter.t!)..sort();
        filterParts.add('t:${sortedTags.join(",")}');
      }

      if (filter.d != null && filter.d!.isNotEmpty) {
        final sortedD = List<String>.from(filter.d!)..sort();
        filterParts.add('d:${sortedD.join(",")}');
      }

      if (filter.p != null && filter.p!.isNotEmpty) {
        final sortedP = List<String>.from(filter.p!)..sort();
        filterParts.add('p:${sortedP.join(",")}');
      }

      if (filter.e != null && filter.e!.isNotEmpty) {
        final sortedE = List<String>.from(filter.e!)..sort();
        filterParts.add('e:${sortedE.join(",")}');
      }

      if (filter.h != null && filter.h!.isNotEmpty) {
        final sortedH = List<String>.from(filter.h!)..sort();
        filterParts.add('h:${sortedH.join(",")}');
      }

      parts.add(filterParts.join('|'));
    }

    final filterString = parts.join('||');
    var hash = 0;
    for (var i = 0; i < filterString.length; i++) {
      hash = ((hash << 5) - hash) + filterString.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash.abs().toString();
  }

  Future<void> _saveRelayConfig(List<String> relays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_relayConfigKey, relays);
      UnifiedLogger.debug('💾 Saved ${relays.length} relay(s) to SharedPreferences', name: 'NostrService');
    } catch (e) {
      UnifiedLogger.error('Failed to save relay config: $e', name: 'NostrService');
    }
  }

  // BackgroundAwareService implementation
  @override
  String get serviceName => 'NostrService';

  @override
  void onAppBackgrounded() {
    UnifiedLogger.info('📱 App backgrounded - relay connections may be suspended by OS',
        name: 'NostrService');
    // Note: We don't proactively close connections here because:
    // 1. The OS will suspend WebSockets automatically
    // 2. Closing them explicitly might prevent proper reconnection
    // Instead, we rely on onAppResumed() to detect and fix disconnections
  }

  @override
  void onExtendedBackground() {
    UnifiedLogger.info('📱 App in extended background - relay connections likely closed by OS',
        name: 'NostrService');
    // After 30 seconds in background, assume all connections are dead
    // Mark all relays as disconnected to trigger reconnection on resume
    for (final relayUrl in _configuredRelays) {
      if (_relays[relayUrl] != null) {
        UnifiedLogger.debug('Marking relay as disconnected: $relayUrl', name: 'NostrService');
      }
    }
  }

  @override
  void onAppResumed() {
    UnifiedLogger.info('📱 App resumed - checking relay connections', name: 'NostrService');

    // Check how many relays are actually connected
    final connectedCount = connectedRelays.length;
    final totalCount = _configuredRelays.length;

    UnifiedLogger.info('📊 Relay status: $connectedCount/$totalCount connected', name: 'NostrService');

    // If no relays are connected, trigger reconnection
    if (connectedCount == 0 && totalCount > 0) {
      UnifiedLogger.warning('⚠️ No relays connected after resume, triggering reconnection',
          name: 'NostrService');

      // Trigger reconnection asynchronously (don't block the lifecycle callback)
      Future.microtask(() async {
        try {
          await reconnectAll();
          final newConnectedCount = connectedRelays.length;
          if (newConnectedCount > 0) {
            UnifiedLogger.info('✅ Relay reconnection successful: $newConnectedCount/$totalCount',
                name: 'NostrService');
          } else {
            UnifiedLogger.error('❌ Relay reconnection failed: still 0/$totalCount connected',
                name: 'NostrService');
          }
        } catch (e) {
          UnifiedLogger.error('❌ Exception during relay reconnection: $e', name: 'NostrService');
        }
      });
    } else if (connectedCount < totalCount) {
      UnifiedLogger.warning('⚠️ Some relays disconnected ($connectedCount/$totalCount), triggering reconnection',
          name: 'NostrService');

      // Some relays disconnected - reconnect them
      Future.microtask(() async {
        try {
          await reconnectAll();
        } catch (e) {
          UnifiedLogger.error('❌ Exception during partial relay reconnection: $e', name: 'NostrService');
        }
      });
    } else {
      UnifiedLogger.info('✅ All relays still connected after resume', name: 'NostrService');
    }
  }

  @override
  void onPeriodicCleanup() {
    // Check relay health periodically
    final connectedCount = connectedRelays.length;
    final totalCount = _configuredRelays.length;

    if (connectedCount < totalCount) {
      UnifiedLogger.warning('🧹 Periodic cleanup: some relays disconnected ($connectedCount/$totalCount)',
          name: 'NostrService');

      // Trigger reconnection if some relays are down
      Future.microtask(() async {
        try {
          await reconnectAll();
        } catch (e) {
          UnifiedLogger.error('❌ Exception during periodic relay reconnection: $e', name: 'NostrService');
        }
      });
    }
  }
}
