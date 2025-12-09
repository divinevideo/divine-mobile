// ABOUTME: Tests for NostrService relay configuration persistence across app restarts
// ABOUTME: Ensures user's relay choices are saved to SharedPreferences and restored on launch

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NostrService Relay Persistence', () {
    late NostrKeyManager keyManager;

    setUp(() async {
      keyManager = NostrKeyManager();
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'should save relay configuration to SharedPreferences when relay is added',
      () async {
        // Arrange: Create service
        final service = NostrService(keyManager);
        await service.initialize();

        // Act: Add a custom relay
        const customRelay = 'wss://custom.relay.com';
        await service.addRelay(customRelay);

        // Assert: Relay should be saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedRelays = prefs.getStringList('configured_relays');

        expect(savedRelays, isNotNull);
        expect(savedRelays, contains(customRelay));

        await service.dispose();
      },
    );

    test(
      'should remove relay from SharedPreferences when relay is removed',
      () async {
        // Arrange: Create service with a relay already configured
        SharedPreferences.setMockInitialValues({
          'configured_relays': [
            'wss://relay.divine.video',
            'wss://old.relay.com',
          ],
        });

        final service = NostrService(keyManager);
        await service.initialize(
          customRelays: ['wss://relay.divine.video', 'wss://old.relay.com'],
        );

        // Act: Remove the old relay
        await service.removeRelay('wss://old.relay.com');

        // Assert: Relay should be removed from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedRelays = prefs.getStringList('configured_relays');

        expect(savedRelays, isNotNull);
        expect(savedRelays, isNot(contains('wss://old.relay.com')));
        expect(savedRelays, contains('wss://relay.divine.video'));

        await service.dispose();
      },
    );

    test('should load saved relay configuration on initialization', () async {
      // Arrange: Set up SharedPreferences with saved relays
      const savedRelay = 'wss://user.saved.relay.com';
      SharedPreferences.setMockInitialValues({
        'configured_relays': [savedRelay],
      });

      // Act: Create and initialize service (should load from SharedPreferences)
      final service = NostrService(keyManager);
      await service.initialize();

      // Assert: Service should have the saved relay configured
      expect(service.relays, contains(savedRelay));

      await service.dispose();
    });

    test(
      'should use default relay when no saved configuration exists',
      () async {
        // Arrange: No saved configuration in SharedPreferences
        SharedPreferences.setMockInitialValues({});

        // Act: Create and initialize service
        final service = NostrService(keyManager);
        await service.initialize();

        // Assert: Service should use AppConstants.defaultRelayUrl
        expect(service.relays.length, equals(1));
        expect(service.relays.first, equals('wss://relay.divine.video'));

        await service.dispose();
      },
    );

    test(
      'should persist relay configuration across simulated app restarts',
      () async {
        // Arrange & Act: First session - add custom relay
        const customRelay = 'wss://persistent.relay.com';
        SharedPreferences.setMockInitialValues({});

        var service = NostrService(keyManager);
        await service.initialize();
        await service.addRelay(customRelay);
        await service.dispose();

        // Simulate app restart by getting saved prefs
        final prefs = await SharedPreferences.getInstance();
        final savedRelays = prefs.getStringList('configured_relays');

        // Act: Second session - create new service instance (simulates app restart)
        SharedPreferences.setMockInitialValues({
          'configured_relays': savedRelays ?? [],
        });

        service = NostrService(keyManager);
        await service.initialize();

        // Assert: Custom relay should still be configured
        expect(service.relays, contains(customRelay));

        await service.dispose();
      },
    );

    test('should not duplicate relays when adding same relay twice', () async {
      // Arrange
      const relay = 'wss://relay.divine.video';
      SharedPreferences.setMockInitialValues({});

      final service = NostrService(keyManager);
      await service.initialize(customRelays: [relay]);

      // Act: Try to add the same relay again
      await service.addRelay(relay);

      // Assert: Relay should only appear once in storage
      final prefs = await SharedPreferences.getInstance();
      final savedRelays = prefs.getStringList('configured_relays');

      expect(savedRelays, isNotNull);
      expect(savedRelays!.where((r) => r == relay).length, equals(1));

      await service.dispose();
    });

    test(
      'should clear old relay3.openvine.co from storage during migration',
      () async {
        // Arrange: User has old relay in storage
        SharedPreferences.setMockInitialValues({
          'configured_relays': ['wss://relay3.openvine.co'],
        });

        // Act: Initialize service (should trigger migration)
        final service = NostrService(keyManager);
        await service.initialize();

        // Assert: Old relay should be removed, new default should be added
        final prefs = await SharedPreferences.getInstance();
        final savedRelays = prefs.getStringList('configured_relays');

        expect(savedRelays, isNotNull);
        expect(savedRelays, isNot(contains('wss://relay3.openvine.co')));
        expect(savedRelays, contains('wss://relay.divine.video'));

        await service.dispose();
      },
    );
  });
}
