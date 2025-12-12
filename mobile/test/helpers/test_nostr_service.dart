// ABOUTME: Test implementation of NostrService for unit tests
// ABOUTME: Provides minimal Nostr functionality without real relay connections

import 'dart:async';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/nostr_timestamp.dart';
import 'package:models/models.dart';

/// Test implementation of NostrService that doesn't connect to real relays
class TestNostrService implements NostrClient {
  final List<Event> _storedEvents = [];
  final Map<String, StreamController<Event>> _subscriptions = {};
  final Map<String, bool> _relayAuthStates = {};
  final _authStateController = StreamController<Map<String, bool>>.broadcast();

  bool _isConnected = true;
  String? _currentUserPubkey;

  @override
  Future<void> initialize({List<String>? customRelays}) async {
    // No-op for tests
  }

  @override
  bool get isInitialized => _isConnected;

  @override
  bool get isDisposed => !_isConnected;

  @override
  String get publicKey => _currentUserPubkey ?? '';

  @override
  bool get hasKeys => _currentUserPubkey != null;

  @override
  int get configuredRelayCount => _isConnected ? 1 : 0;

  @override
  int get connectedRelayCount => _isConnected ? 1 : 0;

  @override
  List<String> get configuredRelays => ['wss://test.relay'];

  @override
  Map<String, RelayConnectionStatus> get relayStatuses => {
    'wss://test.relay': RelayConnectionStatus(
      url: 'wss://test.relay',
      state: _isConnected ? RelayState.connected : RelayState.disconnected,
    ),
  };

  @override
  String get primaryRelay => 'wss://test.relay';

  @override
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    // Return empty stream for tests
    return const Stream.empty();
  }

  void setCurrentUserPubkey(String pubkey) {
    _currentUserPubkey = pubkey;
  }

  @override
  Future<NostrBroadcastResult> broadcast(Event event, {List<String>? targetRelays}) async {
    if (!_isConnected) throw StateError('Not connected');
    _storedEvents.add(event);

    // Notify any matching subscriptions
    for (final entry in _subscriptions.entries) {
      final controller = entry.value;
      if (!controller.isClosed) {
        controller.add(event);
      }
    }

    return NostrBroadcastResult(
      event: event,
      successCount: 1,
      totalRelays: 1,
      results: {'wss://test.relay': true},
      errors: {},
    );
  }

  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  }) async {
    // Create event with metadata tags
    final tags = <List<String>>[];
    // Add metadata fields as tags
    tags.add(['url', metadata.url]);
    tags.add(['m', metadata.mimeType]);
    tags.add(['x', metadata.sha256Hash]);
    tags.add(['size', metadata.sizeBytes.toString()]);
    tags.addAll(hashtags.map((h) => ['t', h]));

    final event = Event(
      _currentUserPubkey ?? 'test-pubkey',
      1063,
      tags,
      content,
      createdAt: NostrTimestamp.now(),
    );

    return broadcast(event);
  }

  Future<NostrBroadcastResult> publishVideoEvent({
    required String videoUrl,
    required String content,
    String? title,
    String? thumbnailUrl,
    int? duration,
    String? dimensions,
    String? mimeType,
    String? sha256,
    int? fileSize,
    List<String> hashtags = const [],
  }) async {
    final tags = <List<String>>[
      ['url', videoUrl],
      if (title != null) ['title', title],
      if (thumbnailUrl != null) ['thumb', thumbnailUrl],
      if (duration != null) ['duration', duration.toString()],
      ...hashtags.map((h) => ['t', h]),
    ];

    final event = Event(
      _currentUserPubkey ?? 'test-pubkey',
      22,
      tags,
      content,
      createdAt: NostrTimestamp.now(),
    );

    return broadcast(event);
  }

  @override
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = const [],
    bool sendAfterAuth = false,
    void Function()? onEose,
  }) {
    final subId = subscriptionId ?? 'test_sub_${DateTime.now().millisecondsSinceEpoch}';

    if (_subscriptions.containsKey(subId)) {
      throw StateError('Subscription $subId already exists');
    }

    final controller = StreamController<Event>.broadcast();
    _subscriptions[subId] = controller;

    // Send existing matching events
    for (final event in _storedEvents) {
      bool matches = false;
      for (final filter in filters) {
        if (filter.kinds != null && !filter.kinds!.contains(event.kind)) {
          continue;
        }
        if (filter.authors != null && !filter.authors!.contains(event.pubkey)) {
          continue;
        }
        matches = true;
        break;
      }
      if (matches) {
        controller.add(event);
      }
    }

    return controller.stream;
  }

  @override
  Future<List<Event>> queryEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = const [],
    bool sendAfterAuth = false,
    bool useGateway = false,
    bool useCache = true,
  }) async {
    final matchingEvents = <Event>[];

    for (final event in _storedEvents) {
      bool matches = false;
      for (final filter in filters) {
        if (filter.kinds != null && !filter.kinds!.contains(event.kind)) {
          continue;
        }
        if (filter.authors != null && !filter.authors!.contains(event.pubkey)) {
          continue;
        }
        matches = true;
        break;
      }
      if (matches) {
        matchingEvents.add(event);
      }
    }

    return matchingEvents;
  }

  @override
  Future<Event?> fetchEventById(
    String eventId, {
    String? relayUrl,
    bool useGateway = false,
    bool useCache = true,
  }) async {
    // Search through stored events for matching ID
    for (final event in _storedEvents) {
      if (event.id == eventId) {
        return event;
      }
    }
    return null;
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
  List<String> get connectedRelays => _isConnected ? ['wss://test.relay'] : [];

  @override
  Future<bool> addRelay(String relayUrl) async {
    // No-op for tests
    return true;
  }

  @override
  Future<bool> removeRelay(String relayUrl) async {
    // No-op for tests
    return true;
  }

  @override
  Map<String, bool> getRelayStatus() {
    return {'wss://test.relay': _isConnected};
  }

  @override
  Future<void> retryDisconnectedRelays() async {
    _isConnected = true;
  }

  Map<String, bool> get relayAuthStates => Map.from(_relayAuthStates);

  Stream<Map<String, bool>> get authStateStream => _authStateController.stream;

  bool isRelayAuthenticated(String relayUrl) {
    return _relayAuthStates[relayUrl] ?? false;
  }

  bool get isVineRelayAuthenticated =>
      isRelayAuthenticated('wss://staging-relay.divine.video');

  void setAuthTimeout(Duration timeout) {
    // No-op for tests
  }

  void clearPersistedAuthStates() {
    // Clear test auth states
    _relayAuthStates.clear();
    _authStateController.add(Map.from(_relayAuthStates));
  }

  @override
  Future<void> dispose() async {
    _isConnected = false;
    for (final controller in _subscriptions.values) {
      await controller.close();
    }
    _subscriptions.clear();
    await _authStateController.close();
  }

  // Test helpers
  void addTestEvent(Event event) {
    _storedEvents.add(event);
  }

  void clearTestEvents() {
    _storedEvents.clear();
  }

  void setRelayAuthState(String relayUrl, bool isAuthenticated) {
    _relayAuthStates[relayUrl] = isAuthenticated;
    _authStateController.add(Map.from(_relayAuthStates));
  }

  @override
  Future<Map<String, dynamic>?> getRelayStats() async {
    // Return mock stats for tests
    return {
      'database': {'total_events': _storedEvents.length},
      'subscriptions': {'active_count': _subscriptions.length},
      'external_relays': configuredRelays.length,
    };
  }

  @override
  Stream<Event> searchUsers(String query, {int? limit}) {
    return const Stream.empty();
  }

  // Handle any unimplemented methods from NostrClient
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Return sensible defaults for common return types
    final memberName = invocation.memberName.toString();
    if (memberName.contains('Future')) {
      return Future.value(null);
    }
    if (memberName.contains('Stream')) {
      return const Stream.empty();
    }
    return super.noSuchMethod(invocation);
  }
}
