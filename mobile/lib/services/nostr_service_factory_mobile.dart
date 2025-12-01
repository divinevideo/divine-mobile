// ABOUTME: Mobile-specific NostrService factory for direct relay connections
// ABOUTME: Returns NostrServiceDirect with direct WebSocket connections to external relays

import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';

/// Create NostrService instance for mobile platforms
///
/// Uses direct WebSocket connections to external Nostr relays
INostrService createDirectRelayService(
  NostrKeyManager keyManager, {
  void Function()? onInitialized,
}) {
  return NostrService(keyManager, onInitialized: onInitialized);
}
