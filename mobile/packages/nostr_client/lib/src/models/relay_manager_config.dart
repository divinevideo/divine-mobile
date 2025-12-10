// ABOUTME: Configuration for RelayManager initialization and behavior.
// ABOUTME: Defines default relay, persistence, and reconnection settings.

import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template relay_storage}
/// Abstract interface for persisting relay configuration.
///
/// Implementations can use SharedPreferences, Hive, or any storage backend.
/// {@endtemplate}
abstract class RelayStorage {
  /// Loads the list of configured relay URLs from storage
  Future<List<String>> loadRelays();

  /// Saves the list of configured relay URLs to storage
  Future<void> saveRelays(List<String> relayUrls);
}

/// {@template in_memory_relay_storage}
/// In-memory implementation of [RelayStorage] for testing.
/// {@endtemplate}
class InMemoryRelayStorage implements RelayStorage {
  /// {@macro in_memory_relay_storage}
  InMemoryRelayStorage([List<String>? initialRelays])
    : _relays = initialRelays ?? [];

  final List<String> _relays;

  @override
  Future<List<String>> loadRelays() async => List.from(_relays);

  @override
  Future<void> saveRelays(List<String> relayUrls) async {
    _relays
      ..clear()
      ..addAll(relayUrls);
  }
}

/// {@template relay_manager_config}
/// Configuration for RelayManager initialization and behavior.
/// {@endtemplate}
class RelayManagerConfig {
  /// {@macro relay_manager_config}
  const RelayManagerConfig({
    required this.defaultRelayUrl,
    this.storage,
    this.autoReconnect = true,
    this.maxReconnectAttempts = 5,
    this.reconnectDelayMs = 2000,
    this.webSocketChannelFactory,
  });

  /// The default relay URL that is always included and cannot be removed
  final String defaultRelayUrl;

  /// Storage implementation for persisting relay configuration
  /// If null, relays are only kept in memory
  final RelayStorage? storage;

  /// Whether to automatically reconnect when a relay disconnects
  final bool autoReconnect;

  /// Maximum number of reconnection attempts before giving up
  final int maxReconnectAttempts;

  /// Base delay in milliseconds between reconnection attempts
  /// Uses exponential backoff: delay * 2^attempt
  final int reconnectDelayMs;

  /// WebSocket channel factory for custom connection handling
  /// If null, uses the default WebSocket implementation
  final WebSocketChannelFactory? webSocketChannelFactory;

  /// Creates a copy with updated fields
  RelayManagerConfig copyWith({
    String? defaultRelayUrl,
    RelayStorage? storage,
    bool? autoReconnect,
    int? maxReconnectAttempts,
    int? reconnectDelayMs,
    WebSocketChannelFactory? webSocketChannelFactory,
  }) {
    return RelayManagerConfig(
      defaultRelayUrl: defaultRelayUrl ?? this.defaultRelayUrl,
      storage: storage ?? this.storage,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      reconnectDelayMs: reconnectDelayMs ?? this.reconnectDelayMs,
      webSocketChannelFactory:
          webSocketChannelFactory ?? this.webSocketChannelFactory,
    );
  }
}
