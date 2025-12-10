// ABOUTME: Mobile-specific NostrService factory for embedded relay
// ABOUTME: Returns NostrService with WebSocket connection to local embedded relay

import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';

/// Create NostrService instance for mobile platforms
///
/// Uses WebSocket connection to local embedded relay on port 7447
INostrService createEmbeddedRelayService(
  NostrKeyManager keyManager, {
  void Function()? onInitialized,
}) {
  return NostrService(keyManager, onInitialized: onInitialized);
}
