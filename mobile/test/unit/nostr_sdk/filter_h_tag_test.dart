// ABOUTME: Test that nostr_sdk Filter class properly supports h tag filtering
// ABOUTME: Verifies the extended Filter functionality for staging-relay.divine.video relay compatibility

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

void main() {
  group('Filter h tag support', () {
    test('Filter constructor should accept h parameter', () {
      final filter = Filter(kinds: [22], h: ['vine']);

      expect(filter.h, equals(['vine']));
      expect(filter.kinds, equals([22]));
    });

    test('Filter toJson should include h tag', () {
      final filter = Filter(kinds: [22], h: ['vine'], limit: 50);

      final json = filter.toJson();

      expect(json['kinds'], equals([22]));
      expect(json['#h'], equals(['vine']));
      expect(json['limit'], equals(50));
    });

    test('Filter fromJson should parse h tag', () {
      final json = {
        'kinds': [0, 22],
        '#h': ['vine'],
        'limit': 100,
      };

      final filter = Filter.fromJson(json);

      expect(filter.kinds, equals([0, 22]));
      expect(filter.h, equals(['vine']));
      expect(filter.limit, equals(100));
    });

    test('Filter checkEvent should validate h tag', () {
      final filter = Filter(kinds: [22], h: ['vine']);

      // Event with vine tag should pass
      final eventWithVineTag = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['h', 'vine'],
          ['url', 'https://example.com/video.mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithVineTag), isTrue);

      // Event without vine tag should fail
      final eventWithoutVineTag = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithoutVineTag), isFalse);

      // Event with different h tag should fail
      final eventWithDifferentHTag = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['h', 'other'],
          ['url', 'https://example.com/video.mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithDifferentHTag), isFalse);
    });

    test('Filter checkEvent should work with multiple h values', () {
      final filter = Filter(kinds: [22], h: ['vine', 'test']);

      // Event with vine tag should pass
      final eventWithVineTag = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        22,
        [
          ['h', 'vine'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithVineTag), isTrue);

      // Event with test tag should pass
      final eventWithTestTag = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        22,
        [
          ['h', 'test'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithTestTag), isTrue);

      // Event with other tag should fail
      final eventWithOtherTag = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        22,
        [
          ['h', 'other'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithOtherTag), isFalse);
    });

    test('Filter checkEvent should pass when h filter is not specified', () {
      final filter = Filter(kinds: [22]);

      // Event without h tag should pass when filter doesn't specify h
      final eventWithoutHTag = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        22,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithoutHTag), isTrue);

      // Event with h tag should also pass when filter doesn't specify h
      final eventWithHTag = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        22,
        [
          ['h', 'vine'],
          ['url', 'https://example.com/video.mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(eventWithHTag), isTrue);
    });

    test('Filter should work with combination of h tag and other filters', () {
      final filter = Filter(
        kinds: [22],
        authors: [
          '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        ],
        h: ['vine'],
      );

      // Event matching all criteria should pass
      final matchingEvent = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        22,
        [
          ['h', 'vine'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(matchingEvent), isTrue);

      // Event with wrong author should fail
      final wrongAuthorEvent = Event(
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        22,
        [
          ['h', 'vine'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(wrongAuthorEvent), isFalse);

      // Event without vine tag should fail
      final noVineTagEvent = Event(
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        22,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(noVineTagEvent), isFalse);
    });
  });
}
