// ABOUTME: Web-specific NostrService factory using direct relay connections
// ABOUTME: Connects directly to external relays since embedded relay not supported on web

import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/nostr_service_direct_web.dart';

/// Create web-specific NostrService that connects directly to external relays
INostrService createEmbeddedRelayService(
  NostrKeyManager keyManager, {
  void Function()? onInitialized,
}) {
  // Return web implementation that connects directly to external relays
  // Note: Web implementation doesn't yet support onInitialized callback
  return NostrServiceDirectWeb(keyManager);
}
