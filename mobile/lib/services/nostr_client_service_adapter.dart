// ABOUTME: Adapter that wraps NostrClient to implement INostrService interface
// ABOUTME: Enables gradual migration from NostrService to NostrClient

import 'dart:async';

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart' hide NostrBroadcastResult;
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/nostr_service_interface.dart';

/// Adapter that wraps NostrClient to implement INostrService
///
/// This allows NostrClient to be used wherever INostrService is expected,
/// enabling gradual migration from the old NostrService to NostrClient.
class NostrClientServiceAdapter implements INostrService {
  NostrClientServiceAdapter({
    required NostrClient client,
    required NostrKeyManager keyManager,
    void Function()? onInitialized,
  })  : _client = client,
        _keyManager = keyManager,
        _onInitialized = onInitialized {
    // Call initialization callback if client is already initialized
    if (_client.isInitialized && _onInitialized != null) {
      _onInitialized();
    }
  }

  final NostrClient _client;
  final NostrKeyManager _keyManager;
  final void Function()? _onInitialized;

  // Auth state tracking - simplified implementation
  final Map<String, bool> _authStates = {};
  final StreamController<Map<String, bool>> _authStateController =
      StreamController<Map<String, bool>>.broadcast();

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  @override
  bool get isInitialized => _client.isInitialized;

  @override
  bool get isDisposed => _client.isDisposed;

  @override
  List<String> get connectedRelays => _client.connectedRelays;

  @override
  String? get publicKey => _client.publicKey;

  @override
  bool get hasKeys => _client.hasKeys;

  @override
  NostrKeyManager get keyManager => _keyManager;

  @override
  int get relayCount => _client.relayCount;

  @override
  int get connectedRelayCount => _client.connectedRelayCount;

  @override
  List<String> get relays => _client.relays;

  @override
  Map<String, dynamic> get relayStatuses {
    final statuses = _client.relayStatuses;
    final result = <String, dynamic>{};
    for (final entry in statuses.entries) {
      result[entry.key] = {
        'connected': entry.value.state == RelayState.connected ||
            entry.value.state == RelayState.authenticated,
        'status': entry.value.state.name,
      };
    }
    return result;
  }

  @override
  String get primaryRelay {
    // Return first connected relay, or first configured relay
    if (_client.connectedRelays.isNotEmpty) {
      return _client.connectedRelays.first;
    }
    if (_client.relays.isNotEmpty) {
      return _client.relays.first;
    }
    return 'wss://relay.divine.video';
  }

  // ==========================================================================
  // AUTH STATE TRACKING
  // ==========================================================================

  @override
  Map<String, bool> get relayAuthStates => Map.unmodifiable(_authStates);

  @override
  Stream<Map<String, bool>> get authStateStream => _authStateController.stream;

  @override
  bool isRelayAuthenticated(String relayUrl) => _authStates[relayUrl] ?? false;

  @override
  bool get isVineRelayAuthenticated =>
      _authStates['wss://relay.divine.video'] ?? false;

  @override
  void setAuthTimeout(Duration timeout) {
    // No-op for now - NostrClient handles this internally
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  @override
  Future<void> initialize({List<String>? customRelays}) async {
    // Initialize the underlying client (connects to relays)
    await _client.initialize();

    // Add custom relays if provided
    if (customRelays != null) {
      for (final relay in customRelays) {
        await _client.addRelay(relay);
      }
    }

    // Call initialization callback
    _onInitialized?.call();
  }

  // ==========================================================================
  // SUBSCRIPTIONS
  // ==========================================================================

  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    return _client.subscribe(filters, onEose: onEose);
  }

  @override
  Future<void> closeAllSubscriptions() async {
    _client.closeAllSubscriptions();
  }

  // ==========================================================================
  // EVENT PUBLISHING
  // ==========================================================================

  @override
  Future<NostrBroadcastResult> broadcastEvent(Event event) async {
    final result = await _client.broadcast(event);
    return NostrBroadcastResult(
      event: result.event ?? event,
      successCount: result.successCount,
      totalRelays: result.totalRelays,
      results: result.results,
      errors: result.errors,
    );
  }

  @override
  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  }) async {
    // Build tags from metadata
    final tags = <List<String>>[
      ['url', metadata.url],
      ['m', metadata.mimeType],
      ['x', metadata.sha256Hash],
      ['size', metadata.sizeBytes.toString()],
      ['dim', metadata.dimensions],
      if (metadata.blurhash != null) ['blurhash', metadata.blurhash!],
      if (metadata.thumbnailUrl != null) ['thumb', metadata.thumbnailUrl!],
      if (metadata.originalHash != null) ['ox', metadata.originalHash!],
      ...hashtags.map((tag) => ['t', tag]),
    ];

    // Create kind 1063 event (NIP-94 file metadata)
    final event = Event(
      _keyManager.publicKey ?? '',
      1063,
      tags,
      content,
    );

    return broadcastEvent(event);
  }

  // ==========================================================================
  // RELAY MANAGEMENT
  // ==========================================================================

  @override
  Future<bool> addRelay(String relayUrl) async {
    return _client.addRelay(relayUrl);
  }

  @override
  Future<void> removeRelay(String relayUrl) async {
    await _client.removeRelay(relayUrl);
  }

  @override
  Map<String, bool> getRelayStatus() {
    final statuses = _client.relayStatuses;
    final result = <String, bool>{};
    for (final entry in statuses.entries) {
      result[entry.key] = entry.value.state == RelayState.connected ||
          entry.value.state == RelayState.authenticated;
    }
    return result;
  }

  @override
  Future<void> reconnectAll() async {
    await _client.retryDisconnectedRelays();
  }

  @override
  Future<void> retryInitialization() async {
    await _client.retryDisconnectedRelays();
  }

  // ==========================================================================
  // EVENT QUERYING
  // ==========================================================================

  @override
  Future<List<Event>> getEvents({
    required List<Filter> filters,
    int? limit,
  }) async {
    // Apply limit to first filter if specified
    final adjustedFilters = limit != null
        ? filters
            .map((f) => Filter(
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
                ))
            .toList()
        : filters;

    return _client.queryEvents(adjustedFilters);
  }

  @override
  Future<Event?> fetchEventById(String eventId, {String? relayUrl}) async {
    return _client.fetchEventById(eventId, relayUrl: relayUrl);
  }

  // ==========================================================================
  // SEARCH (NIP-50)
  // ==========================================================================

  @override
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    return _client.searchVideos(
      query,
      authors: authors,
      since: since,
      until: until,
      limit: limit,
    );
  }

  @override
  Stream<Event> searchUsers(String query, {int? limit}) {
    return _client.searchUsers(query, limit: limit);
  }

  // ==========================================================================
  // DIAGNOSTICS
  // ==========================================================================

  @override
  Future<Map<String, dynamic>?> getRelayStats() async {
    // Return basic relay statistics
    return {
      'connectedRelays': _client.connectedRelayCount,
      'configuredRelays': _client.relayCount,
      'relays': _client.relays,
    };
  }

  // ==========================================================================
  // DISPOSAL
  // ==========================================================================

  @override
  Future<void> dispose() async {
    await _authStateController.close();
    await _client.dispose();
  }
}
