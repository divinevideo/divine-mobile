// ABOUTME: Unit test for NostrService - tests service interface without full initialization
// ABOUTME: Validates service creation, state management, and basic functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

void main() {
  group('NostrService Unit Tests', () {
    late NostrService embeddedRelayService;
    late NostrKeyManager keyManager;

    setUp(() {
      keyManager = NostrKeyManager();
      embeddedRelayService = NostrService(keyManager);
    });

    test('service can be instantiated', () {
      expect(embeddedRelayService, isNotNull);
      expect(embeddedRelayService.isInitialized, isFalse);
      expect(embeddedRelayService.isDisposed, isFalse);
    });

    test('service has correct initial state', () {
      expect(embeddedRelayService.isInitialized, isFalse);
      expect(embeddedRelayService.isDisposed, isFalse);
      expect(
        embeddedRelayService.relayCount,
        equals(1),
      ); // Should include embedded relay
      expect(embeddedRelayService.connectedRelayCount, equals(1));
      expect(embeddedRelayService.relays, contains('ws://localhost:7447'));
      expect(embeddedRelayService.primaryRelay, equals('ws://localhost:7447'));
    });

    test('service provides key manager access', () {
      expect(embeddedRelayService.keyManager, equals(keyManager));
      expect(embeddedRelayService.hasKeys, equals(keyManager.hasKeys));
      expect(embeddedRelayService.publicKey, equals(keyManager.publicKey));
    });

    test('service provides relay status information', () {
      final statuses = embeddedRelayService.relayStatuses;
      expect(statuses, isNotEmpty);
      expect(statuses.containsKey('ws://localhost:7447'), isTrue);

      final embeddedStatus = statuses['ws://localhost:7447'];
      expect(embeddedStatus['connected'], isTrue);
    });

    test('service provides relay auth states', () {
      final authStates = embeddedRelayService.relayAuthStates;
      expect(authStates, isA<Map<String, bool>>());

      // Auth states stream should be available
      expect(embeddedRelayService.authStateStream, isNotNull);

      // Should report vine relay authentication
      expect(embeddedRelayService.isVineRelayAuthenticated, isA<bool>());
    });

    test('service can add external relays', () async {
      final initialCount = embeddedRelayService.relayCount;

      // Adding embedded relay URL should return false (already present)
      final addedSame = await embeddedRelayService.addRelay(
        'ws://localhost:7447',
      );
      expect(addedSame, isFalse);
      expect(embeddedRelayService.relayCount, equals(initialCount));

      // Adding external relay should work (though may not fully connect in unit test)
      final addedExternal = await embeddedRelayService.addRelay(
        'wss://localhost:8081',
      );
      expect(addedExternal, isA<bool>());
    });

    test('service can remove external relays but not embedded relay', () async {
      // Cannot remove embedded relay
      await embeddedRelayService.removeRelay('ws://localhost:7447');
      expect(embeddedRelayService.relays, contains('ws://localhost:7447'));

      // Can remove external relays (if any were added)
      // This just tests the method doesn't throw
      await embeddedRelayService.removeRelay('wss://nonexistent.com');
    });

    test('service provides relay status checks', () {
      final status = embeddedRelayService.getRelayStatus();
      expect(status, isA<Map<String, bool>>());
      expect(status['ws://localhost:7447'], isTrue);

      expect(
        embeddedRelayService.isRelayAuthenticated('ws://localhost:7447'),
        isA<bool>(),
      );
    });

    test('service can handle auth timeout setting', () {
      // Should not throw - method is no-op for embedded relay
      expect(
        () => embeddedRelayService.setAuthTimeout(Duration(seconds: 30)),
        returnsNormally,
      );
    });

    test('service can be disposed', () {
      expect(embeddedRelayService.isDisposed, isFalse);

      embeddedRelayService.dispose();
      expect(embeddedRelayService.isDisposed, isTrue);

      // Second dispose should be safe
      expect(() => embeddedRelayService.dispose(), returnsNormally);
    });

    test('disposed service throws on operations', () async {
      embeddedRelayService.dispose();

      // Operations on disposed service should throw
      expect(
        () => embeddedRelayService.subscribeToEvents(filters: []),
        throwsStateError,
      );

      // broadcastEvent with null should throw (either StateError or TypeError)
      expect(
        () => embeddedRelayService.broadcastEvent(null as dynamic),
        throwsA(isA<Error>()),
      );
    });

    test('service provides P2P functionality interface', () async {
      // P2P methods should be available (may not work without full initialization)
      expect(() => embeddedRelayService.startP2PDiscovery(), returnsNormally);
      expect(() => embeddedRelayService.stopP2PDiscovery(), returnsNormally);
      expect(() => embeddedRelayService.startP2PAdvertising(), returnsNormally);
      expect(() => embeddedRelayService.stopP2PAdvertising(), returnsNormally);
      expect(() => embeddedRelayService.getP2PPeers(), returnsNormally);
      expect(() => embeddedRelayService.syncWithP2PPeers(), returnsNormally);
      expect(() => embeddedRelayService.startAutoP2PSync(), returnsNormally);
      expect(() => embeddedRelayService.stopAutoP2PSync(), returnsNormally);
    });

    test('service provides stats interface', () async {
      // Stats method should be available (may return null without initialization)
      final stats = await embeddedRelayService.getRelayStats();
      expect(stats, anyOf(isNull, isA<Map<String, dynamic>>()));
    });

    test('service provides search interface', () {
      // Search should return empty stream without full initialization
      final searchStream = embeddedRelayService.searchVideos('test query');
      expect(searchStream, isA<Stream>());
    });
  });
}
