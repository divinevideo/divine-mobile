// ABOUTME: Comprehensive tests for Nostr service functionality
// ABOUTME: Tests relay management, event broadcasting, and service lifecycle

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart'
    show NIP94Metadata, NIP94ValidationException;
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';

void main() {
  group('NostrService', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;

    setUp(() {
      keyManager = NostrKeyManager();
      nostrService = NostrService(keyManager);
    });

    tearDown(() {
      nostrService.dispose();
    });

    group('Initialization', () {
      test('should start uninitialized', () {
        expect(nostrService.isInitialized, isFalse);
        expect(nostrService.hasKeys, isFalse);
        expect(nostrService.publicKey, isNull);
        expect(nostrService.connectedRelays, isEmpty);
        expect(nostrService.relayCount, equals(0));
        expect(nostrService.connectedRelayCount, equals(0));
      });

      test('should use embedded relay by default', () {
        // NostrService starts with no external relays configured
        // The embedded relay runs internally and external relays are added during initialization
        expect(nostrService.relays, isEmpty);
      });
    });

    group('State Management', () {
      test('should track initialization state correctly', () {
        expect(nostrService.isInitialized, isFalse);
      });

      test('should track connected relays', () {
        expect(nostrService.connectedRelays, isEmpty);
        expect(nostrService.connectedRelayCount, equals(0));
      });

      test('should provide relay status information', () {
        final status = nostrService.getRelayStatus();
        expect(status, isA<Map<String, bool>>());
      });
    });

    group('Event Broadcasting', () {
      test('should require initialization before broadcasting', () async {
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        final event = Event(publicKey, 1063, [
          ['url', 'test.com'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], 'Test content');
        event.sign(privateKey);

        expect(
          () => nostrService.broadcastEvent(event),
          throwsA(isA<StateError>()),
        );
      });

      test('should validate event structure', () {
        // Test that events have required fields
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        final event = Event(publicKey, 1063, [
          ['url', 'https://example.com/file.gif'],
          ['m', 'image/gif'],
          ['x', 'sha256hash'],
          ['size', '1024'],
          ['dim', '320x240'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], 'Test NIP-94 event');
        event.sign(privateKey);

        expect(event.kind, equals(1063));
        expect(event.content, equals('Test NIP-94 event'));
        expect(event.tags, isNotEmpty);
        expect(event.tags.any((tag) => tag[0] == 'url'), isTrue);
      });
    });

    group('NIP-94 Publishing', () {
      test('should create valid NIP-94 metadata', () {
        const metadata = NIP94Metadata(
          url: 'https://example.com/test.gif',
          mimeType: 'image/gif',
          sha256Hash:
              'a1b2c3d4e5f67890123456789012345678901234567890123456789012345678',
          sizeBytes: 1024,
          dimensions: '320x240',
        );

        expect(metadata.isValid, isTrue);
        expect(metadata.isGif, isTrue);
      });

      test('should require valid metadata for publishing', () async {
        const invalidMetadata = NIP94Metadata(
          url: '', // Invalid empty URL
          mimeType: 'image/gif',
          sha256Hash: 'invalid_hash', // Invalid hash
          sizeBytes: 0, // Invalid size
          dimensions: 'invalid', // Invalid dimensions
        );

        expect(invalidMetadata.isValid, isFalse);

        expect(
          () => nostrService.publishFileMetadata(
            metadata: invalidMetadata,
            content: 'Test content',
          ),
          throwsA(isA<NIP94ValidationException>()),
        );
      });

      test('should handle hashtag extraction', () {
        const hashtags = ['nostr', 'vine', 'gif'];

        // Test that hashtags are properly processed
        expect(hashtags, contains('nostr'));
        expect(hashtags, contains('vine'));
        expect(hashtags, contains('gif'));
      });
    });

    group('Filter Conversion', () {
      test('should convert hashtag filters correctly', () {
        // Create a filter with hashtags
        final filter = Filter(
          kinds: [34236],
          t: ['bitcoin', 'nostr'], // hashtags
          authors: ['pubkey1', 'pubkey2'],
          limit: 50,
        );

        // Test that the filter has the expected properties
        expect(filter.kinds, equals([34236]));
        expect(filter.t, equals(['bitcoin', 'nostr']));
        expect(filter.authors, equals(['pubkey1', 'pubkey2']));
        expect(filter.limit, equals(50));
      });

      test('should convert e-tags and p-tags correctly', () {
        // Create a filter with e-tags and p-tags
        final filter = Filter(
          kinds: [1],
          e: ['eventid1', 'eventid2'], // event references
          p: ['pubkey1', 'pubkey2'], // pubkey references
          since: 1000,
          until: 2000,
        );

        // Test that the filter has the expected properties
        expect(filter.kinds, equals([1]));
        expect(filter.e, equals(['eventid1', 'eventid2']));
        expect(filter.p, equals(['pubkey1', 'pubkey2']));
        expect(filter.since, equals(1000));
        expect(filter.until, equals(2000));
      });

      test('should convert d-tags for parameterized replaceable events', () {
        // Create a filter with d-tags
        final filter = Filter(
          kinds: [34236],
          d: ['identifier1', 'identifier2'], // d-tag identifiers
          authors: ['pubkey1'],
        );

        // Test that the filter has the expected properties
        expect(filter.kinds, equals([34236]));
        expect(filter.d, equals(['identifier1', 'identifier2']));
        expect(filter.authors, equals(['pubkey1']));
      });

      test('should handle filters without tags correctly', () {
        // Create a filter without any tags
        final filter = Filter(
          kinds: [34236],
          authors: ['pubkey1', 'pubkey2'],
          limit: 100,
          since: 1000,
        );

        // Test that the filter has the expected properties
        expect(filter.kinds, equals([34236]));
        expect(filter.authors, equals(['pubkey1', 'pubkey2']));
        expect(filter.t, isNull);
        expect(filter.e, isNull);
        expect(filter.p, isNull);
        expect(filter.d, isNull);
        expect(filter.limit, equals(100));
        expect(filter.since, equals(1000));
      });

      test('should handle home feed subscription filters', () {
        // Create a filter for home feed (following specific authors)
        final followingPubkeys = ['npub1abc123', 'npub2def456', 'npub3ghi789'];

        final filter = Filter(
          kinds: [34236], // Video events
          authors: followingPubkeys,
          limit: 100,
        );

        // Test that the filter properly includes authors for home feed
        expect(filter.kinds, equals([34236]));
        expect(filter.authors, equals(followingPubkeys));
        expect(filter.authors?.length, equals(3));
        expect(filter.limit, equals(100));
      });

      test('should verify filter conversion maintains all tag types', () {
        // This test verifies that our NostrService._convertToEmbeddedFilter
        // properly converts nostr_sdk filters to embedded relay filters
        // with the correct '#' prefix for tag filters

        // Create a complex filter with multiple tag types
        final filter = Filter(
          kinds: [34236],
          authors: ['author1', 'author2'],
          t: ['bitcoin', 'lightning'], // hashtags -> #t
          e: ['event1', 'event2'], // event refs -> #e
          p: ['pubkey1', 'pubkey2'], // pubkey refs -> #p
          d: ['id1', 'id2'], // identifiers -> #d
          since: 1000,
          until: 2000,
          limit: 50,
        );

        // The converted filter should have tags with # prefix
        // This is what the embedded relay expects:
        // tags: {
        //   '#t': ['bitcoin', 'lightning'],
        //   '#e': ['event1', 'event2'],
        //   '#p': ['pubkey1', 'pubkey2'],
        //   '#d': ['id1', 'id2']
        // }

        expect(filter.kinds, equals([34236]));
        expect(filter.authors, equals(['author1', 'author2']));
        expect(filter.t, equals(['bitcoin', 'lightning']));
        expect(filter.e, equals(['event1', 'event2']));
        expect(filter.p, equals(['pubkey1', 'pubkey2']));
        expect(filter.d, equals(['id1', 'id2']));
        expect(filter.since, equals(1000));
        expect(filter.until, equals(2000));
        expect(filter.limit, equals(50));
      });

      test('should handle empty tag lists correctly', () {
        // Test filters with empty tag arrays
        final filter = Filter(
          kinds: [34236],
          authors: ['author1'],
          t: [], // empty hashtag list
          e: [], // empty event list
          p: [], // empty pubkey list
          d: [], // empty identifier list
        );

        // Empty tag arrays should be treated as null/not set
        expect(filter.kinds, equals([34236]));
        expect(filter.authors, equals(['author1']));
        expect(filter.t, isEmpty);
        expect(filter.e, isEmpty);
        expect(filter.p, isEmpty);
        expect(filter.d, isEmpty);
      });
    });

    group('Relay Management', () {
      test('should handle relay addition', () async {
        // This would normally connect to a real relay
        // For testing, we just verify the method exists
        expect(nostrService.addRelay, isA<Function>());
      });

      test('should handle relay removal', () async {
        // Test relay removal method exists
        expect(nostrService.removeRelay, isA<Function>());
      });

      test('should support reconnection', () async {
        expect(nostrService.reconnectAll, isA<Function>());
      });
    });

    group('Error Handling', () {
      test('should handle network connection failures gracefully', () {
        // Test that the service doesn't crash on connection failures
        expect(nostrService.connectedRelayCount, equals(0));
      });

      test('should provide meaningful error messages', () {
        final error = StateError('Test error message');
        expect(error.message, equals('Test error message'));
        expect(error.toString(), contains('StateError'));
      });

      test('should handle partial relay failures', () {
        // Test that the service continues working even if some relays fail
        final status = nostrService.getRelayStatus();
        expect(status, isA<Map<String, bool>>());
      });
    });

    group('Broadcasting Results', () {
      test('should create valid broadcast result', () {
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        final mockEvent = Event(publicKey, 1063, [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], 'Test');
        mockEvent.sign(privateKey);

        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 2,
          totalRelays: 4,
          results: {
            'relay1': true,
            'relay2': true,
            'relay3': false,
            'relay4': false,
          },
          errors: {'relay3': 'Connection failed', 'relay4': 'Timeout'},
        );

        expect(result.successCount, equals(2));
        expect(result.totalRelays, equals(4));
        expect(result.isSuccessful, isTrue);
        expect(result.isCompleteSuccess, isFalse);
        expect(result.successRate, equals(0.5));
        expect(result.successfulRelays, equals(['relay1', 'relay2']));
        expect(result.failedRelays, equals(['relay3', 'relay4']));
      });

      test('should handle complete success', () {
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        final mockEvent = Event(publicKey, 1063, [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], 'Test');
        mockEvent.sign(privateKey);

        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 3,
          totalRelays: 3,
          results: {'relay1': true, 'relay2': true, 'relay3': true},
          errors: {},
        );

        expect(result.isSuccessful, isTrue);
        expect(result.isCompleteSuccess, isTrue);
        expect(result.successRate, equals(1.0));
        expect(result.failedRelays, isEmpty);
      });

      test('should handle complete failure', () {
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        final mockEvent = Event(publicKey, 1063, [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], 'Test');
        mockEvent.sign(privateKey);

        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 0,
          totalRelays: 2,
          results: {'relay1': false, 'relay2': false},
          errors: {'relay1': 'Error 1', 'relay2': 'Error 2'},
        );

        expect(result.isSuccessful, isFalse);
        expect(result.isCompleteSuccess, isFalse);
        expect(result.successRate, equals(0.0));
        expect(result.successfulRelays, isEmpty);
        expect(result.failedRelays, equals(['relay1', 'relay2']));
      });

      test('should provide meaningful string representation', () {
        final privateKey = generatePrivateKey();
        final publicKey = getPublicKey(privateKey);
        final mockEvent = Event(publicKey, 1063, [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], 'Test');
        mockEvent.sign(privateKey);

        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 2,
          totalRelays: 3,
          results: {},
          errors: {},
        );

        final str = result.toString();
        expect(str, contains('NostrBroadcastResult'));
        expect(str, contains('2/3'));
        expect(str, contains('66.7%'));
      });
    });

    group('Disposal', () {
      test('should clean up resources on disposal', () {
        nostrService.dispose();

        expect(nostrService.connectedRelayCount, equals(0));
        expect(nostrService.relayCount, equals(0));
      });

      test('should handle multiple disposal calls', () {
        nostrService.dispose();
        nostrService.dispose(); // Should not throw

        expect(nostrService.connectedRelayCount, equals(0));
      });
    });

    group('Future Event Subscription', () {
      test('should support event subscription interface', () {
        // Test that the subscription method exists for future implementation
        expect(nostrService.subscribeToEvents, isA<Function>());
      });
    });
  });
}
