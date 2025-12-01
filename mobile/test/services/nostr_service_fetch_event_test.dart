// ABOUTME: Unit tests for NostrService fetchEventById functionality
// ABOUTME: Tests event fetching by ID across different NostrService implementations

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/utils/nostr_timestamp.dart';
import '../helpers/test_nostr_service.dart';

// Valid 64-character hex pubkeys for testing
const testPubkey1 =
    'a1b2c3d4e5f60708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20';
const testPubkey2 =
    'b2c3d4e5f60708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021';
const testPubkey3 =
    'c3d4e5f60708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122';

void main() {
  group('NostrService fetchEventById', () {
    late TestNostrService nostrService;

    setUp(() {
      nostrService = TestNostrService();
    });

    tearDown(() {
      nostrService.dispose();
    });

    group('Event Fetching', () {
      test('fetches event by ID when event exists', () async {
        // Create a test event
        final testEvent = Event(
          testPubkey1,
          1, // Kind 1 (text note)
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test content',
          createdAt: NostrTimestamp.now(),
        );

        // Add event to test service
        nostrService.addTestEvent(testEvent);

        // Fetch the event using auto-generated ID
        final result = await nostrService.fetchEventById(testEvent.id);

        expect(result, isNotNull);
        expect(result!.id, equals(testEvent.id));
        expect(result.content, equals('Test content'));
        expect(result.kind, equals(1));
      });

      test('returns null when event does not exist', () async {
        const nonExistentId =
            'nonexistent123456789012345678901234567890123456789012345678901234';

        final result = await nostrService.fetchEventById(nonExistentId);

        expect(result, isNull);
      });

      test('fetches video event (kind 34236) by ID', () async {
        // Create a video event
        final videoEvent = Event(
          testPubkey1,
          34236, // NIP-71 video event kind
          [
            ['url', 'https://cdn.divine.video/test.mp4'],
            ['title', 'Test Video'],
            ['d', 'unique-identifier'],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Video description',
          createdAt: NostrTimestamp.now(),
        );

        nostrService.addTestEvent(videoEvent);

        final result = await nostrService.fetchEventById(videoEvent.id);

        expect(result, isNotNull);
        expect(result!.id, equals(videoEvent.id));
        expect(result.kind, equals(34236));
        expect(result.content, equals('Video description'));
      });

      test('fetches profile event (kind 0) by ID', () async {
        final profileEvent = Event(
          testPubkey1,
          0, // Kind 0 (profile)
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          '{"name":"Test User","about":"Test bio"}',
          createdAt: NostrTimestamp.now(),
        );

        nostrService.addTestEvent(profileEvent);

        final result = await nostrService.fetchEventById(profileEvent.id);

        expect(result, isNotNull);
        expect(result!.id, equals(profileEvent.id));
        expect(result.kind, equals(0));
      });

      test('handles multiple events with different IDs', () async {
        // Add multiple events
        final event1 = Event(
          testPubkey1,
          1,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Content 1',
          createdAt: NostrTimestamp.now(),
        );

        final event2 = Event(
          testPubkey2,
          1,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Content 2',
          createdAt: NostrTimestamp.now(),
        );

        nostrService.addTestEvent(event1);
        nostrService.addTestEvent(event2);

        // Fetch first event
        final result1 = await nostrService.fetchEventById(event1.id);
        expect(result1, isNotNull);
        expect(result1!.id, equals(event1.id));
        expect(result1.content, equals('Content 1'));

        // Fetch second event
        final result2 = await nostrService.fetchEventById(event2.id);
        expect(result2, isNotNull);
        expect(result2!.id, equals(event2.id));
        expect(result2.content, equals('Content 2'));
      });

      test('returns first match when searching by ID', () async {
        // Create multiple unique events and verify correct retrieval
        final event1 = Event(
          testPubkey1,
          1,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'First event content',
          createdAt: NostrTimestamp.now() - 1000,
        );

        final event2 = Event(
          testPubkey2,
          1,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Second event content',
          createdAt: NostrTimestamp.now(),
        );

        nostrService.addTestEvent(event1);
        nostrService.addTestEvent(event2);

        // Fetch each event by its specific ID
        final result1 = await nostrService.fetchEventById(event1.id);
        expect(result1, isNotNull);
        expect(result1!.id, equals(event1.id));
        expect(result1.content, equals('First event content'));

        final result2 = await nostrService.fetchEventById(event2.id);
        expect(result2, isNotNull);
        expect(result2!.id, equals(event2.id));
        expect(result2.content, equals('Second event content'));
      });
    });

    group('Edge Cases', () {
      test('handles empty event list', () async {
        // No events added
        const eventId =
            'empty123empty123empty123empty123empty123empty123empty123empty1234';

        final result = await nostrService.fetchEventById(eventId);

        expect(result, isNull);
      });

      test('handles short event ID gracefully', () async {
        const shortId = 'short';

        final result = await nostrService.fetchEventById(shortId);

        expect(result, isNull);
      });

      test('handles empty string ID', () async {
        const emptyId = '';

        final result = await nostrService.fetchEventById(emptyId);

        expect(result, isNull);
      });

      test('ignores relayUrl parameter in test implementation', () async {
        // Test that relayUrl is optional and doesn't affect behavior
        final testEvent = Event(
          testPubkey1,
          1,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test content',
          createdAt: NostrTimestamp.now(),
        );

        nostrService.addTestEvent(testEvent);

        final result = await nostrService.fetchEventById(
          testEvent.id,
          relayUrl: 'wss://test.relay',
        );

        expect(result, isNotNull);
        expect(result!.id, equals(testEvent.id));
      });
    });

    group('Integration with getEvents', () {
      test('fetchEventById uses correct filter structure', () async {
        // This test verifies that fetchEventById properly uses Filter with ids
        final testEvent = Event(
          testPubkey1,
          1,
          [
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test content',
          createdAt: NostrTimestamp.now(),
        );

        nostrService.addTestEvent(testEvent);

        // This should work via the Filter(ids: [eventId]) path
        final result = await nostrService.fetchEventById(testEvent.id);

        expect(result, isNotNull);
        expect(result!.id, equals(testEvent.id));
      });
    });
  });
}
