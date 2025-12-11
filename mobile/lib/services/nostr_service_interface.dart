// ABOUTME: Interface for Nostr services to ensure compatibility across platforms
// ABOUTME: Provides common contract for NostrService implementations

import 'dart:async';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:models/models.dart';

/// Result of broadcasting an event to relays
class NostrBroadcastResult {
  const NostrBroadcastResult({
    required this.event,
    required this.successCount,
    required this.totalRelays,
    required this.results,
    required this.errors,
  });
  final Event event;
  final int successCount;
  final int totalRelays;
  final Map<String, bool> results;
  final Map<String, String> errors;

  bool get isSuccessful => successCount > 0;
  bool get isCompleteSuccess => successCount == totalRelays;
  double get successRate => totalRelays > 0 ? successCount / totalRelays : 0.0;

  List<String> get successfulRelays =>
      results.entries.where((e) => e.value).map((e) => e.key).toList();

  List<String> get failedRelays =>
      results.entries.where((e) => !e.value).map((e) => e.key).toList();

  @override
  String toString() =>
      'NostrBroadcastResult('
      'success: $successCount/$totalRelays, '
      'rate: ${(successRate * 100).toStringAsFixed(1)}%'
      ')';
}

/// Common interface for Nostr service implementations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
abstract class INostrService {
  // Getters
  bool get isInitialized;
  bool get isDisposed;
  List<String> get connectedRelays;
  String? get publicKey;
  bool get hasKeys;
  NostrKeyManager get keyManager;
  int get relayCount;
  int get connectedRelayCount;
  List<String> get relays;
  Map<String, dynamic> get relayStatuses;

  // AUTH state tracking
  Map<String, bool> get relayAuthStates;
  Stream<Map<String, bool>> get authStateStream;
  bool isRelayAuthenticated(String relayUrl);
  bool get isVineRelayAuthenticated;
  void setAuthTimeout(Duration timeout);

  // Methods
  Future<void> initialize({List<String>? customRelays});
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  });
  Future<NostrBroadcastResult> broadcastEvent(Event event);
  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  });

  // Relay management methods
  Future<bool> addRelay(String relayUrl);
  Future<void> removeRelay(String relayUrl);
  Map<String, bool> getRelayStatus();
  Future<void> reconnectAll();
  Future<void> retryInitialization();

  // Subscription management
  Future<void> closeAllSubscriptions();

  // Event querying
  Future<List<Event>> getEvents({required List<Filter> filters, int? limit});

  /// Fetch a single event by ID
  Future<Event?> fetchEventById(String eventId, {String? relayUrl});

  // NIP-50 Search functionality
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  });

  // NIP-50 Search functionality
  Stream<Event> searchUsers(String query, {int? limit});

  // Primary relay for all client operations
  String get primaryRelay;

  // Diagnostics and monitoring
  Future<Map<String, dynamic>?> getRelayStats();

  Future<void> dispose();
}
