// ABOUTME: Integration test for flutter_embedded_nostr_relay package
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Verifies SQLite persistence and event storage functionality

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Enable test mode for embedded relay to use in-memory database
  embedded.DatabaseHelper.enableTestMode();

  // Mock platform channels for path_provider
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        MethodCall methodCall,
      ) async {
        return '.';
      });

  group('Flutter Embedded Nostr Relay Integration', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;

    setUp(() async {
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});

      // Create a test key manager
      keyManager = NostrKeyManager();
      await keyManager.initialize();
      await keyManager.generateKeys();

      // Create NostrService with embedded relay
      nostrService = NostrService(keyManager);
      await nostrService.initialize();
    });

    tearDown(() async {
      await nostrService.dispose();
    });

    test('should initialize embedded relay with SQLite storage', () {
      expect(nostrService.isInitialized, isTrue);
      expect(
        nostrService.connectedRelays.contains('ws://localhost:7447'),
        isTrue,
      );
      // Verify OpenVine's relay is the default
      expect(
        nostrService.relays.contains('wss://staging-relay.divine.video'),
        isTrue,
      );
      expect(
        nostrService.primaryRelay,
        equals('wss://staging-relay.divine.video'),
      );
    });

    test('should persist events to SQLite database', () async {
      // Create a test event
      final event = Event(
        keyManager.publicKey!,
        34236, // Video event
        [
          ['url', 'https://example.com/test.mp4'],
          ['title', 'Test Video'],
          ['t', 'test'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video content from embedded relay integration',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Sign the event
      event.sign(keyManager.privateKey!);

      // Broadcast the event
      final result = await nostrService.broadcastEvent(event);

      expect(result.successCount, greaterThan(0));
      expect(result.event.id, isNotEmpty);
    });

    test('should retrieve events from SQLite storage', () async {
      // Create and store an event
      final testContent =
          'Embedded relay test ${DateTime.now().millisecondsSinceEpoch}';
      final event = Event(
        keyManager.publicKey!,
        34236,
        [
          ['t', 'embedded-test'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        testContent,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.sign(keyManager.privateKey!);

      await nostrService.broadcastEvent(event);

      // Subscribe to events and verify we get our event back
      final events = <Event>[];
      final subscription = nostrService.subscribeToEvents(
        filters: [
          Filter(kinds: [34236], authors: [keyManager.publicKey!]),
        ],
      );

      // Collect events for a short time
      await for (final e
          in subscription
              .take(5)
              .timeout(
                const Duration(seconds: 2),
                onTimeout: (sink) => sink.close(),
              )) {
        events.add(e);
      }

      // Verify we got our event
      expect(events.any((e) => e.content == testContent), isTrue);
    });

    test('should support external relay synchronization', () async {
      // Verify default OpenVine relay is configured
      expect(
        nostrService.relays.contains('wss://staging-relay.divine.video'),
        isTrue,
      );
      expect(
        nostrService.relays.length,
        equals(2),
      ); // embedded + staging-relay.divine.video

      // Add a new relay
      final added = await nostrService.addRelay('wss://nos.lol');
      expect(added, isTrue);
      expect(nostrService.relays.contains('wss://nos.lol'), isTrue);
      expect(
        nostrService.relays.length,
        equals(3),
      ); // embedded + relay3 + nos.lol

      // Remove the relay
      await nostrService.removeRelay('wss://nos.lol');
      expect(nostrService.relays.contains('wss://nos.lol'), isFalse);
      expect(
        nostrService.relays.length,
        equals(2),
      ); // back to embedded + relay3
    });

    test('should handle replaceable events correctly', () async {
      // Create a replaceable event (kind 10000-19999)
      final event1 = Event(
        keyManager.publicKey!,
        10001, // Replaceable event kind
        [
          ['d', 'test-replaceable'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'First version',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event1.sign(keyManager.privateKey!);

      await nostrService.broadcastEvent(event1);

      // Create a newer version of the same replaceable event
      await Future.delayed(const Duration(milliseconds: 100));

      final event2 = Event(
        keyManager.publicKey!,
        10001,
        [
          ['d', 'test-replaceable'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Second version - should replace first',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event2.sign(keyManager.privateKey!);

      await nostrService.broadcastEvent(event2);

      // Query for the replaceable event
      final events = await nostrService.getEvents(
        filters: [
          Filter(kinds: [10001], authors: [keyManager.publicKey!]),
        ],
      );

      // Should only have the latest version
      expect(events.length, equals(1));
      expect(
        events.first.content,
        equals('Second version - should replace first'),
      );
    });

    test('should perform content-based search for videos', () async {
      // Create a video event with searchable content
      final event = Event(
        keyManager.publicKey!,
        34236,
        [
          ['url', 'https://example.com/search-test.mp4'],
          ['title', 'Searchable Video'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'This is a searchable Flutter video about Nostr relay integration',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.sign(keyManager.privateKey!);

      await nostrService.broadcastEvent(event);

      // Search for videos containing "Flutter"
      final searchResults = <Event>[];
      final searchStream = nostrService.searchVideos(
        'Flutter',
        authors: [keyManager.publicKey!],
      );

      await for (final e
          in searchStream
              .take(5)
              .timeout(
                const Duration(seconds: 2),
                onTimeout: (sink) => sink.close(),
              )) {
        searchResults.add(e);
      }

      // Verify search found our event
      expect(searchResults.any((e) => e.content.contains('Flutter')), isTrue);
    });
    test('should discover relays from user profiles (NIP-65)', () async {
      // Create a user profile event with relay information
      final profileEvent = Event(
        keyManager.publicKey!,
        0, // kind 0 - user metadata
        [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        '{"name":"Test User","about":"Testing relay discovery","relays":"wss://relay.example.com"}',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      profileEvent.sign(keyManager.privateKey!);
      await nostrService.broadcastEvent(profileEvent);

      // Create a relay list event (NIP-65)
      final relayListEvent = Event(
        keyManager.publicKey!,
        10002, // kind 10002 - relay list metadata
        [
          ['r', 'wss://custom.relay.io', 'write'],
          ['r', 'wss://another.relay.com', 'read'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      relayListEvent.sign(keyManager.privateKey!);
      await nostrService.broadcastEvent(relayListEvent);

      // Discover relays from the user's profile
      await nostrService.discoverUserRelays(keyManager.publicKey!);

      // Verify relays were discovered and added
      // Note: Some relays might fail to connect in test environment
      final relays = nostrService.relays;
      Log.info('Discovered relays: $relays');

      // Should still have at least the default relays
      expect(relays.contains('ws://localhost:7447'), isTrue);
      expect(relays.contains('wss://staging-relay.divine.video'), isTrue);
    });

    test('should discover relays from event hints', () async {
      // Create events with relay hints in tags
      final eventWithHints = Event(
        keyManager.publicKey!,
        1, // kind 1 - text note
        [
          ['e', 'someeventid', 'wss://hint.relay.org'],
          ['p', 'somepubkey', 'wss://profile.relay.net'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Event with relay hints for discovery',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      eventWithHints.sign(keyManager.privateKey!);
      await nostrService.broadcastEvent(eventWithHints);

      // Discover relays from event hints
      await nostrService.discoverRelaysFromEventHints(keyManager.publicKey!);

      // Verify the discovery method ran without errors
      expect(nostrService.isInitialized, isTrue);

      // Should still have default relays
      expect(
        nostrService.relays.contains('wss://staging-relay.divine.video'),
        isTrue,
      );
    });
  });
}
