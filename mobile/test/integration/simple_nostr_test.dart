// ABOUTME: Simple integration test to verify NostrService consolidated properly
// ABOUTME: Tests basic functionality without platform dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';

void main() {
  group('NostrService Consolidation Test', () {
    test('should create NostrService instance', () {
      // Create a mock key manager
      final keyManager = NostrKeyManager();

      // Create the service
      final service = NostrService(keyManager);

      // Basic checks
      expect(service, isNotNull);
      expect(service.isInitialized, false);
      expect(service.isDisposed, false);
      expect(service.hasKeys, false);
      expect(service.publicKey, isNull);
      expect(service.relayCount, 0);
      expect(service.connectedRelayCount, 0);

      // Check relay management methods exist
      expect(service.relays, isEmpty);
      expect(service.relayStatuses, isEmpty);

      // Dispose
      service.dispose();
      expect(service.isDisposed, true);
    });

    // Note: NostrServiceException was removed during embedded relay refactor
    // Exception handling is now handled by the embedded relay service directly
  });
}
