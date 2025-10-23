// ABOUTME: Concrete web implementation of NostrService using direct relay connections
// ABOUTME: Bypasses embedded relay and connects directly to external Nostr relays via WebSocket

import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_web.dart';

/// Concrete implementation of NostrServiceWeb for direct relay connections
class NostrServiceDirectWeb extends NostrServiceWeb {
  final NostrKeyManager _keyManager;

  NostrServiceDirectWeb(this._keyManager) : super();

  @override
  NostrKeyManager get keyManager => _keyManager;

  @override
  Future<Map<String, dynamic>?> getRelayStats() => super.getRelayStats();
}