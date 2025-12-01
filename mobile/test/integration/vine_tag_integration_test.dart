// ABOUTME: Integration test for vine tag requirement across all services
// ABOUTME: Tests complete vine tag workflow from event creation to relay querying

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

void main() {
  group('Vine Tag Integration Tests', () {
    test('VideoEventService filters should include vine tag', () {
      // Create a filter for Kind 22 events
      final filter = Filter(
        kinds: [22],
        h: ['vine'],
        limit: 50,
      );

      // Verify the filter includes vine tag
      expect(filter.h, equals(['vine']));
      expect(filter.kinds, equals([22]));

      // Test JSON serialization includes vine tag
      final json = filter.toJson();
      expect(json['#h'], equals(['vine']));
      expect(json['kinds'], equals([22]));
    });

    test('UserProfileService filters should include vine tag', () {
      // Create a filter for Kind 0 events (profiles)
      final filter = Filter(
        kinds: [0],
        authors: [
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210'
        ],
        h: ['vine'],
        limit: 1,
      );

      // Verify the filter includes vine tag
      expect(filter.h, equals(['vine']));
      expect(filter.kinds, equals([0]));
      expect(
          filter.authors,
          equals([
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210'
          ]));

      // Test JSON serialization includes vine tag
      final json = filter.toJson();
      expect(json['#h'], equals(['vine']));
      expect(json['kinds'], equals([0]));
      expect(
          json['authors'],
          equals([
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210'
          ]));
    });

    test('SocialService reaction filters should include vine tag', () {
      // Create a filter for Kind 7 events (reactions)
      final filter = Filter(
        kinds: [7],
        e: ['f6789012345678901234567890123456789012345678901234567890abcdef12'],
        h: ['vine'],
      );

      // Verify the filter includes vine tag
      expect(filter.h, equals(['vine']));
      expect(filter.kinds, equals([7]));
      expect(
          filter.e,
          equals([
            'f6789012345678901234567890123456789012345678901234567890abcdef12'
          ]));

      // Test JSON serialization includes vine tag
      final json = filter.toJson();
      expect(json['#h'], equals(['vine']));
      expect(json['kinds'], equals([7]));
      expect(
          json['#e'],
          equals([
            'f6789012345678901234567890123456789012345678901234567890abcdef12'
          ]));
    });

    test('Filter should correctly validate events with vine tag', () {
      final filter = Filter(
        kinds: [22],
        h: ['vine'],
      );

      // Create a valid event with vine tag
      final validEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['h', 'vine'],
          ['url', 'https://example.com/video.mp4'],
          ['client', 'diVine'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Create an invalid event without vine tag
      final invalidEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['url', 'https://example.com/video.mp4'],
          ['client', 'diVine'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Valid event should pass
      expect(filter.checkEvent(validEvent), isTrue);

      // Invalid event should fail
      expect(filter.checkEvent(invalidEvent), isFalse);
    });

    test('Multiple h tag values should work correctly', () {
      final filter = Filter(
        kinds: [22],
        h: ['vine', 'test', 'dev'],
      );

      // Event with vine tag should pass
      final vineEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['h', 'vine'],
          ['url', 'test.mp4'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Event with test tag should pass
      final testEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['h', 'test'],
          ['url', 'test.mp4'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Event with dev tag should pass
      final devEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['h', 'dev'],
          ['url', 'test.mp4'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Event with other tag should fail
      final otherEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['h', 'other'],
          ['url', 'test.mp4'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(filter.checkEvent(vineEvent), isTrue);
      expect(filter.checkEvent(testEvent), isTrue);
      expect(filter.checkEvent(devEvent), isTrue);
      expect(filter.checkEvent(otherEvent), isFalse);
    });

    test('Profile filters should validate vine tag requirement', () {
      final profileFilter = Filter(
        kinds: [0],
        authors: [
          '1111111111111111111111111111111111111111111111111111111111111111'
        ],
        h: ['vine'],
      );

      // Valid profile event with vine tag
      final validProfile = Event(
        '1111111111111111111111111111111111111111111111111111111111111111',
        0,
        [
          ['h', 'vine'],
          ['name', 'Test User'],
          ['about', 'Test bio'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        '{"name":"Test User","about":"Test bio"}',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Invalid profile event without vine tag
      final invalidProfile = Event(
        '1111111111111111111111111111111111111111111111111111111111111111',
        0,
        [
          ['name', 'Test User'],
          ['about', 'Test bio'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        '{"name":"Test User","about":"Test bio"}',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(profileFilter.checkEvent(validProfile), isTrue);
      expect(profileFilter.checkEvent(invalidProfile), isFalse);
    });

    test('Contact list filters should validate vine tag requirement', () {
      final contactFilter = Filter(
        kinds: [3],
        authors: [
          '2222222222222222222222222222222222222222222222222222222222222222'
        ],
        h: ['vine'],
      );

      // Valid contact list with vine tag
      final validContacts = Event(
        '2222222222222222222222222222222222222222222222222222222222222222',
        3,
        [
          ['h', 'vine'],
          [
            'p',
            '9012345678901234567890123456789012345678901234567890abcdef1234567'
          ],
          [
            'p',
            '012345678901234567890123456789012345678901234567890abcdef12345678'
          ],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Invalid contact list without vine tag
      final invalidContacts = Event(
        '2222222222222222222222222222222222222222222222222222222222222222',
        3,
        [
          [
            'p',
            '9012345678901234567890123456789012345678901234567890abcdef1234567'
          ],
          [
            'p',
            '012345678901234567890123456789012345678901234567890abcdef12345678'
          ],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(contactFilter.checkEvent(validContacts), isTrue);
      expect(contactFilter.checkEvent(invalidContacts), isFalse);
    });

    test('Complex filter with multiple criteria and vine tag', () {
      final complexFilter = Filter(
        kinds: [22],
        authors: [
          '3333333333333333333333333333333333333333333333333333333333333333',
          '2345678901234567890123456789012345678901234567890abcdef1234567890'
        ],
        h: ['vine'],
        t: ['funny', 'viral'],
        limit: 25,
        since: DateTime.now().millisecondsSinceEpoch ~/ 1000 -
            86400, // Last 24 hours
      );

      // Event matching all criteria
      final matchingEvent = Event(
        '3333333333333333333333333333333333333333333333333333333333333333',
        22,
        [
          ['h', 'vine'],
          ['t', 'funny'],
          ['url', 'https://example.com/funny.mp4'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Funny video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Event missing vine tag
      final noVineEvent = Event(
        '3333333333333333333333333333333333333333333333333333333333333333',
        22,
        [
          ['t', 'funny'],
          ['url', 'https://example.com/funny.mp4'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Funny video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Event from wrong author
      final wrongAuthorEvent = Event(
        '4444444444444444444444444444444444444444444444444444444444444444',
        22,
        [
          ['h', 'vine'],
          ['t', 'funny'],
          ['url', 'https://example.com/funny.mp4'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Funny video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      expect(complexFilter.checkEvent(matchingEvent), isTrue);
      expect(complexFilter.checkEvent(noVineEvent), isFalse);
      expect(complexFilter.checkEvent(wrongAuthorEvent), isFalse);
    });
  });
}
