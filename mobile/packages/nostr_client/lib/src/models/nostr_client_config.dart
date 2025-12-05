import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template nostr_client_config}
/// Configuration for NostrClient initialization
/// {@endtemplate}
class NostrClientConfig {
  /// {@macro nostr_client_config}
  const NostrClientConfig({
    required this.signer,
    required this.publicKey,
    this.eventFilters = const [],
    this.onNotice,
    this.gatewayUrl,
    this.enableGateway = false,
    this.webSocketChannelFactory,
  });

  /// Signer for event signing
  final NostrSigner signer;
  /// Public key of the client
  final String publicKey;
  /// Event filters for initial subscriptions
  final List<EventFilter> eventFilters;
  /// Callback for relay notices
  final void Function(String, String)? onNotice;
  /// Gateway URL (if using gateway)
  final String? gatewayUrl;
  /// Whether to enable gateway support
  final bool enableGateway;
  /// WebSocket channel factory for testing (optional)
  final WebSocketChannelFactory? webSocketChannelFactory;
}
