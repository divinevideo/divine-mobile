// ABOUTME: Unit tests for Filter class hashtag ('t' tag) filtering functionality
// ABOUTME: Tests serialization, deserialization, and event filtering with hashtags

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

// Valid hex pubkey for testing
const testPubkey1 =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
const testPubkey2 =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a3';
const testPubkey3 =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a4';

void main() {
  group('Filter hashtag support', () {
    test('should serialize hashtags to JSON with #t key', () {
      final filter = Filter(
        kinds: [22],
        t: ['bitcoin', 'nostr', 'openvine'],
        limit: 10,
      );

      final json = filter.toJson();

      expect(json['kinds'], equals([22]));
      expect(json['#t'], equals(['bitcoin', 'nostr', 'openvine']));
      expect(json['limit'], equals(10));
    });

    test('should not include #t key when hashtags is null', () {
      final filter = Filter(kinds: [22], limit: 10);

      final json = filter.toJson();

      expect(json.containsKey('#t'), false);
      expect(json['kinds'], equals([22]));
      expect(json['limit'], equals(10));
    });

    test('should deserialize hashtags from JSON with #t key', () {
      final json = {
        'kinds': [22],
        '#t': ['bitcoin', 'nostr'],
        'limit': 5,
      };

      final filter = Filter.fromJson(json);

      expect(filter.kinds, equals([22]));
      expect(filter.t, equals(['bitcoin', 'nostr']));
      expect(filter.limit, equals(5));
    });

    test('should handle missing #t key in JSON deserialization', () {
      final json = {
        'kinds': [22],
        'limit': 5,
      };

      final filter = Filter.fromJson(json);

      expect(filter.kinds, equals([22]));
      expect(filter.t, isNull);
      expect(filter.limit, equals(5));
    });

    test('should filter events by hashtags correctly', () {
      final filter = Filter(kinds: [22], t: ['bitcoin', 'nostr']);

      // Event with matching hashtag
      final matchingEvent = Event(
        testPubkey1,
        22,
        [
          ['t', 'bitcoin'],
          ['t', 'crypto'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video about bitcoin',
        createdAt: 1234567890,
      );

      // Event without matching hashtag
      final nonMatchingEvent = Event(
        testPubkey2,
        22,
        [
          ['t', 'ethereum'],
          ['t', 'crypto'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video about ethereum',
        createdAt: 1234567890,
      );

      // Event with no hashtags
      final noHashtagEvent = Event(
        testPubkey3,
        22,
        [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video without hashtags',
        createdAt: 1234567890,
      );

      expect(filter.checkEvent(matchingEvent), true);
      expect(filter.checkEvent(nonMatchingEvent), false);
      expect(filter.checkEvent(noHashtagEvent), false);
    });

    test('should pass all events when no hashtag filter is set', () {
      final filter = Filter(kinds: [22]);

      final event = Event(
        testPubkey1,
        22,
        [
          ['t', 'bitcoin'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video',
        createdAt: 1234567890,
      );

      final eventNoHashtags = Event(
        testPubkey2,
        22,
        [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video without hashtags',
        createdAt: 1234567890,
      );

      expect(filter.checkEvent(event), true);
      expect(filter.checkEvent(eventNoHashtags), true);
    });

    test('should filter events with multiple hashtag matches', () {
      final filter = Filter(kinds: [22], t: ['bitcoin', 'nostr', 'openvine']);

      final multipleHashtagEvent = Event(
        testPubkey1,
        22,
        [
          ['t', 'bitcoin'],
          ['t', 'nostr'],
          ['t', 'crypto'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video with multiple hashtags',
        createdAt: 1234567890,
      );

      expect(filter.checkEvent(multipleHashtagEvent), true);
    });

    test('should handle malformed tags gracefully', () {
      final filter = Filter(kinds: [22], t: ['bitcoin']);

      final malformedTagEvent = Event(
        testPubkey1,
        22,
        [
          ['t'], // Missing value
          ['t', 'bitcoin'], // Valid tag
          'not_a_list', // Invalid tag format
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video with malformed tags',
        createdAt: 1234567890,
      );

      expect(filter.checkEvent(malformedTagEvent), true);
    });
  });
}
