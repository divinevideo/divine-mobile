// ABOUTME: Configuration for RelayManager initialization and behavior.
// ABOUTME: Defines the default relay, persistence, and connection factory.

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

  /// Loads the list of relays the user explicitly removed.
  Future<List<String>> loadRemovedRelays();

  /// Saves the list of relays the user explicitly removed.
  Future<void> saveRemovedRelays(List<String> relayUrls);
}

/// {@template in_memory_relay_storage}
/// In-memory implementation of [RelayStorage] for testing.
/// {@endtemplate}
class InMemoryRelayStorage implements RelayStorage {
  /// {@macro in_memory_relay_storage}
  InMemoryRelayStorage([
    List<String>? initialRelays,
    List<String>? removedRelays,
  ]) : _relays = initialRelays ?? [],
       _removedRelays = removedRelays ?? [];

  final List<String> _relays;
  final List<String> _removedRelays;

  @override
  Future<List<String>> loadRelays() async => List.from(_relays);

  @override
  Future<void> saveRelays(List<String> relayUrls) async {
    _relays
      ..clear()
      ..addAll(relayUrls);
  }

  @override
  Future<List<String>> loadRemovedRelays() async => List.from(_removedRelays);

  @override
  Future<void> saveRemovedRelays(List<String> relayUrls) async {
    _removedRelays
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
    this.webSocketChannelFactory,
    this.allowedRelayHost,
  });

  /// The environment default relay URL.
  final String defaultRelayUrl;

  /// When set, only relays whose host equals this value are admitted.
  ///
  /// Null means no restriction (production behavior). Used to lock a
  /// non-production environment to its own relay host so a user's NIP-65
  /// relay list cannot pull in a different environment's relays.
  final String? allowedRelayHost;

  /// Storage implementation for persisting relay configuration
  /// If null, relays are only kept in memory
  final RelayStorage? storage;

  /// WebSocket channel factory for custom connection handling
  /// If null, uses the default WebSocket implementation
  final WebSocketChannelFactory? webSocketChannelFactory;

  /// Creates a copy with updated fields
  RelayManagerConfig copyWith({
    String? defaultRelayUrl,
    RelayStorage? storage,
    WebSocketChannelFactory? webSocketChannelFactory,
    String? allowedRelayHost,
  }) {
    return RelayManagerConfig(
      defaultRelayUrl: defaultRelayUrl ?? this.defaultRelayUrl,
      storage: storage ?? this.storage,
      webSocketChannelFactory:
          webSocketChannelFactory ?? this.webSocketChannelFactory,
      allowedRelayHost: allowedRelayHost ?? this.allowedRelayHost,
    );
  }
}
