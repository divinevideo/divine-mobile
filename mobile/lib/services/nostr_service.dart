// ABOUTME: NostrService - production implementation using embedded relay DIRECTLY
// ABOUTME: Uses flutter_embedded_nostr_relay API directly, manages external relay connections

import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;
import 'package:logging/logging.dart' as logging;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/models/nip94_metadata.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/p2p_discovery_service.dart';
import 'package:openvine/services/p2p_video_sync_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/log_batcher.dart';

/// Production implementation of NostrService using EmbeddedNostrRelay directly
/// Manages external relay connections and provides unified API to the app
class NostrService implements INostrService {
  NostrService(this._keyManager, {embedded.EmbeddedNostrRelay? embeddedRelay}) {
    // Allow injecting an embedded relay for testing
    if (embeddedRelay != null) {
      _embeddedRelay = embeddedRelay;
    }
  }

  final NostrKeyManager _keyManager;
  final Map<String, StreamController<Event>> _subscriptions = {};
  final Map<String, bool> _relayAuthStates = {};
  final _authStateController = StreamController<Map<String, bool>>.broadcast();

  // Global recent event dedupe across all active subscriptions
  final Queue<String> _recentEventQueue = Queue<String>();
  final Set<String> _recentEventSet = <String>{};
  static const int _recentEventMax = 5000;

  // Embedded relay (handles external connections automatically)
  embedded.EmbeddedNostrRelay? _embeddedRelay;

  // P2P sync components
  P2PDiscoveryService? _p2pService;
  P2PVideoSyncService? _videoSyncService;
  bool _p2pEnabled = false;

  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _configuredRelays = [];

  @override
  Future<void> initialize(
      {List<String>? customRelays, bool enableP2P = true}) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (_isInitialized) return; // Already initialized

    Log.info('Starting initialization with embedded relay',
        name: 'NostrService', category: LogCategory.relay);

    // Ensure default relay is always included
    final defaultRelay = 'wss://relay3.openvine.co';
    final relaysToAdd = customRelays ?? [defaultRelay];
    if (!relaysToAdd.contains(defaultRelay)) {
      relaysToAdd.add(defaultRelay);
    }

    try {
      // Skip embedded relay initialization on web platform
      if (kIsWeb) {
        Log.info('Skipping embedded relay initialization on web platform',
            name: 'NostrService', category: LogCategory.relay);
        CrashReportingService.instance.logInitializationStep('Skipped embedded relay on web');
      } else {
        // Initialize embedded relay (use injected instance if provided)
        _embeddedRelay ??= embedded.EmbeddedNostrRelay();

        Log.info('Initializing embedded relay...',
            name: 'NostrService', category: LogCategory.relay);
        CrashReportingService.instance.logInitializationStep('Creating embedded relay instance');

        try {
          CrashReportingService.instance.logInitializationStep('Starting embedded relay initialization');
          await _embeddedRelay!.initialize(
            logLevel: logging.Level.WARNING, // Reduce logging spam - only warnings and errors
            enableGarbageCollection: true,
          );
          Log.info('Embedded relay initialized successfully',
              name: 'NostrService', category: LogCategory.relay);
          CrashReportingService.instance.logInitializationStep('Embedded relay initialized successfully');
        } catch (e) {
        Log.error('Embedded relay initialization encountered issues: $e',
            name: 'NostrService', category: LogCategory.relay);
        CrashReportingService.instance.recordError(e, StackTrace.current,
            reason: 'Embedded relay initialization failed');
        CrashReportingService.instance.logInitializationStep('Embedded relay failed: $e');

        // Check if this is a Web platform issue (path_provider not supported)
        if (e.toString().contains('path_provider') ||
            e.toString().contains('getApplicationDocumentsDirectory')) {
          Log.warning('Embedded relay not supported on Web platform, will use fallback',
              name: 'NostrService', category: LogCategory.relay);
          _embeddedRelay = null; // Clear the failed instance
        } else {
          // On iOS, the relay might continue with limited functionality
          // Check if it's still marked as initialized
          if (!_embeddedRelay!.isInitialized) {
            Log.warning('Embedded relay failed to initialize properly',
                name: 'NostrService', category: LogCategory.relay);
          } else {
            Log.info('Embedded relay continuing with limited functionality',
                name: 'NostrService', category: LogCategory.relay);
          }
        }
      }
      }

      // Initialize embeddedRelayFailed for web platform
      bool embeddedRelayFailed = kIsWeb;

      // Add external relays (embedded relay will manage connections if available)
      if (!embeddedRelayFailed && _embeddedRelay != null) {
        for (final relayUrl in relaysToAdd) {
          try {
            await _embeddedRelay!.addExternalRelay(relayUrl);
            _configuredRelays.add(relayUrl);
            Log.info('Added external relay: $relayUrl',
                name: 'NostrService', category: LogCategory.relay);

            // Check if the relay is actually connected
            final connectedRelays = _embeddedRelay!.connectedRelays;
            Log.debug('Connected relays after adding: $connectedRelays',
                name: 'NostrService', category: LogCategory.relay);
          } catch (e) {
            Log.error('Failed to add relay $relayUrl: $e',
                name: 'NostrService', category: LogCategory.relay);
          }
        }
      }

      // Initialize P2P sync if enabled
      if (enableP2P) {
        _p2pEnabled = true;
        // P2P initialization moved to lazy loading when needed
      }

      _isInitialized = true;
      Log.info(
          'Initialization complete with ${_configuredRelays.length} external relays',
          name: 'NostrService',
          category: LogCategory.relay);
    } catch (e) {
      Log.error('Embedded relay initialization failed, attempting fallback: $e',
          name: 'NostrService', category: LogCategory.relay);

      // FALLBACK: Ensure at least the default relay is in the configured list
      // even if embedded relay fails, so UI shows the relay and retry is possible
      if (!_configuredRelays.contains(defaultRelay)) {
        _configuredRelays.add(defaultRelay);
        Log.info('Added default relay to configured list for retry capability',
            name: 'NostrService', category: LogCategory.relay);
      }

      // Mark as partially initialized to allow app to continue
      _isInitialized = true; // Allow app to continue even with failures

      // Don't throw error - let app continue with limited functionality
      Log.warning(
          'NostrService initialized with limited functionality - relay connections may need manual retry',
          name: 'NostrService',
          category: LogCategory.relay);
    }
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

    // Get status from embedded relay for all configured external relays
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];
    for (final relayUrl in _configuredRelays) {
      final isConnected = connectedRelays.contains(relayUrl);
      statuses[relayUrl] = {
        'connected': isConnected,
        'authenticated': isConnected, // Embedded relay handles auth
      };
      // Update our auth state tracking
      _relayAuthStates[relayUrl] = isConnected;
    }

    return statuses;
  }

  @override
  Map<String, bool> get relayAuthStates {
    // Update auth states from embedded relay status
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];
    for (final relayUrl in _configuredRelays) {
      _relayAuthStates[relayUrl] = connectedRelays.contains(relayUrl);
    }
    return Map.from(_relayAuthStates);
  }

  @override
  Stream<Map<String, bool>> get authStateStream => _authStateController.stream;

  @override
  bool isRelayAuthenticated(String relayUrl) {
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];
    return connectedRelays.contains(relayUrl);
  }

  @override
  bool get isVineRelayAuthenticated {
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];
    return _configuredRelays.any((relay) => connectedRelays.contains(relay));
  }

  @override
  void setAuthTimeout(Duration timeout) {
    // Not applicable for embedded relay
  }

  @override
  Stream<Event> subscribeToEvents(
      {required List<nostr.Filter> filters,
      bool bypassLimits = false,
      void Function()? onEose}) {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_embeddedRelay == null) {
      throw StateError('Embedded relay not initialized');
    }

    // Generate deterministic subscription ID based on filter content
    // This prevents duplicate subscriptions with identical filters
    final filterHash = _generateFilterHash(filters);
    final id = 'sub_$filterHash';

    // Check if we already have this exact subscription
    if (_subscriptions.containsKey(id) && !_subscriptions[id]!.isClosed) {
      Log.info('🔄 Reusing existing subscription $id with identical filters',
          name: 'NostrService', category: LogCategory.relay);
      return _subscriptions[id]!.stream;
    }

    // Check for too many concurrent subscriptions
    if (_subscriptions.length >= 10 && !bypassLimits) {
      Log.warning(
          'Too many concurrent subscriptions (${_subscriptions.length}). Cleaning up old ones.',
          name: 'NostrService',
          category: LogCategory.relay);

      // Clean up any closed controllers
      _subscriptions.removeWhere((key, controller) => controller.isClosed);

      // If still too many, aggressively close oldest profile subscriptions
      if (_subscriptions.length >= 10) {
        final profileSubs = _subscriptions.entries
            .where((entry) => entry.key.startsWith('sub_') && entry.key.contains('profiles'))
            .toList();

        // Close half of the profile subscriptions to make room
        for (int i = 0; i < profileSubs.length ~/ 2; i++) {
          final entry = profileSubs[i];
          Log.debug('Force closing old profile subscription: ${entry.key}',
              name: 'NostrService', category: LogCategory.relay);
          try {
            entry.value.close();
          } catch (e) {
            // Ignore errors when closing
          }
          _subscriptions.remove(entry.key);
        }
      }

      Log.info('After cleanup, active subscriptions: ${_subscriptions.length}',
          name: 'NostrService', category: LogCategory.relay);
    }

    final controller = StreamController<Event>.broadcast();
    // Per-subscription de-duplication to avoid duplicate EVENTs from multiple relays/filters
    final seenEventIds = <String>{};
    _subscriptions[id] = controller;
    Log.debug('Total active subscriptions: ${_subscriptions.length}',
        name: 'NostrService', category: LogCategory.relay);

    // Convert nostr_sdk filters to embedded relay filters
    final embeddedFilters = filters.map(_convertToEmbeddedFilter).toList();

    // Debug logging for filters
    Log.debug(
        'Creating subscription $id with ${embeddedFilters.length} filters',
        name: 'NostrService',
        category: LogCategory.relay);
    for (var i = 0; i < embeddedFilters.length; i++) {
      final filter = embeddedFilters[i];
      Log.debug(
          '  Filter $i: kinds=${filter.kinds}, authors=${filter.authors?.length ?? 0} authors, tags=${filter.tags}',
          name: 'NostrService',
          category: LogCategory.relay);
      // Log first few authors for debugging
      if (filter.authors != null && filter.authors!.isNotEmpty) {
        final authorsPreview = filter.authors!.take(3).join(', ');
        Log.debug('    First authors: $authorsPreview',
            name: 'NostrService', category: LogCategory.relay);
      }
    }

    // Use embedded relay directly - it handles external relay subscriptions automatically
    Log.debug('Calling embedded relay subscribe with $id',
        name: 'NostrService', category: LogCategory.relay);
    final subscription = _embeddedRelay!.subscribe(
      subscriptionId: id,
      filters: embeddedFilters,
      onEvent: (embeddedEvent) {
        // Use batched logging for repetitive relay event logs
        RelayEventLogBatcher.batchRelayEvent(subscriptionId: id);
        // Convert embedded relay event to nostr_sdk event
        final event = _convertFromEmbeddedEvent(embeddedEvent);

        // Drop duplicates for this subscription
        if (seenEventIds.contains(event.id)) {
          // Use batched logging for duplicate events
          RelayEventLogBatcher.batchDuplicateEvent(
            eventId: event.id,
            subscriptionId: id,
          );
          return;
        }
        seenEventIds.add(event.id);

        // Global dedupe: if this event was already delivered via another subscription, drop it
        if (!_rememberGlobalEvent(event.id)) {
          Log.debug(
              'Dropping globally-duplicate event ${event.id.substring(0, 8)}',
              name: 'NostrService',
              category: LogCategory.relay);
          return;
        }

        if (!controller.isClosed) {
          // Debug log for home feed events
          if (id.contains('homeFeed')) {
            Log.debug(
                'Received home feed event - kind: ${event.kind}, author: ${event.pubkey.substring(0, 8)}...',
                name: 'NostrService',
                category: LogCategory.relay);
          }
          controller.add(event);
        }
      },
      onEose: () {
        UnifiedLogger.debug('EOSE received for subscription $id',
            name: 'NostrService');
        try {
          onEose?.call();
        } catch (e) {
          UnifiedLogger.error('Error in onEose callback for $id: $e',
              name: 'NostrService');
        }

        // Auto-cleanup profile subscriptions after EOSE to prevent leaks
        if (id.contains('profile') && _subscriptions.containsKey(id)) {
          Timer(const Duration(seconds: 30), () {
            if (_subscriptions.containsKey(id)) {
              Log.debug('Auto-closing profile subscription after 30s: $id',
                  name: 'NostrService', category: LogCategory.relay);
              try {
                _subscriptions[id]?.close();
                _subscriptions.remove(id);
              } catch (e) {
                // Ignore errors
              }
            }
          });
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );

    // Handle controller disposal
    controller.onCancel = () {
      Log.debug(
          'Stream cancelled for subscription $id - closing embedded relay subscription',
          name: 'NostrService',
          category: LogCategory.relay);
      try {
        subscription.close();
        UnifiedLogger.info(
            'Successfully closed embedded relay subscription $id',
            name: 'NostrService');
      } catch (e) {
        UnifiedLogger.error('Error closing embedded relay subscription $id: $e',
            name: 'NostrService');
      }
      _subscriptions.remove(id);
      UnifiedLogger.debug(
          'Active subscriptions after removal: ${_subscriptions.length}',
          name: 'NostrService');
    };

    return controller.stream;
  }

  // Remember event id across all subscriptions. Returns true if first time seen.
  bool _rememberGlobalEvent(String eventId) {
    if (_recentEventSet.contains(eventId)) return false;
    _recentEventSet.add(eventId);
    _recentEventQueue.addLast(eventId);
    if (_recentEventQueue.length > _recentEventMax) {
      final removed = _recentEventQueue.removeFirst();
      _recentEventSet.remove(removed);
    }
    return true;
  }

  @override
  Future<NostrBroadcastResult> broadcastEvent(Event event) async {
    // Allow reinitializing if disposed (since we're keepAlive)
    if (_isDisposed) {
      Log.warning('NostrService was disposed, attempting to reinitialize',
          name: 'NostrService', category: LogCategory.relay);
      _isDisposed = false;
      _isInitialized = false;
      await initialize();
    }

    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_embeddedRelay == null) {
      throw StateError('Embedded relay not initialized');
    }

    // Log broadcast attempt
    Log.info('🚀 Broadcasting event ${event.id} (kind ${event.kind})',
        name: 'NostrService', category: LogCategory.relay);
    Log.info('📊 Relay Status:',
        name: 'NostrService', category: LogCategory.relay);
    Log.info('   - Embedded relay initialized: ${_embeddedRelay!.isInitialized}',
        name: 'NostrService', category: LogCategory.relay);
    Log.info('   - Configured relays: ${_configuredRelays.join(", ")}',
        name: 'NostrService', category: LogCategory.relay);
    Log.info('   - Connected relays: ${_embeddedRelay!.connectedRelays.join(", ")}',
        name: 'NostrService', category: LogCategory.relay);

    final results = <String, bool>{};
    final errors = <String, String>{};

    try {
      // Check if embedded relay is still initialized before publishing
      if (!_embeddedRelay!.isInitialized) {
        Log.warning('Embedded relay is not initialized, attempting to reinitialize',
            name: 'NostrService', category: LogCategory.relay);

        // Try to reinitialize the embedded relay
        try {
          await _embeddedRelay!.initialize(
            logLevel: logging.Level.WARNING, // Reduce logging spam - only warnings and errors
            enableGarbageCollection: true,
          );
          Log.info('Embedded relay reinitialized successfully',
              name: 'NostrService', category: LogCategory.relay);

          // Re-add external relays
          for (final relayUrl in _configuredRelays) {
            try {
              await _embeddedRelay!.addExternalRelay(relayUrl);
              Log.info('Re-added external relay: $relayUrl',
                  name: 'NostrService', category: LogCategory.relay);
            } catch (e) {
              Log.warning('Failed to re-add external relay $relayUrl: $e',
                  name: 'NostrService', category: LogCategory.relay);
            }
          }
        } catch (e) {
          Log.error('Failed to reinitialize embedded relay: $e',
              name: 'NostrService', category: LogCategory.relay);
          throw StateError('Embedded relay cannot be reinitialized: $e');
        }
      }

      // Convert nostr_sdk event to embedded relay event
      final embeddedEvent = _convertToEmbeddedEvent(event);

      // Debug logging for contact list events
      if (event.kind == 3) {
        Log.info('📋 Publishing contact list event to embedded relay',
            name: 'NostrService', category: LogCategory.relay);
      }

      // Try to publish with stream closure recovery
      bool success = false;
      try {
        // Publish to embedded relay - it will automatically forward to external relays
        Log.info('📤 Publishing to embedded relay...',
            name: 'NostrService', category: LogCategory.relay);
        success = await _embeddedRelay!.publish(embeddedEvent);
        Log.info('✅ Embedded relay publish result: $success',
            name: 'NostrService', category: LogCategory.relay);
      } catch (e) {
        Log.error('❌ Embedded relay publish error: $e',
            name: 'NostrService', category: LogCategory.relay);
        // Check if the error is due to stream closure
        if (e.toString().contains('Cannot add new events after calling close') ||
            e.toString().contains('Bad state')) {
          Log.warning('Embedded relay stream closed, attempting recovery',
              name: 'NostrService', category: LogCategory.relay);

          // Try to reinitialize the embedded relay completely
          try {
            // Create a new embedded relay instance
            _embeddedRelay = embedded.EmbeddedNostrRelay();
            await _embeddedRelay!.initialize(
              enableGarbageCollection: false, // TEMPORARY: Disable GC to test storage issue
            );

            // Re-add external relays
            for (final relayUrl in _configuredRelays) {
              try {
                await _embeddedRelay!.addExternalRelay(relayUrl);
                Log.info('Re-added external relay after recovery: $relayUrl',
                    name: 'NostrService', category: LogCategory.relay);
              } catch (e) {
                Log.warning('Failed to re-add external relay $relayUrl: $e',
                    name: 'NostrService', category: LogCategory.relay);
              }
            }

            // Retry the publish
            success = await _embeddedRelay!.publish(embeddedEvent);
            Log.info('Successfully published after stream recovery',
                name: 'NostrService', category: LogCategory.relay);
          } catch (recoveryError) {
            Log.error('Failed to recover from stream closure: $recoveryError',
                name: 'NostrService', category: LogCategory.relay);
            rethrow;
          }
        } else {
          // Re-throw other errors
          rethrow;
        }
      }

      if (success) {
        // Mark local and connected external relays as successful
        results['local'] = true;
        Log.info('✅ Local embedded relay: SUCCESS',
            name: 'NostrService', category: LogCategory.relay);

        // The embedded relay handles external relay publishing
        for (final relayUrl in _configuredRelays) {
          final isConnected =
              _embeddedRelay!.connectedRelays.contains(relayUrl);
          results[relayUrl] = isConnected;
          if (isConnected) {
            Log.info('✅ External relay $relayUrl: CONNECTED (event forwarded)',
                name: 'NostrService', category: LogCategory.relay);
          } else {
            Log.warning('⚠️  External relay $relayUrl: NOT CONNECTED',
                name: 'NostrService', category: LogCategory.relay);
            errors[relayUrl] = 'Relay not connected';
          }
        }
      } else {
        results['local'] = false;
        errors['local'] = 'Event rejected by embedded relay';
        Log.error('❌ Local embedded relay: REJECTED',
            name: 'NostrService', category: LogCategory.relay);

        // Mark all external relays as failed too
        for (final relayUrl in _configuredRelays) {
          results[relayUrl] = false;
          errors[relayUrl] = 'Local relay publish failed';
          Log.error('❌ External relay $relayUrl: FAILED (local publish rejected)',
              name: 'NostrService', category: LogCategory.relay);
        }
      }
    } catch (e) {
      results['local'] = false;
      errors['local'] = e.toString();

      // Mark all external relays as failed too
      for (final relayUrl in _configuredRelays) {
        results[relayUrl] = false;
        errors[relayUrl] = 'Embedded relay error: $e';
      }
    }

    final successCount = results.values.where((success) => success).length;

    Log.info('📊 Broadcast Summary:',
        name: 'NostrService', category: LogCategory.relay);
    Log.info('   - Success: $successCount/${results.length} relays',
        name: 'NostrService', category: LogCategory.relay);
    Log.info('   - Results: $results',
        name: 'NostrService', category: LogCategory.relay);
    if (errors.isNotEmpty) {
      Log.info('   - Errors: $errors',
          name: 'NostrService', category: LogCategory.relay);
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
    // TODO: Implement file metadata publishing to embedded relay
    throw UnimplementedError('File metadata publishing not yet implemented');
  }

  @override
  Future<bool> addRelay(String relayUrl) async {
    if (_configuredRelays.contains(relayUrl)) {
      return false; // Already added
    }

    // Add to configured list even if embedded relay isn't ready
    _configuredRelays.add(relayUrl);
    UnifiedLogger.info('Added relay to configuration: $relayUrl',
        name: 'NostrService');

    // Try to connect if embedded relay is available
    if (_embeddedRelay != null) {
      try {
        await _embeddedRelay!.addExternalRelay(relayUrl);
        UnifiedLogger.info('Connected to relay: $relayUrl',
            name: 'NostrService');

        // Notify auth state listeners
        _relayAuthStates[relayUrl] = true;
        _authStateController.add(Map.from(_relayAuthStates));

        return true;
      } catch (e) {
        UnifiedLogger.error('Failed to connect relay (will retry): $e',
            name: 'NostrService');
      }
    } else {
      // Try to initialize embedded relay again
      await retryInitialization();
    }

    return true; // Added to config even if not connected yet
  }

  /// Retry initialization of embedded relay and reconnect configured relays
  @override
  Future<void> retryInitialization() async {
    if (_embeddedRelay != null) {
      UnifiedLogger.info('Embedded relay already exists', name: 'NostrService');

      // Try to reconnect configured relays
      for (final relayUrl in _configuredRelays) {
        try {
          await _embeddedRelay!.addExternalRelay(relayUrl);
          _relayAuthStates[relayUrl] = true;
          UnifiedLogger.info('Reconnected to relay: $relayUrl',
              name: 'NostrService');
        } catch (e) {
          UnifiedLogger.error('Failed to reconnect relay $relayUrl: $e',
              name: 'NostrService');
        }
      }
      _authStateController.add(Map.from(_relayAuthStates));
      return;
    }

    UnifiedLogger.info('Retrying embedded relay initialization...',
        name: 'NostrService');

    try {
      // Try to initialize embedded relay again
      _embeddedRelay = embedded.EmbeddedNostrRelay();
      await _embeddedRelay!.initialize(
        logLevel: logging.Level.WARNING, // Reduce logging spam - only warnings and errors
        enableGarbageCollection: true,
      );
      UnifiedLogger.info('Embedded relay initialized on retry',
          name: 'NostrService');

      // Reconnect all configured relays
      for (final relayUrl in _configuredRelays) {
        try {
          await _embeddedRelay!.addExternalRelay(relayUrl);
          _relayAuthStates[relayUrl] = true;
          UnifiedLogger.info('Reconnected to relay: $relayUrl',
              name: 'NostrService');
        } catch (e) {
          UnifiedLogger.error('Failed to reconnect relay $relayUrl: $e',
              name: 'NostrService');
        }
      }

      // Notify auth state listeners
      _authStateController.add(Map.from(_relayAuthStates));
    } catch (e) {
      UnifiedLogger.error('Embedded relay retry failed: $e',
          name: 'NostrService');
    }
  }

  @override
  Future<void> removeRelay(String relayUrl) async {
    if (_embeddedRelay != null) {
      try {
        await _embeddedRelay!.removeExternalRelay(relayUrl);
      } catch (e) {
        UnifiedLogger.error('Failed to remove relay $relayUrl: $e',
            name: 'NostrService');
      }
    }

    _configuredRelays.remove(relayUrl);
    _relayAuthStates.remove(relayUrl);
    UnifiedLogger.info('Removed external relay: $relayUrl',
        name: 'NostrService');
  }

  @override
  Map<String, bool> getRelayStatus() {
    final status = <String, bool>{};
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];

    for (final relayUrl in _configuredRelays) {
      status[relayUrl] = connectedRelays.contains(relayUrl);
    }

    return status;
  }

  @override
  Future<void> reconnectAll() async {
    if (!_isInitialized) return;

    // Embedded relay doesn't need reconnection
    // TODO: Reconnect external relays if needed
  }

  @override
  Future<void> closeAllSubscriptions() async {
    for (final controller in _subscriptions.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _subscriptions.clear();

    // TODO: Close embedded relay subscriptions
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
    if (_embeddedRelay == null) {
      throw StateError('Embedded relay not initialized');
    }

    // Create filter for video events - using NIP-71 video kinds + reposts
    final filter = embedded.Filter(
      kinds: [34236, 34235, 22, 21, 6], // Video event kinds + repost (kind 6)
      authors: authors,
      since: since != null ? (since.millisecondsSinceEpoch ~/ 1000) : null,
      until: until != null ? (until.millisecondsSinceEpoch ~/ 1000) : null,
      limit: limit ?? 100,
    );

    // Use embedded relay to query cached events from external relays
    final controller = StreamController<Event>();

    () async {
      try {
        final embeddedEvents = await _embeddedRelay!.queryEvents([filter]);
        final searchQuery = query.toLowerCase();

        // Filter events based on search query
        for (final embeddedEvent in embeddedEvents) {
          // Search in content
          bool matches =
              embeddedEvent.content.toLowerCase().contains(searchQuery);

          // Also search in tags (title, description, etc.)
          if (!matches) {
            for (final tag in embeddedEvent.tags) {
              if (tag
                  .any((value) => value.toLowerCase().contains(searchQuery))) {
                matches = true;
                break;
              }
            }
          }

          // Add matching events to the stream
          if (matches && !controller.isClosed) {
            final event = _convertFromEmbeddedEvent(embeddedEvent);
            controller.add(event);
          }
        }

        // Close the stream when done
        if (!controller.isClosed) {
          await controller.close();
        }
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
  String get primaryRelay => _configuredRelays.isNotEmpty
      ? _configuredRelays.first
      : 'wss://relay3.openvine.co';

  /// Get embedded relay statistics for performance monitoring
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
        'p2p_peers': _p2pService?.peers.length ?? 0,
        'p2p_connections': _p2pService?.connections.length ?? 0,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // P2P Sync Methods

  /// Start P2P discovery for nearby divine devices
  Future<bool> startP2PDiscovery() async {
    if (!_p2pEnabled) return false;

    await _ensureP2PInitialized();
    if (_p2pService == null) return false;

    try {
      await _p2pService!.startDiscovery();
      return true;
    } catch (e) {
      UnifiedLogger.error('Failed to start P2P discovery: $e',
          name: 'NostrService');
      return false;
    }
  }

  /// Stop P2P discovery
  Future<void> stopP2PDiscovery() async {
    if (_p2pService != null) {
      await _p2pService!.stopDiscovery();
    }
  }

  /// Start advertising this device for P2P connections
  Future<bool> startP2PAdvertising() async {
    if (!_p2pEnabled) return false;

    await _ensureP2PInitialized();
    if (_p2pService == null) return false;

    try {
      await _p2pService!.startAdvertising();
      return true;
    } catch (e) {
      UnifiedLogger.error('Failed to start P2P advertising: $e',
          name: 'NostrService');
      return false;
    }
  }

  /// Stop advertising this device
  Future<void> stopP2PAdvertising() async {
    if (_p2pService != null) {
      await _p2pService!.stopAdvertising();
    }
  }

  /// Get list of discovered P2P peers
  List<P2PPeer> getP2PPeers() {
    return _p2pService?.peers ?? [];
  }

  /// Connect to a P2P peer and start syncing video events
  Future<bool> connectToP2PPeer(P2PPeer peer) async {
    if (!_p2pEnabled) return false;

    await _ensureP2PInitialized();
    if (_p2pService == null) return false;

    try {
      final connection = await _p2pService!.connectToPeer(peer);
      if (connection != null) {
        // Setup event sync inline instead of separate method
        connection.dataStream.listen(
          (data) => _handleP2PMessage(connection.peer.id, data),
          onError: (error) => UnifiedLogger.error(
              'P2P: Data stream error from ${connection.peer.name}: $error',
              name: 'NostrService'),
        );
        return true;
      }
    } catch (e) {
      UnifiedLogger.error('Failed to connect to P2P peer ${peer.name}: $e',
          name: 'NostrService');
    }

    return false;
  }

  /// Sync video events with all connected P2P peers
  Future<void> syncWithP2PPeers() async {
    if (!_p2pEnabled || _videoSyncService == null) return;

    try {
      await _videoSyncService!.syncWithAllPeers();
      UnifiedLogger.info('P2P: Video sync completed with all peers',
          name: 'NostrService');
    } catch (e) {
      UnifiedLogger.error('Failed to sync with P2P peers: $e',
          name: 'NostrService');
    }
  }

  /// Start automatic P2P video syncing
  Future<void> startAutoP2PSync(
      {Duration interval = const Duration(minutes: 5)}) async {
    if (!_p2pEnabled || _videoSyncService == null) return;

    await _videoSyncService!.startAutoSync(interval: interval);
    UnifiedLogger.info('P2P: Auto video sync started', name: 'NostrService');
  }

  /// Stop automatic P2P video syncing
  Future<void> stopAutoP2PSync() async {
    if (_videoSyncService != null) {
      _videoSyncService!.stopAutoSync();
      UnifiedLogger.info('P2P: Auto video sync stopped', name: 'NostrService');
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    // Flush any remaining batched logs
    LogBatcher.flush();

    UnifiedLogger.info('Starting disposal...', name: 'NostrService');

    // Close all active subscriptions
    await closeAllSubscriptions();
    await _authStateController.close();

    // Note: No nostr_sdk client or WebSocket server to disconnect
    // We use the embedded relay directly

    // Shutdown embedded relay - only if we're truly disposing
    // In production, we want to avoid shutting down the relay if the service is still needed
    if (_embeddedRelay != null) {
      try {
        // Check if the relay is still being used before shutting down
        if (_embeddedRelay!.isInitialized) {
          UnifiedLogger.info('Embedded relay is still initialized, checking if shutdown is safe',
              name: 'NostrService');
          
          // For now, we'll skip shutdown to avoid the "cannot add events after close" error
          // The relay will be cleaned up when the app terminates
          UnifiedLogger.warning(
              'Skipping embedded relay shutdown to prevent event publishing issues',
              name: 'NostrService');
          
          // Optionally disconnect from external relays without shutting down the embedded relay
          for (final relayUrl in _configuredRelays) {
            try {
              await _embeddedRelay!.removeExternalRelay(relayUrl);
              UnifiedLogger.info('Removed external relay: $relayUrl',
                  name: 'NostrService');
            } catch (e) {
              UnifiedLogger.warning('Failed to remove external relay $relayUrl: $e',
                  name: 'NostrService');
            }
          }
          _configuredRelays.clear();
        }
      } catch (e) {
        UnifiedLogger.error('Error during embedded relay cleanup: $e',
            name: 'NostrService');
      }
      
      // Don't null out the embedded relay reference to allow potential reuse
      // _embeddedRelay = null;
    }

    // Clean up P2P services
    _p2pService?.dispose();
    _videoSyncService?.dispose();
    _p2pService = null;
    _videoSyncService = null;

    _isDisposed = true;
    UnifiedLogger.info('Disposal complete', name: 'NostrService');
  }

  /// Get events from the embedded relay (which caches from external relays)
  @override
  Future<List<Event>> getEvents({
    required List<nostr.Filter> filters,
    int? limit,
  }) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');
    if (_embeddedRelay == null) {
      throw StateError('Embedded relay not initialized');
    }

    // Convert to embedded relay filters
    final embeddedFilters = filters.map(_convertToEmbeddedFilter).toList();

    // Apply limit to first filter if provided
    if (limit != null && embeddedFilters.isNotEmpty) {
      final firstFilter = embeddedFilters[0];
      embeddedFilters[0] = embedded.Filter(
        ids: firstFilter.ids,
        authors: firstFilter.authors,
        kinds: firstFilter.kinds,
        tags: firstFilter.tags,
        since: firstFilter.since,
        until: firstFilter.until,
        limit: limit,
      );
    }

    // Query embedded relay directly
    final embeddedEvents = await _embeddedRelay!.queryEvents(embeddedFilters);

    // Convert back to nostr_sdk events
    return embeddedEvents.map(_convertFromEmbeddedEvent).toList();
  }

  // Private helper methods

  /// Convert nostr_sdk Filter to embedded relay Filter
  /// Generate a deterministic hash for a set of filters to prevent duplicate subscriptions
  String _generateFilterHash(List<nostr.Filter> filters) {
    // Create a deterministic string representation of the filters
    final parts = <String>[];

    for (final filter in filters) {
      final filterParts = <String>[];

      // Add kinds
      if (filter.kinds != null && filter.kinds!.isNotEmpty) {
        final sortedKinds = List<int>.from(filter.kinds!)..sort();
        filterParts.add('k:${sortedKinds.join(",")}');
      }

      // Add authors
      if (filter.authors != null && filter.authors!.isNotEmpty) {
        final sortedAuthors = List<String>.from(filter.authors!)..sort();
        filterParts.add('a:${sortedAuthors.join(",")}');
      }

      // Add ids
      if (filter.ids != null && filter.ids!.isNotEmpty) {
        final sortedIds = List<String>.from(filter.ids!)..sort();
        filterParts.add('i:${sortedIds.join(",")}');
      }

      // Add since/until
      if (filter.since != null) filterParts.add('s:${filter.since}');
      if (filter.until != null) filterParts.add('u:${filter.until}');

      // Add limit
      if (filter.limit != null) filterParts.add('l:${filter.limit}');

      // Add tags
      if (filter.t != null && filter.t!.isNotEmpty) {
        final sortedTags = List<String>.from(filter.t!)..sort();
        filterParts.add('t:${sortedTags.join(",")}');
      }

      // Add d tags
      if (filter.d != null && filter.d!.isNotEmpty) {
        final sortedD = List<String>.from(filter.d!)..sort();
        filterParts.add('d:${sortedD.join(",")}');
      }

      // Add p and e tags if present
      if (filter.p != null && filter.p!.isNotEmpty) {
        final sortedP = List<String>.from(filter.p!)..sort();
        filterParts.add('p:${sortedP.join(",")}');
      }
      if (filter.e != null && filter.e!.isNotEmpty) {
        final sortedE = List<String>.from(filter.e!)..sort();
        filterParts.add('e:${sortedE.join(",")}');
      }

      // Add group/h tag if used by client
      if (filter.h != null && filter.h!.isNotEmpty) {
        final sortedH = List<String>.from(filter.h!)..sort();
        filterParts.add('h:${sortedH.join(",")}');
      }

      parts.add(filterParts.join('|'));
    }

    // Create a hash from the filter string
    final filterString = parts.join('||');
    // Use a simple hash function for the subscription ID
    var hash = 0;
    for (var i = 0; i < filterString.length; i++) {
      hash = ((hash << 5) - hash) + filterString.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF; // Convert to 32-bit integer
    }
    return hash.abs().toString();
  }

  embedded.Filter _convertToEmbeddedFilter(nostr.Filter filter) {
    // Build tags map for embedded relay - note the # prefix for tag filters
    final Map<String, List<String>> tags = {};

    // Add e tags if present
    if (filter.e != null && filter.e!.isNotEmpty) {
      tags['#e'] = filter.e!;
    }

    // Add p tags if present
    if (filter.p != null && filter.p!.isNotEmpty) {
      tags['#p'] = filter.p!;
    }

    // Add t tags (hashtags) if present
    if (filter.t != null && filter.t!.isNotEmpty) {
      tags['#t'] = filter.t!;
    }

    // Add d tags (NIP-33 parameterized replaceable events) if present
    if (filter.d != null && filter.d!.isNotEmpty) {
      tags['#d'] = filter.d!;
    }

    // Add custom group tag if present (client uses 'h')
    if (filter.h != null && filter.h!.isNotEmpty) {
      tags['#h'] = filter.h!;
    }

    return embedded.Filter(
      ids: filter.ids,
      authors: filter.authors,
      kinds: filter.kinds,
      tags: tags.isNotEmpty ? tags : null,
      since: filter.since,
      until: filter.until,
      limit: filter.limit,
    );
  }

  /// Convert embedded relay NostrEvent to nostr_sdk Event
  Event _convertFromEmbeddedEvent(embedded.NostrEvent embeddedEvent) {
    return Event.fromJson({
      'id': embeddedEvent.id,
      'pubkey': embeddedEvent.pubkey,
      'created_at': embeddedEvent.createdAt,
      'kind': embeddedEvent.kind,
      'tags': embeddedEvent.tags,
      'content': embeddedEvent.content,
      'sig': embeddedEvent.sig,
    });
  }

  /// Convert nostr_sdk Event to embedded relay NostrEvent
  embedded.NostrEvent _convertToEmbeddedEvent(Event event) {
    return embedded.NostrEvent.fromJson({
      'id': event.id,
      'pubkey': event.pubkey,
      'created_at': event.createdAt,
      'kind': event.kind,
      'tags': event.tags,
      'content': event.content,
      'sig': event.sig,
    });
  }

  /// Initialize P2P sync functionality (lazy loaded)
  Future<void> _ensureP2PInitialized() async {
    if (_p2pService != null) return;

    try {
      _p2pService = P2PDiscoveryService();
      final initialized = await _p2pService!.initialize();

      if (initialized && _embeddedRelay != null) {
        // Initialize video sync service
        _videoSyncService = P2PVideoSyncService(_embeddedRelay!, _p2pService!);

        UnifiedLogger.info('P2P: Sync initialized successfully',
            name: 'NostrService');

        // Auto-start advertising when P2P is enabled
        await _p2pService!.startAdvertising();
      } else {
        UnifiedLogger.warning(
            'P2P: Initialization failed - permissions not granted',
            name: 'NostrService');
        _p2pService = null;
      }
    } catch (e) {
      UnifiedLogger.error('P2P: Initialization error: $e',
          name: 'NostrService');
      _p2pService = null;
    }
  }

  /// Handle incoming P2P messages
  Future<void> _handleP2PMessage(String peerId, List<int> data) async {
    try {
      final jsonString = utf8.decode(data);
      final message = jsonDecode(jsonString) as Map<String, dynamic>;

      // Delegate to video sync service
      if (_videoSyncService != null) {
        await _videoSyncService!.handleIncomingSync(peerId, message);
      } else {
        UnifiedLogger.warning('P2P: Video sync service not initialized',
            name: 'NostrService');
      }
    } catch (e) {
      UnifiedLogger.error('P2P: Failed to handle message from $peerId: $e',
          name: 'NostrService');
    }
  }

  // ==========================================================================
  // NIP-65 Relay Discovery Methods
  // ==========================================================================

  /// Discover and add relays from a user's profile (kind 0 and kind 10002 events)
  /// This implements NIP-65 relay list metadata
  Future<void> discoverUserRelays(String pubkey) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');

    try {
      // Query for kind 10002 (relay list metadata) - NIP-65
      final relayListFilter = embedded.Filter(
        kinds: [10002], // Relay list metadata
        authors: [pubkey],
        limit: 1,
      );

      final relayListEvents =
          await _embeddedRelay!.queryEvents([relayListFilter]);

      if (relayListEvents.isNotEmpty) {
        final relayListEvent = relayListEvents.first;
        // Parse relay list from tags
        for (final tag in relayListEvent.tags) {
          if (tag.isNotEmpty && tag[0] == 'r' && tag.length > 1) {
            final relayUrl = tag[1];
            if (!_configuredRelays.contains(relayUrl)) {
              // Check for read/write markers if present
              final isWrite = tag.length > 2 && tag[2] == 'write';
              final isRead = tag.length > 2 && tag[2] == 'read';

              await addRelay(relayUrl);
              UnifiedLogger.debug(
                  'Discovered relay from NIP-65: $relayUrl (write: $isWrite, read: $isRead)',
                  name: 'NostrService');
            }
          }
        }
      }

      // Also check for kind 3 (contact list) which sometimes includes relay hints
      final contactListFilter = embedded.Filter(
        kinds: [3], // Contact list
        authors: [pubkey],
        limit: 1,
      );

      final contactListEvents =
          await _embeddedRelay!.queryEvents([contactListFilter]);

      if (contactListEvents.isNotEmpty) {
        final contactEvent = contactListEvents.first;
        // Some clients store relay URLs in the content field as JSON
        try {
          final content = contactEvent.content;
          if (content.isNotEmpty) {
            final relayPattern = RegExp(r'wss?://[^\s,"\}]+');
            final matches = relayPattern.allMatches(content);

            for (final match in matches) {
              final relayUrl = match.group(0);
              if (relayUrl != null && !_configuredRelays.contains(relayUrl)) {
                await addRelay(relayUrl);
                UnifiedLogger.debug(
                    'Discovered relay from contact list: $relayUrl',
                    name: 'NostrService');
              }
            }
          }
        } catch (e) {
          UnifiedLogger.error('Error parsing contact list for relays: $e',
              name: 'NostrService');
        }
      }
    } catch (e) {
      UnifiedLogger.error('Error discovering user relays: $e',
          name: 'NostrService');
    }
  }

  /// Add relays that are commonly used by a user based on their event history
  Future<void> discoverRelaysFromEventHints(String pubkey) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (!_isInitialized) throw StateError('NostrService not initialized');

    try {
      // Get recent events from the user
      final userEventsFilter = embedded.Filter(
        authors: [pubkey],
        limit: 20, // Check last 20 events for relay hints
      );

      final userEvents = await _embeddedRelay!.queryEvents([userEventsFilter]);

      final discoveredRelays = <String>{};

      for (final event in userEvents) {
        // Check for relay hints in tags
        for (final tag in event.tags) {
          if (tag.length >= 3 && (tag[0] == 'e' || tag[0] == 'p')) {
            // NIP-01: ["e", <event-id>, <relay-url>] or ["p", <pubkey>, <relay-url>]
            final relayHint = tag.length > 2 ? tag[2] : null;
            if (relayHint != null && relayHint.startsWith('wss://')) {
              discoveredRelays.add(relayHint);
            }
          }
        }
      }

      // Add discovered relays
      for (final relayUrl in discoveredRelays) {
        if (!_configuredRelays.contains(relayUrl)) {
          await addRelay(relayUrl);
          UnifiedLogger.debug('Discovered relay from event hints: $relayUrl',
              name: 'NostrService');
        }
      }
    } catch (e) {
      UnifiedLogger.error('Error discovering relays from event hints: $e',
          name: 'NostrService');
    }
  }
}
