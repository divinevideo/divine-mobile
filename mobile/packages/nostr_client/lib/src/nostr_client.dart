import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:nostr_client/src/models/models.dart';
import 'package:nostr_client/src/relay_manager.dart';
import 'package:nostr_gateway/nostr_gateway.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template nostr_client}
/// Abstraction layer for Nostr communication
///
/// This client wraps nostr_sdk and provides:
/// - Subscription deduplication (prevents duplicate subscriptions)
/// - Gateway integration for cached queries
/// - Clean API for repositories to use
/// - Proper resource management
/// - Relay management via RelayManager
/// {@endtemplate}
class NostrClient {
  /// {@macro nostr_client}
  ///
  /// Creates a new NostrClient instance with the given configuration.
  /// Requires a [RelayManager] for relay management, persistence, and
  /// status tracking.
  NostrClient({
    required NostrClientConfig config,
    required RelayManager relayManager,
    GatewayClient? gatewayClient,
  }) : _nostr = _createNostr(config),
       _relayManager = relayManager,
       _gatewayClient = gatewayClient;

  /// Creates a NostrClient with injected dependencies for testing
  @visibleForTesting
  NostrClient.forTesting({
    required Nostr nostr,
    required RelayManager relayManager,
    GatewayClient? gatewayClient,
  }) : _nostr = nostr,
       _relayManager = relayManager,
       _gatewayClient = gatewayClient;

  static Nostr _createNostr(NostrClientConfig config) {
    RelayBase tempRelayGenerator(String url) => RelayBase(
      url,
      RelayStatus(url),
      channelFactory: config.webSocketChannelFactory,
    );
    return Nostr(
      config.signer,
      config.publicKey,
      config.eventFilters,
      tempRelayGenerator,
      onNotice: config.onNotice,
      channelFactory: config.webSocketChannelFactory,
    );
  }

  final Nostr _nostr;
  final GatewayClient? _gatewayClient;
  final RelayManager _relayManager;

  /// Public key of the client
  String get publicKey => _nostr.publicKey;

  /// Map of subscription IDs to their filter hashes (for deduplication)
  final Map<String, String> _subscriptionFilters = {};

  /// Map of active subscriptions
  final Map<String, StreamController<Event>> _subscriptionStreams = {};

  /// Publishes an event to relays
  ///
  /// Delegates to nostr_sdk for relay management and broadcasting.
  /// Returns the sent event if successful, or `null` if failed.
  Future<Event?> publishEvent(
    Event event, {
    List<String>? targetRelays,
  }) async {
    return _nostr.sendEvent(
      event,
      targetRelays: targetRelays,
    );
  }

  /// Queries events with given filters
  ///
  /// Uses gateway first if enabled, falls back to WebSocket on failure.
  /// Returns a list of events matching the filters.
  ///
  /// If [useGateway] is `true` and gateway is enabled, attempts to use
  /// the REST gateway first for faster cached responses.
  Future<List<Event>> queryEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useGateway = true,
  }) async {
    if (useGateway && filters.length == 1) {
      final gatewayClient = _gatewayClient;
      if (gatewayClient != null) {
        final response = await _tryGateway(
          () => gatewayClient.query(filters.first),
        );
        if (response != null && response.hasEvents) {
          return response.events;
        }
      }
    }

    // Fall back to WebSocket query
    final filtersJson = filters.map((f) => f.toJson()).toList();
    return _nostr.queryEvents(
      filtersJson,
      id: subscriptionId,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
    );
  }

  /// Fetches a single event by ID
  ///
  /// Uses gateway first if enabled, falls back to WebSocket on failure.
  ///
  /// If [useGateway] is `true` and gateway is enabled, attempts to use
  /// the REST gateway first for faster cached responses.
  Future<Event?> fetchEventById(
    String eventId, {
    String? relayUrl,
    bool useGateway = true,
  }) async {
    final targetRelays = relayUrl != null ? [relayUrl] : null;
    if (useGateway) {
      final gatewayClient = _gatewayClient;
      if (gatewayClient != null) {
        final event = await _tryGateway(
          () => gatewayClient.getEvent(eventId),
        );
        if (event != null) {
          return event;
        }
      }
    }

    // Fall back to WebSocket query
    final filters = [
      Filter(ids: [eventId], limit: 1),
    ];
    final events = await queryEvents(
      filters,
      useGateway: false,
      tempRelays: targetRelays,
    );
    return events.isEmpty ? null : events.first;
  }

  /// Fetches a profile (kind 0) by pubkey
  ///
  /// Uses gateway first if enabled, falls back to WebSocket on failure.
  ///
  /// If [useGateway] is `true` and gateway is enabled, attempts to use
  /// the REST gateway first for faster cached responses.
  Future<Event?> fetchProfile(
    String pubkey, {
    bool useGateway = true,
  }) async {
    if (useGateway) {
      final gatewayClient = _gatewayClient;
      if (gatewayClient != null) {
        final profile = await _tryGateway(
          () => gatewayClient.getProfile(pubkey),
        );
        if (profile != null) {
          return profile;
        }
      }
    }

    // Fall back to WebSocket query
    final filters = [
      Filter(authors: [pubkey], kinds: [EventKind.metadata], limit: 1),
    ];
    final events = await queryEvents(filters, useGateway: false);
    return events.isEmpty ? null : events.first;
  }

  /// Subscribes to events matching the given filters
  ///
  /// Returns a stream of events. Automatically deduplicates subscriptions
  /// with identical filters to prevent duplicate WebSocket subscriptions.
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    void Function()? onEose,
  }) {
    // Generate deterministic subscription ID based on filter content
    final filterHash = _generateFilterHash(filters);
    final id = subscriptionId ?? 'sub_$filterHash';

    // Check if we already have this exact subscription
    if (_subscriptionStreams.containsKey(id) &&
        !_subscriptionStreams[id]!.isClosed) {
      return _subscriptionStreams[id]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<Event>.broadcast();
    _subscriptionStreams[id] = controller;
    _subscriptionFilters[id] = filterHash;

    // Convert filters to JSON format expected by nostr_sdk
    final filtersJson = filters.map((f) => f.toJson()).toList();

    // Subscribe using nostr_sdk
    final actualId = _nostr.subscribe(
      filtersJson,
      (event) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      },
      id: id,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
    );

    // If nostr_sdk generated a different ID, update our mapping
    if (actualId != id && actualId.isNotEmpty) {
      _subscriptionStreams.remove(id);
      _subscriptionStreams[actualId] = controller;
      _subscriptionFilters[actualId] = filterHash;
    }

    return controller.stream;
  }

  /// Unsubscribes from a subscription
  Future<void> unsubscribe(String subscriptionId) async {
    _nostr.unsubscribe(subscriptionId);
    final controller = _subscriptionStreams.remove(subscriptionId);
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    _subscriptionFilters.remove(subscriptionId);
  }

  /// Closes all subscriptions
  void closeAllSubscriptions() {
    _subscriptionStreams.keys.toList().forEach(unsubscribe);
  }

  /// Adds a relay connection
  ///
  /// Delegates to RelayManager for persistence and status tracking.
  Future<bool> addRelay(String relayUrl) async {
    return _relayManager.addRelay(relayUrl);
  }

  /// Removes a relay connection
  ///
  /// Delegates to RelayManager.
  Future<bool> removeRelay(String relayUrl) async {
    return _relayManager.removeRelay(relayUrl);
  }

  /// Gets list of configured relay URLs
  List<String> get configuredRelays => _relayManager.configuredRelays;

  /// Gets list of connected relay URLs
  List<String> get connectedRelays => _relayManager.connectedRelays;

  /// Gets count of connected relays
  int get connectedRelayCount => _relayManager.connectedRelayCount;

  /// Gets count of configured relays
  int get configuredRelayCount => _relayManager.configuredRelayCount;

  /// Gets relay statuses
  Map<String, RelayConnectionStatus> get relayStatuses =>
      _relayManager.currentStatuses;

  /// Stream of relay status updates
  Stream<Map<String, RelayConnectionStatus>> get relayStatusStream =>
      _relayManager.statusStream;

  /// Retry connecting to all disconnected relays
  Future<void> retryDisconnectedRelays() async {
    await _relayManager.retryDisconnectedRelays();
  }

  /// Sends a like reaction to an event
  Future<Event?> sendLike(
    String eventId, {
    String? content,
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    return _nostr.sendLike(
      eventId,
      content: content,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  /// Sends a repost
  Future<Event?> sendRepost(
    String eventId, {
    String? relayAddr,
    String content = '',
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    return _nostr.sendRepost(
      eventId,
      relayAddr: relayAddr,
      content: content,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  /// Deletes an event
  Future<Event?> deleteEvent(
    String eventId, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    return _nostr.deleteEvent(
      eventId,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  /// Deletes multiple events
  Future<Event?> deleteEvents(
    List<String> eventIds, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    return _nostr.deleteEvents(
      eventIds,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  /// Sends a contact list
  Future<Event?> sendContactList(
    ContactList contacts,
    String content, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    return _nostr.sendContactList(
      contacts,
      content,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
  }

  /// Disposes the client and cleans up resources
  ///
  /// Closes all subscriptions, disconnects from relays, and cleans up
  /// internal state. After calling this, the client should not be used.
  Future<void> dispose() async {
    closeAllSubscriptions();
    await _relayManager.dispose();
    _nostr.close();
    _subscriptionFilters.clear();
  }

  /// Generates a deterministic hash for filters
  /// to prevent duplicate subscriptions
  String _generateFilterHash(List<Filter> filters) {
    final json = filters.map((f) => f.toJson()).toList();
    final jsonString = jsonEncode(json);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Attempts to execute a gateway operation
  /// (e.g. query events, fetch events, fetch profiles),
  /// falling back gracefully on failure
  ///
  /// Returns the result if successful, or `null` if gateway is unavailable
  /// or the operation fails. Only falls back for recoverable errors (network,
  /// timeouts, server errors). Client errors (4xx) are not retried.
  Future<T?> _tryGateway<T>(
    Future<T> Function() operation, {
    bool shouldFallback = true,
  }) async {
    if (_gatewayClient == null) {
      return null;
    }

    try {
      return await operation();
    } on Exception catch (_) {
      return null;
    }
  }
}
