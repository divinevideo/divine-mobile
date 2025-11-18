// ABOUTME: Web-specific NostrService factory using nostr_sdk RelayPool
// ABOUTME: Uses same NostrService implementation as mobile (no embedded relay needed)

import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';

/// Create NostrService instance for web platform
///
/// Uses nostr_sdk RelayPool for direct relay connections
INostrService createEmbeddedRelayService(NostrKeyManager keyManager, {void Function()? onInitialized}) {
  return NostrService(keyManager, onInitialized: onInitialized);
}
