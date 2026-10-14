// ABOUTME: Abstract transport interface for Nostr protocol messages
// ABOUTME: Enables fixture-based testing and WebSocket production implementation

/// Transport abstraction for Nostr protocol communication
abstract class NostrTransport {
  /// Stream of messages received from relay (server → client)
  Stream<String> get incoming;

  /// Send a message to the relay (client → server)
  void send(String json);

  /// Releases the transport's resources.
  ///
  /// The returned future completes once the transport has finished closing.
  Future<void> dispose();
}
