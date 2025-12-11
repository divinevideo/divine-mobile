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
  /// The RelayManager is created internally using the Nostr instance's
  /// RelayPool to ensure they share the same connection pool.
  factory NostrClient({
    required NostrClientConfig config,
    required RelayManagerConfig relayManagerConfig,
    GatewayClient? gatewayClient,
  }) {
    final nostr = _createNostr(config);
    final relayManager = RelayManager(
      config: relayManagerConfig,
      relayPool: nostr.relayPool,
    );
    return NostrClient._internal(
      nostr: nostr,
      relayManager: relayManager,
      gatewayClient: gatewayClient,
    );
  }

  /// Internal constructor used by factory and testing constructors
  NostrClient._internal({
    required Nostr nostr,
    required RelayManager relayManager,
    GatewayClient? gatewayClient,
  }) : _nostr = nostr,
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

  /// Tracks whether dispose() has been called
  bool _isDisposed = false;

  /// Public key of the client
  String get publicKey => _nostr.publicKey;

  /// Whether the client has been initialized
  ///
  /// Returns true if the relay manager is initialized
  bool get isInitialized => _relayManager.isInitialized;

  /// Whether the client has been disposed
  ///
  /// After disposal, the client should not be used
  bool get isDisposed => _isDisposed;

  /// Whether the client has keys configured
  ///
  /// Returns true if the public key is not empty
  bool get hasKeys => publicKey.isNotEmpty;

  /// Initializes the client by connecting to configured relays
  ///
  /// This must be called before using the client to ensure relay connections
  /// are established. Can be called multiple times safely.
  Future<void> initialize() async {
    await _relayManager.initialize();
  }

  /// Alias for [configuredRelayCount] for API compatibility
  int get relayCount => configuredRelayCount;

  /// Alias for [configuredRelays] for API compatibility
  List<String> get relays => configuredRelays;

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

  /// Broadcasts an event and returns detailed result
  ///
  /// Alias for [broadcast] for API compatibility with INostrService.
  Future<NostrBroadcastResult> broadcastEvent(Event event) => broadcast(event);

  /// Gets events matching filters
  ///
  /// Alias for [queryEvents] for API compatibility with INostrService.
  Future<List<Event>> getEvents({
    required List<Filter> filters,
    int? limit,
  }) async {
    // Apply limit to filters if specified
    final adjustedFilters = limit != null
        ? filters
              .map(
                (f) => Filter(
                  ids: f.ids,
                  authors: f.authors,
                  kinds: f.kinds,
                  since: f.since,
                  until: f.until,
                  limit: limit,
                  search: f.search,
                  e: f.e,
                  p: f.p,
                  t: f.t,
                  d: f.d,
                ),
              )
              .toList()
        : filters;
    return queryEvents(adjustedFilters);
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
  /// Alias for [subscribe] for API compatibility with INostrService.
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    return subscribe(filters, onEose: onEose);
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

  /// Primary relay for client operations
  ///
  /// Returns the first connected relay, or first configured relay,
  /// or the default relay URL if none are configured.
  String get primaryRelay {
    if (connectedRelays.isNotEmpty) {
      return connectedRelays.first;
    }
    if (configuredRelays.isNotEmpty) {
      return configuredRelays.first;
    }
    return 'wss://relay.divine.video';
  }

  /// Gets relay statistics for diagnostics
  ///
  /// Returns a map containing relay connection stats.
  Future<Map<String, dynamic>?> getRelayStats() async {
    return {
      'connectedRelays': connectedRelayCount,
      'configuredRelays': configuredRelayCount,
      'relays': configuredRelays,
    };
  }

  /// Retry connecting to all disconnected relays
  Future<void> retryDisconnectedRelays() async {
    await _relayManager.retryDisconnectedRelays();
  }

  /// Reconnects to all relays
  ///
  /// Alias for [retryDisconnectedRelays] for API compatibility.
  Future<void> reconnectAll() => retryDisconnectedRelays();

  /// Retries initialization
  ///
  /// Alias for [retryDisconnectedRelays] for API compatibility.
  Future<void> retryInitialization() => retryDisconnectedRelays();

  /// Gets relay connection status as a simple map
  ///
  /// Returns Map<String, bool> where the value indicates if the relay is connected.
  Map<String, bool> getRelayStatus() {
    final statuses = relayStatuses;
    final result = <String, bool>{};
    for (final entry in statuses.entries) {
      result[entry.key] =
          entry.value.state == RelayState.connected ||
          entry.value.state == RelayState.authenticated;
    }
    return result;
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

  /// Searches for video events using NIP-50 search
  ///
  /// Returns a stream of video events (kind 34236) matching the search query.
  /// Uses NIP-50 search parameter for full-text search on compatible relays.
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    final filter = Filter(
      kinds: const [34236, 16], // Video events + generic repost
      authors: authors,
      since: since != null ? since.millisecondsSinceEpoch ~/ 1000 : null,
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit ?? 100,
      search: query,
    );

    return subscribe([filter]);
  }

  /// Searches for user profiles using NIP-50 search
  ///
  /// Returns a stream of profile events (kind 0) matching the search query.
  /// Uses NIP-50 search parameter for full-text search on compatible relays.
  Stream<Event> searchUsers(
    String query, {
    int? limit,
  }) {
    final filter = Filter(
      kinds: const [EventKind.metadata],
      limit: limit ?? 100,
      search: query,
    );

    return subscribe([filter]);
  }

  /// Broadcasts an event to relays with result tracking
  ///
  /// Similar to [publishEvent] but returns detailed per-relay tracking.
  /// Use this when you need visibility into which relays accepted the event.
  ///
  /// Note: Per-relay tracking is currently based on the connected relays
  /// at broadcast time. The underlying nostr_sdk doesn't provide individual
  /// relay responses, so results are inferred from overall success/failure.
  Future<NostrBroadcastResult> broadcast(
    Event event, {
    List<String>? targetRelays,
  }) async {
    final relays = connectedRelays;
    final totalRelays = targetRelays?.length ?? relays.length;

    try {
      final sentEvent = await _nostr.sendEvent(
        event,
        targetRelays: targetRelays,
      );

      if (sentEvent != null) {
        // Event was accepted by at least one relay
        // Since nostr_sdk doesn't provide per-relay tracking,
        // we mark all connected relays as successful
        final results = <String, bool>{};
        final relayList = targetRelays ?? relays;
        for (final relay in relayList) {
          results[relay] = true;
        }

        return NostrBroadcastResult(
          event: sentEvent,
          successCount: totalRelays,
          totalRelays: totalRelays,
          results: results,
          errors: {},
        );
      } else {
        // Event was not accepted by any relay
        final results = <String, bool>{};
        final errors = <String, String>{};
        final relayList = targetRelays ?? relays;
        for (final relay in relayList) {
          results[relay] = false;
          errors[relay] = 'Failed to send';
        }

        return NostrBroadcastResult(
          event: null,
          successCount: 0,
          totalRelays: totalRelays,
          results: results,
          errors: errors,
        );
      }
    } on Exception catch (e) {
      // Exception during broadcast
      final results = <String, bool>{};
      final errors = <String, String>{};
      final relayList = targetRelays ?? relays;
      for (final relay in relayList) {
        results[relay] = false;
        errors[relay] = e.toString();
      }

      return NostrBroadcastResult(
        event: null,
        successCount: 0,
        totalRelays: totalRelays,
        results: results,
        errors: errors,
      );
    }
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
    _isDisposed = true;
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
